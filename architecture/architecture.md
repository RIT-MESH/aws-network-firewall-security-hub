# Architecture

## Overview

A centralized inspection pattern: all workload egress and cross-VPC traffic
is forced through a single AWS Network Firewall deployed in an inspection VPC,
attached to a Transit Gateway that connects production, development, and shared
services VPCs. Workload VPCs have no direct internet path.

## Architecture diagram

The repository includes a professional architecture-as-code diagram generated
with the Python diagrams package (Mingrammer):

- **SVG and PNG** files in `architecture/diagrams/` are **generated artifacts**,
  not hand-drawn images.
- The **Python source** (`architecture/diagrams/generate_architecture.py`) is
  the architecture-as-code source of truth for the visual diagram.
- **Terraform** remains the infrastructure source of truth.
- The diagram represents the **intended Terraform architecture**, not live AWS
  resource discovery.
- Contributors must **regenerate the diagram** after relevant architecture
  changes by running:

`ash
python -m pip install -r a`architecture/diagrams/`requirements.txt
python a`architecture/diagrams/generate_architecture.py`
`

Graphviz (dot) must be installed and available in PATH. The GitHub Actions
workflow rchitecture-diagram.yml verifies that committed artifacts are up to
date on every pull request and push to main.
## Components

- **Inspection VPC**: AWS Network Firewall (2 AZs), NAT Gateways (2 AZs),
  Internet Gateway, TGW attachment subnets, firewall subnets, public/NAT
  subnets.
- **Transit Gateway**: explicit route tables for workload, shared services, and
  inspection; appliance mode on the inspection attachment for symmetric routing.
- **Production / Development / Shared Services VPCs**: private app/shared
  subnets and TGW attachment subnets only (no IGW).
- **AWS Network Firewall policy**: stateful Suricata rule groups (allow/deny/
  alert/dns), domain allowlist/blocklist, stateless drop group, STRICT_ORDER.
- **Logging**: CloudWatch alert/flow log groups + encrypted S3 archival.
- **Monitoring**: CloudWatch dashboard, metric filters, alarms, optional SNS.

## Availability

Firewall, NAT, and TGW attachments span two AZs. Workload app subnets span two
AZs. The architecture targets high availability; single-AZ is not supported.

## See also

- `routing-design.md` for route tables and packet paths
- `security-boundaries.md` for trust boundaries
- `traffic-flows.md` for allowed/blocked flow walkthroughs
- `diagrams/architecture.mmd` for the Mermaid diagram
