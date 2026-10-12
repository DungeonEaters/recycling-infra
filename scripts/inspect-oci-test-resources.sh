#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config_file="${project_root}/.oci-project.env"

if [[ ! -f "$config_file" ]]; then
  printf 'Missing %s. Create it from .oci-project.env.example.\n' "$config_file" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$config_file"

: "${OCI_CLI_PROFILE:=DEFAULT}"
: "${TEST_COMPARTMENT_NAME:?TEST_COMPARTMENT_NAME must be set}"

oci_cmd=(oci --profile "$OCI_CLI_PROFILE")
compartment_ocid="$("${oci_cmd[@]}" iam compartment list \
  --compartment-id-in-subtree true \
  --all \
  --query "data[?name=='${TEST_COMPARTMENT_NAME}'].id | [0]" \
  --raw-output)"

if [[ -z "$compartment_ocid" || "$compartment_ocid" == "null" ]]; then
  printf 'Compartment "%s" was not found below the configured tenancy.\n' \
    "$TEST_COMPARTMENT_NAME" >&2
  exit 1
fi

printf '\nVCNs\n'
"${oci_cmd[@]}" network vcn list \
  --compartment-id "$compartment_ocid" \
  --all \
  --output table

printf '\nSubnets\n'
"${oci_cmd[@]}" network subnet list \
  --compartment-id "$compartment_ocid" \
  --all \
  --output table

printf '\nInstances\n'
"${oci_cmd[@]}" compute instance list \
  --compartment-id "$compartment_ocid" \
  --all \
  --output table
