module "network" {
  source = "./modules/network"

  proxmox_nodes      = var.cluster_nodes
  vlan_public_id     = var.vlan_public_id
  vlan_k8s_id        = var.vlan_k8s_id
  vlan_db_id         = var.vlan_db_id
}

module "k8s_masters" {
  source = "./modules/k8s-masters"

  proxmox_nodes      = var.cluster_nodes
  ssh_public_key     = var.ssh_public_key
  vlan_k8s_id        = var.vlan_k8s_id
  vlan_public_id     = var.vlan_public_id
  
  depends_on = [module.network]
}

module "k8s_workers" {
  source = "./modules/k8s-workers"

  proxmox_nodes      = var.cluster_nodes
  ssh_public_key     = var.ssh_public_key
  vlan_k8s_id        = var.vlan_k8s_id
  
  depends_on = [module.network]
}

module "database_servers" {
  source = "./modules/database"

  proxmox_nodes      = var.cluster_nodes
  ssh_public_key     = var.ssh_public_key
  vlan_db_id         = var.vlan_db_id
  
  depends_on = [module.network]
}

output "master_ips" {
  description = "Kubernetes master node IPs"
  value       = module.k8s_masters.master_ips
}

output "worker_ips" {
  description = "Kubernetes worker node IPs"
  value       = module.k8s_workers.worker_ips
}

output "database_ips" {
  description = "Database node IPs"
  value       = module.database_servers.database_ips
}

output "vlan_ids" {
  description = "VLAN IDs"
  value = {
    public = var.vlan_public_id
    k8s    = var.vlan_k8s_id
    db     = var.vlan_db_id
  }
}