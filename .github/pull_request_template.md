## Summary

Brief description of the change.

## Change type

- [ ] Terraform / infrastructure
- [ ] Firewall rules
- [ ] Routing
- [ ] Logging / monitoring
- [ ] Tests
- [ ] Documentation
- [ ] CI

## Security-sensitive?

If you changed any of the following, explain the routing/firewall impact:

- `terraform/modules/network-firewall/`
- `terraform/modules/firewall-policy/`
- `terraform/modules/inspection-routing/`
- `terraform/modules/transit-gateway/`
- `rules/`

## Validation

- [ ] `terraform fmt -check -recursive` passes
- [ ] `terraform validate` passes
- [ ] `pytest` passes
- [ ] No secrets, state files, or plan files committed
- [ ] No `terraform apply` run without explicit approval

## Deployment status

This project is **designed and statically validated**. Do not claim "deployed and validated" without real deployment evidence.