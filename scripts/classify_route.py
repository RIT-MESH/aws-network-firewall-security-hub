#!/usr/bin/env python3
"""Classify an AWS VPC route target from the actual populated route field and
identifier prefix.

AWS `describe-route-tables` does not return every route target in the "obvious"
field. In particular, an AWS Network Firewall endpoint route is returned with
the endpoint ID (a `vpce-` value) in `GatewayId`, while `VpcEndpointId` is null.
Classifying any populated `GatewayId` as an Internet Gateway therefore produces
false "firewall bypass" reports. This module classifies from the populated field
AND the identifier prefix, and fails closed on unknown or blackhole routes.

Usable as a library (import classify_route) and as a CLI that reads a JSON route
object, a list of routes, or a `describe-route-tables` response from stdin.

Exit codes (CLI): 0 = all routes valid and match --expected; 1 = mismatch /
blackhole / multiple targets / unknown; 2 = usage / IO error.
"""
from __future__ import annotations

import argparse
import json
import sys
from typing import Any, Dict, List, Tuple

# Classification labels.
NAT = "NAT"
TGW = "TGW"
VPC_ENDPOINT = "VPC_ENDPOINT"
IGW = "IGW"
NFW_ENDPOINT = "NFW_ENDPOINT"
LOCAL = "LOCAL"
ENI = "ENI"
EIGW = "EIGW"
UNKNOWN = "UNKNOWN"

# Route target fields in the describe-route-tables Route object, in priority
# order for classification. A well-formed route has exactly one populated.
_TARGET_FIELDS = (
    "NatGatewayId",
    "TransitGatewayId",
    "VpcEndpointId",
    "GatewayId",
    "NetworkInterfaceId",
    "EgressOnlyInternetGatewayId",
)


def _truthy(v: Any) -> bool:
    return bool(v) and v != "null" and v != "None"


def target_fields_populated(route: Dict[str, Any]) -> List[str]:
    """Return the names of target fields that carry a value (excluding local)."""
    populated = []
    for f in _TARGET_FIELDS:
        v = route.get(f)
        if _truthy(v):
            populated.append(f)
    return populated


def classify(route: Dict[str, Any]) -> str:
    """Classify a route target from the populated field and identifier prefix."""
    if _truthy(route.get("NatGatewayId")):
        return NAT
    if _truthy(route.get("TransitGatewayId")):
        return TGW
    if _truthy(route.get("VpcEndpointId")):
        return VPC_ENDPOINT
    gw = route.get("GatewayId")
    if _truthy(gw):
        if gw == "local":
            return LOCAL
        if gw.startswith("igw-"):
            return IGW
        if gw.startswith("vpce-"):
            return NFW_ENDPOINT
        return UNKNOWN
    if _truthy(route.get("NetworkInterfaceId")):
        return ENI
    if _truthy(route.get("EgressOnlyInternetGatewayId")):
        return EIGW
    return UNKNOWN


def is_blackhole(route: Dict[str, Any]) -> bool:
    return route.get("State") == "blackhole"


def has_multiple_targets(route: Dict[str, Any]) -> bool:
    # `local` is the implicit VPC-local route and is not a "target" in the
    # gateway/endpoint sense; ignore it when counting populated targets.
    populated = [f for f in target_fields_populated(route) if f != "GatewayId" or route.get("GatewayId") != "local"]
    return len(populated) > 1


def validate(route: Dict[str, Any], expected: str | None = None) -> Tuple[bool, str]:
    """Validate a single route. Returns (ok, reason)."""
    if is_blackhole(route):
        return False, "blackhole"
    if has_multiple_targets(route):
        return False, "multiple_targets:" + ",".join(target_fields_populated(route))
    label = classify(route)
    if label == UNKNOWN:
        return False, "unknown_target"
    if expected and label != expected:
        return False, f"expected={expected} actual={label}"
    if route.get("State") and route.get("State") != "active":
        return False, f"state={route.get('State')}"
    return True, label


def _iter_routes(blob: Any):
    """Yield route dicts from a route, a list of routes, or a
    describe-route-tables response ({RouteTables:[{Routes:[...]}]})."""
    if isinstance(blob, dict):
        if "RouteTables" in blob and isinstance(blob["RouteTables"], list):
            for rt in blob["RouteTables"]:
                yield from _iter_routes(rt)
        elif "Routes" in blob and isinstance(blob["Routes"], list):
            for r in blob["Routes"]:
                yield r
        elif any(f in blob for f in _TARGET_FIELDS) or "DestinationCidrBlock" in blob:
            yield blob
    elif isinstance(blob, list):
        for item in blob:
            yield from _iter_routes(item)


def main(argv: List[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Classify AWS VPC route targets.")
    p.add_argument("--expected", help="required classification label for each route")
    p.add_argument("--destination", default="0.0.0.0/0", help="only validate routes with this destination CIDR")
    p.add_argument("--quiet", action="store_true", help="only print failures")
    args = p.parse_args(argv)
    try:
        blob = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError) as e:
        print(f"error reading JSON from stdin: {e}", file=sys.stderr)
        return 2
    exit_code = 0
    for route in _iter_routes(blob):
        if route.get("DestinationCidrBlock") and route.get("DestinationCidrBlock") != args.destination:
            continue
        ok, reason = validate(route, args.expected)
        if ok:
            if not args.quiet:
                print(f"OK {reason} dst={route.get('DestinationCidrBlock')}")
        else:
            print(f"FAIL {reason} dst={route.get('DestinationCidrBlock')}", file=sys.stderr)
            exit_code = 1
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
