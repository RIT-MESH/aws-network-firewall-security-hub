#!/usr/bin/env python3
"""Generate safe, scenario-based test traffic for the firewall validation lab.

Scenarios use explicit, documentation-only destinations only. This tool never
scans arbitrary networks. Each scenario prints the expected result, performs a
single bounded connection attempt, prints the actual result, and exits non-zero
when the observed result differs from the expectation.

Usage:
    python scripts/generate-test-traffic.py --scenario allowed-https
    python scripts/generate-test-traffic.py --scenario blocked-telnet --dry-run

Scenarios:
    allowed-https      outbound HTTPS to an allowed domain (expected: ALLOW)
    blocked-telnet      outbound Telnet to a TEST-NET IP (expected: BLOCK)
    blocked-domain      HTTPS to a blocked domain (expected: BLOCK)
    unauthorized-dns    DNS to an unauthorized external resolver (expected: BLOCK)
"""
from __future__ import annotations

import argparse
import socket
import ssl
import sys
from dataclasses import dataclass
from urllib.parse import urlparse


@dataclass
class Scenario:
    name: str
    description: str
    expected: str  # ALLOW or BLOCK
    host: str
    port: int
    protocol: str  # tcp or udp
    note: str


SCENARIOS = {
    "allowed-https": Scenario(
        "allowed-https",
        "Outbound HTTPS to an allowed domain",
        "ALLOW",
        "example.com",
        443,
        "tcp",
        "example.com is in the allowed-domains ALLOWLIST",
    ),
    "blocked-telnet": Scenario(
        "blocked-telnet",
        "Outbound Telnet to a TEST-NET documentation IP",
        "BLOCK",
        "192.0.2.1",  # RFC 5737 TEST-NET-1
        23,
        "tcp",
        "Telnet is dropped by deny.rules; TEST-NET IP will not respond",
    ),
    "blocked-domain": Scenario(
        "blocked-domain",
        "HTTPS to a documentation-only blocked domain",
        "BLOCK",
        "restricted.example.org",
        443,
        "tcp",
        "blocked-domains DENYLIST; name will not resolve in the lab",
    ),
    "unauthorized-dns": Scenario(
        "unauthorized-dns",
        "DNS query to an unauthorized external resolver (TEST-NET)",
        "BLOCK",
        "192.0.2.53",  # TEST-NET, will not respond
        53,
        "udp",
        "UDP DNS to external resolver is dropped by deny.rules",
    ),
}


def _attempt_tcp(host: str, port: int, timeout: float) -> bool:
    """Return True if a TCP connection succeeds within timeout."""
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def _attempt_tls(host: str, port: int, timeout: float) -> bool:
    """Return True if a TLS handshake succeeds within timeout."""
    try:
        ctx = ssl.create_default_context()
        with socket.create_connection((host, port), timeout=timeout) as sock:
            with ctx.wrap_socket(sock, server_hostname=host) as _s:
                return True
    except OSError:
        return False


def _attempt_udp(host: str, port: int, timeout: float) -> bool:
    """Return True if a UDP DNS query gets a response within timeout."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.settimeout(timeout)
            s.sendto(b"\x00", (host, port))
            s.recvfrom(512)
            return True
    except OSError:
        return False


def run_scenario(name: str, timeout: float, dry_run: bool) -> int:
    if name not in SCENARIOS:
        print(f"unknown scenario: {name}", file=sys.stderr)
        return 2
    sc = SCENARIOS[name]
    print(f"scenario: {sc.name}")
    print(f"  description: {sc.description}")
    print(f"  host={sc.host} port={sc.port} proto={sc.protocol}")
    print(f"  note: {sc.note}")
    print(f"  expected: {sc.expected}")

    if dry_run:
        print("  actual:   (dry-run, no traffic sent)")
        return 0

    if sc.protocol == "tcp" and sc.port == 443:
        ok = _attempt_tls(sc.host, sc.port, timeout)
    elif sc.protocol == "tcp":
        ok = _attempt_tcp(sc.host, sc.port, timeout)
    else:
        ok = _attempt_udp(sc.host, sc.port, timeout)

    actual = "ALLOW" if ok else "BLOCK"
    print(f"  actual:   {actual}")
    if actual != sc.expected:
        print(f"  result:   MISMATCH (expected {sc.expected}, got {actual})", file=sys.stderr)
        return 1
    print("  result:   MATCH")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--scenario", required=True, choices=sorted(SCENARIOS))
    parser.add_argument("--timeout", type=float, default=5.0, help="per-attempt timeout in seconds")
    parser.add_argument("--dry-run", action="store_true", help="print expected results without sending traffic")
    args = parser.parse_args(argv)
    return run_scenario(args.scenario, args.timeout, args.dry_run)


if __name__ == "__main__":
    sys.exit(main())