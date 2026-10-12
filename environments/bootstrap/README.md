# OCI bootstrap test

This root validates the prerequisite layer required before application infrastructure
can use an OCI Object Storage Terraform backend.

It creates only ephemeral test resources:

- compartment `cmp-reciclaje-test`;
- private, versioned bucket `recycling-tfstate-test`;
- remote state key `bootstrap-test/terraform.tfstate`.

`Bootstrap OCI test` runs format and validation on each push to
`infra/test-bootstrap`. It provisions only when a commit message contains
`[bootstrap-apply]`. This guard prevents normal documentation or code pushes from
creating OCI resources.

The first apply uses Terraform's default local backend, creates the bucket, and then
the workflow writes a temporary S3 backend configuration before migrating state to OCI
Object Storage in the same job. Do not run `destroy` from a different local state:
initialize the same remote backend first.

This module intentionally does not create API signing keys or Customer Secret Keys.
Private credential material must never enter Terraform configuration or state.
