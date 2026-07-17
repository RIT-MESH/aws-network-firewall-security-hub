"""Tests for domain-list and IP-set files used by the firewall policy."""
from __future__ import annotations

import ipaddress
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DOMAIN_DIR = REPO_ROOT / "rules" / "domain-lists"
IPSET_DIR = REPO_ROOT / "rules" / "ip-sets"

DOMAIN_RE = re.compile(r"^(?=.{1,253}$)([a-z0-9-]+\.)+[a-z]{2,}$", re.IGNORECASE)


def _read_list(path: Path) -> list[str]:
    out = []
    for line in path.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        out.append(s)
    return out


def test_allowed_domains_have_no_duplicates():
    domains = _read_list(DOMAIN_DIR / "allowed-domains.txt")
    assert len(domains) == len(set(domains)), f"duplicate allowed domains: {domains}"


def test_blocked_domains_have_no_duplicates():
    domains = _read_list(DOMAIN_DIR / "blocked-domains.txt")
    assert len(domains) == len(set(domains)), f"duplicate blocked domains: {domains}"


def test_allow_and_block_lists_do_not_overlap():
    allowed = set(_read_list(DOMAIN_DIR / "allowed-domains.txt"))
    blocked = set(_read_list(DOMAIN_DIR / "blocked-domains.txt"))
    overlap = allowed & blocked
    assert not overlap, f"allow and block lists overlap: {overlap}"


def test_domains_look_like_domains():
    for name in ("allowed-domains.txt", "blocked-domains.txt"):
        for d in _read_list(DOMAIN_DIR / name):
            assert DOMAIN_RE.match(d), f"invalid domain {d!r} in {name}"


def test_ip_set_files_parse_and_have_no_duplicates():
    for name in ("home-networks.txt", "blocked-destinations.txt"):
        cidrs = _read_list(IPSET_DIR / name)
        assert len(cidrs) == len(set(cidrs)), f"duplicate CIDRs in {name}: {cidrs}"
        for c in cidrs:
            ipaddress.ip_network(c)  # raises if invalid


def test_blocked_destinations_not_in_home_networks():
    home = set(_read_list(IPSET_DIR / "home-networks.txt"))
    blocked = set(_read_list(IPSET_DIR / "blocked-destinations.txt"))
    assert not (home & blocked), "blocked destinations must not overlap home networks"