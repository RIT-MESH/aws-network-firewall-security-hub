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

import base64
import re
import shutil
import xml.etree.ElementTree as ET
from pathlib import Path

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import EC2
from diagrams.aws.general import GenericFirewall, InternetAlt1
from diagrams.aws.management import (
    Cloudwatch,
    CloudwatchAlarm,
    CloudwatchLogs,
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

XLINK_NS = "http://www.w3.org/1999/xlink"
SVG_NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG_NS)
ET.register_namespace("xlink", XLINK_NS)

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
    "labelloc": "t",
    "labeljust": "c",
}
NODE_ATTR = {
    "fontname": "Helvetica",
    "fontsize": "12",
}
EDGE_ATTR = {
    "fontname": "Helvetica",
    "fontsize": "11",
}


def _embed_icons_in_svg(svg_path):
    """Replace local icon references with embedded base64 data URIs."""
    tree = ET.parse(str(svg_path))
    root = tree.getroot()
    cache = {}
    num_refs = 0
    num_embedded = 0

    for img in root.iter("{%s}image" % SVG_NS):
        num_refs += 1
        href = img.get("{%s}href" % XLINK_NS) or img.get("href") or ""
        if not href:
            continue
        if href.startswith("data:"):
            num_embedded += 1
            continue

        local_path = href.replace("file://", "")
        fp = Path(local_path)
        if str(fp) not in cache:
            if not fp.exists():
                continue
            data = fp.read_bytes()
            b64 = base64.b64encode(data).decode("ascii")
            cache[str(fp)] = "data:image/png;base64," + b64

        data_uri = cache[str(fp)]
        if img.get("{%s}href" % XLINK_NS) is not None:
            img.set("{%s}href" % XLINK_NS, data_uri)
        if img.get("href") is not None:
            img.set("href", data_uri)
        num_embedded += 1

    tree.write(str(svg_path), encoding="unicode", xml_declaration=True)
    return num_refs, num_embedded


def _validate_svg_portability(svg_path):
    """Fail if the SVG contains any non-portable image references."""
    text = svg_path.read_text(encoding="utf-8")
    forbidden = [
        ("site-packages", "Python site-packages reference"),
        ("file://", "file:// URI"),
        ("/home/", "Linux home directory path"),
        ("/Users/", "macOS Users directory path"),
    ]
    errors = []
    for pattern, desc in forbidden:
        if pattern in text:
            errors.append("SVG contains %s" % desc)

    # Check for Windows drive letter paths like C:\
    if re.search(r"[A-Za-z]:\\", text):
        errors.append("SVG contains Windows absolute path")

    try:
        root = ET.fromstring(text)
    except ET.ParseError as exc:
        raise SystemExit("SVG is not valid XML: %s" % exc)

    for img in root.iter("{%s}image" % SVG_NS):
        href = img.get("{%s}href" % XLINK_NS) or img.get("href") or ""
        if not href.startswith("data:image/"):
            errors.append("Image href does not start with data:image/")

    if errors:
        raise SystemExit("SVG portability validation failed:\n  - " + "\n  - ".join(errors))


def _build_diagram() -> None:
    """Build the architecture diagram content (nodes and edges).

    Layout strategy -- three horizontal sections, left to right:
    Left   – workload VPCs (compact, 2 nodes each)
    Center – Transit Gateway cluster + Inspection VPC with per-AZ firewall/NAT
    Right  – Internet Gateway + Internet
    A compact Logging & Monitoring cluster sits alongside the firewall.
    SSM management is represented by the PrivateLink endpoint labels alone;
    no separate SSM Management node is drawn to avoid long cross-diagram edges.
    """

    # ---- Internet (rightmost, outside AWS Region) -----------------------
    internet = InternetAlt1("Internet")

    # ---- AWS Region ------------------------------------------------------
    with Cluster("AWS Region"):

        # ================================================================
        # LEFT: Workload VPCs (compact -- 2 nodes per VPC)
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
        # CENTER: Transit Gateway (compact cluster with attachments)
        # ================================================================
        with Cluster("Transit Gateway"):
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
    # Edges – Firewall policy (dotted)
    # -----------------------------------------------------------------------
    fw_policy >> Edge(style="dotted", label="policy") >> fw_a
    fw_policy >> Edge(style="dotted") >> fw_b

    # -----------------------------------------------------------------------
    # Edges – Logging (dotted, short – logging cluster is near firewall)
    # -----------------------------------------------------------------------
    fw_a >> Edge(style="dotted", label="ALERT") >> cw_alert
    fw_b >> Edge(style="dotted", label="ALERT") >> cw_alert
    fw_a >> Edge(style="dotted", label="FLOW") >> s3_archive
    fw_b >> Edge(style="dotted", label="FLOW") >> s3_archive

    # VPC Flow Logs (within logging cluster, short edge)
    vpc_flow >> Edge(style="dotted", label="flow") >> cw_alert

    # CloudWatch monitoring chain
    cw_alert >> Edge(label="metrics") >> cw_dash
    cw_alert >> Edge(label="filter") >> cw_alarm


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

    # Post-process SVG: embed local icons as base64 data URIs.
    num_refs, num_embedded = _embed_icons_in_svg(svg_path)
    print(f"SVG icon embedding: {num_refs} image references, "
          f"{num_embedded} embedded as base64 data URIs")

    # Validate SVG portability.
    _validate_svg_portability(svg_path)
    print("SVG portability validation: PASS (no local paths, all data URIs)")

    # Re-validate XML after post-processing.
    ET.parse(str(svg_path))
    print("SVG XML validation: PASS")

    # Report final file sizes (SVG may have grown from embedded icons).
    for path2, fmt2 in [(png_path, "PNG"), (svg_path, "SVG")]:
        print(f"Final {fmt2}: {path2} ({path2.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
