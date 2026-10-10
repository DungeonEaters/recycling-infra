# Recycling Infrastructure

Source of truth for Recycling Logistics infrastructure: local development Compose, production runtime configuration, Caddy, Dev Container and Oracle Cloud Terraform.

## Scope

- Local stack for the backend, admin panel and driver application.
- Production Compose using immutable GHCR images behind Caddy and Let's Encrypt.
- Oracle Cloud Always Free: Ubuntu Ampere A1 ARM64, VCN, subnet, ingress rules and Docker cloud-init.
- Terraform plan/apply workflows for Oracle Cloud.

## Local development

Run from this directory:

```bash
make up
```

Compose builds the sibling repositories:

- `../recycling-backend`
- `../recycling-web`
- `../recycling-mobile`

Endpoints: API `http://localhost:8000`, admin panel `http://localhost:5173`, driver app `http://localhost:5174`.

## Production

`docker-compose.prod.yml` runs immutable images from GHCR behind Caddy. Set secrets in an untracked `.env.production` before deployment.

The design requires a shared Oracle Always Free VM for test and production, with separate Compose directories, networks, volumes, databases and subdomains. See [environments/production/README.md](environments/production/README.md).

## Oracle Cloud Terraform

Terraform is in [environments/production/](environments/production/). It provisions:

- VCN, public subnet, Internet Gateway, route table and security list.
- Public TCP 80/443; SSH restricted to `admin_cidrs`.
- Ubuntu `VM.Standard.A1.Flex`, defaulting to 4 OCPUs and 24 GB RAM.
- Cloud-init for Docker Engine, Docker Compose plugin and UFW.

Use the initial local workflow only after filling a private `terraform.tfvars`:

```bash
cd environments/production
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform validate
terraform plan
```

Never commit `.tfvars`, Terraform state, OCI API keys, SSH private keys or production `.env` files.

## Terraform pipelines

| Workflow | Trigger | Purpose |
|---|---|---|
| `Terraform plan` | Pull request or manual | PR: format/validate. Manual: plan against OCI remote state. |
| `Terraform apply` | Manual only from `main`, input `APPLY`, Environment approval | Plan and apply Oracle resources. |

Before authenticated CI runs, manually create a private OCI Object Storage bucket and Customer Secret Key for Terraform state. The bucket is a bootstrap dependency and intentionally not managed by this state.

Configure GitHub Environment `production` secrets:

- `OCI_TENANCY_OCID`, `OCI_USER_OCID`, `OCI_API_KEY_FINGERPRINT`, `OCI_API_PRIVATE_KEY`
- `OCI_STATE_S3_ACCESS_KEY`, `OCI_STATE_S3_SECRET_KEY`

Configure Environment variables:

- `OCI_REGION`, `OCI_COMPARTMENT_OCID`, `OCI_AVAILABILITY_DOMAIN`, `OCI_UBUNTU_IMAGE_OCID`
- `DEPLOY_SSH_PUBLIC_KEY`, `ADMIN_CIDRS`, `OCI_STATE_BUCKET`, `OCI_STATE_NAMESPACE`

No `terraform destroy` workflow exists. Destruction is a separately reviewed break-glass procedure.
