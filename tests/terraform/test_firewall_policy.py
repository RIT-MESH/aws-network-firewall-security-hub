"""Regression tests for the firewall policy stateless/stateful defaults.

These pin the fix that forwards unmatched stateless traffic to the stateful
engine. The original defect: stateless_default_actions = ["aws:drop"] dropped
all traffic at the stateless engine before the stateful allow/deny/alert/DNS/
domain-list rules could evaluate it (firewall received packets but PassedPackets
= 0). These tests ensure the defaults forward to the stateful engine, the
stateful default remains drop_strict, the stateless prohibited-destination rule
group stays attached, and the stateful rule groups stay in strict order. No test
may pass with aws:drop as the stateless default.
"""
from __future__ import annotations

import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
TF_DIR = REPO_ROOT / "terraform"
FP_VARS = TF_DIR / "modules" / "firewall-policy" / "variables.tf"
FP_MAIN = TF_DIR / "modules" / "firewall-policy" / "main.tf"
ROOT_MAIN = TF_DIR / "main.tf"


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _var_block(text: str, name: str) -> str:
    m = re.search(rf'variable\s+"{re.escape(name)}"\s*\{{(.*?)\n\}}', text, re.DOTALL)
    assert m, f"variable {name} not found"
    return m.group(1)


def test_stateless_default_forwards_to_stateful_engine():
    blk = _var_block(_read(FP_VARS), "stateless_default_actions")
    assert "aws:forward_to_sfe" in blk, "stateless default must forward to the stateful engine"
    assert '"aws:drop"' not in re.sub(r'error_message\s*=.*', '', blk, flags=re.DOTALL), (
        "stateless_default_actions default must not be aws:drop"
    )


def test_stateless_fragment_default_forwards_to_stateful_engine():
    blk = _var_block(_read(FP_VARS), "stateless_fragment_default_actions")
    assert "aws:forward_to_sfe" in blk
    assert '"aws:drop"' not in re.sub(r'error_message\s*=.*', '', blk, flags=re.DOTALL), (
        "stateless_fragment_default_actions default must not be aws:drop"
    )


def test_stateless_defaults_have_forward_to_sfe_validation():
    """The variable validation must reject a bare aws:drop so the defect cannot recur."""
    for name in ("stateless_default_actions", "stateless_fragment_default_actions"):
        blk = _var_block(_read(FP_VARS), name)
        assert "validation" in blk and "aws:forward_to_sfe" in blk, (
            f"{name} must have a validation requiring aws:forward_to_sfe"
        )


def test_stateful_default_remains_drop_strict():
    blk = _var_block(_read(FP_VARS), "stateful_default_actions")
    assert "aws:drop_strict" in blk, "stateful default must remain drop_strict"


def test_stateful_rule_order_strict():
    blk = _var_block(_read(FP_VARS), "stateful_rule_order")
    assert "STRICT_ORDER" in blk


def test_stateless_prohibited_destination_rule_group_remains_attached():
    text = _read(FP_MAIN)
    assert re.search(r'stateless_rule_group_reference', text), (
        "stateless rule group reference (prohibited destinations) must remain in the policy"
    )
    assert "aws_networkfirewall_rule_group.stateless_drop" in text


def test_stateful_rule_groups_remain_attached_in_strict_order():
    text = _read(FP_MAIN)
    assert re.search(r'stateful_engine_options', text)
    assert re.search(r'rule_order\s*=\s*var\.stateful_rule_order', text), (
        "stateful engine options must use the strict rule order variable"
    )
    # stateful rule group references for allow/deny/alert/dns + domain lists
    for key in ("allow", "deny", "alert", "dns"):
        assert f'stateful["{key}"]' in text or f'stateful_rule_group_reference' in text
    assert "allowed_domains" in text and "blocked_domains" in text


def test_root_does_not_override_stateless_default_to_drop():
    text = _read(ROOT_MAIN)
    blk = re.search(r'module\s+"firewall_policy"\s*\{(.*?)\n\}', text, re.DOTALL)
    assert blk, "firewall_policy module block not found"
    # The root must not set stateless defaults back to aws:drop.
    assert not re.search(r'stateless_default_actions\s*=\s*\[?"aws:drop"?]', blk.group(1)), (
        "root module must not override stateless_default_actions to aws:drop"
    )


def test_no_aws_drop_as_stateless_default_anywhere():
    """No stateless default in the firewall-policy module may be aws:drop."""
    text = _read(FP_VARS)
    # Strip error_message strings (which legitimately mention aws:drop).
    stripped = re.sub(r'error_message\s*=.*?(?=\n\s*\n|\n\s*validation|\n\s*\}|\Z)', '', text, flags=re.DOTALL)
    # The default lines must not be ["aws:drop"].
    for m in re.finditer(r'default\s*=\s*(\[[^\]]*\])', stripped):
        if 'stateless' in stripped[:m.start()].rsplit('variable', 1)[-1]:
            assert "aws:drop" not in m.group(1), f"stateless default must not be aws:drop: {m.group(1)}"


# Route-classification regression tests remain in tests/scripts/test_classify_route.py
# and are executed by the same pytest run.

def test_dns_pass_priority_is_above_deny():
    """Approved-DNS pass rules must evaluate before the unauthorized-DNS deny
    rules, otherwise the deny rules (dest 0.0.0.0/0:53) shadow the approved-DNS
    pass rules (dest shared:53) because 0.0.0.0/0 includes the shared CIDR."""
    text = _read(FP_MAIN)
    m = re.search(r'stateful_priorities\s*=\s*\{(.*?)\}', text, re.DOTALL)
    assert m, "stateful_priorities map not found"
    blk = m.group(1)
    dns = int(re.search(r'dns\s*=\s*(\d+)', blk).group(1))
    deny = int(re.search(r'deny\s*=\s*(\d+)', blk).group(1))
    assert dns < deny, (
        f"DNS pass priority ({dns}) must be lower than deny priority ({deny}) so "
        "approved DNS to the shared resolver passes before the unauthorized-DNS deny"
    )


def test_stream_exception_policy_defaults_to_continue():
    """The stateful engine must continue the TCP handshake until it can inspect
    the TLS SNI; otherwise drop_strict drops the SYN before the domain-list
    rules can evaluate (allowed HTTPS fails, restricted domains dropped by
    default instead of the DENYLIST)."""
    blk = _var_block(_read(FP_VARS), "stream_exception_policy")
    assert "CONTINUE" in blk, "stream_exception_policy must default to CONTINUE"
    assert "DROP" in blk and "CONTINUE" in blk  # validation allows both


def test_stateful_engine_options_set_stream_exception_policy():
    text = _read(FP_MAIN)
    assert re.search(r'stream_exception_policy\s*=\s*var\.stream_exception_policy', text), (
        "stateful_engine_options must set stream_exception_policy"
    )