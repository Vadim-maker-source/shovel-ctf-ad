#!/usr/bin/env python3
import argparse, json, os, re, sys, time
from datetime import datetime, timezone
from pathlib import Path

SECRET = re.compile(r"(?i)(authorization|cookie|token|secret|password|api[-_]?key)")

def scrub(v, key=""):
    if isinstance(v, dict):
        return {k: ("REDACTED" if SECRET.search(k) else scrub(x, k)) for k, x in v.items()}
    if isinstance(v, list): return [scrub(x, key) for x in v]
    return v

def emit(event, out):
    alert = event.get("alert", {}); sid = alert.get("signature_id", "unknown")
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    d = out / (stamp + "-" + str(sid)); d.mkdir(parents=True, exist_ok=False)
    clean = scrub(event); (d/"event.json").write_text(json.dumps(clean, indent=2)+"\n")
    http = clean.get("http", {}); method = http.get("http_method", "GET"); url = http.get("url", "http://LOCAL-CLONE/")
    variants = [{"name":"baseline-replay","method":method,"url":url},{"name":"canary-marker","method":method,"url":url.replace("CANARY","CANARY-LOCAL-001")},{"name":"parameter-review","method":method,"url":url,"note":"mutate only in a local clone"}]
    (d/"payloads.json").write_text(json.dumps(variants, indent=2)+"\n")
    replay = "#!/usr/bin/env python3\n# Generated draft; review for an owned local clone.\nMETHOD = " + repr(method) + "\nURL = " + repr(url) + "\nHEADERS = {}\nBODY = None\nprint({'method': METHOD, 'url': URL, 'headers': HEADERS})\n"
    (d/"replay.py").write_text(replay); os.chmod(d/"replay.py", 0o700)
    (d/"README.md").write_text("Alert SID: " + str(sid) + "\nSignature: " + str(alert.get("signature", "")) + "\n")
    print(d)

def main():
    p=argparse.ArgumentParser(); p.add_argument("--eve", required=True); p.add_argument("--out", default="artifacts"); a=p.parse_args(); out=Path(a.out); out.mkdir(parents=True, exist_ok=True); seen=set(); stream=sys.stdin if a.eve == "-" else open(a.eve, encoding="utf-8", errors="replace")
    while True:
        line=stream.readline()
        if not line:
            if a.eve == "-": break
            time.sleep(1); continue
        try: e=json.loads(line)
        except json.JSONDecodeError: continue
        if e.get("event_type") != "alert": continue
        key=(e.get("timestamp"), e.get("flow_id"), e.get("alert",{}).get("signature_id"))
        if key not in seen: seen.add(key); emit(e, out)
if __name__ == "__main__": main()
