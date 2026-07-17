#!/usr/bin/env bash
# Read-only route inspection templates for deployed infrastructure.
# Default behavior prints the AWS CLI commands to run; pass --run to execute
# read-only queries. Never performs mutations.
set -euo pipefail

RUN=0
if [[ "${1:-}" == "--run" ]]; then RUN=1; fi

maybe_run() {
  if [[ "$RUN" -eq 1 ]]; then
    echo "==> $*"
    sh -c "$1"
  else
    echo "$1"
  fi
}

echo "# Workload VPC app subnet default routes (target must be a Transit Gateway, not an IGW):"
maybe_run 'aws ec2 describe-route-tables --filters Name=tag:Purpose,Values=app --query "RouteTables[*].{rt:RouteTableId,routes:Routes}" --output table'

echo "# Transit Gateway route-table associations:"
maybe_run 'aws ec2 describe-transit-gateway-route-tables --query "TransitGatewayRouteTables[*].{rt:TransitGatewayRouteTableId,assoc:Associations}" --output table'

echo "# Transit Gateway propagations:"
maybe_run 'aws ec2 describe-transit-gateway-attachments --query "TransitGatewayAttachments[*].{attach:TransitGatewayAttachmentId,prop:Association}" --output table'

echo "# Inspection VPC firewall subnet routes (0.0.0.0/0 -> NAT Gateway):"
maybe_run 'aws ec2 describe-route-tables --filters Name=tag:Purpose,Values=firewall --query "RouteTables[*].{rt:RouteTableId,routes:Routes}" --output table'

echo "# Direct internet-route absence check (workload VPCs must have no 0.0.0.0/0 -> igw):"
maybe_run 'aws ec2 describe-internet-gateways --query "InternetGateways[*].Attachments[*].VpcId" --output table'