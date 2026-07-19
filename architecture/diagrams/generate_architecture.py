#!/usr/bin/env python3
"""Generate the AWS Network Firewall Security Hub architecture diagram.

This script is the architecture-as-code source of truth for the visual
diagram.  It uses the Mingrammer `diagrams` package (which wraps Graphviz)
to produce both PNG and SVG outputs that reflect the Terraform configuration
in the `terraform/` directory.

Terraform remains the infrastructure source of truth; this diagram represents
the *intended* Terraform architecture, not live AWS resource discovery.

Usage::

    python -m pip install -r architecture/diagrams/requirements.txt
    python architecture/diagrams/generate_architecture.py

Graphviz (the `dot` binary) must be installed and available in `PATH`.
"""
from __future__ import annotations

import shutil
from pathlib import Path

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import EC2
from diagrams.aws.general import GenericFirewall, InternetAlt1
from diagrams.aws.management import (
    Cloudwatch,
    CloudwatchAlarm,
    CloudwatchLogs,
    SystemsManager,
)
from diagrams.aws.network import (
    Endpoint,
    IGW,
    NATGateway,
    NetworkFirewall,
    PrivateSubnet,
    PublicSubnet,
    TGW,
    TGWAttach,
    VPCFlowLogs,
)
from diagrams.aws.storage import S3

# ---------------------------------------------------------------------------
# Output configuration
# ---------------------------------------------------------------------------
# Resolve the output directory relative to this file so the script works
# regardless of the current working directory.
SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_NAME = "aws-network-firewall-architecture"
SHOW = False  # Do not open the rendered image automatically


def _build_diagram() -> None:
    """Build the architecture diagram content (nodes and edges).

    This function is called once per output format so that the architecture
    definition is not duplicated between PNG and SVG generation.
    """
    # ---- Internet --------------------------------------------------------
    internet = InternetAlt1("Internet")

    # ---- AWS Region cluster ---------------------------------------------
    with Cluster("AWS Region"):

        # ================================================================
        # Inspection VPC -- IGW is VPC-level (not per-AZ)
        # ================================================================
        with Cluster("Inspection VPC"):
            igw = IGW("Internet Gateway")

            # --- AZ-a ----------------------------------------------------
            with Cluster("AZ-a"):
                fw_a = NetworkFirewall("NFW Endpoint")
                nat_a = NATGateway("NAT Gateway")
                pub_a = PublicSubnet("Public subnet")
                tgw_insp_a = PrivateSubnet("TGW subnet")

            # --- AZ-b ----------------------------------------------------
            with Cluster("AZ-b"):
                fw_b = NetworkFirewall("NFW Endpoint")
                nat_b = NATGateway("NAT Gateway")
                pub_b = PublicSubnet("Public subnet")
                tgw_insp_b = PrivateSubnet("TGW subnet")

            # Firewall policy + rule groups (VPC-level, not an AWS WAF).
            # GenericFirewall avoids misrepresenting AWS WAF which is not
            # deployed by this Terraform configuration.
            fw_policy = GenericFirewall(
                "Firewall Policy\n+ Stateful/Stateless\nRule Groups"
            )

        # ================================================================
        # Transit Gateway (central hub)
        # ================================================================
        tgw = TGW("Transit Gateway")
        tgw_attach_insp = TGWAttach("Inspection\nattachment")
        tgw_attach_prod = TGWAttach("Production\nattachment")
        tgw_attach_dev = TGWAttach("Development\nattachment")
        tgw_attach_shared = TGWAttach("Shared Svcs\nattachment")

        # ================================================================
        # Production VPC
        # ================================================================
        with Cluster("Production VPC"):
            with Cluster("AZ-a"):
                prod_app_a = PrivateSubnet("App subnet")
                prod_tgw_a = PrivateSubnet("TGW subnet")
            with Cluster("AZ-b"):
                prod_app_b = PrivateSubnet("App subnet")
                prod_tgw_b = PrivateSubnet("TGW subnet")
            prod_ec2 = EC2("Optional\nTest Workload")
            prod_ssm = Endpoint(
                "SSM PrivateLink\nssm / ssmmessages / ec2messages"
            )

        # ================================================================
        # Development VPC
        # ================================================================
        with Cluster("Development VPC"):
            with Cluster("AZ-a"):
                dev_app_a = PrivateSubnet("App subnet")
                dev_tgw_a = PrivateSubnet("TGW subnet")
            with Cluster("AZ-b"):
                dev_app_b = PrivateSubnet("App subnet")
                dev_tgw_b = PrivateSubnet("TGW subnet")
            dev_ec2 = EC2("Optional\nTest Workload")
            dev_ssm = Endpoint(
                "SSM PrivateLink\nssm / ssmmessages / ec2messages"
            )

        # ================================================================
        # Shared Services VPC
        # ================================================================
        with Cluster("Shared Services VPC"):
            with Cluster("AZ-a"):
                shared_app_a = PrivateSubnet("Shared subnet")
                shared_tgw_a = PrivateSubnet("TGW subnet")
            with Cluster("AZ-b"):
                shared_app_b = PrivateSubnet("Shared subnet")
                shared_tgw_b = PrivateSubnet("TGW subnet")
            shared_ec2 = EC2("Optional\nTest Workload")
            shared_ssm = Endpoint(
                "SSM PrivateLink\nssm / ssmmessages / ec2messages"
            )

        # ================================================================
        # Logging & Monitoring
        # ================================================================
        with Cluster("Logging & Monitoring"):
            cw_alert_logs = CloudwatchLogs("CloudWatch\nALERT logs")
            cw_vpc_flow = CloudwatchLogs("CloudWatch\nVPC Flow Logs")
            cw_dashboard = Cloudwatch("CloudWatch\nDashboard")
            cw_alarm = CloudwatchAlarm("Metric\nAlarms")
            s3_archive = S3("AWS Network Firewall\nLog Archive")
            ssm_mgmt = SystemsManager("SSM\nManagement")
            vpc_flow = VPCFlowLogs("VPC\nFlow Logs")

    # -----------------------------------------------------------------------
    # Edges -- Egress traffic flow (workload -> internet)
    # -----------------------------------------------------------------------
    # Production egress
    prod_ec2 >> Edge(label="0.0.0.0/0") >> tgw
    # Development egress
    dev_ec2 >> Edge(label="0.0.0.0/0") >> tgw
    # Shared Services egress
    shared_ec2 >> Edge(label="0.0.0.0/0") >> tgw

    # TGW -> Inspection VPC (firewall)
    tgw >> Edge(label="to inspection") >> tgw_attach_insp
    tgw_attach_insp >> Edge(label="-> NFW") >> fw_a
    tgw_attach_insp >> Edge(label="-> NFW") >> fw_b

    # Firewall -> NAT -> IGW -> Internet
    fw_a >> Edge(label="allowed") >> nat_a
    fw_b >> Edge(label="allowed") >> nat_b
    nat_a >> Edge() >> pub_a
    nat_b >> Edge() >> pub_b
    pub_a >> Edge(label="0.0.0.0/0") >> igw
    pub_b >> Edge(label="0.0.0.0/0") >> igw
    igw >> Edge() >> internet

    # -----------------------------------------------------------------------
    # Edges -- Cross-VPC traffic through centralized inspection
    # -----------------------------------------------------------------------
    tgw >> Edge(style="dashed", label="cross-VPC") >> tgw_attach_prod
    tgw >> Edge(style="dashed") >> tgw_attach_dev
    tgw >> Edge(style="dashed") >> tgw_attach_shared

    # -----------------------------------------------------------------------
    # Edges -- Firewall policy
    # -----------------------------------------------------------------------
    fw_policy >> Edge(style="dotted", label="policy") >> fw_a
    fw_policy >> Edge(style="dotted") >> fw_b

    # -----------------------------------------------------------------------
    # Edges -- NFW logging (ALERT -> CloudWatch, FLOW -> S3)
    # -----------------------------------------------------------------------
    fw_a >> Edge(style="dotted", label="ALERT") >> cw_alert_logs
    fw_b >> Edge(style="dotted", label="ALERT") >> cw_alert_logs
    fw_a >> Edge(style="dotted", label="FLOW") >> s3_archive
    fw_b >> Edge(style="dotted", label="FLOW") >> s3_archive

    # VPC Flow Logs -> CloudWatch (separate from NFW logs)
    vpc_flow >> Edge(style="dotted", label="flow") >> cw_vpc_flow

    # CloudWatch monitoring chain
    cw_alert_logs >> Edge(label="metrics") >> cw_dashboard
    cw_alert_logs >> Edge(label="filter") >> cw_alarm

    # -----------------------------------------------------------------------
    # Edges -- SSM management via PrivateLink
    # -----------------------------------------------------------------------
    prod_ssm >> Edge(style="dashed", label="SSM") >> ssm_mgmt
    dev_ssm >> Edge(style="dashed") >> ssm_mgmt
    shared_ssm >> Edge(style="dashed") >> ssm_mgmt
    prod_ec2 >> Edge(style="dotted") >> prod_ssm
    dev_ec2 >> Edge(style="dotted") >> dev_ssm
    shared_ec2 >> Edge(style="dotted") >> shared_ssm


def main() -> None:
    """Generate both PNG and SVG architecture diagrams."""

    # The diagrams library uses the `dot` binary from Graphviz.
    # Verify it is available before attempting to render.
    if not shutil.which("dot"):
        raise SystemExit(
            "Error: Graphviz 'dot' binary not found in PATH.\n"
            "Install Graphviz (https://graphviz.org/download/) and ensure\n"
            "'dot' is available before running this script."
        )

    # Generate both formats.  The diagrams library accepts a list for
    # `outformat` so both PNG and SVG are produced in a single invocation.
    with Diagram(
        "AWS Network Firewall Security Hub",
        filename=str(SCRIPT_DIR / OUTPUT_NAME),
        outformat=["png", "svg"],
        show=SHOW,
        direction="LR",
        graph_attr={"ranksep": "2.0", "nodesep": "1.0", "splines": "ortho"},
    ):
        _build_diagram()

    png_path = SCRIPT_DIR / f"{OUTPUT_NAME}.png"
    svg_path = SCRIPT_DIR / f"{OUTPUT_NAME}.svg"

    for path, fmt in [(png_path, "PNG"), (svg_path, "SVG")]:
        if path.exists() and path.stat().st_size > 0:
            print(f"Generated {fmt}: {path} ({path.stat().st_size} bytes)")
        else:
            raise SystemExit(f"Error: {fmt} output was not generated at {path}")


if __name__ == "__main__":
    main()
