terraform {
  required_version = ">= 1.10.0"

  # The first apply uses -backend=false. After the bucket exists, the workflow
  # migrates this state to the S3-compatible OCI Object Storage backend.
  backend "s3" {}

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }
}
