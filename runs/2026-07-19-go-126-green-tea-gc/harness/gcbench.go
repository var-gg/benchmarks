// gcbench — a firsthand A/B for Go 1.26's Green Tea garbage collector.
//
// The SAME binary is built twice:
//   default                       -> Green Tea GC (Go 1.26 default)
//   GOEXPERIMENT=nogreenteagc     -> the pre-1.26 (classic) GC
// and run across three heap SHAPES, because the Go team's own note says the win is
// "10-40% ... in programs that heavily use the GC" with high-fanout structures
// benefiting most — and third parties disagree (tile38 ~35% vs DoltHub ~neutral).
// This harness is designed to make that disagreement legible by varying fanout.
//
// Headline metric: runtime.MemStats.GCCPUFraction — the fraction of total process
// CPU spent in GC since start (the standard "GC overhead" proxy). We also report
// GC count, total pause, and wall time. Deterministic: fixed sizes, seeded PRNG.
//
// Usage: gcbench <tree|graph|flat> [live_mb] [churn_iters]
package main

import (
	"fmt"
	"math/rand"
	"os"
	"runtime"
	"runtime/debug"
	"strconv"
	"time"
)

// small pointer-heavy node: three child pointers + a little payload.
// Small objects with pointers are exactly what Green Tea's scanner targets.
type node struct {
	l, m, r *node
	v       int64
}

// buildTree makes a full ternary tree until it has ~n nodes. Pointer-dense.
func buildTree(n int) *node {
	if n <= 0 {
		return nil
	}
	root := &node{v: int64(n)}
	q := []*node{root}
	made := 1
	for made < n && len(q) > 0 {
		cur := q[0]
		q = q[1:]
		for _, slot := range []**node{&cur.l, &cur.m, &cur.r} {
			if made >= n {
				break
			}
			c := &node{v: int64(made)}
			*slot = c
			q = append(q, c)
			made++
		}
	}
	return root
}

// buildGraph makes n small nodes each pointing at 3 random others: high fan-out,
// many inter-object pointers (the worst case for a scanning GC).
func buildGraph(n int, rng *rand.Rand) []*node {
	g := make([]*node, n)
	for i := range g {
		g[i] = &node{v: int64(i)}
	}
	for i := range g {
		g[i].l = g[rng.Intn(n)]
		g[i].m = g[rng.Intn(n)]
		g[i].r = g[rng.Intn(n)]
	}
	return g
}

func main() {
	shape := "tree"
	if len(os.Args) > 1 {
		shape = os.Args[1]
	}
	liveMB := 400
	if len(os.Args) > 2 {
		liveMB, _ = strconv.Atoi(os.Args[2])
	}
	churn := 60
	if len(os.Args) > 3 {
		churn, _ = strconv.Atoi(os.Args[3])
	}

	// node is 4 words on amd64 (3 ptr + 1 int64) = 32 bytes.
	const nodeBytes = 32
	nLive := liveMB * 1024 * 1024 / nodeBytes
	rng := rand.New(rand.NewSource(42)) // deterministic

	debug.SetGCPercent(100) // pin GOGC so both builds see identical pressure

	// ---- build a persistent live heap of the chosen shape ----
	var liveTree *node
	var liveGraph []*node
	var liveFlat [][]int64
	switch shape {
	case "tree":
		liveTree = buildTree(nLive)
	case "graph":
		liveGraph = buildGraph(nLive, rng)
	case "flat":
		// low-fanout: big pointer-free int64 slabs, few pointers to scan.
		slab := 1 << 20 // 1M int64 = 8MB per slab
		nSlabs := liveMB * 1024 * 1024 / (slab * 8)
		liveFlat = make([][]int64, nSlabs)
		for i := range liveFlat {
			s := make([]int64, slab)
			for j := range s {
				s[j] = int64(j)
			}
			liveFlat[i] = s
		}
	default:
		fmt.Fprintln(os.Stderr, "unknown shape:", shape)
		os.Exit(2)
	}

	runtime.GC() // settle before measuring
	var m0 runtime.MemStats
	runtime.ReadMemStats(&m0)
	t0 := time.Now()

	// ---- churn: allocate + drop garbage of the same shape to force GC cycles
	//      over the live heap. This is the "heavily uses the GC" regime. ----
	var sink int64
	for it := 0; it < churn; it++ {
		switch shape {
		case "tree":
			g := buildTree(nLive / 4)
			sink += g.v
		case "graph":
			g := buildGraph(nLive/4, rng)
			sink += g[0].v
		case "flat":
			s := make([]int64, nLive) // one big pointer-free garbage slab
			s[it%len(s)] = int64(it)
			sink += s[it%len(s)]
		}
	}

	wall := time.Since(t0)
	var m1 runtime.MemStats
	runtime.ReadMemStats(&m1)

	// keep live set reachable past measurement
	switch shape {
	case "tree":
		if liveTree != nil {
			sink += liveTree.v
		}
	case "graph":
		sink += liveGraph[0].v
	case "flat":
		sink += liveFlat[0][0]
	}

	greentea := "on(default)"
	if v := os.Getenv("GCBENCH_LABEL"); v != "" {
		greentea = v
	}

	fmt.Printf("{\"shape\":%q,\"gc\":%q,\"live_mb\":%d,\"churn\":%d,"+
		"\"gomaxprocs\":%d,\"num_gc\":%d,\"gc_cpu_fraction\":%.5f,"+
		"\"pause_total_ms\":%.2f,\"wall_ms\":%.1f,\"heap_sys_mb\":%.0f,\"sink\":%d}\n",
		shape, greentea, liveMB, churn,
		runtime.GOMAXPROCS(0),
		m1.NumGC-m0.NumGC,
		m1.GCCPUFraction,
		float64(m1.PauseTotalNs-m0.PauseTotalNs)/1e6,
		wall.Seconds()*1000,
		float64(m1.HeapSys)/(1024*1024),
		sink)
}
