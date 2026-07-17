"""Static tests for the SSM VPC endpoints (PrivateLink) fix."""
from __future__ import annotations

import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
TF_DIR = REPO_ROOT / "terraform"
MAIN_TF = TF_DIR / "main.tf"
MOD_MAIN = TF_DIR / "modules" / "ssm-vpc-endpoints" / "main.tf"
MOD_VARS = TF_DIR / "modules" / "ssm-vpc-endpoints" / "variables.tf"


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _module_block(text: str, name: str) -> str:
    # Match up to the closing brace at the start of a line (no trailing newline required).
    m = re.search(rf'module "{re.escape(name)}"\s*\{{(.*?)\n\}}', text, re.DOTALL)
    assert m, f"module {name} not found"
    return m.group(1)


def test_three_workload_endpoint_module_instances_exist():
    main = _read(MAIN_TF)
    for name in ("ssm_endpoints_production", "ssm_endpoints_development", "ssm_endpoints_shared_services"):
        assert re.search(rf'module "{re.escape(name)}"\s*\{{', main), f"{name} missing"


def test_no_endpoints_in_inspection_vpc():
    main = _read(MAIN_TF)
    assert "ssm_endpoints_inspection" not in main, "SSM endpoints must not be added to the inspection VPC"


def test_module_creates_three_ssm_services():
    text = _read(MOD_MAIN)
    assert '"ssm"' in text and '"ssmmessages"' in text and '"ec2messages"' in text


def test_endpoints_are_interface_with_private_dns():
    text = _read(MOD_MAIN)
    assert re.search(r'vpc_endpoint_type\s*=\s*"Interface"', text)
    assert re.search(r'private_dns_enabled\s*=\s*true', text)


def test_service_name_uses_region_not_hardcoded():
    text = _read(MOD_MAIN)
    assert re.search(r'service_name\s*=\s*"com\.amazonaws\.\$\{var\.region\}\.\$\{each\.key\}"', text)
    assert not re.search(r'com\.amazonaws\.(us-east-1|ap-northeast-1)', text), "region must not be hardcoded"


def test_endpoint_security_group_ingress_tcp_443_only():
    text = _read(MOD_MAIN)
    assert re.search(r'from_port\s*=\s*443', text)
    assert re.search(r'to_port\s*=\s*443', text)
    assert re.search(r'protocol\s*=\s*"tcp"', text)
    assert not re.search(r'from_port\s*=\s*(22|3389)', text)


def test_endpoint_security_group_no_public_ingress():
    text = _read(MOD_MAIN)
    assert "0.0.0.0/0" not in text, "endpoint SG must not allow 0.0.0.0/0"
    assert re.search(r'cidr_blocks\s*=\s*\[var\.vpc_cidr\]', text)


def test_endpoint_security_group_no_broad_egress():
    text = _read(MOD_MAIN)
    assert not re.search(r'egress\s*\{', text), "endpoint SG should have no egress block (stateful)"


def test_endpoints_use_private_subnets():
    text = _read(MOD_MAIN)
    assert re.search(r'subnet_ids\s*=\s*var\.private_subnet_ids', text)
    assert re.search(r'variable "private_subnet_ids"', _read(MOD_VARS))


def test_module_instances_use_workload_private_subnets():
    main = _read(MAIN_TF)
    prod = _module_block(main, "ssm_endpoints_production")
    dev = _module_block(main, "ssm_endpoints_development")
    shared = _module_block(main, "ssm_endpoints_shared_services")
    assert 'subnet_ids_by_purpose["app"]' in prod
    assert 'subnet_ids_by_purpose["app"]' in dev
    assert 'subnet_ids_by_purpose["shared"]' in shared


def test_no_route_or_firewall_policy_changes_for_endpoints():
    main = _read(MAIN_TF)
    for name in ("ssm_endpoints_production", "ssm_endpoints_development", "ssm_endpoints_shared_services"):
        block = _module_block(main, name)
        assert "aws_route" not in block
        assert "networkfirewall" not in block
        assert "transit_gateway" not in block.lower()


def test_workload_module_instances_use_region_variable():
    main = _read(MAIN_TF)
    for name in ("ssm_endpoints_production", "ssm_endpoints_development", "ssm_endpoints_shared_services"):
        block = _module_block(main, name)
        assert re.search(r'region\s*=\s*var\.aws_region', block)
