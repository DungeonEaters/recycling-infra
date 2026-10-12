#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config_file="${project_root}/.oci-project.env"
web_root="${WEB_SOURCE_DIR:-${project_root}/../recycling-web}"

test -f "$config_file" || {
  printf 'Missing %s. Create it from .oci-project.env.example.\n' "$config_file" >&2
  exit 1
}
test -f "$web_root/package.json" || {
  printf 'Cannot find recycling-web at %s.\n' "$web_root" >&2
  exit 1
}

# shellcheck disable=SC1090
source "$config_file"

: "${OCI_CLI_PROFILE:=DEFAULT}"
: "${TEST_COMPARTMENT_NAME:?TEST_COMPARTMENT_NAME must be set}"
: "${TEST_INSTANCE_NAME:=recycling-logistics-test}"
: "${FRONTEND_TEST_INSTANCE_NAME:=recycling-logistics-frontend-test}"
: "${DEPLOY_SSH_KEY:=$HOME/.ssh/recycling-logistics-deploy}"

for command in oci ssh scp ssh-keygen npm tar; do
  command -v "$command" >/dev/null || {
    printf '%s is required but was not found in PATH.\n' "$command" >&2
    exit 1
  }
done

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

instance_public_ip() {
  local instance_name="$1"
  local instance_id vnic_id
  instance_id="$("${oci_cmd[@]}" compute instance list \
    --compartment-id "$compartment_ocid" \
    --all \
    --query "data[?\"display-name\"=='${instance_name}' && \"lifecycle-state\"=='RUNNING'].id | [0]" \
    --raw-output)"
  [[ -n "$instance_id" && "$instance_id" != "null" ]] || {
    printf 'Running instance "%s" was not found.\n' "$instance_name" >&2
    return 1
  }
  vnic_id="$("${oci_cmd[@]}" compute vnic-attachment list \
    --compartment-id "$compartment_ocid" \
    --instance-id "$instance_id" \
    --all \
    --query 'data[0]."vnic-id"' \
    --raw-output)"
  "${oci_cmd[@]}" network vnic get --vnic-id "$vnic_id" --query 'data."public-ip"' --raw-output
}

api_host="$(instance_public_ip "$TEST_INSTANCE_NAME")"
web_host="$(instance_public_ip "$FRONTEND_TEST_INSTANCE_NAME")"
for host in "$api_host" "$web_host"; do
  [[ "$host" =~ ^[A-Za-z0-9.-]+$ ]] || {
    printf 'Invalid public host returned by OCI: %s\n' "$host" >&2
    exit 1
  }
  ssh-keygen -F "$host" >/dev/null || {
    printf 'No verified SSH host key for %s. Verify and add it before deploying.\n' "$host" >&2
    exit 1
  }
done

ssh_opts=(
  -i "$DEPLOY_SSH_KEY"
  -o BatchMode=yes
  -o StrictHostKeyChecking=yes
  -o ConnectTimeout=15
)

VITE_API_URL="http://${api_host}" npm --prefix "$web_root" ci --no-audit --no-fund
VITE_API_URL="http://${api_host}" npm --prefix "$web_root" run build

archive="$(mktemp "${TMPDIR:-/tmp}/recycling-web.XXXXXX.tar.gz")"
trap 'rm -f "$archive"' EXIT
tar -C "$web_root/dist" -czf "$archive" .

ssh "${ssh_opts[@]}" "ubuntu@${api_host}" \
  "cd /opt/recycling-logistics/test && sed -i 's|^CORS_ORIGINS=.*|CORS_ORIGINS=http://${web_host},http://localhost:5173,http://localhost:5174|' .env && docker compose --env-file .env -f docker-compose.test.yml up -d api caddy"

scp "${ssh_opts[@]}" \
  "$archive" \
  "${project_root}/docker-compose.test-web.yml" \
  "${project_root}/Caddyfile.test-web" \
  "ubuntu@${web_host}:/opt/recycling-logistics/test/"

ssh "${ssh_opts[@]}" "ubuntu@${web_host}" \
  "cd /opt/recycling-logistics/test && rm -rf site && mkdir site && tar -xzf $(basename "$archive") -C site && docker compose -f docker-compose.test-web.yml up -d && curl --fail --silent --show-error http://localhost/ >/dev/null"

curl --fail --silent --show-error --connect-timeout 15 "http://${web_host}/" >/dev/null
printf 'Web deployment verified: http://%s (API: http://%s)\n' "$web_host" "$api_host"
