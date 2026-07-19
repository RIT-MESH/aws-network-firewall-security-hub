# Traffic flows

This document explains how traffic is processed by the centralized AWS Network
Firewall inspection architecture. The diagrams below show traffic decisions
(allow, block, alert) and the path each packet takes through route tables,
Transit Gateway, the firewall engine, NAT gateways, and logging.

The Mermaid source for the primary flow diagram is in
`architecture/diagrams/traffic-flow.mmd`.

## Firewall processing flow

The primary processing flow shows how every packet from a workload VPC is
routed through the firewall and evaluated by stateless then stateful rules
before reaching a destination or being dropped.

```mermaid
flowchart LR
    subgraph Source["Source VPC"]
        WL["Workload<br/>instance"]
        RT1["App subnet<br/>route table"]
    end

    subgraph TGW["Transit Gateway"]
        TWRT["Workload route table<br/>0.0.0.0/0 -> inspection"]
        INSP["Inspection attachment<br/>(appliance mode)"]
    end

    subgraph NFW["Network Firewall - same AZ"]
        TGWRT["TGW subnet<br/>route table"]
        SL{"Stateless<br/>evaluation"}
        SF{"Stateful Suricata<br/>evaluation"}
    end

    ALLOW["ALLOW"]
    BLOCK["BLOCK"]
    NAT["NAT -> IGW -> Internet"]
    cross["TGW -> dest VPC"]
    DROP["Dropped"]
    CW["CloudWatch<br/>ALERT logs"]
    S3["S3 FLOW<br/>archive"]

    WL --> RT1 --> TWRT --> INSP --> TGWRT --> SL
    SL -->|"prohibited IP"| BLOCK
    SL -->|"forward to stateful"| SF
    SF -->|"tls.sni allowlist pass"| ALLOW
    SF -->|"tls.sni denylist drop"| BLOCK
    SF -->|"explicit pass rule"| ALLOW
    SF -->|"explicit drop rule"| BLOCK
    SF -->|"unmatched catch-all"| BLOCK
    ALLOW -->|"internet egress"| NAT
    ALLOW -->|"cross-VPC"| cross
    BLOCK --> DROP
    BLOCK -.->|"ALERT"| CW
    BLOCK -.->|"FLOW"| S3
    ALLOW -.->|"FLOW"| S3
```

## Allowed HTTPS egress

When a workload requests an approved domain, the firewall passes the flow
and traffic exits through the NAT gateway and Internet Gateway.

```mermaid
flowchart LR
    WL["Workload<br/>HTTPS request"] --> RT["App route table<br/>-> TGW"]
    RT --> TGW["Transit Gateway<br/>-> inspection"]
    TGW --> FW["Network Firewall<br/>same-AZ endpoint"]
    FW --> SNI{"tls.sni rule<br/>domain in<br/>allowlist?"}
    SNI -->|"Yes - pass"| NAT["NAT Gateway<br/>same AZ"]
    NAT --> IGW["Internet Gateway"]
    IGW --> NET["Internet"]
    FW -.->|"FLOW log"| S3["S3 FLOW archive"]
```

## Blocked or unapproved HTTPS

Restricted domains are dropped by the tls.sni denylist. Unmatched HTTPS
domains are dropped by the catch-all from_server rule. Both generate alert
and flow logs.

```mermaid
flowchart LR
    WL["Workload<br/>HTTPS request"] --> FW["Network Firewall"]
    FW --> SNI{"tls.sni<br/>evaluation"}
    SNI -->|"domain in denylist"| DROP1["DROP<br/>flow-level drop"]
    SNI -->|"domain not in allowlist"| DROP2["DROP<br/>catch-all<br/>from_server drop"]
    SNI -->|"domain in allowlist"| PASS["PASS<br/>allowed"]
    DROP1 -.-> CW["CloudWatch<br/>ALERT log"]
    DROP1 -.-> S3["S3 FLOW archive"]
    DROP2 -.-> CW
    DROP2 -.-> S3
    PASS --> NAT["NAT -> IGW -> Internet"]
```

## Inspected cross-VPC flows

Cross-VPC traffic is inspected by the firewall before reaching the destination
VPC. Approved flows pass through; unapproved flows are dropped.

### Development to Production - blocked

```mermaid
flowchart LR
    DEV["Dev workload"] --> TGW["Transit Gateway"]
    TGW --> FW["Network Firewall"]
    FW --> RULE{"Stateful rule<br/>dev -> prod?"}
    RULE -->|"drop rule<br/>sid 10000020<br/>SSH"| BLOCK["DROP<br/>+ alert log"]
    RULE -->|"drop rule<br/>sid 10000021<br/>any port"| BLOCK
    BLOCK -.-> CW["CloudWatch<br/>ALERT log"]
```

### Shared Services to Production SSH - allowed

```mermaid
flowchart LR
    SH["Shared Services<br/>workload"] --> TGW["Transit Gateway"]
    TGW --> FW["Network Firewall"]
    FW --> RULE{"Stateful rule<br/>shared -> prod:22?"}
    RULE -->|"pass rule<br/>sid 10000010"| PASS["PASS"]
    PASS --> TGW2["TGW -> inspection<br/>route table"]
    TGW2 --> PROD["Production VPC<br/>private subnet"]
```

### Production to Shared Services logging - allowed

```mermaid
flowchart LR
    PROD["Production<br/>workload"] --> TGW["Transit Gateway"]
    TGW --> FW["Network Firewall"]
    FW --> RULE{"Stateful rule<br/>prod -> shared:514?"}
    RULE -->|"pass rule<br/>sid 10000011"| PASS["PASS"]
    PASS --> TGW2["TGW"]
    TGW2 --> SH["Shared Services VPC"]
```

## DNS decision flow

Workloads must use the approved DNS resolver in Shared Services. External DNS
resolvers are blocked.

```mermaid
flowchart LR
    WL["Workload<br/>DNS request"] --> FW["Network Firewall"]
    FW --> DEST{"Destination<br/>resolver?"}
    DEST -->|"Shared Services<br/>resolver:53"| PASS["PASS<br/>sid 10000080/10000081"]
    DEST -->|"External resolver<br/>e.g. 8.8.8.8:53"| BLOCK["DROP<br/>sid 10000023/10000025"]
    PASS --> SH["Shared Services VPC"]
    BLOCK -.-> CW["CloudWatch<br/>ALERT log"]
```

## Symmetric return traffic

Transit Gateway appliance mode preserves Availability Zone affinity so that
return traffic passes through the same firewall endpoint as the forward path.

```mermaid
flowchart LR
    NET["Internet response"] --> IGW["Internet Gateway"]
    IGW --> NAT["NAT Gateway<br/>same AZ"]
    NAT --> PUB["Public subnet<br/>route table<br/>spoke CIDR -> firewall"]
    PUB --> FW["Network Firewall<br/>same-AZ endpoint<br/>(established flow)"]
    FW --> TGW["Transit Gateway<br/>appliance mode<br/>same AZ"]
    TGW --> WL["Originating workload<br/>same AZ"]
```

Appliance mode on the inspection TGW attachment ensures that traffic
ingressing AZ-a returns through AZ-a, keeping the forward and return paths
symmetric through the same firewall endpoint.

## Traffic-policy matrix

| Source | Destination | Protocol | Result | Path |
| --- | --- | --- | --- | --- |
| Production | Internet (allowed domain) | HTTPS | Allow | app->TGW->firewall->tls.sni pass->NAT->IGW |
| Development | Internet (allowed domain) | HTTPS | Allow | app->TGW->firewall->tls.sni pass->NAT->IGW |
| Shared Services | Internet (allowed domain) | HTTPS | Allow | app->TGW->firewall->tls.sni pass->NAT->IGW |
| Any workload | Restricted domain | HTTPS | Block | app->TGW->firewall->tls.sni drop |
| Any workload | Unmatched domain | HTTPS | Block | app->TGW->firewall->catch-all from_server drop |
| Production | Internet | Telnet | Block+alert | app->TGW->firewall->deny drop (sid 10000022) |
| Development | Production | SSH | Block+alert | app->TGW->firewall->deny drop (sid 10000020) |
| Development | Production | any app port | Block | deny drop (sid 10000021) |
| Shared Services | Production | SSH | Allow | app->TGW->firewall->allow pass (sid 10000010) |
| Production | Shared Services | 514/tcp | Allow | allow pass (sid 10000011) |
| Workloads | Shared Services resolver | 53 udp/tcp | Allow | dns pass (sid 10000080/10000081) |
| Workloads | External resolver | 53 udp/tcp | Block | deny drop (sid 10000023/10000025) |
| Any workload | Prohibited IP set | any | Block | stateless drop + deny drop (sid 10000024) |
| Return | established | relevant | Allow | firewall stateful + appliance-mode symmetric return |

## Notes

- HTTPS egress is allowlist-only via native Suricata `tls.sni` rules (priority 55).
- Blocked domains are dropped via `tls.sni` denylist rules within the same group.
- Unmatched HTTPS server responses are dropped by the catch-all `from_server` rule.
- Drop actions emit alert and flow logs (block and alert in one rule).
- NFW FLOW logs are archived to S3; ALERT logs go to CloudWatch.
- VPC Flow Logs go to CloudWatch (separate from NFW logs).
- The stateful default is `alert_strict` which allows the TCP handshake to
  complete so `tls.sni` rules can evaluate the SNI before applying the verdict.
- No workload VPC has an Internet Gateway; direct bypass is not possible.
- Runtime validation confirmed all 20 traffic tests pass with this design.
