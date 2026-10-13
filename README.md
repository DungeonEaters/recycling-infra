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

Architecture and manual OCI bootstrap details:

- [Production infrastructure design](docs/architecture/infrastructure_design.md)
- [Oracle administrator setup](docs/architecture/oracle_admin_setup.md)

The prerequisite test root in [environments/bootstrap/](environments/bootstrap/) creates
an isolated test compartment and remote state bucket before production provisioning. It
is intentionally separate because Terraform must initialize its backend before the
production root can create resources.

## Test application deployment

The isolated test infrastructure splits its limited Always Free capacity between two AMD
instances: PostgreSQL, the API and Caddy run on the backend host; Caddy serves the
compiled web panel from the frontend host. This validates the provisioning and runtime
path; it is not sized for the complete application stack.

The test deployment is initiated from an administrator workstation already allowed by
`ADMIN_CIDRS`, not from a GitHub-hosted runner. This preserves restricted SSH access
and avoids opening port 22 to GitHub's dynamic runner ranges. The script discovers the
running test instance through OCI, requires a verified local SSH host key, and prompts
for a `read:packages` GHCR token without writing it to Terraform, repository files or
command-line arguments.

```bash
cp .oci-project.env.example .oci-project.env # first use only
make deploy-test-check
make deploy-test-api IMAGE_TAG=test-0.1.0-rc.1
make deploy-test-web
```

The API script deploys the lightweight stack and verifies
`http://<test-instance-public-ip>/health`. `make deploy-test-web` builds the local
`recycling-web` checkout with the backend's public URL, allows only the frontend origin
through API CORS, deploys the static site to the frontend candidate, and verifies its
public HTTP endpoint. To roll back the API, rerun its command with a previous immutable
backend image tag. A self-hosted runner may reuse these scripts later; the current
GitHub-hosted SSH deployment is intentionally unsupported.

### Retrying OCI Ampere A1 capacity

OCI may temporarily have no free A1 host capacity in the home region. The bounded
local CLI retry script requests the Always Free A1 maximum, one `VM.Standard.A1.Flex`
instance with 2 OCPUs and 12 GB RAM, and retries only `Out of host capacity` failures:

```bash
# Set OCI_AVAILABILITY_DOMAIN and ARM_CANDIDATE_UBUNTU_IMAGE_OCID in .oci-project.env.
make retry-test-a1-candidate
```

The default is 24 attempts, 15 minutes apart. It never retries quota, authentication,
network, or configuration failures. It creates the instance directly through OCI CLI
outside Terraform state and prints the required `terraform import` command after
success; run that import before making any further Terraform changes.

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

## Production deployment automation

`.github/workflows/deploy.yml` defines the intended manual update of an existing GHCR
`image_tag` (produced by the `release.yml` workflow of
`recycling-backend`/`recycling-web`/`recycling-mobile`; see
[cicd-strategy.md](https://github.com/DungeonEaters/recycling-logistics-design/blob/main/docs/delivery/cicd-strategy.md)).
It does not build images or execute Terraform.

Do not use that SSH workflow from GitHub-hosted runners while port 22 remains limited
to `ADMIN_CIDRS`: it will time out by design. The supported test mechanism is the
local script above. Production automation must invoke the same deployment logic from
a dedicated self-hosted runner or another approved non-SSH channel.

The future runner Environment per target (`test`, `production`) requires:

**Secrets:**

- `SSH_PRIVATE_KEY` — dedicated deploy key, see [oracle-credentials-setup.md](https://github.com/DungeonEaters/recycling-logistics-design/blob/main/docs/infrastructure/oracle-credentials-setup.md)
- `SSH_KNOWN_HOSTS` — output of `ssh-keyscan <SERVER_HOST>`
- `GHCR_USERNAME`, `GHCR_PULL_TOKEN` — a GitHub user + PAT (`read:packages`) able to pull the three GHCR images on the VM

**Variables:**

- `SERVER_HOST` — VM public IP (from the first `terraform apply`)
- `SERVER_USER` — `ubuntu`
- `DEPLOY_PATH` — e.g. `/opt/recycling/production`

The VM's `.env` at `DEPLOY_PATH` must already define `API_IMAGE`, `WEB_IMAGE`, `MOBILE_IMAGE`, `APP_DOMAIN`, `ACME_EMAIL` and the application secrets (see `.env.production.example`); the workflow only updates `IMAGE_TAG` and recreates the selected service(s).
