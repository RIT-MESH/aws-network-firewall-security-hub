# Validation guide

## Static (no AWS credentials)

```bash
terraform fmt -check -recursive
terraform init -backend=false        # in terraform/
terraform validate
pytest
scripts/test-firewall-rules.sh
```

`make validate` runs all available tools and skips missing ones clearly.

## Rule validation

```bash
python -m pytest tests/rules -q
scripts/test-firewall-rules.sh
```

## Routing validation (deployed)

```bash
scripts/test-routes.sh --run
```

## Traffic validation (deployed)

```bash
python scripts/generate-test-traffic.py --scenario allowed-https --timeout 5
python scripts/generate-test-traffic.py --scenario blocked-telnet --timeout 5
scripts/test-connectivity.sh --run
```

Each scenario exits non-zero when observed != expected.

## Log analysis

```bash
python scripts/analyze-firewall-logs.py tests/fixtures/sample-alert-logs.json
```

## CI

GitHub Actions run terraform, security, tests, and documentation workflows on
pull requests and pushes to main. None run `terraform apply`.