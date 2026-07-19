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
NFW_MAIN = TF_DIR / "modules" / "network-firewall" / "main.tf"
NFW_OUT = TF_DIR / "modules" / "network-firewall" / "outputs.tf"
IR_VARS = TF_DIR / "modules" / "inspection-routing" / "variables.tf"
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


def test_no_subnet_maps_public_ip_anywhere():
    locals_text = _read(LOCALS_TF)
    assert "map_public_ip = true" not in locals_text, (
        "no subnet should map public IPs; NAT uses its own EIP"
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
    # Route table and endpoint are aligned by the SAME AZ-index key (each.key),
    # not a positional list index. This prevents silent AZ misalignment that
    # would route traffic to the wrong-AZ firewall endpoint.
    assert re.search(r"for_each\s*=\s*var\.firewall_routes_enabled\s*\?\s*var\.firewall_endpoint_ids_by_az", text), (
        "tgw_to_firewall must iterate over the AZ-index-keyed endpoint map"
    )
    assert re.search(r"route_table_id\s*=\s*var\.inspection_tgw_route_table_ids\[each\.key\]", text), (
        "route_table_id must be looked up by each.key (same AZ key as the endpoint)"
    )
    assert re.search(r"vpc_endpoint_id\s*=\s*each\.value", text), (
        "vpc_endpoint_id must be each.value from the AZ-keyed map"
    )


def test_no_positional_endpoint_indexing_remains():
    """Regression guard: the old positional list-index coupling must not return.
    Positional coupling (var.firewall_endpoint_ids[count.index]) was fragile
    because it relied on two independent orderings coincidentally matching; a
    mismatch silently routed traffic to the wrong-AZ firewall endpoint, which
    presents at runtime as 'firewall received 0 packets' despite correct routes.
    """
    text = _read(ROUTING_TF)
    assert not re.search(r"var\.firewall_endpoint_ids\b", text), (
        "positional var.firewall_endpoint_ids list must not be referenced; use the AZ-keyed map"
    )
    assert "local.tgw_rt_order" not in text, (
        "tgw_rt_order positional ordering helper must not remain"
    )


def test_inspection_routing_endpoint_var_is_az_keyed_map():
    text = _read(IR_VARS)
    m = re.search(r'variable\s+"firewall_endpoint_ids_by_az"\s*\{(.*?)\n\}', text, re.DOTALL)
    assert m, "firewall_endpoint_ids_by_az variable must be declared"
    assert re.search(r"type\s*=\s*map\(string\)", m.group(1)), (
        "firewall_endpoint_ids_by_az must be map(string), keyed by AZ index"
    )


def test_network_firewall_emits_az_keyed_endpoint_map():
    text = _read(NFW_OUT)
    assert re.search(r'output\s+"endpoint_ids_by_az"', text), (
        "network-firewall must export endpoint_ids_by_az"
    )
    # The map must be keyed by tostring(i) (AZ index), not by AZ name, so its
    # keys line up with inspection_tgw_route_table_ids keys ("0","1",...).
    assert re.search(r'tostring\(i\)\s*=>\s*local\.endpoint_id_by_az_name\[az\]', text), (
        "endpoint_ids_by_az must be keyed by AZ index (tostring(i))"
    )


def test_network_firewall_has_endpoint_per_az_check():
    """Runtime guard: a check block must assert one endpoint per AZ so a missing
    endpoint fails loudly at apply time instead of silently producing a
    wrong-length map that misaligns per-AZ routes."""
    text = _read(NFW_MAIN)
    assert re.search(r'check\s+"firewall_endpoint_per_az"', text), (
        "network-firewall must declare the firewall_endpoint_per_az check block"
    )
    assert "availability_zone == az" in text


def test_main_passes_az_keyed_endpoint_map():
    main = _read(MAIN_TF)
    block = _module_block(main, "inspection_routing")
    assert re.search(r"firewall_endpoint_ids_by_az\s*=\s*module\.network_firewall\.endpoint_ids_by_az", block), (
        "main.tf must pass the AZ-index-keyed endpoint map to inspection_routing"
    )
    assert not re.search(r"firewall_endpoint_ids\s*=\s*module\.network_firewall\.endpoint_ids", block), (
        "main.tf must not pass the positional firewall_endpoint_ids list"
    )


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
    # The public_internet route must be gated by purpose == "public", not by
    # map_public_ip, so subnets never map public IPs.
    assert re.search(r'for_each\s*=\s*\{[^}]*purpose\s*==\s*"public"[^}]*\}', text, re.DOTALL)

# ----- Return-path: public subnet spoke-CIDR routes -> same-AZ NFW endpoint -----

def test_public_to_firewall_spokes_resource_exists():
    text = _read(ROUTING_TF)
    assert _resource(text, "public_to_firewall_spokes"), (
        "public_to_firewall_spokes route resource must exist for the return-path fix"
    )


def test_public_spoke_routes_use_setproduct_of_az_keys_and_spoke_cidrs():
    text = _read(ROUTING_TF)
    m = re.search(r'resource\s+"aws_route"\s+"public_to_firewall_spokes"\s*\{(.*?)\n\}', text, re.DOTALL)
    assert m, "public_to_firewall_spokes block not found"
    blk = m.group(1)
    assert "setproduct(" in blk and "var.inspection_public_route_table_ids" in blk and "var.spoke_cidrs" in blk, (
        "public spoke routes must be the cross product of public route-table AZ keys and spoke CIDRs"
    )


def test_public_spoke_route_targets_nfw_endpoint_keyed_by_same_az():
    text = _read(ROUTING_TF)
    m = re.search(r'resource\s+"aws_route"\s+"public_to_firewall_spokes"\s*\{(.*?)\n\}', text, re.DOTALL)
    blk = m.group(1)
    # route table and endpoint both keyed by each.value.az_key (same AZ)
    assert re.search(r"route_table_id\s*=\s*var\.inspection_public_route_table_ids\[each\.value\.az_key\]", blk), (
        "route_table_id must be looked up by each.value.az_key"
    )
    assert re.search(r"vpc_endpoint_id\s*=\s*var\.firewall_endpoint_ids_by_az\[each\.value\.az_key\]", blk), (
        "vpc_endpoint_id must be the same-AZ firewall endpoint keyed by each.value.az_key"
    )
    assert "destination_cidr_block" in blk and "each.value.spoke_cidr" in blk


def test_public_spoke_routes_have_no_positional_indexing():
    text = _read(ROUTING_TF)
    m = re.search(r'resource\s+"aws_route"\s+"public_to_firewall_spokes"\s*\{(.*?)\n\}', text, re.DOTALL)
    blk = m.group(1)
    assert "count.index" not in blk, "no positional count.index coupling in public spoke routes"
    assert not re.search(r"firewall_endpoint_ids\b\[(?!_by_az)", blk), (
        "no positional firewall_endpoint_ids list indexing; use the AZ-keyed map"
    )


def test_public_spoke_routes_do_not_target_igw_nat_or_tgw():
    text = _read(ROUTING_TF)
    m = re.search(r'resource\s+"aws_route"\s+"public_to_firewall_spokes"\s*\{(.*?)\n\}', text, re.DOTALL)
    blk = m.group(1)
    assert "gateway_id" not in blk, "public spoke return routes must not target an IGW"
    assert "nat_gateway_id" not in blk, "public spoke return routes must not target a NAT Gateway"
    assert "transit_gateway_id" not in blk, (
        "public spoke return routes must not bypass inspection by targeting the TGW directly"
    )


def test_public_default_route_still_targets_igw():
    text = _read(VPC_MAIN)
    assert re.search(r'"aws_route"\s+"public_internet"', text)
    assert re.search(r'gateway_id\s*=\s*aws_internet_gateway\.this\[0\]\.id', text)


def test_expected_public_spoke_route_count_is_six():
    """2 AZs x 3 spoke CIDRs = 6 public spoke return routes."""
    locals_text = _read(LOCALS_TF)
    spoke_cidrs = re.findall(r'(var\.\w+_vpc_cidr),', locals_text)
    # three spoke CIDRs are referenced in spoke_cidrs (production/development/shared_services)
    spoke = [c for c in spoke_cidrs if c in (
        "var.production_vpc_cidr", "var.development_vpc_cidr", "var.shared_services_vpc_cidr")]
    assert len(set(spoke)) == 3, f"expected 3 spoke CIDRs, got {set(spoke)}"
    # 2 AZs (keys "0","1" in the public route table map in main.tf)
    main = _read(MAIN_TF)
    pubkeys = re.findall(r'"([01])"\s*=\s*module\.inspection_vpc\.route_table_ids\["public-[ab]"\]', main)
    assert len(set(pubkeys)) == 2, f"expected 2 public route-table AZ keys, got {set(pubkeys)}"
    # 2 x 3 = 6
    assert len(set(pubkeys)) * len(set(spoke)) == 6