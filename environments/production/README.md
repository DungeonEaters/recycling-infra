# Oracle Cloud Always Free provisioning

## Prerequisites

- Oracle Cloud tenancy, user and API signing key.
- Terraform >= 1.7 and OCI CLI/provider credentials.
- An Always Free Ampere A1 capacity reservation or availability in the selected availability domain.
- A dedicated SSH key pair for deployment/admin access. Keep its private half outside this repository.

## Configure

```bash
cd environments/production
cp terraform.tfvars.example terraform.tfvars
chmod 600 terraform.tfvars
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

`terraform apply` creates an Ubuntu ARM64 A1 instance configured for 4 OCPUs and 24 GB by default. A1 capacity is constrained; retrying a different availability domain or reducing shape values may be required.

For the team workflow, use the GitHub Actions pipelines described in the repository [README](../../README.md). They require a pre-created OCI Object Storage bucket because Terraform state must persist between GitHub runners. The bucket is a bootstrap resource and is deliberately not created by this state.

## After apply

1. Copy `public_ip` from Terraform output.
2. Create DNS A records for `<domain>`, `api.<domain>` and `driver.<domain>`.
3. Verify TCP 80/443 are open in OCI security list and Ubuntu firewall.
4. SSH in as `ubuntu`; cloud-init installs Docker and Compose.
5. Create separate `/opt/recycling-logistics/test/.env` and `/opt/recycling-logistics/production/.env` from the application repo's `.env.production.example`.
6. Add GitHub Environment secrets and variables in the application repo. Deployment is manual and must reference an existing GHCR tag.

## State

This initial scaffold uses local state to keep first provisioning explicit. Before shared automation, migrate state to an encrypted OCI Object Storage backend with locking/operational access controls. Do not commit `terraform.tfstate` or `terraform.tfvars`.
