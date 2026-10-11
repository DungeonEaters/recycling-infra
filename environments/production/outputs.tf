output "public_ip" {
  value       = oci_core_instance.main.public_ip
  description = "Assign A/AAAA DNS records for root, api and driver subdomains to this address."
}

output "instance_id" {
  value = oci_core_instance.main.id
}
