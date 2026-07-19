#!/usr/bin/env bash
# Read-only route inspection and validation for deployed infrastructure.
#
# Classifies AWS VPC route targets from the actual populated route field AND the
# identifier prefix (so an AWS Network Firewall endpoint route, which AWS
# returns with a vpce-prefixed value in GatewayId, is correctly recognised as
# NFW_ENDPOINT and NOT mistaken for an Internet Gateway).
#
# Default behavior prints the commands to run. Pass --run to execute the
# read-only queries and validate; the script exits non-zero if any required
# route is missing, mis-targeted, blackhole, or unknown. Never performs
# mutations.
set -euo pipefail

RUN=0
if [[ "${1:-}" == "--run" ]]; then RUN=1; fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="$SCRIPT_DIR/classify_route.py"
FAIL=0

# Run a command in --run mode, otherwise just print it.
maybe_run() {
  if [[ "$RUN" -eq 1 ]]; then
    echo "==> $*"
    sh -c "$1"
  else
    echo "$1"
  fi
}

# Validate that every 0.0.0.0/0 route in route tables tagged Purpose=$1 is
# classified as $2, is active, and is not blackhole. Fails closed on unknown or
# multiple-target routes.
check_purpose() {
  local purpose="$1" expected="$2"
  local cmd="aws ec2 describe-route-tables --filters Name=tag:Purpose,Values=$purpose --output json"
  if [[ "$RUN" -eq 1 ]]; then
    echo "==> Purpose=$purpose: require 0.0.0.0/0 -> $expected (active, not blackhole)"
    if ! sh -c "$cmd" | python "$PY" --expected "$expected" --destination 0.0.0.0/0 --quiet; then
      echo "FAIL: Purpose=$purpose route classification mismatch / blackhole / unknown" >&2
      FAIL=1
    fi
  else
    echo "$cmd | python $PY --expected $expected --destination 0.0.0.0/0"
  fi
}

echo "# Required default-route targets (classified from populated field + ID prefix):"
echo "#   workload app subnets (Purpose=app)      -> TGW"
echo "#   workload shared subnets (Purpose=shared) -> TGW"
echo "#   inspection firewall subnets (Purpose=firewall) -> NAT"
echo "#   inspection public subnets (Purpose=public)     -> IGW"
echo "#   inspection TGW subnets (Purpose=tgw)           -> NFW_ENDPOINT"
check_purpose "app" "TGW"
check_purpose "shared" "TGW"
check_purpose "firewall" "NAT"
check_purpose "public" "IGW"
check_purpose "tgw" "NFW_ENDPOINT"

echo "# Full route fields per purpose (no target field hidden):"
maybe_run 'aws ec2 describe-route-tables --filters Name=tag:Purpose,Values=tgw,public,firewall,app,shared --query "RouteTables[*].{rt:RouteTableId,purpose:Tags[?Key==`"Purpose`"].Value|[0],routes:Routes[?DestinationCidrBlock==`"0.0.0.0/0`"].{dst:DestinationCidrBlock,gw:GatewayId,vpce:VpcEndpointId,tgw:TransitGatewayId,nat:NatGatewayId,eni:NetworkInterfaceId,eigw:EgressOnlyInternetGatewayId,state:State,origin:Origin}}" --output table'

echo "# Transit Gateway route-table associations and propagations:"
maybe_run 'aws ec2 describe-transit-gateway-route-tables --query "TransitGatewayRouteTables[*].{rt:TransitGatewayRouteTableId,assoc:Associations}" --output table'
maybe_run 'aws ec2 describe-transit-gateway-attachments --query "TransitGatewayAttachments[*].{attach:TransitGatewayAttachmentId,prop:Association}" --output table'

echo "# Firewall endpoint -> Availability Zone alignment (endpoint AZ must equal the AZ of the tgw route table that targets it):"
maybe_run 'aws network-firewall describe-firewall --query "Firewall.FirewallStatus.SyncStates[*].{az:AvailabilityZone,endpoint:Attachment[0].EndpointId,subnet:Attachment[0].SubnetId,state:Attachment[0].Status}" --output table'

echo "# Firewall control-plane status (SyncState must be IN_SYNC, Configuration.Status READY):"
maybe_run 'aws network-firewall describe-firewall --query "Firewall.{name:FirewallName,status:FirewallStatus.SyncState,config:FirewallStatus.Configuration.Status}" --output table'

echo "# NAT Gateway state per AZ (must be available):"
maybe_run 'aws ec2 describe-nat-gateways --query "NatGateways[*].{nat:NatGatewayId,state:State,subnet:SubnetId}" --output table'

echo "# Workload VPCs must have NO Internet Gateway (no direct internet path / no firewall bypass):"
maybe_run 'aws ec2 describe-internet-gateways --query "InternetGateways[*].Attachments[*].VpcId" --output table'

if [[ "$RUN" -eq 1 ]] && [[ "$FAIL" -ne 0 ]]; then
  echo "route validation FAILED" >&2
  exit 1
fi
echo "# route validation complete"
