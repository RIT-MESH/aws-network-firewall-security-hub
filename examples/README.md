# Examples

Reference `terraform.tfvars` values for the single Terraform root at `terraform/`.

- `minimal/` - smallest useful HA configuration (2 AZs, test workloads off)
- `complete/` - full logging, monitoring with SNS, and optional test workloads

Copy a tfvars example to `terraform/terraform.tfvars`, adjust, then:

```bash
cd terraform
terraform init
terraform plan -out=tfplan   # review
terraform apply tfplan       # explicit approval only
```