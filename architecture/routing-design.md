# Routing design

This document describes the intended packet paths and the route tables that
implement centralized inspection. All routes are static and explicit; Transit
Gateway default route-table association and propagation are disabled.

> Static tests (tests/terraform/test_routing.py) confirm the configuration
> intends this design. They do NOT prove packet-level behavior. Runtime
> validation in AWS is still required.

## CIDR plan (defaults)

| VPC | CIDR | Subnets (AZ A / AZ B) |
| --- | --- | --- |
| Inspection | 10.0.0.0/16 | firewall 10.0.1.0/24 / 10.0.2.0/24, tgw 10.0.3.0/24 / 10.0.4.0/24, public 10.0.5.0/24 / 10.0.6.0/24 |
| Production | 10.1.0.0/16 | app 10.1.1.0/24 / 10.1.2.0/24, tgw 10.1.3.0/24 / 10.1.4.0/24 |
| Development | 10.2.0.0/16 | app 10.2.1.0/24 / 10.2.2.0/24, tgw 10.2.3.0/24 / 10.2.4.0/24 |
| Shared Services | 10.3.0.0/16 | shared 10.3.1.0/24 / 10.3.2.0/24, tgw 10.3.3.0/24 / 10.3.4.0/24 |

## Route tables

### Workload VPC app subnets (Production, Development, Shared Services)

| Destination | Target | Purpose |
| --- | --- | --- |
| 0.0.0.0/0 | Transit Gateway | Force all egress and cross-VPC traffic to inspection |

Workload VPCs have **no Internet Gateway** and no `0.0.0.0/0` route to an IGW,
so they cannot bypass inspection.

### Transit Gateway route tables

| Route table | Associations | Routes | Propagations |
| --- | --- | --- | --- |
| workload | production, development | 0.0.0.0/0 -> inspection attachment | (none) |
| shared_services | shared_services | 0.0.0.0/0 -> inspection attachment | (none) |
| inspection | inspection | (none) | production, development, shared_services |

### Inspection VPC subnets

| Subnet | Route table | Destination | Target | Purpose |
| --- | --- | --- | --- | --- |
| tgw-a / tgw-b | per-AZ | 0.0.0.0/0 | per-AZ Network Firewall endpoint | Send TGW-arriving traffic to the firewall |
| fw-a / fw-b | per-AZ | 0.0.0.0/0 | per-AZ NAT Gateway | Internet egress after inspection |
| fw-a / fw-b | per-AZ | spoke CIDRs (10.1.0.0/16, 10.2.0.0/16, 10.3.0.0/16) | Transit Gateway | Cross-VPC return after inspection |
| public-a / public-b | per-AZ | 0.0.0.0/0 | Internet Gateway | NAT Gateway egress to internet |

## Packet paths

### 1. Workload -> Internet (egress)

1. Workload app subnet -> 0.0.0.0/0 -> TGW attachment (workload VPC).
2. TGW workload route table -> 0.0.0.0/0 -> inspection attachment.
3. Inspection TGW attachment subnet (appliance mode) -> 0.0.0.0/0 -> per-AZ firewall endpoint.
4. Firewall inspects (stateful rule groups).
5. Firewall subnet -> 0.0.0.0/0 -> per-AZ NAT Gateway.
6. NAT Gateway -> public subnet -> 0.0.0.0/0 -> Internet Gateway -> Internet.

### 2. Return path (Internet -> workload)

1. Internet -> IGW -> NAT Gateway (state preserved per AZ).
2. NAT Gateway -> firewall subnet -> firewall (stateful, established flow).
3. Firewall subnet -> spoke CIDR route? No: return traffic destination is the
   spoke. The firewall subnet has a more-specific spoke CIDR route -> TGW.
4. TGW inspection route table (spoke CIDRs propagated) -> spoke attachment.
5. Appliance mode keeps the return on the same AZ, preserving symmetry.

### 3. Cross-VPC (e.g., Production -> Shared Services)

1. Production app subnet -> 0.0.0.0/0 -> TGW.
2. TGW workload route table -> 0.0.0.0/0 -> inspection attachment.
3. Inspection TGW attachment subnet -> firewall.
4. Firewall inspects; firewall subnet -> spoke CIDR (shared 10.3.0.0/16) -> TGW.
5. TGW inspection route table -> shared_services attachment.
6. Shared Services app subnet receives traffic. Return path is symmetric.

### 4. Blocked path example (Development -> Production SSH)

1. Development app subnet -> 0.0.0.0/0 -> TGW -> inspection -> firewall.
2. Stateful rule `drop tcp $DEV_NET -> $PROD_NET 22` drops the flow.
3. No return traffic is generated; an alert/flow log is emitted.

### 5. Failed/blocked bypass attempt

A workload attempting a direct internet path has no IGW and no `0.0.0.0/0 -> IGW`
route, so the only path is via the TGW to inspection. Direct bypass is not
possible from a workload VPC.

## Firewall endpoint selection by Availability Zone

The inspection TGW attachment has **appliance mode** enabled so that traffic
ingressing the inspection VPC on AZ A returns on AZ A. Each inspection
TGW-attachment subnet route table points `0.0.0.0/0` to the firewall endpoint in
the same AZ, and each firewall subnet points to the NAT Gateway in the same AZ.
This keeps forward and return paths on the same AZ, avoiding asymmetric routing.

## Notes and limitations

- The per-AZ `tgw -> firewall` route is created only once `firewall_endpoints`
  is wired from the Network Firewall module (Phase 4).
- Until the firewall exists, traffic entering the inspection TGW attachment
  subnets has no `0.0.0.0/0` route; this is intentional and completed in Phase 4.
- Runtime tests (test-routes.sh) are required to confirm actual forwarding.