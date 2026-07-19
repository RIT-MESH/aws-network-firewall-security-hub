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

echo "# Inspection TGW attachment subnet routes (Purpose=tgw): MUST contain 0.0.0.0/0 -> a firewall VPC endpoint (vpce-). A missing or blackhole route here is the leading cause of 'firewall received 0 packets'."
maybe_run 'aws ec2 describe-route-tables --filters Name=tag:Purpose,Values=tgw --query "RouteTables[*].{rt:RouteTableId,az:Tags[?Key==`"AzIndex`"].Value|[0],routes:Routes[?DestinationCidrBlock==`"0.0.0.0/0`"].{dst:DestinationCidrBlock,target:VpcEndpointId,state:State}}" --output table'

echo "# Firewall endpoint -> Availability Zone alignment. The endpoint AZ must equal the AZ of the tgw route table that targets it. Verify each sync_states entry has exactly one endpoint and its AvailabilityZone matches the intended AZ."
maybe_run 'aws network-firewall describe-firewall --query "Firewall.FirewallStatus.SyncStates[*].{az:AvailabilityZone,endpoint:Attachment[0].EndpointId,subnet:Attachment[0].SubnetId,state:Config}" --output table'

echo "# Firewall control-plane status. FirewallStatusSyncState must be IN_SYNC and Config be READY before traffic tests; otherwise endpoints are not installed and packets will not flow."
maybe_run 'aws network-firewall describe-firewall --query "Firewall.{name:FirewallName,status:FirewallStatus.SyncState,config:FirewallStatus.Configuration.Status}" --output table'

echo "# NAT Gateway state (per AZ). Each firewall subnet 0.0.0.0/0 route targets a NAT Gateway that must be in available state, or egress (and thus return) traffic blackholes."
maybe_run 'aws ec2 describe-nat-gateways --query "NatGateways[*].{nat:NatGatewayId,state:State,az:SubnetId,ip:NatGatewayAddresses[0].PublicIp}" --output table'

echo "# Workload app subnet default routes: target MUST be a Transit Gateway (tgw-), never an Internet Gateway. Confirms workloads cannot bypass inspection."
maybe_run 'aws ec2 describe-route-tables --filters Name=tag:Purpose,Values=app --query "RouteTables[*].{rt:RouteTableId,routes:Routes[?DestinationCidrBlock==`"0.0.0.0/0`"].{dst:DestinationCidrBlock,tgw:TransitGatewayId,igw:GatewayId}}" --output table'
