#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  deploy-test-api.sh --image-tag <tag>
  deploy-test-api.sh --check

Deploys the lightweight PostgreSQL + API + Caddy test stack to the OCI test
instance. In deploy mode, the script prompts for a GHCR PAT with read:packages.
The token is transmitted only through SSH standard input and is never written to
Terraform, project files or command-line arguments.
EOF
}

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config_file="${project_root}/.oci-project.env"
image_tag=""
check_only=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image-tag)
      image_tag="${2:?Missing value for --image-tag}"
      shift 2
      ;;
    --check)
      check_only=true
      shift
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -f "$config_file" ]]; then
  printf 'Missing %s. Create it from .oci-project.env.example.\n' "$config_file" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$config_file"

: "${OCI_CLI_PROFILE:=DEFAULT}"
: "${TEST_COMPARTMENT_NAME:?TEST_COMPARTMENT_NAME must be set}"
: "${TEST_INSTANCE_NAME:=recycling-logistics-test}"
: "${GHCR_USERNAME:=JulioRom}"
: "${DEPLOY_SSH_KEY:=$HOME/.ssh/recycling-logistics-deploy}"

for command in oci ssh scp ssh-keygen; do
  command -v "$command" >/dev/null || {
    printf '%s is required but was not found in PATH.\n' "$command" >&2
    exit 1
  }
done

if ! "$check_only"; then
  [[ "$image_tag" =~ ^[A-Za-z0-9._-]+$ ]] || {
    printf 'A valid --image-tag is required.\n' >&2
    exit 2
  }
fi

test -r "$DEPLOY_SSH_KEY" || {
  printf 'Cannot read deployment SSH key: %s\n' "$DEPLOY_SSH_KEY" >&2
  exit 1
}

oci_cmd=(oci --profile "$OCI_CLI_PROFILE")
compartment_ocid="$("${oci_cmd[@]}" iam compartment list \
  --compartment-id-in-subtree true \
  --all \
  --query "data[?name=='${TEST_COMPARTMENT_NAME}'].id | [0]" \
  --raw-output)"

[[ -n "$compartment_ocid" && "$compartment_ocid" != "null" ]] || {
  printf 'Compartment "%s" was not found.\n' "$TEST_COMPARTMENT_NAME" >&2
  exit 1
}

instance_id="$("${oci_cmd[@]}" compute instance list \
  --compartment-id "$compartment_ocid" \
  --all \
  --query "data[?\"display-name\"=='${TEST_INSTANCE_NAME}' && \"lifecycle-state\"=='RUNNING'].id | [0]" \
  --raw-output)"

[[ -n "$instance_id" && "$instance_id" != "null" ]] || {
  printf 'Running test instance "%s" was not found.\n' "$TEST_INSTANCE_NAME" >&2
  exit 1
}

vnic_id="$("${oci_cmd[@]}" compute vnic-attachment list \
  --compartment-id "$compartment_ocid" \
  --instance-id "$instance_id" \
  --all \
  --query 'data[0]."vnic-id"' \
  --raw-output)"

public_host="$("${oci_cmd[@]}" network vnic get \
  --vnic-id "$vnic_id" \
  --query 'data."public-ip"' \
  --raw-output)"

[[ -n "$public_host" && "$public_host" != "null" ]] || {
  printf 'The test instance does not have a public IP.\n' >&2
  exit 1
}

ssh-keygen -F "$public_host" >/dev/null || {
  printf 'No verified SSH host key for %s. Verify and add it before deploying.\n' \
    "$public_host" >&2
  exit 1
}

ssh_opts=(
  -i "$DEPLOY_SSH_KEY"
  -o BatchMode=yes
  -o StrictHostKeyChecking=yes
  -o ConnectTimeout=15
)
deploy_path="/opt/recycling-logistics/test"

if "$check_only"; then
  # shellcheck disable=SC2029
  ssh "${ssh_opts[@]}" "ubuntu@${public_host}" \
    "DEPLOY_PATH='$deploy_path' bash -s -- --check" \
    <"${project_root}/scripts/deploy-test-api-remote.sh"
  exit 0
fi

read -r -s -p 'GHCR PAT (read:packages): ' ghcr_pull_token
printf '\n'
[[ -n "$ghcr_pull_token" ]] || {
  printf 'A GHCR pull token is required.\n' >&2
  exit 1
}

scp "${ssh_opts[@]}" \
  "${project_root}/docker-compose.test.yml" \
  "${project_root}/Caddyfile.test" \
  "${project_root}/scripts/deploy-test-api-remote.sh" \
  "ubuntu@${public_host}:${deploy_path}/"

 # shellcheck disable=SC2029
printf '%s\n' "$ghcr_pull_token" |
  ssh "${ssh_opts[@]}" "ubuntu@${public_host}" \
    "chmod 700 '${deploy_path}/deploy-test-api-remote.sh' && DEPLOY_PATH='$deploy_path' bash '${deploy_path}/deploy-test-api-remote.sh' --image-tag '$image_tag' --ghcr-username '$GHCR_USERNAME' --public-host '$public_host'"

unset ghcr_pull_token
curl --fail --silent --show-error --connect-timeout 15 "http://${public_host}/health"
printf '\nDeployment verified: http://%s/health\n' "$public_host"
