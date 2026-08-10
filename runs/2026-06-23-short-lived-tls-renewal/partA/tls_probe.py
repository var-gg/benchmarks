#!/usr/bin/env python3
"""Part A probe: stand up a TLS server with a short-lived cert, then probe the
handshake BEFORE and AFTER the cert's NotAfter to capture the exact moment a
stalled renewal turns into a hard client failure. Deterministic, localhost-only."""
import os, ssl, socket, subprocess, threading, time, datetime, sys

HERE = os.path.dirname(os.path.abspath(__file__))
os.environ["MSYS_NO_PATHCONV"] = "1"
CA_CRT = os.path.join(HERE, "ca.crt")
CA_KEY = os.path.join(HERE, "ca.key")
LEAF_KEY = os.path.join(HERE, "leaf.key")
LEAF_CRT = os.path.join(HERE, "leaf_probe.crt")
LEAF_CSR = os.path.join(HERE, "leaf.csr")
EXT = os.path.join(HERE, "leaf.ext")
LIFE = 20  # seconds

def sh(*a):
    return subprocess.run(a, cwd=HERE, capture_output=True, text=True)

# Re-mint a fresh leaf valid now-3s .. now+LIFE, signed by the existing local CA.
now = datetime.datetime.now(datetime.timezone.utc)
nb = (now - datetime.timedelta(seconds=3)).strftime("%Y%m%d%H%M%SZ")
na = (now + datetime.timedelta(seconds=LIFE)).strftime("%Y%m%d%H%M%SZ")
r = sh("openssl", "x509", "-req", "-in", LEAF_CSR, "-CA", CA_CRT, "-CAkey", CA_KEY,
       "-CAcreateserial", "-not_before", nb, "-not_after", na,
       "-extfile", EXT, "-sha256", "-out", LEAF_CRT)
if r.returncode != 0:
    print("mint failed:", r.stderr); sys.exit(1)

na_epoch = int((now + datetime.timedelta(seconds=LIFE)).timestamp())
print(f"[mint] fresh leaf: lifetime={LIFE}s NotAfter_epoch={na_epoch}")

# TLS server thread
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain(LEAF_CRT, LEAF_KEY)
srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(("127.0.0.1", 0)); PORT = srv.getsockname()[1]; srv.listen(8)
print(f"[server] listening 127.0.0.1:{PORT} with the short-lived cert")
stop = False
def serve():
    srv.settimeout(1.0)
    while not stop:
        try: c, _ = srv.accept()
        except socket.timeout: continue
        except OSError: break
        try:
            s = ctx.wrap_socket(c, server_side=True); s.close()
        except Exception:
            try: c.close()
            except Exception: pass
threading.Thread(target=serve, daemon=True).start()

def probe(label):
    """A picky client (verify against our CA, hostname check) — like a real browser/curl."""
    cctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    cctx.load_verify_locations(CA_CRT)
    cctx.check_hostname = True
    cctx.verify_mode = ssl.CERT_REQUIRED
    try:
        with socket.create_connection(("127.0.0.1", PORT), timeout=3) as raw:
            with cctx.wrap_socket(raw, server_hostname="localhost") as s:
                cert = s.getpeercert()
                print(f"[{label}] HANDSHAKE OK  (NotAfter={cert.get('notAfter')})")
                return True
    except ssl.SSLCertVerificationError as e:
        print(f"[{label}] HANDSHAKE FAILED  verify_code={e.verify_code} reason={e.verify_message!r}")
        return False
    except Exception as e:
        print(f"[{label}] HANDSHAKE FAILED  {type(e).__name__}: {e}")
        return False

# Probe 1: while valid
print("\n--- T0: renewal is healthy, cert is fresh ---")
ok1 = probe("valid")

# Probe 2: simulate a stalled renewal — we simply DON'T renew, and wait past NotAfter.
wait = na_epoch - int(time.time()) + 3
print(f"\n--- simulating a STALLED renewal: nothing renews; waiting {wait}s past NotAfter ---")
time.sleep(max(0, wait))
ok2 = probe("expired")

stop = True
try: srv.close()
except Exception: pass
print("\n=== RESULT ===")
print(f"before expiry: {'OK' if ok1 else 'FAIL'}   after expiry (renewal stalled): {'OK' if ok2 else 'FAIL'}")
print("interpretation: the cert lifetime is a hard deadline. The instant renewal")
print("stalls past NotAfter, every verifying client breaks at the TLS handshake —")
print("no grace period. That is the 'conveyor belt that jams', not a calendar reminder.")
