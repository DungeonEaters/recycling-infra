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
variable "availability_domain" { type = string }
variable "ubuntu_image_ocid" { type = string }
variable "ssh_public_key" {
  type      = string
  sensitive = true
}
variable "admin_cidrs" {
  type        = list(string)
  description = "Trusted CIDRs allowed to reach SSH. Do not use 0.0.0.0/0."
}
variable "display_name" {
  type    = string
  default = "recycling-logistics-test"
}
variable "shape" {
  type    = string
  default = "VM.Standard.A1.Flex"
}
variable "is_flexible_shape" {
  type        = bool
  default     = true
  description = "Whether the selected compute shape accepts OCPU and memory configuration."
}
variable "ocpus" {
  type    = number
  default = 1
  validation {
    condition     = var.ocpus >= 1 && var.ocpus <= 4
    error_message = "Always Free supports 1-4 A1 OCPUs."
  }
}
variable "memory_in_gbs" {
  type    = number
  default = 6
  validation {
    condition     = var.memory_in_gbs >= 6 && var.memory_in_gbs <= 24
    error_message = "Always Free supports 6-24 GB A1 memory."
  }
}
variable "boot_volume_size_in_gbs" {
  type    = number
  default = 50
  validation {
    condition     = var.boot_volume_size_in_gbs >= 50
    error_message = "Boot volume size must be at least 50 GB."
  }
}
variable "vcn_cidr" {
  type    = string
  default = "10.20.0.0/16"
}
variable "subnet_cidr" {
  type    = string
  default = "10.20.1.0/24"
}
