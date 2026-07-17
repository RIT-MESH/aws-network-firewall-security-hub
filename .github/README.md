# GitHub configuration

- `workflows/terraform.yml` - fmt, init (backend=false), validate, tflint
- `workflows/security.yml` - checkov, tfsec, gitleaks
- `workflows/tests.yml` - pytest, shellcheck, yamllint
- `workflows/documentation.yml` - markdownlint, lychee link check
- `ISSUE_TEMPLATE/` - bug report and feature request
- `pull_request_template.md`

No workflow runs `terraform apply`.
