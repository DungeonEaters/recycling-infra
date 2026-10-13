resource "oci_identity_compartment" "test" {
  compartment_id = var.parent_compartment_ocid
  name           = var.compartment_name
  description    = "Ephemeral Recycling Logistics Terraform bootstrap validation."
  enable_delete  = true
}

resource "oci_objectstorage_bucket" "state" {
  compartment_id = oci_identity_compartment.test.id
  namespace      = var.object_storage_namespace
  name           = var.state_bucket_name
  access_type    = "NoPublicAccess"
  storage_tier   = "Standard"
  versioning     = "Enabled"
}
