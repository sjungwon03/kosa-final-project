output "proxysql_admin_url" {
  description = "ProxySQL admin URL"
  value       = "${split("/", module.proxysql[0].vm_ip)[0]}:6032"
}

output "mysql_connection_string_proxysql" {
  description = "MySQL connection string via ProxySQL"
  value       = "mysql -h ${var.internal_ip_prefix}.105 -P 6033 -u root -p"
}