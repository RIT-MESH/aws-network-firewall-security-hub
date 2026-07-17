"""Security-focused static tests.

Scans Terraform source for the security posture required by the project guide.
These are static checks; they do not prove runtime security.
"""
from __future__ import annotations

import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
TF_DIR = REPO_ROOT / "terraform"
PROD_TFVARS = TF_DIR / "environments" / "production" / "terraform.tfvars.example"


def _tf_files() -> list[Path]:
    out = []
    for p in TF_DIR.rglob("*.tf"):
        if ".terraform" in p.parts:
            continue
        out.append(p)
    return out


def _all_tf_text() -> str:
    return "\n".join(p.read_text(encoding="utf-8") for p in _tf_files())


# ----- no SSH/RDP open to the world -----

def test_no_ssh_or_rdp_open_to_world():
    text = _all_tf_text()
    # Find any ingress block allowing 22 or 3389 from 0.0.0.0/0
    for block in re.finditer(r"ingress\s*\{.*?\n\s*\}", text, re.DOTALL):
        b = block.group(0)
        if "0.0.0.0/0" in b and re.search(r"from_port\s*=\s*(22|3389)", b):
            pytest.fail("an ingress block allows SSH/RDP from 0.0.0.0/0")


def test_no_unrestricted_public_ingress():
    text = _all_tf_text()
    # Any ingress with cidr_blocks = ["0.0.0.0/0"] is considered unrestricted.
    for block in re.finditer(r"ingress\s*\{.*?\n\s*\}", text, re.DOTALL):
        b = block.group(0)
        if re.search(r"cidr_blocks\s*=\s*\[[^\]]*0\.0\.0\.0/0[^\]]*\]", b):
            pytest.fail("an ingress block allows unrestricted 0.0.0.0/0 ingress")


# ----- S3 log bucket security -----

def test_s3_log_bucket_blocks_public_access():
    text = (TF_DIR / "modules" / "logging" / "main.tf").read_text(encoding="utf-8")
    for attr in ("block_public_acls", "block_public_policy", "ignore_public_acls", "restrict_public_buckets"):
        assert re.search(rf"{attr}\s*=\s*true", text), f"S3 log bucket must set {attr} = true"


def test_s3_log_bucket_has_encryption():
    text = (TF_DIR / "modules" / "logging" / "main.tf").read_text(encoding="utf-8")
    assert "aws_s3_bucket_server_side_encryption_configuration" in text
    assert re.search(r"sse_algorithm\s*=\s*\"AES256\"", text), "S3 log bucket must enable server-side encryption"


def test_s3_log_bucket_has_lifecycle():
    text = (TF_DIR / "modules" / "logging" / "main.tf").read_text(encoding="utf-8")
    assert "aws_s3_bucket_lifecycle_configuration" in text


def test_s3_log_bucket_versioning_enabled():
    text = (TF_DIR / "modules" / "logging" / "main.tf").read_text(encoding="utf-8")
    assert re.search(r"status\s*=\s*\"Enabled\"", text), "S3 log bucket versioning must be Enabled"


# ----- Network Firewall logging -----

def test_network_firewall_logging_configured():
    text = (TF_DIR / "modules" / "network-firewall" / "main.tf").read_text(encoding="utf-8")
    assert "aws_networkfirewall_logging_configuration" in text
    assert "log_destination_config" in text


# ----- workload instances must not have public IPs -----

def test_no_public_ip_on_instances():
    text = _all_tf_text()
    # If any aws_instance sets associate_public_ip_address = true, fail.
    for m in re.finditer(r'resource\s+"aws_instance"[^\{]*\{.*?\n\}', text, re.DOTALL):
        if re.search(r"associate_public_ip_address\s*=\s*true", m.group(0)):
            pytest.fail("an aws_instance assigns a public IP")


# ----- IMDSv2 and EBS encryption (enforced when instances exist) -----

def test_instances_require_imdsv2_when_present():
    text = _all_tf_text()
    instances = list(re.finditer(r'resource\s+"aws_instance"[^\{]*\{.*?\n\}', text, re.DOTALL))
    if not instances:
        pytest.skip("no aws_instance resources yet")
    for m in instances:
        body = m.group(0)
        assert re.search(r"http_tokens\s*=\s*\"required\"", body), "aws_instance must require IMDSv2 (http_tokens required)"


def test_instances_encrypt_ebs_when_present():
    text = _all_tf_text()
    instances = list(re.finditer(r'resource\s+"aws_instance"[^\{]*\{.*?\n\}', text, re.DOTALL))
    if not instances:
        pytest.skip("no aws_instance resources yet")
    for m in instances:
        body = m.group(0)
        assert re.search(r"encrypted\s*=\s*true", body), "aws_instance must encrypt EBS volumes"


# ----- production protection flags -----

def test_production_tfvars_enables_firewall_protection():
    if not PROD_TFVARS.is_file():
        pytest.skip("production tfvars example not present")
    text = PROD_TFVARS.read_text(encoding="utf-8")
    for attr in ("firewall_delete_protection", "firewall_subnet_change_protection", "firewall_policy_change_protection"):
        assert re.search(rf"{attr}\s*=\s*true", text), f"production tfvars must set {attr} = true"


# ----- no hardcoded credentials -----

def test_no_credentials_in_tf():
    text = _all_tf_text()
    assert not re.search(r"AKIA[0-9A-Z]{16}", text), "AWS access key id literal found"
    assert not re.search(r"aws_secret_access_key\s*=\s*[\"'][^\"']+[\"']", text, re.IGNORECASE), "aws_secret_access_key literal found"
    assert "-----BEGIN" not in text, "private key material found"