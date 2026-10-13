variable "tenancy_ocid" {
  type      = string
  sensitive = true
}

variable "user_ocid" {
  type      = string
  sensitive = true
}

variable "api_key_fingerprint" {
  type      = string
  sensitive = true
}

variable "api_private_key" {
  type      = string
  sensitive = true
}

variable "region" {
  type = string
  validation {
    condition     = var.region == "sa-santiago-1"
    error_message = "Bootstrap is restricted to sa-santiago-1."
  }
}

variable "parent_compartment_ocid" {
  type        = string
  sensitive   = true
  description = "Tenancy/root compartment OCID that owns the ephemeral test compartment."
}

variable "object_storage_namespace" {
  type        = string
  description = "OCI Object Storage namespace for the tenancy."
}

variable "compartment_name" {
  type        = string
  default     = "cmp-reciclaje-test"
  description = "Ephemeral compartment created to validate the bootstrap path."
}

variable "state_bucket_name" {
  type        = string
  default     = "recycling-tfstate-test"
  description = "Private bucket that receives this module's state after bootstrap."
}
