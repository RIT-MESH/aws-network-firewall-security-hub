"""Unit tests for the Python traffic-generation and log-analysis utilities.

The scripts use hyphenated filenames, so they are loaded via importlib.
"""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_DIR = REPO_ROOT / "scripts"
FIXTURE = REPO_ROOT / "tests" / "fixtures" / "sample-alert-logs.json"


def _load(module_name: str, filename: str):
    path = SCRIPTS_DIR / filename
    spec = importlib.util.spec_from_file_location(module_name, path)
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = mod
    spec.loader.exec_module(mod)
    return mod


afl = _load("afl", "analyze-firewall-logs.py")
gtt = _load("gtt", "generate-test-traffic.py")


# ----- analyze-firewall-logs -----

def test_load_records_jsonl():
    recs = afl.load_records(str(FIXTURE))
    assert len(recs) == 8


def test_summarize_counts():
    recs = afl.load_records(str(FIXTURE))
    s = afl.summarize(recs)
    assert s["total"] == 8
    assert s["dropped"] == 5
    assert s["alert"] == 1
    assert s["allowed"] == 2


def test_summarize_top_sources():
    recs = afl.load_records(str(FIXTURE))
    s = afl.summarize(recs)
    srcs = dict(s["top_sources"])
    assert "10.2.1.10" in srcs


def test_load_records_json_array(tmp_path):
    p = tmp_path / "arr.json"
    p.write_text(json.dumps([{"action": "drop"}, {"action": "pass"}]), encoding="utf-8")
    recs = afl.load_records(str(p))
    assert len(recs) == 2


def test_analyze_main(capsys):
    rc = afl.main([str(FIXTURE)])
    out = capsys.readouterr().out
    assert rc == 0
    assert "Total records: 8" in out
    assert "Dropped events: 5" in out


# ----- generate-test-traffic -----

def test_scenarios_defined():
    assert set(gtt.SCENARIOS) == {"allowed-https", "blocked-telnet", "blocked-domain", "unauthorized-dns"}


def test_expected_results_match_policy():
    assert gtt.SCENARIOS["allowed-https"].expected == "ALLOW"
    assert gtt.SCENARIOS["blocked-telnet"].expected == "BLOCK"
    assert gtt.SCENARIOS["blocked-domain"].expected == "BLOCK"
    assert gtt.SCENARIOS["unauthorized-dns"].expected == "BLOCK"


@pytest.mark.parametrize("name", sorted(gtt.SCENARIOS))
def test_dry_run_returns_zero(capsys, name):
    rc = gtt.run_scenario(name, timeout=1.0, dry_run=True)
    out = capsys.readouterr().out
    assert rc == 0
    assert "expected:" in out


def test_unknown_scenario_returns_two(capsys):
    rc = gtt.run_scenario("nope", timeout=1.0, dry_run=True)
    assert rc == 2


def test_blocked_telnet_uses_test_net():
    sc = gtt.SCENARIOS["blocked-telnet"]
    assert sc.host.startswith("192.0.2.")
    assert sc.port == 23


def test_blocked_domain_uses_documentation_domain():
    sc = gtt.SCENARIOS["blocked-domain"]
    assert sc.host.endswith(".example.org")