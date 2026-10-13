#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: retry-oci-a1-candidate.sh [--max-attempts <count>] [--delay-seconds <seconds>]

Attempts to create one Always Free maximum OCI Ampere A1 candidate (2 OCPUs,
12 GB RAM) in the configured test compartment. Only OCI "Out of host capacity"
errors are retried. All other errors stop immediately.

Required .oci-project.env values:
  OCI_AVAILABILITY_DOMAIN
  ARM_CANDIDATE_UBUNTU_IMAGE_OCID

Optional .oci-project.env values:
  ARM_CANDIDATE_DISPLAY_NAME       Default: recycling-logistics-arm-cli-candidate
  ARM_CANDIDATE_BOOT_VOLUME_GBS    Default: 50
  DEPLOY_SSH_PUBLIC_KEY_PATH       Default: ~/.ssh/recycling-logistics-deploy.pub

The candidate is created directly with OCI CLI, outside Terraform state. If it
succeeds, import it into the dedicated Terraform candidate resource before
making further Terraform changes.
EOF
}

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config_file="${project_root}/.oci-project.env"
max_attempts=24
delay_seconds=900

while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-attempts)
      max_attempts="${2:?Missing value for --max-attempts}"
      shift 2
      ;;
    --delay-seconds)
      delay_seconds="${2:?Missing value for --delay-seconds}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

[[ "$max_attempts" =~ ^[1-9][0-9]*$ ]] || {
  printf '--max-attempts must be a positive integer.\n' >&2
  exit 2
}
[[ "$delay_seconds" =~ ^[1-9][0-9]*$ ]] || {
  printf '--delay-seconds must be a positive integer.\n' >&2
  exit 2
}
test -f "$config_file" || {
  printf 'Missing %s. Create it from .oci-project.env.example.\n' "$config_file" >&2
  exit 1
}

# shellcheck disable=SC1090
source "$config_file"

: "${OCI_CLI_PROFILE:=DEFAULT}"
: "${TEST_COMPARTMENT_NAME:?TEST_COMPARTMENT_NAME must be set}"
: "${OCI_AVAILABILITY_DOMAIN:?OCI_AVAILABILITY_DOMAIN must be set}"
: "${ARM_CANDIDATE_UBUNTU_IMAGE_OCID:?ARM_CANDIDATE_UBUNTU_IMAGE_OCID must be set}"
: "${ARM_CANDIDATE_DISPLAY_NAME:=recycling-logistics-arm-cli-candidate}"
: "${ARM_CANDIDATE_BOOT_VOLUME_GBS:=50}"
: "${DEPLOY_SSH_PUBLIC_KEY_PATH:=$HOME/.ssh/recycling-logistics-deploy.pub}"

for command in oci python3 ssh-keygen; do
  command -v "$command" >/dev/null || {
    printf '%s is required but was not found in PATH.\n' "$command" >&2
    exit 1
  }
done
test -r "$DEPLOY_SSH_PUBLIC_KEY_PATH" || {
  printf 'Cannot read SSH public key: %s\n' "$DEPLOY_SSH_PUBLIC_KEY_PATH" >&2
  exit 1
}
[[ "$ARM_CANDIDATE_BOOT_VOLUME_GBS" =~ ^[4-9][7-9]$|^[5-9][0-9]$|^[1-9][0-9]{2,}$ ]] || {
  printf 'ARM_CANDIDATE_BOOT_VOLUME_GBS must be at least 47.\n' >&2
  exit 2
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

subnet_id="$("${oci_cmd[@]}" network subnet list \
  --compartment-id "$compartment_ocid" \
  --all \
  --query "data[?\"display-name\"=='recycling-logistics-test-public-subnet' && \"lifecycle-state\"=='AVAILABLE'].id | [0]" \
  --raw-output)"
[[ -n "$subnet_id" && "$subnet_id" != "null" ]] || {
  printf 'The available test public subnet was not found.\n' >&2
  exit 1
}

metadata_file="$(mktemp "${TMPDIR:-/tmp}/oci-a1-metadata.XXXXXX.json")"
error_file="$(mktemp "${TMPDIR:-/tmp}/oci-a1-launch.XXXXXX.log")"
trap 'rm -f "$metadata_file" "$error_file"' EXIT
python3 - "$DEPLOY_SSH_PUBLIC_KEY_PATH" "${project_root}/environments/test/cloud-init.yaml" >"$metadata_file" <<'PYTHON'
import base64
import json
import pathlib
import sys

ssh_key = pathlib.Path(sys.argv[1]).read_text().strip()
cloud_init = base64.b64encode(pathlib.Path(sys.argv[2]).read_bytes()).decode()
print(json.dumps({"ssh_authorized_keys": ssh_key, "user_data": cloud_init}))
PYTHON

for attempt in $(seq 1 "$max_attempts"); do
  printf 'A1 launch attempt %s/%s at %s\n' "$attempt" "$max_attempts" "$(date -u +%FT%TZ)"
  if launch_output="$("${oci_cmd[@]}" compute instance launch \
    --compartment-id "$compartment_ocid" \
    --availability-domain "$OCI_AVAILABILITY_DOMAIN" \
    --shape VM.Standard.A1.Flex \
    --shape-config '{"ocpus":2,"memoryInGBs":12}' \
    --subnet-id "$subnet_id" \
    --assign-public-ip true \
    --display-name "$ARM_CANDIDATE_DISPLAY_NAME" \
    --image-id "$ARM_CANDIDATE_UBUNTU_IMAGE_OCID" \
    --boot-volume-size-in-gbs "$ARM_CANDIDATE_BOOT_VOLUME_GBS" \
    --metadata "file://${metadata_file}" \
    --wait-for-state RUNNING \
    --max-wait-seconds 900 2>"$error_file")"; then
    instance_id="$(printf '%s' "$launch_output" | python3 -c 'import json, sys; print(json.load(sys.stdin)["data"]["id"])')"
    printf 'A1 candidate is RUNNING: %s\n' "$instance_id"
    printf 'Import it before using Terraform again:\n'
    printf '  terraform -chdir=environments/test import '\''oci_core_instance.arm_candidate[0]'\'' %s\n' "$instance_id"
    exit 0
  fi

  if ! grep -Fq 'Out of host capacity' "$error_file"; then
    printf 'A1 launch failed with a non-capacity error; not retrying:\n' >&2
    cat "$error_file" >&2
    exit 1
  fi

  printf 'No A1 host capacity; retrying in %s seconds.\n' "$delay_seconds" >&2
  sleep "$delay_seconds"
done

printf 'No A1 capacity after %s attempts. No instance was created.\n' "$max_attempts" >&2
exit 1
