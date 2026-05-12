output "percona_ips" {
  description = "Percona XtraDB Cluster node IP addresses"
  value       = [for p in module.percona : p.vm_ip]
}

output "percona_names" {
  description = "Percona node names"
  value       = [for p in module.percona : p.vm_name]
}

output "percona_first_ip" {
  description = "First Percona node IP (bootstrap node)"
  value       = module.percona[0].vm_ip
}

output "haproxy_ips" {
  description = "HAProxy node IP addresses"
  value       = [for h in module.haproxy : h.vm_ip]
}

output "haproxy_names" {
  description = "HAProxy node names"
  value       = [for h in module.haproxy : h.vm_name]
}

output "proxysql_ips" {
  description = "ProxySQL node IP addresses"
  value       = [for p in module.proxysql : p.vm_ip]
}

output "proxysql_names" {
  description = "ProxySQL node names"
  value       = [for p in module.proxysql : p.vm_name]
}

output "haproxy_vip" {
  description = "Virtual IP for HAProxy in DMZ"
  value       = "${var.dmz_ip_prefix}.30"
}

output "proxysql_vip" {
  description = "Virtual IP for ProxySQL in DMZ"
  value       = "${var.dmz_ip_prefix}.35"
}

output "all_node_ips" {
  description = "All node IP addresses"
  value = concat(
    [for p in module.percona : p.vm_ip],
    [for h in module.haproxy : h.vm_ip],
    [for p in module.proxysql : p.vm_ip]
  )
}