"""Static routing tests for the centralized inspection architecture.

These tests inspect Terraform source to confirm the intended routing design is
present. They do NOT prove packet-level behavior; runtime validation in AWS is
still required. See architecture/routing-design.md for the documented paths.
"""
from __future__ import annotations

import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
TF_DIR = REPO_ROOT / "terraform"
MAIN_TF = TF_DIR / "main.tf"
ROUTING_TF = TF_DIR / "modules" / "inspection-routing" / "main.tf"
TGW_VARS = TF_DIR / "modules" / "transit-gateway" / "variables.tf"
VPC_MAIN = TF_DIR / "modules" / "vpc" / "main.tf"
LOCALS_TF = TF_DIR / "locals.tf"


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _module_block(text: str, name: str) -> str:
    m = re.search(rf'module "{re.escape(name)}"\s*\{{(.*?)\n\}}\n', text, re.DOTALL)
    assert m, f"module {name} not found"
    return m.group(1)


def _resource(text: str, label: str) -> bool:
    return re.search(rf'"aws_route"\s+"{re.escape(label)}"', text) is not None


# ----- workload VPCs have no direct internet path -----

def test_workload_vpcs_have_no_internet_gateway():
    main = _read(MAIN_TF)
    for vpc in ("production_vpc", "development_vpc", "shared_services_vpc"):
        block = _module_block(main, vpc)
        assert re.search(r"create_internet_gateway\s*=\s*false", block), (
            f"{vpc} must set create_internet_gateway = false"
        )


def test_inspection_vpc_has_internet_gateway():
    block = _module_block(_read(MAIN_TF), "inspection_vpc")
    assert re.search(r"create_internet_gateway\s*=\s*true", block), (
        "inspection VPC must have create_internet_gateway = true"
    )


def test_workload_subnet_maps_have_no_public_subnets():
    locals_text = _read(LOCALS_TF)
    for name in ("production_subnets", "development_subnets", "shared_services_subnets"):
        block_match = re.search(rf'{name}\s*=\s*\{{(.*?)\n  \}}', locals_text, re.DOTALL)
        assert block_match, f"{name} not found in locals"
        assert "map_public_ip = true" not in block_match.group(1), (
            f"{name} must not contain public (map_public_ip=true) subnets"
        )


# ----- centralized inspection routing entries -----

def test_workload_app_subnets_default_to_tgw():
    text = _read(ROUTING_TF)
    assert _resource(text, "workload_default_to_tgw")
    assert re.search(r'destination_cidr_block\s*=\s*"0\.0\.0\.0/0"', text)
    assert re.search(r"transit_gateway_id\s*=\s*var\.transit_gateway_id", text)


def test_firewall_subnets_default_to_nat():
    text = _read(ROUTING_TF)
    assert _resource(text, "firewall_default_to_nat")
    assert re.search(r"nat_gateway_id\s*=\s*aws_nat_gateway\.this\[each\.key\]\.id", text)


def test_firewall_subnets_route_spokes_to_tgw():
    text = _read(ROUTING_TF)
    assert _resource(text, "firewall_to_tgw_spokes")
    assert "var.spoke_cidrs" in text
    assert "var.transit_gateway_id" in text


def test_tgw_attachment_subnet_routes_to_firewall_endpoint():
    text = _read(ROUTING_TF)
    assert _resource(text, "tgw_to_firewall")
    assert re.search(r"vpc_endpoint_id\s*=\s*each\.value", text)


def test_spoke_cidrs_include_all_workload_vpcs():
    locals_text = _read(LOCALS_TF)
    for cidr_var in ("var.production_vpc_cidr", "var.development_vpc_cidr", "var.shared_services_vpc_cidr"):
        assert cidr_var in locals_text, f"{cidr_var} must be in spoke_cidrs"


# ----- Transit Gateway configuration -----

def test_tgw_default_association_and_propagation_disabled():
    tgw_vars = _read(TGW_VARS)
    assert re.search(r'default_route_table_association".*default\s*=\s*"disable"', tgw_vars, re.DOTALL)
    assert re.search(r'default_route_table_propagation".*default\s*=\s*"disable"', tgw_vars, re.DOTALL)


def test_inspection_attachment_uses_appliance_mode():
    block = _module_block(_read(MAIN_TF), "transit_gateway")
    insp = re.search(r"inspection\s*=\s*\{(.*?)\n    \}", block, re.DOTALL)
    assert insp, "inspection attachment not found"
    assert re.search(r"appliance_mode\s*=\s*true", insp.group(1)), (
        "inspection TGW attachment must enable appliance_mode for symmetric routing"
    )


def test_workload_tgw_route_table_defaults_to_inspection():
    block = _module_block(_read(MAIN_TF), "transit_gateway")
    rt_block = re.search(r"route_tables\s*=\s*\{(.*?)\n  \}", block, re.DOTALL)
    assert rt_block, "route_tables block not found"
    workload = re.search(r"workload\s*=\s*\{(.*?)\n    \}", rt_block.group(1), re.DOTALL)
    assert workload, "workload route table not found"
    assert re.search(r'destination\s*=\s*"0\.0\.0\.0/0".*target_attachment\s*=\s*"inspection"', workload.group(1), re.DOTALL)


def test_inspection_route_table_propagates_spokes():
    block = _module_block(_read(MAIN_TF), "transit_gateway")
    rt_block = re.search(r"route_tables\s*=\s*\{(.*?)\n  \}", block, re.DOTALL)
    assert rt_block, "route_tables block not found"
    inspection = re.search(r"inspection\s*=\s*\{(.*?)\n    \}", rt_block.group(1), re.DOTALL)
    assert inspection, "inspection route table not found"
    for spoke in ("production", "development", "shared_services"):
        assert spoke in inspection.group(1), f"{spoke} must propagate to inspection route table"


# ----- no public default route leaking to workload VPCs -----

def test_vpc_module_only_adds_igw_default_route_for_public_subnets():
    text = _read(VPC_MAIN)
    assert re.search(r'"aws_route"\s+"public_internet"', text)
    # The public_internet route must be gated by map_public_ip = true.
    assert re.search(r'for_each\s*=\s*\{[^}]*map_public_ip[^}]*\}', text, re.DOTALL)