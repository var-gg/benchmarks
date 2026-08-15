// Reconstructed fixture generator (backfill).
//
// Writes the representative benchmark app used on 2026-06-18: a React 19
// dashboard with 24 chart component modules, each pulling in a recharts chart
// + a lucide-react icon, so the module graph and the bundler workload match
// what was measured. Deterministic: same output every run.
//
//   node gen-app.mjs <targetDir>
//
// run.sh calls this once per Vite version into a clean project dir, then only
// the vite + @vitejs/plugin-react versions differ between the two trees.

import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const target = process.argv[2];
if (!target) {
  console.error("usage: node gen-app.mjs <targetDir>");
  process.exit(1);
}

const N = 24; // 24 chart component modules — matches the recorded bench
const CHARTS = ["LineChart", "AreaChart", "BarChart"]; // rotate across modules
const ICONS = ["Activity", "TrendingUp", "BarChart3", "PieChart"]; // lucide-react

const srcDir = join(target, "src");
const compDir = join(srcDir, "components");
mkdirSync(compDir, { recursive: true });

// 24 chart components. Each imports a recharts chart family + a lucide icon so
// the dependency graph is non-trivial and representative of a real dashboard.
const names = [];
for (let i = 0; i < N; i++) {
  const name = `Panel${String(i).padStart(2, "0")}`;
  names.push(name);
  const chart = CHARTS[i % CHARTS.length];
  const series = chart === "BarChart" ? "Bar" : chart === "AreaChart" ? "Area" : "Line";
  const icon = ICONS[i % ICONS.length];
  writeFileSync(
    join(compDir, `${name}.jsx`),
    `import { ${chart}, ${series}, XAxis, YAxis, Tooltip, ResponsiveContainer } from "recharts";
import { ${icon} } from "lucide-react";

const data = Array.from({ length: 12 }, (_, k) => ({ x: k, y: ((k * ${i + 1}) % 17) + 3 }));

export default function ${name}() {
  return (
    <div className="panel">
      <h3><${icon} size={16} /> ${name}</h3>
      <ResponsiveContainer width="100%" height={160}>
        <${chart} data={data}>
          <XAxis dataKey="x" />
          <YAxis />
          <Tooltip />
          <${series} dataKey="y" />
        </${chart}>
      </ResponsiveContainer>
    </div>
  );
}
`
  );
}

const imports = names.map((n) => `import ${n} from "./components/${n}.jsx";`).join("\n");
const grid = names.map((n) => `      <${n} />`).join("\n");
writeFileSync(
  join(srcDir, "App.jsx"),
  `${imports}

export default function App() {
  return (
    <main className="grid">
${grid}
    </main>
  );
}
`
);

writeFileSync(
  join(srcDir, "main.jsx"),
  `import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import App from "./App.jsx";

createRoot(document.getElementById("root")).render(
  <StrictMode>
    <App />
  </StrictMode>
);
`
);

writeFileSync(
  join(target, "index.html"),
  `<!doctype html>
<html>
  <head><meta charset="utf-8" /><title>vite-bench</title></head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
`
);

console.log(`generated ${N} chart components into ${target}`);
