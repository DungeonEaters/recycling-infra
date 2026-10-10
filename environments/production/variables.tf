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
variable "region" { type = string }
variable "compartment_ocid" { type = string }
variable "availability_domain" {
  type        = string
  description = "Availability domain name returned by OCI for the selected region."
}
variable "ubuntu_image_ocid" {
  type        = string
  description = "Canonical Ubuntu ARM64 image OCID for the selected region."
}
variable "ssh_public_key" {
  type        = string
  sensitive   = true
  description = "Dedicated administration/deployment public key."
}
variable "admin_cidrs" {
  type        = list(string)
  description = "Trusted CIDRs allowed to reach SSH. Do not use 0.0.0.0/0."
}
variable "display_name" {
  type    = string
  default = "recycling-logistics"
}
variable "shape" {
  type    = string
  default = "VM.Standard.A1.Flex"
}
variable "ocpus" {
  type    = number
  default = 4
  validation {
    condition     = var.ocpus >= 1 && var.ocpus <= 4
    error_message = "Always Free supports 1-4 A1 OCPUs."
  }
}
variable "memory_in_gbs" {
  type    = number
  default = 24
  validation {
    condition     = var.memory_in_gbs >= 6 && var.memory_in_gbs <= 24
    error_message = "Always Free supports 6-24 GB A1 memory."
  }
}
variable "vcn_cidr" {
  type    = string
  default = "10.10.0.0/16"
}
variable "subnet_cidr" {
  type    = string
  default = "10.10.1.0/24"
}
