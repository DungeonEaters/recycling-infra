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

output "arm_candidate_public_ip" {
  value       = try(oci_core_instance.arm_candidate[0].public_ip, null)
  description = "Public IP of the separate ARM capacity candidate, when created."
}
