"""Regression tests for AWS VPC route-target classification.

These pin the classification logic in scripts/classify_route.py so the earlier
false "firewall bypass" cannot recur. The key real-world case: AWS Network
Firewall endpoint routes are returned by describe-route-tables with the endpoint
ID (a vpce-prefixed value) in GatewayId, and VpcEndpointId is null. A classifier
that treats every populated GatewayId as an Internet Gateway would wrongly label
a correct NFW-endpoint route as IGW. These tests require classification from the
populated field AND the identifier prefix, and fail closed on unknown, blackhole,
or multiple-target routes.
"""
from __future__ import annotations

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "scripts"))

import classify_route as cr  # noqa: E402


def _route(**kw):
    base = {
        "DestinationCidrBlock": "0.0.0.0/0",
        "Origin": "CreateRoute",
        "State": "active",
        "GatewayId": None,
        "VpcEndpointId": None,
        "NatGatewayId": None,
        "TransitGatewayId": None,
        "NetworkInterfaceId": None,
        "EgressOnlyInternetGatewayId": None,
    }
    base.update(kw)
    return base


def test_gateway_id_igw_prefix_classified_as_igw():
    assert cr.classify(_route(GatewayId="igw-0abcdef1234567890")) == cr.IGW


def test_gateway_id_vpce_prefix_classified_as_nfw_endpoint():
    assert cr.classify(_route(GatewayId="vpce-0abcdef1234567890")) == cr.NFW_ENDPOINT


def test_gateway_id_local_classified_as_local():
    assert cr.classify(_route(DestinationCidrBlock="10.0.0.0/16", GatewayId="local")) == cr.LOCAL


def test_vpc_endpoint_id_classified_as_vpc_endpoint():
    assert cr.classify(_route(VpcEndpointId="vpce-11111111111111111")) == cr.VPC_ENDPOINT


def test_nat_gateway_id_classified_as_nat():
    assert cr.classify(_route(NatGatewayId="nat-0abcdef1234567890")) == cr.NAT


def test_transit_gateway_id_classified_as_tgw():
    assert cr.classify(_route(TransitGatewayId="tgw-0abcdef1234567890")) == cr.TGW


def test_network_interface_id_classified_as_eni():
    assert cr.classify(_route(NetworkInterfaceId="eni-0abcdef1234567890")) == cr.ENI


def test_egress_only_internet_gateway_classified_as_eigw():
    assert cr.classify(_route(EgressOnlyInternetGatewayId="eigw-0abcdef1234567890")) == cr.EIGW


def test_empty_or_unknown_target_classified_as_unknown():
    assert cr.classify(_route()) == cr.UNKNOWN


def test_gateway_id_other_prefix_is_unknown():
    assert cr.classify(_route(GatewayId="vgw-0abcdef1234567890")) == cr.UNKNOWN


def test_blackhole_route_fails_validation():
    ok, reason = cr.validate(_route(TransitGatewayId="tgw-0abcdef1234567890", State="blackhole"), expected="TGW")
    assert not ok
    assert reason == "blackhole"


def test_multiple_target_fields_fail_validation():
    r = _route(TransitGatewayId="tgw-0abcdef1234567890", NatGatewayId="nat-0abcdef1234567890")
    ok, reason = cr.validate(r, expected="TGW")
    assert not ok
    assert reason.startswith("multiple_targets")


def test_validate_expected_mismatch_fails():
    ok, reason = cr.validate(_route(GatewayId="igw-0abcdef1234567890"), expected="NFW_ENDPOINT")
    assert not ok
    assert "expected=NFW_ENDPOINT" in reason and "actual=IGW" in reason


def test_validate_active_nfw_endpoint_passes():
    ok, reason = cr.validate(_route(GatewayId="vpce-0abcdef1234567890"), expected="NFW_ENDPOINT")
    assert ok and reason == cr.NFW_ENDPOINT


def test_false_bypass_regression_nfw_in_gateway_id_not_igw():
    """The exact case that previously produced a false 'firewall bypass' report:
    an NFW endpoint route carried in GatewayId must NOT be classified as IGW.
    """
    r = _route(GatewayId="vpce-0abcdef1234567890")  # VpcEndpointId is null (the real shape)
    assert cr.classify(r) == cr.NFW_ENDPOINT
    assert cr.classify(r) != cr.IGW
    ok, reason = cr.validate(r, expected="NFW_ENDPOINT")
    assert ok and reason == cr.NFW_ENDPOINT
    assert cr.classify(_route(GatewayId="igw-0abcdef1234567890")) == cr.IGW


def test_iter_routes_handles_describe_route_tables_response():
    blob = {"RouteTables": [
        {"RouteTableId": "rtb-aaa", "Routes": [
            _route(GatewayId="vpce-0abcdef1234567890"),
            {"DestinationCidrBlock": "10.0.0.0/16", "GatewayId": "local", "State": "active"},
        ]},
    ]}
    routes = list(cr._iter_routes(blob))
    assert len(routes) == 2
    assert cr.classify(routes[0]) == cr.NFW_ENDPOINT
    assert cr.classify(routes[1]) == cr.LOCAL
