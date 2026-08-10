#!/usr/bin/env python3
"""Part B — drive a real ACME order against a local pebble CA using its
`shortlived` profile, then ask the CA's ARI (ACME Renewal Information) endpoint
WHEN to renew. Demonstrates the mechanism that replaces fixed-interval cron.

Pure-Python ACME (ES256 JWS) so there are no extra deps beyond cryptography+requests.
Pebble runs with PEBBLE_VA_ALWAYS_VALID=1 so challenge validation is auto-satisfied;
we still walk the full order/authz/challenge/finalize state machine.
"""
import base64, json, time, sys, requests
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature
from cryptography import x509
from cryptography.x509.oid import NameOID, ExtensionOID

requests.packages.urllib3.disable_warnings()
DIR = "https://localhost:14000/dir"
S = requests.Session(); S.verify = False
DOMAIN = "shortlived.example.test"

def b64(b): return base64.urlsafe_b64encode(b).rstrip(b"=").decode()

# ---- account key (EC P-256) + JWK ----
acct_key = ec.generate_private_key(ec.SECP256R1())
nums = acct_key.public_key().public_numbers()
def i2b(i): return i.to_bytes(32, "big")
JWK = {"crv": "P-256", "kty": "EC", "x": b64(i2b(nums.x)), "y": b64(i2b(nums.y))}
import hashlib
thumb = b64(hashlib.sha256(json.dumps(JWK, sort_keys=True, separators=(",", ":")).encode()).digest())

def es256(data: bytes) -> bytes:
    der = acct_key.sign(data, ec.ECDSA(hashes.SHA256()))
    r, s = decode_dss_signature(der)
    return i2b(r) + i2b(s)

directory = S.get(DIR).json()
def nonce(): return S.head(directory["newNonce"]).headers["Replay-Nonce"]

def jws_post(url, payload, kid=None):
    protected = {"alg": "ES256", "nonce": nonce(), "url": url}
    protected["kid" if kid else "jwk"] = kid if kid else JWK
    p64 = b64(json.dumps(protected).encode())
    y64 = "" if payload == "" else b64(json.dumps(payload).encode())
    sig = b64(es256(f"{p64}.{y64}".encode()))
    r = S.post(url, json={"protected": p64, "payload": y64, "signature": sig},
               headers={"Content-Type": "application/jose+json"})
    return r

# ---- newAccount ----
r = jws_post(directory["newAccount"], {"termsOfServiceAgreed": True})
kid = r.headers["Location"]
print(f"[acct] created kid=...{kid[-12:]}")

# ---- newOrder (request the shortlived profile) ----
order_req = {"identifiers": [{"type": "dns", "value": DOMAIN}], "profile": "shortlived"}
r = jws_post(directory["newOrder"], order_req, kid=kid)
if r.status_code >= 400:
    print("[order] profile rejected, retrying without profile:", r.text[:200])
    r = jws_post(directory["newOrder"], {"identifiers": [{"type": "dns", "value": DOMAIN}]}, kid=kid)
order_url = r.headers["Location"]; order = r.json()
print(f"[order] status={order['status']} profile={order.get('profile','-')}")

# ---- authz -> challenge (pebble auto-validates) ----
for az_url in order["authorizations"]:
    az = jws_post(az_url, "", kid=kid).json()
    ch = az["challenges"][0]
    jws_post(ch["url"], {}, kid=kid)  # poke the challenge; ALWAYS_VALID does the rest
# poll order to 'ready'
for _ in range(30):
    order = jws_post(order_url, "", kid=kid).json()
    if order["status"] in ("ready", "valid", "invalid"): break
    time.sleep(1)
print(f"[order] after authz: status={order['status']}")

# ---- finalize with a CSR ----
leaf_key = ec.generate_private_key(ec.SECP256R1())
csr = (x509.CertificateSigningRequestBuilder()
       .subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, DOMAIN)]))
       .add_extension(x509.SubjectAlternativeName([x509.DNSName(DOMAIN)]), critical=False)
       .sign(leaf_key, hashes.SHA256()))
jws_post(order["finalize"], {"csr": b64(csr.public_bytes(serialization.Encoding.DER))}, kid=kid)
for _ in range(30):
    order = jws_post(order_url, "", kid=kid).json()
    if order["status"] in ("valid", "invalid"): break
    time.sleep(1)
if order["status"] != "valid":
    print("[finalize] order not valid:", order); sys.exit(1)

# ---- download issued cert ----
cert_pem = jws_post(order["certificate"], "", kid=kid).content
cert = x509.load_pem_x509_certificates(cert_pem)[0]   # leaf is first in the chain
nb = cert.not_valid_before_utc; na = cert.not_valid_after_utc
life_h = (na - nb).total_seconds() / 3600
print(f"\n[cert] issued under '{order.get('profile','-')}' profile")
print(f"  NotBefore : {nb.isoformat()}")
print(f"  NotAfter  : {na.isoformat()}")
print(f"  Lifetime  : {life_h:.1f} hours  (short-lived: the CA, not you, picked this)")

# ---- compute ARI CertID and ask WHEN to renew ----
aki = cert.extensions.get_extension_for_oid(ExtensionOID.AUTHORITY_KEY_IDENTIFIER).value.key_identifier
sn = cert.serial_number
sl = (sn.bit_length() + 7) // 8 or 1
sb = sn.to_bytes(sl, "big")
if sb[0] & 0x80: sb = b"\x00" + sb       # DER INTEGER content octets (positive)
certid = f"{b64(aki)}.{b64(sb)}"
ari_url = directory["renewalInfo"].rstrip("/") + "/" + certid
r = S.get(ari_url)
print(f"\n[ARI] GET {ari_url[-60:]}  -> HTTP {r.status_code}")
if r.status_code == 200:
    info = r.json(); w = info["suggestedWindow"]
    print(f"  suggestedWindow.start : {w['start']}")
    print(f"  suggestedWindow.end   : {w['end']}")
    print(f"  explanationURL        : {info.get('explanationURL','-')}")
    print(f"  Retry-After header     : {r.headers.get('Retry-After','-')}")
    print("\n  interpretation: the CA itself hands back a TIME WINDOW to renew in.")
    print("  A correct client renews at a random point inside this window, not on a")
    print("  fixed cron. That is how a fleet avoids a synchronized renewal stampede,")
    print("  and how the CA can pull renewals forward early during a mass-revocation.")
else:
    print("  body:", r.text[:300])
