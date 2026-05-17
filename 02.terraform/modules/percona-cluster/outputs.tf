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

output "proxysql_ips" {
  description = "ProxySQL node IP addresses"
  value       = [for p in module.proxysql : p.vm_ip]
}

output "proxysql_names" {
  description = "ProxySQL node names"
  value       = [for p in module.proxysql : p.vm_name]
}

output "proxysql_vip" {
  description = "Virtual IP for ProxySQL"
  value       = "${var.internal_ip_prefix}.105"
}

output "all_node_ips" {
  description = "All node IP addresses"
  value = concat(
    [for p in module.percona : p.vm_ip],
    [for p in module.proxysql : p.vm_ip]
  )
}