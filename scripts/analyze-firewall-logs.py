#!/usr/bin/env python3
"""Analyze AWS Network Firewall JSON logs (sanitized fixtures or real exports).

Reads a file containing JSON records (one JSON object per line, or a JSON
array) and prints a summary: totals by action, top sources/destinations/ports/
signature IDs, events by protocol, and events by hour.

Usage:
    python scripts/analyze-firewall-logs.py tests/fixtures/sample-alert-logs.json
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Iterable


def load_records(path: str) -> list[dict]:
    """Load firewall log records from a file (JSONL or a JSON array)."""
    p = Path(path)
    text = p.read_text(encoding="utf-8").strip()
    records: list[dict] = []
    if text.startswith("["):
        records = json.loads(text)
    else:
        for line in text.splitlines():
            line = line.strip()
            if not line:
                continue
            records.append(json.loads(line))
    return records


def _hour(ts: str) -> str:
    # ts like "2026-07-17T12:34:56Z" -> "2026-07-17T12"
    return ts[:13] if len(ts) >= 13 else ts


def summarize(records: Iterable[dict]) -> dict:
    recs = list(records)
    actions = Counter(r.get("action", "unknown") for r in recs)
    src = Counter(r.get("src_ip") for r in recs if r.get("src_ip"))
    dst = Counter(r.get("dest_ip") for r in recs if r.get("dest_ip"))
    ports = Counter(str(r.get("dest_port")) for r in recs if r.get("dest_port") is not None)
    sids = Counter(str(r.get("sid")) for r in recs if r.get("sid") is not None)
    protos = Counter(r.get("protocol") for r in recs if r.get("protocol"))
    hours = Counter(_hour(r.get("timestamp", "")) for r in recs if r.get("timestamp"))

    return {
        "total": len(recs),
        "by_action": dict(actions),
        "allowed": actions.get("pass", 0) + actions.get("PASS", 0) + actions.get("allow", 0),
        "dropped": actions.get("drop", 0) + actions.get("DROP", 0),
        "alert": actions.get("alert", 0) + actions.get("ALERT", 0),
        "top_sources": src.most_common(10),
        "top_destinations": dst.most_common(10),
        "top_destination_ports": ports.most_common(10),
        "top_sids": sids.most_common(10),
        "by_protocol": dict(protos),
        "by_hour": dict(sorted(hours.items())),
    }


def print_summary(summary: dict) -> None:
    print(f"Total records: {summary['total']}")
    print(f"Allowed events: {summary['allowed']}")
    print(f"Dropped events: {summary['dropped']}")
    print(f"Alert events:   {summary['alert']}")
    print()
    print("Top source addresses:")
    for ip, n in summary["top_sources"]:
        print(f"  {ip:<40} {n}")
    print("Top destination addresses:")
    for ip, n in summary["top_destinations"]:
        print(f"  {ip:<40} {n}")
    print("Top destination ports:")
    for port, n in summary["top_destination_ports"]:
        print(f"  {port:<10} {n}")
    print("Top signature IDs:")
    for sid, n in summary["top_sids"]:
        print(f"  {sid:<12} {n}")
    print("Events by protocol:")
    for proto, n in summary["by_protocol"].items():
        print(f"  {proto:<10} {n}")
    print("Events by hour:")
    for hour, n in summary["by_hour"].items():
        print(f"  {hour}  {n}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("file", help="path to a JSONL or JSON-array firewall log file")
    args = parser.parse_args(argv)
    records = load_records(args.file)
    print_summary(summarize(records))
    return 0


if __name__ == "__main__":
    sys.exit(main())