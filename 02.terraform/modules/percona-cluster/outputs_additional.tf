output "proxysql_admin_url" {
  description = "ProxySQL admin URL"
  value       = "${split("/", module.proxysql[0].vm_ip)[0]}:6032"
}

output "mysql_connection_string_proxysql" {
  description = "MySQL connection string via ProxySQL (DMZ)"
  value       = "mysql -h ${var.dmz_ip_prefix}.35 -P 6033 -u root -p"
}