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
SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_NAME = "aws-network-firewall-architecture"
SHOW = False

# Graphviz attributes tuned for a wide, readable landscape layout.
# ratio=compress + size constrains the canvas to a landscape aspect ratio.
GRAPH_ATTR = {
    "rankdir": "LR",
    "ranksep": "1.2",
    "nodesep": "0.4",
    "splines": "spline",
    "fontname": "Helvetica",
    "fontsize": "14",
    "pad": "0.3",
    "ratio": "compress",
    "size": "24,14!",
}
NODE_ATTR = {
    "fontname": "Helvetica",
    "fontsize": "12",
}
EDGE_ATTR = {
    "fontname": "Helvetica",
    "fontsize": "11",
}


def _build_diagram() -> None:
    """Build the architecture diagram content (nodes and edges).

    Layout strategy -- three horizontal sections, left to right:
    Left   – workload VPCs (compact, 2 nodes each)
    Center – Transit Gateway + Inspection VPC with per-AZ firewall/NAT
    Right  – Internet Gateway + Internet
    A compact Logging & Monitoring cluster is placed alongside the firewall.
    """

    # ---- Internet (rightmost) -------------------------------------------
    internet = InternetAlt1("Internet")

    # ---- AWS Region ------------------------------------------------------
    with Cluster("AWS Region"):

        # ================================================================
        # LEFT: Workload VPCs (compact — 2 nodes per VPC)
        # ================================================================

        # --- Production VPC ---
        with Cluster("Production VPC\n(private app + TGW subnets, 2 AZs)"):
            prod_ec2 = EC2("Optional\nTest Workload")
            prod_ssm = Endpoint(
                "SSM PrivateLink\nssm / ssmmessages\n/ ec2messages"
            )

        # --- Development VPC ---
        with Cluster("Development VPC\n(private app + TGW subnets, 2 AZs)"):
            dev_ec2 = EC2("Optional\nTest Workload")
            dev_ssm = Endpoint(
                "SSM PrivateLink\nssm / ssmmessages\n/ ec2messages"
            )

        # --- Shared Services VPC ---
        with Cluster("Shared Services VPC\n(shared + TGW subnets, 2 AZs)"):
            shared_ec2 = EC2("Optional\nTest Workload")
            shared_ssm = Endpoint(
                "SSM PrivateLink\nssm / ssmmessages\n/ ec2messages"
            )

        # ================================================================
        # CENTER: Transit Gateway
        # ================================================================
        tgw = TGW("Transit\nGateway")
        tgw_attach_prod = TGWAttach("Prod\nattach")
        tgw_attach_dev = TGWAttach("Dev\nattach")
        tgw_attach_shared = TGWAttach("Shared\nattach")
        tgw_attach_insp = TGWAttach("Insp\nattach")

        # ================================================================
        # CENTER-RIGHT: Inspection VPC
        # ================================================================
        with Cluster("Inspection VPC"):
            igw = IGW("Internet\nGateway")

            with Cluster("AZ-a"):
                fw_a = NetworkFirewall("NFW\nEndpoint")
                nat_a = NATGateway("NAT\nGateway")
                pub_a = PublicSubnet("Public\nsubnet")

            with Cluster("AZ-b"):
                fw_b = NetworkFirewall("NFW\nEndpoint")
                nat_b = NATGateway("NAT\nGateway")
                pub_b = PublicSubnet("Public\nsubnet")

            fw_policy = GenericFirewall(
                "Firewall Policy\n+ Stateful/Stateless\nRule Groups"
            )

        # ================================================================
        # Logging & Monitoring (compact, alongside firewall)
        # ================================================================
        with Cluster("Logging & Monitoring"):
            cw_alert = CloudwatchLogs("CW\nALERT logs")
            s3_archive = S3("NFW FLOW\nLog Archive")
            cw_dash = Cloudwatch("CW\nDashboard")
            cw_alarm = CloudwatchAlarm("Metric\nAlarms")
            ssm_mgmt = SystemsManager("SSM\nManagement")
            vpc_flow = VPCFlowLogs("VPC\nFlow Logs")

    # -----------------------------------------------------------------------
    # Edges – Primary egress flow (left to right)
    # -----------------------------------------------------------------------
    prod_ec2 >> Edge(label="default route") >> tgw
    dev_ec2 >> Edge(label="default route") >> tgw
    shared_ec2 >> Edge(label="default route") >> tgw

    # TGW -> Inspection (all traffic to firewall)
    tgw >> Edge(label="to inspection") >> tgw_attach_insp
    tgw_attach_insp >> Edge(label="per-AZ\nfirewall") >> fw_a
    tgw_attach_insp >> Edge(label="per-AZ\nfirewall") >> fw_b

    # Firewall -> NAT -> IGW -> Internet
    fw_a >> Edge(label="per-AZ\nNAT") >> nat_a
    fw_b >> Edge(label="per-AZ\nNAT") >> nat_b
    nat_a >> Edge() >> pub_a
    nat_b >> Edge() >> pub_b
    pub_a >> Edge() >> igw
    pub_b >> Edge() >> igw
    igw >> Edge(label="egress") >> internet

    # -----------------------------------------------------------------------
    # Edges – TGW attachments (dashed for cross-VPC)
    # -----------------------------------------------------------------------
    tgw >> Edge(style="dashed", label="cross-VPC") >> tgw_attach_prod
    tgw >> Edge(style="dashed") >> tgw_attach_dev
    tgw >> Edge(style="dashed") >> tgw_attach_shared

    # -----------------------------------------------------------------------
    # Edges – Firewall policy (dotted)
    # -----------------------------------------------------------------------
    fw_policy >> Edge(style="dotted", label="policy") >> fw_a
    fw_policy >> Edge(style="dotted") >> fw_b

    # -----------------------------------------------------------------------
    # Edges – Logging (dotted, short)
    # -----------------------------------------------------------------------
    fw_a >> Edge(style="dotted", label="ALERT") >> cw_alert
    fw_b >> Edge(style="dotted", label="ALERT") >> cw_alert
    fw_a >> Edge(style="dotted", label="FLOW") >> s3_archive
    fw_b >> Edge(style="dotted", label="FLOW") >> s3_archive

    # VPC Flow Logs
    vpc_flow >> Edge(style="dotted", label="flow") >> cw_alert

    # CloudWatch monitoring chain
    cw_alert >> Edge(label="metrics") >> cw_dash
    cw_alert >> Edge(label="filter") >> cw_alarm

    # -----------------------------------------------------------------------
    # Edges – SSM management (dashed)
    # -----------------------------------------------------------------------
    prod_ssm >> Edge(style="dashed", label="SSM") >> ssm_mgmt
    dev_ssm >> Edge(style="dashed") >> ssm_mgmt
    shared_ssm >> Edge(style="dashed") >> ssm_mgmt
    prod_ec2 >> Edge(style="dotted") >> prod_ssm
    dev_ec2 >> Edge(style="dotted") >> dev_ssm
    shared_ec2 >> Edge(style="dotted") >> shared_ssm


def main() -> None:
    """Generate both PNG and SVG architecture diagrams."""

    if not shutil.which("dot"):
        raise SystemExit(
            "Error: Graphviz 'dot' binary not found in PATH.\n"
            "Install Graphviz (https://graphviz.org/download/) and ensure\n"
            "'dot' is available before running this script."
        )

    with Diagram(
        "AWS Network Firewall Security Hub",
        filename=str(SCRIPT_DIR / OUTPUT_NAME),
        outformat=["png", "svg"],
        show=SHOW,
        direction="LR",
        graph_attr=GRAPH_ATTR,
        node_attr=NODE_ATTR,
        edge_attr=EDGE_ATTR,
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
