# Traffic flows

Allowed and blocked flows against the traffic-policy matrix. See
`routing-design.md` for the route tables that implement these.

| Source | Destination | Protocol | Result | Path |
| --- | --- | --- | --- | --- |
| Production | Internet (allowed domain) | HTTPS | Allow | app->TGW->firewall->allowed-domains ALLOWLIST->NAT->IGW |
| Development | Internet (allowed domain) | HTTPS | Allow | app->TGW->firewall->ALLOWLIST->NAT->IGW |
| Production | Internet | Telnet | Block+alert | app->TGW->firewall->deny drop (sid 10000022) |
| Development | Production | SSH | Block+alert | app->TGW->firewall->deny drop (sid 10000020) |
| Development | Production | any app port | Block | deny drop (sid 10000021) |
| Shared services | Production | SSH | Allow | app->TGW->firewall->allow pass (sid 10000010) |
| Production | Shared services | 514/tcp | Allow | allow pass (sid 10000011) |
| Workloads | Shared services resolver | 53 udp/tcp | Allow | dns allow (sid 10000040/41) |
| Workloads | External resolver | 53 udp/tcp | Block | deny drop (sid 10000023/10000025) |
| Any workload | blocked domain | HTTP/HTTPS | Block | blocked-domains DENYLIST (priority 50) |
| Any workload | prohibited IP set | any | Block | deny drop (sid 10000024) + stateless drop |
| Any VPC | unapproved cross-VPC | any | Block | stateful default drop_strict |
| Return | established | relevant | Allow statefully | firewall stateful + appliance-mode symmetric return |

## Notes

- HTTP/HTTPS egress is allowlist-only (allowed-domains ALLOWLIST, priority 60).
- Drop actions also emit alert/flow logs ("block and alert").
- The exact runtime behavior of domain lists and STRICT_ORDER requires runtime
  validation in AWS; static tests confirm intent only.
