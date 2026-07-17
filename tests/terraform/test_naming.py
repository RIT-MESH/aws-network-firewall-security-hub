"""Static naming-convention tests."""
from __future__ import annotations

import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
MAIN_TF = REPO_ROOT / "terraform" / "main.tf"
LOCALS_TF = REPO_ROOT / "terraform" / "locals.tf"


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_name_prefix_follows_convention():
    text = _read(LOCALS_TF)
    assert re.search(r'name_prefix\s*=\s*"anfw-\$\{var\.environment\}"', text), (
        "name_prefix must be anfw-<environment>"
    )


def test_no_hardcoded_environment_in_names():
    text = _read(MAIN_TF)
    # Name assignments must not hardcode a specific environment prefix.
    names = re.findall(r'name\s*=\s*"([^"]+)"', text)
    for name in names:
        assert not re.search(r"anfw-(lab|prod|production|dev|staging)", name), (
            f"resource name {name!r} hardcodes an environment; use local.name_prefix"
        )


def test_resource_names_use_name_prefix():
    text = _read(MAIN_TF)
    # At least the top-level infra modules must derive names from local.name_prefix.
    infra_names = re.findall(r'name\s*=\s*"(\$\{local\.name_prefix\}[^"]+)"', text)
    assert infra_names, "expected infra module names to use ${local.name_prefix}"
    for name in infra_names:
        assert name.startswith("${local.name_prefix}")


def test_common_tags_present():
    text = _read(LOCALS_TF)
    for tag in ("Project", "Environment", "ManagedBy", "Owner", "Purpose"):
        assert tag in text, f"common tag {tag} missing from locals"