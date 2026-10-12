output "compartment_ocid" {
  value       = oci_identity_compartment.test.id
  description = "OCI compartment created for the ephemeral bootstrap test."
}

output "state_bucket_name" {
  value       = oci_objectstorage_bucket.state.name
  description = "Private Object Storage bucket receiving the bootstrap state."
}

output "object_storage_namespace" {
  value       = oci_objectstorage_bucket.state.namespace
  description = "Object Storage namespace used by the state backend."
}
