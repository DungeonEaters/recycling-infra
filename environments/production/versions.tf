terraform {
  required_version = ">= 1.7.0"

  # OCI Object Storage exposes an S3-compatible API. Backend parameters and
  # credentials are provided by CI at init time; nothing sensitive is committed.
  backend "s3" {}

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }
}
