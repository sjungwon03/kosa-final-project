terraform {
  required_version = ">= 1.0.0"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc07"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.8.0"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure     = var.proxmox_tls_insecure
}

module "percona_cluster" {
  source = "./modules/percona-cluster"

  cluster_name  = var.cluster_name
  proxmox_nodes = var.proxmox_nodes
  template_name = var.template_name

  percona_nodes      = var.percona_nodes
  percona_cpu        = var.percona_cpu
  percona_memory     = var.percona_memory
  percona_disk_size  = var.percona_disk_size
  percona_vmid_start = var.percona_vmid_start

  proxysql_nodes      = var.proxysql_nodes
  proxysql_cpu        = var.proxysql_cpu
  proxysql_memory     = var.proxysql_memory
  proxysql_disk_size  = var.proxysql_disk_size
  proxysql_vmid_start = var.proxysql_vmid_start

  storage = var.storage

  network_bridge    = var.network_bridge
  dmz_vlan_tag      = var.dmz_vlan_tag
  internal_vlan_tag = var.internal_vlan_tag

  dmz_ip_prefix      = var.dmz_ip_prefix
  internal_ip_prefix = var.internal_ip_prefix

  dmz_gateway      = var.dmz_gateway
  internal_gateway = var.internal_gateway

  dns_servers = var.dns_servers

  ssh_public_key = var.ssh_public_key
  ciuser         = var.ciuser
  cipassword     = var.cipassword

  ha_enabled = var.ha_enabled
  ha_group   = var.ha_group

  tags = var.tags
}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.ini.tftpl", {
    percona_ips        = module.percona_cluster.percona_ips
    percona_names      = module.percona_cluster.percona_names
    proxysql_ips       = module.percona_cluster.proxysql_ips
    proxysql_names     = module.percona_cluster.proxysql_names
    proxysql_vip       = "${var.dmz_ip_prefix}.35"
    dmz_ip_prefix      = var.dmz_ip_prefix
    internal_ip_prefix = var.internal_ip_prefix
  })
  filename = "${path.module}/../ansible/inventory/hosts.ini"
}

resource "local_file" "cluster_info" {
  content = jsonencode({
    cluster_name = var.cluster_name
    dmz = {
      vlan_tag  = var.dmz_vlan_tag
      ip_prefix = var.dmz_ip_prefix
      gateway   = var.dmz_gateway
      proxysql = {
        ips   = module.percona_cluster.proxysql_ips
        names = module.percona_cluster.proxysql_names
        vip   = "${var.dmz_ip_prefix}.35"
      }
    }
    internal = {
      vlan_tag  = var.internal_vlan_tag
      ip_prefix = var.internal_ip_prefix
      gateway   = var.internal_gateway
      percona = {
        ips      = module.percona_cluster.percona_ips
        names    = module.percona_cluster.percona_names
        first_ip = module.percona_cluster.percona_first_ip
      }
    }
  })
  filename = "${path.module}/cluster-info.json"
}