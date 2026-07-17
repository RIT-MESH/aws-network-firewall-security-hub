# Scripts

- `bootstrap.sh` - local setup instructions
- `validate.sh` - run all available validation tools (skip missing clearly)
- `test-firewall-rules.sh` - validate rule artifacts (SIDs, domain lists)
- `test-routes.sh` - read-only route inspection templates (`--run` to execute)
- `test-connectivity.sh` - run safe traffic scenarios (dry-run by default)
- `generate-test-traffic.py` - scenario-based safe traffic generator
- `analyze-firewall-logs.py` - summarize firewall JSON logs
- `estimate-costs.sh` - cost-relevant components and pricing links

All shell scripts start with `set -euo pipefail`. The Python tools support
`--dry-run` and never scan arbitrary networks.