# Module: firewall-policy

Firewall policy and rule groups: stateless default actions, stateless rule groups, stateful Suricata rule groups (loaded from repository files), domain-list rule groups, IP-set references, strict stateful evaluation order where used, and rule capacity. Clearly separates pass, drop, reject, and alert rules and documents evaluation order.

TODO (Phase 2+): implement main.tf, ariables.tf, outputs.tf, and ersions.tf (if module-local constraints are needed). No resources are declared in this Phase 1 foundation.
