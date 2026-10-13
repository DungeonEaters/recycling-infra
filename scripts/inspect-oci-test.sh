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
: "${TEST_STATE_BUCKET:?TEST_STATE_BUCKET must be set}"
: "${TEST_STATE_PREFIX:?TEST_STATE_PREFIX must be set}"

command -v oci >/dev/null || {
  printf 'The OCI CLI is required but was not found in PATH.\n' >&2
  exit 1
}

oci_cmd=(oci --profile "$OCI_CLI_PROFILE")
namespace="$("${oci_cmd[@]}" os ns get --query 'data' --raw-output)"
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

printf '\nCompartment\n'
"${oci_cmd[@]}" iam compartment get \
  --compartment-id "$compartment_ocid" \
  --query 'data.{name:name,state:"lifecycle-state",ocid:id}' \
  --output table

printf '\nTerraform state bucket\n'
"${oci_cmd[@]}" os bucket get \
  --namespace-name "$namespace" \
  --bucket-name "$TEST_STATE_BUCKET" \
  --query 'data.{name:name,publicAccess:"public-access-type",versioning:versioning}' \
  --output table

printf '\nTerraform state objects\n'
"${oci_cmd[@]}" os object list \
  --namespace-name "$namespace" \
  --bucket-name "$TEST_STATE_BUCKET" \
  --prefix "$TEST_STATE_PREFIX" \
  --all \
  --output table
