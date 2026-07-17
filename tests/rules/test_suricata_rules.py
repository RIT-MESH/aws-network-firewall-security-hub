"""Tests for the Suricata-compatible stateful rule files.

Validates: unique SIDs, required metadata (sid, rev, msg), valid actions,
explicit direction, flow keyword for TCP rules, expected lab rules present,
and no placeholder SIDs.
"""
from __future__ import annotations

import ipaddress
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
STATEFUL_DIR = REPO_ROOT / "rules" / "stateful"
RULE_FILES = ["allow.rules", "deny.rules", "alert.rules", "dns.rules"]
VALID_ACTIONS = {"alert", "drop", "pass", "reject"}

RULE_RE = re.compile(r"^(alert|drop|pass|reject)\b.*?\)\s*$", re.DOTALL | re.MULTILINE)
SID_RE = re.compile(r"sid:\s*(\d+)\s*;", re.DOTALL)
REV_RE = re.compile(r"rev:\s*(\d+)\s*;", re.DOTALL)
MSG_RE = re.compile(r'msg:\s*"([^"]*)"\s*;', re.DOTALL)
FLOW_RE = re.compile(r"flow:\s*([a-z_,]+)\s*;", re.DOTALL)
HEADER_RE = re.compile(r"^(alert|drop|pass|reject)\s+(\S+)\s+(.+?)\s+(->|<>|<->)\s+(.+?)\s*\(", re.DOTALL)


def _parse_file(path: Path) -> list[dict]:
    text = path.read_text(encoding="utf-8")
    rules = []
    for m in RULE_RE.finditer(text):
        rule_text = m.group(0)
        header = HEADER_RE.search(rule_text)
        sid_m = SID_RE.search(rule_text)
        rev_m = REV_RE.search(rule_text)
        msg_m = MSG_RE.search(rule_text)
        flow_m = FLOW_RE.search(rule_text)
        rules.append({
            "action": header.group(1) if header else None,
            "protocol": header.group(2) if header else None,
            "direction": header.group(4) if header else None,
            "rule": rule_text,
            "sid": int(sid_m.group(1)) if sid_m else None,
            "rev": int(rev_m.group(1)) if rev_m else None,
            "msg": msg_m.group(1) if msg_m else None,
            "flow": flow_m.group(1) if flow_m else None,
            "file": path.name,
        })
    return rules


def _all_rules() -> list[dict]:
    rules = []
    for name in RULE_FILES:
        rules.extend(_parse_file(STATEFUL_DIR / name))
    return rules


def test_rule_files_parse():
    rules = _all_rules()
    assert len(rules) >= 8, f"expected at least 8 rules, got {len(rules)}"


def test_every_rule_has_required_metadata():
    for r in _all_rules():
        assert r["sid"] is not None, f"{r['file']}: missing sid in {r['rule']!r}"
        assert r["rev"] is not None, f"{r['file']}: missing rev (sid {r['sid']})"
        assert r["msg"] is not None and r["msg"].strip() != "", f"{r['file']}: missing msg (sid {r['sid']})"


def test_sids_are_unique():
    rules = _all_rules()
    sids = [r["sid"] for r in rules]
    dupes = {s for s in sids if sids.count(s) > 1}
    assert not dupes, f"duplicate SIDs: {dupes}"


def test_actions_are_valid():
    for r in _all_rules():
        assert r["action"] in VALID_ACTIONS, f"{r['file']}: invalid action {r['action']!r}"


def test_explicit_direction():
    for r in _all_rules():
        assert r["direction"] == "->", f"{r['file']} sid {r['sid']}: direction must be '->', got {r['direction']!r}"


def test_tcp_rules_have_flow_keyword():
    for r in _all_rules():
        if r["protocol"] == "tcp":
            assert r["flow"] is not None, f"{r['file']} sid {r['sid']}: tcp rule missing flow keyword"


def test_no_placeholder_sids():
    for r in _all_rules():
        assert r["sid"] >= 1000000, f"{r['file']}: placeholder/low sid {r['sid']}"
        assert r["sid"] != 1000000, f"{r['file']}: placeholder sid 1000000"


def test_expected_lab_rules_exist():
    msgs = " ".join(r["msg"] for r in _all_rules()).lower()
    assert "telnet" in msgs and "blocked" in msgs, "expected a Telnet drop rule"
    assert "development to production ssh" in msgs, "expected a dev->prod SSH drop rule"
    assert "suspicious outbound" in msgs, "expected a suspicious-port alert rule"
    assert "dns to approved resolver" in msgs, "expected a DNS allow rule"


def test_rule_group_files_exist():
    for name in RULE_FILES:
        assert (STATEFUL_DIR / name).is_file(), f"missing {name}"


def test_blocked_destination_cidrs_are_documentation_only():
    # The prohibited IP set must use TEST-NET ranges (RFC 5737), not real infrastructure.
    text = (REPO_ROOT / "rules" / "ip-sets" / "blocked-destinations.txt").read_text(encoding="utf-8")
    cidrs = []
    for line in text.splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        cidrs.append(s)
    test_nets = {"192.0.2.0/24", "198.51.100.0/24", "203.0.113.0/24"}
    for c in cidrs:
        net = ipaddress.ip_network(c)
        assert str(net) in test_nets, f"blocked destination {c} must be a TEST-NET documentation range"