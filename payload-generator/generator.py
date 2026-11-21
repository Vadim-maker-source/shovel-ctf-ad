#!/usr/bin/env python3
import argparse
import ast
import json
import os
import re
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import urlopen

SECRET = re.compile(r"(?i)(authorization|cookie|token|secret|password|api[-_]?key)")


def scrub(value, key=""):
    if isinstance(value, dict):
        result = {}
        for k, v in value.items():
            if SECRET.search(k):
                result[k] = "REDACTED"
            elif k.lower() in {"request_headers", "response_headers", "headers"} and isinstance(v, list):
                result[k] = [
                    {**header, "value": "REDACTED"}
                    if isinstance(header, dict) and SECRET.search(str(header.get("name", "")))
                    else scrub(header, k)
                    for header in v
                ]
            else:
                result[k] = scrub(v, k)
        return result
    if isinstance(value, list):
        return [scrub(v, key) for v in value]
    return value


class HeaderRedactor(ast.NodeTransformer):
    """Mask credentials in the request-header dicts Shovel puts in its replay."""
    def visit_Dict(self, node):
        self.generic_visit(node)
        for key, value in zip(node.keys, node.values):
            if isinstance(key, ast.Constant) and isinstance(key.value, str) and SECRET.search(key.value):
                value.value = ast.Constant("REDACTED")
        return node


def safe_replay(source):
    try:
        tree = ast.parse(source)
    except SyntaxError:
        return None
    tree = HeaderRedactor().visit(tree)
    ast.fix_missing_locations(tree)
    return ast.unparse(tree) + "\n"


def fetch_json(url):
    with urlopen(url, timeout=10) as response:
        return json.load(response)


def fetch_text(url):
    with urlopen(url, timeout=15) as response:
        return response.read().decode("utf-8", errors="replace")


def emit(flow_id, alert, detail, base, out):
    sid = alert.get("signature_id", "unknown")
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    folder = out / f"{stamp}-{uuid.uuid4().hex[:8]}-{sid}"
    folder.mkdir(mode=0o700, parents=True, exist_ok=False)

    http_events = detail.get("http", [])
    event = {"flow_id": flow_id, "alert": alert, "flow": detail.get("flow"), "http": http_events,
             "fileinfo": detail.get("fileinfo", [])}
    (folder / "event.json").write_text(json.dumps(scrub(event), indent=2, ensure_ascii=False) + "\n")

    # Shovel builds this replay from HTTP transaction records and request filedata,
    # so POST bodies are included when Suricata captured them.
    try:
        replay_source = fetch_text(f"{base}/api/flow/{flow_id}/replay-http")
        replay = safe_replay(replay_source)
        if replay is None:
            (folder / "replay-source.txt").write_text(replay_source)
            body_note = "Shovel returned replay source that was not valid Python; inspect replay-source.txt."
        else:
            replay_path = folder / "replay.py"
            replay_path.write_text(replay)
            os.chmod(replay_path, 0o700)
            body_note = "Shovel HTTP replay endpoint supplied the captured request(s); POST bodies are included when available."
    except (HTTPError, URLError, OSError) as exc:
        (folder / "replay.py").write_text("# Could not fetch Shovel HTTP replay: " + str(exc) + "\n")
        body_note = f"Could not retrieve HTTP replay: {exc}"

    (folder / "README.md").write_text(
        f"Alert SID: {sid}\nSignature: {alert.get('signature', '')}\nFlow: {flow_id}\n\n"
        f"{body_note}\nReview the request and target before running the draft.\n"
    )
    print(folder, flush=True)


def main():
    parser = argparse.ArgumentParser(description="Save Shovel alert details and captured HTTP replay drafts")
    parser.add_argument("--shovel", default="http://127.0.0.1:8000")
    parser.add_argument("--out", default=str(Path.home() / "shovel" / "generated"))
    parser.add_argument("--interval", type=float, default=5)
    args = parser.parse_args()
    out = Path(args.out).expanduser()
    out.mkdir(parents=True, exist_ok=True, mode=0o700)
    monitor_shovel(args.shovel.rstrip("/"), out, args.interval)


def monitor_shovel(base, out, interval):
    seen = set()
    checked_flows = set()
    state_path = out / ".seen-alerts.jsonl"
    if state_path.exists():
        for line in state_path.read_text(errors="replace").splitlines():
            try:
                seen.add(tuple(json.loads(line)))
            except (ValueError, TypeError):
                continue
    print(f"Monitoring {base}; output: {out}", flush=True)
    while True:
        try:
            flows = fetch_json(base + "/api/flow").get("flows", [])
            for flow in flows:
                flow_id = int(flow["id"])
                if flow_id in checked_flows:
                    continue
                checked_flows.add(flow_id)
                detail = fetch_json(f"{base}/api/flow/{flow_id}")
                if not detail.get("http"):
                    continue
                for alert in detail.get("alert", []):
                    # Shovel also represents HTTP method/status tags as alert rows;
                    # only real Suricata signatures have a non-empty signature.
                    if not alert.get("signature"):
                        continue
                    key = (flow_id, alert.get("signature_id"))
                    if key in seen:
                        continue
                    emit(flow_id, alert, detail, base, out)
                    with state_path.open("a") as state:
                        state.write(json.dumps(key) + "\n")
                    seen.add(key)
        except (HTTPError, URLError, OSError, ValueError, KeyError) as exc:
            print(f"Shovel API error: {exc}", file=sys.stderr, flush=True)
        time.sleep(max(interval, 1))


if __name__ == "__main__":
    main()
