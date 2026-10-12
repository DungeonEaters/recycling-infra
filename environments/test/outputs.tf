output "public_ip" {
  value       = oci_core_instance.main.public_ip
  description = "Temporary public address for test validation."
}

output "instance_id" {
  value = oci_core_instance.main.id
}

output "vcn_id" {
  value = oci_core_vcn.main.id
}
