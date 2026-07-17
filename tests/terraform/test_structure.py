"""Structural tests for the AWS Network Firewall Security Hub repository.

These tests validate repository structure, version pinning, and the absence of
common secret/anti-pattern leaks. They run without AWS credentials and do not
prove packet-level or runtime behavior.
"""
from __future__ import annotations

import os
import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
TF_DIR = REPO_ROOT / "terraform"

REQUIRED_MODULES = [
    "vpc",
    "transit-gateway",
    "inspection-routing",
    "network-firewall",
    "firewall-policy",
    "logging",
    "test-workload",
    "monitoring",
]

REQUIRED_FILES = [
    "AGENTS.md",
    "README.md",
    "LICENSE",
    "Makefile",
    ".gitignore",
    ".editorconfig",
    ".gitattributes",
    ".pre-commit-config.yaml",
    "terraform/versions.tf",
    "terraform/providers.tf",
    "terraform/main.tf",
    "terraform/variables.tf",
    "terraform/outputs.tf",
    "terraform/locals.tf",
]

FORBIDDEN_PATTERNS = {
    "aws_access_key_id literal": re.compile(r"AKIA[0-9A-Z]{16}"),
    "aws_secret_access_key literal": re.compile(r"(?i)aws_secret_access_key\s*=\s*[\"'][^\"']+[\"']"),
    "private key block": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |DSA |)PRIVATE KEY-----"),
}

# Directories whose contents should be ignored when scanning for leaks.
IGNORE_DIRS = {".git", ".terraform", "node_modules", "__pycache__", ".pytest_cache"}


def _iter_repo_files(suffixes=None):
    suffixes = tuple(suffixes or ())
    for dirpath, dirnames, filenames in os.walk(REPO_ROOT):
        dirnames[:] = [d for d in dirnames if d not in IGNORE_DIRS]
        for name in filenames:
            if suffixes and not name.endswith(suffixes):
                continue
            yield Path(dirpath) / name


def _tf_files() -> list[Path]:
    return [p for p in _iter_repo_files((".tf",)) if ".terraform" not in p.parts]


# ----- structure -----

def test_required_modules_exist():
    missing = [m for m in REQUIRED_MODULES if not (TF_DIR / "modules" / m).is_dir()]
    assert not missing, f"missing module dirs: {missing}"


def test_required_files_exist():
    missing = [f for f in REQUIRED_FILES if not (REPO_ROOT / f).is_file()]
    assert not missing, f"missing required files: {missing}"


# ----- version pinning -----

def test_terraform_version_is_constrained():
    content = (TF_DIR / "versions.tf").read_text(encoding="utf-8")
    assert "required_version" in content, "required_version must be declared"
    # Must be a constrained range, not an open-ended >= 1.0 style.
    assert re.search(r'required_version\s*=\s*"[^"]*<\s*[0-9]', content), (
        "required_version must use an upper bound, e.g. >= 1.5.0, < 2.0"
    )
    assert ">= 1.0\"" not in content and '>= 1.0,' not in content, (
        "open-ended '>= 1.0' version is not allowed"
    )


def test_aws_provider_is_pinned():
    content = (TF_DIR / "versions.tf").read_text(encoding="utf-8")
    assert re.search(r"source\s*=\s*\"hashicorp/aws\"", content), "aws provider source must be hashicorp/aws"
    assert re.search(r"version\s*=\s*\"[~>=<][^\"]+\"", content), "aws provider version must be pinned"


# ----- leak / anti-pattern guards -----

def test_no_committed_tfstate_or_tfplan():
    offenders = [p.name for p in _iter_repo_files() if re.search(r"\.tfstate(\.|$)|\.tfplan(\.|$)", p.name)]
    assert not offenders, f"tfstate/tfplan files present: {offenders}"


def test_no_forbidden_patterns_in_repo():
    hits = []
    for path in _iter_repo_files():
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except (OSError, UnicodeDecodeError):
            continue
        for label, pattern in FORBIDDEN_PATTERNS.items():
            if pattern.search(text):
                hits.append(f"{label}: {path.relative_to(REPO_ROOT)}")
    assert not hits, f"forbidden patterns found: {hits}"


def test_no_hardcoded_aws_account_id_in_tf():
    # 12-digit account ids commonly appear as arn:aws:...::123456789012 or quoted 12-digit literals.
    account_arn = re.compile(r"arn:aws(?:-[a-z]+)?:[a-z]+::(\d{12})\b")
    quoted_12 = re.compile(r"[\"'](\d{12})[\"']")
    hits = []
    for path in _tf_files():
        text = path.read_text(encoding="utf-8", errors="ignore")
        for m in account_arn.finditer(text):
            hits.append(f"{path.relative_to(REPO_ROOT)}: arn account id {m.group(1)}")
        for m in quoted_12.finditer(text):
            hits.append(f"{path.relative_to(REPO_ROOT)}: quoted 12-digit {m.group(1)}")
    assert not hits, f"hardcoded account ids: {hits}"


def test_no_ssh_or_rdp_open_to_world():
    # Flag 0.0.0.0/0 only when used for SSH(22) or RDP(3389) ingress, not for
    # legitimate NAT/IGW default routes.
    open_world = re.compile(r"0\.0\.0\.0/0")
    port_22_3389 = re.compile(r"from_port\s*=\s*(22|3389)")
    for path in _tf_files():
        text = path.read_text(encoding="utf-8", errors="ignore")
        if open_world.search(text) and port_22_3389.search(text):
            # Inspect ingress blocks specifically.
            for block in re.finditer(r"ingress\s*\{[^}]*\}", text, re.DOTALL):
                if "0.0.0.0/0" in block.group(0) and re.search(r"from_port\s*=\s*(22|3389)", block.group(0)):
                    pytest.fail(f"{path.relative_to(REPO_ROOT)}: SSH/RDP open to 0.0.0.0/0")
