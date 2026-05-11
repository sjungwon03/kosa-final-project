locals {
  percona_nodes = [
    for i in range(var.percona_nodes) : {
      name     = "${var.cluster_name}-pxc-${i + 1}"
      ip       = "${var.internal_ip_prefix}.${var.percona_ip_start + i}"
      node_idx = i % length(var.proxmox_nodes)
    }
  ]

  haproxy_nodes = [
    for i in range(var.haproxy_nodes) : {
      name     = "${var.cluster_name}-haproxy-${i + 1}"
      ip       = "${var.dmz_ip_prefix}.${var.haproxy_ip_start + i}"
      node_idx = i % length(var.proxmox_nodes)
    }
  ]

  proxysql_nodes = [
    for i in range(var.proxysql_nodes) : {
      name     = "${var.cluster_name}-proxysql-${i + 1}"
      ip       = "${var.dmz_ip_prefix}.${var.proxysql_ip_start + i}"
      node_idx = (i + 2) % length(var.proxmox_nodes)
    }
  ]
}

module "percona" {
  source = "../proxmox-vm"
  count  = var.percona_nodes

  vm_name       = local.percona_nodes[count.index].name
  target_node   = var.proxmox_nodes[local.percona_nodes[count.index].node_idx]
  template_name = var.template_name
  vmid          = var.percona_vmid_start + count.index

  cpu_cores    = var.percona_cpu
  memory       = var.percona_memory
  disk_size    = var.percona_disk_size
  storage      = var.storage

  network_bridge = var.network_bridge
  vlan_tag       = var.internal_vlan_tag

  ip_address  = "${local.percona_nodes[count.index].ip}/24"
  gateway     = var.internal_gateway
  dns_servers = var.dns_servers

  ssh_public_key = var.ssh_public_key
  ciuser         = var.ciuser
  cipassword     = var.cipassword

  ha_enabled     = var.ha_enabled
  ha_group       = var.ha_group
  ha_state       = "started"

  tags = concat(var.tags, ["percona", "internal"])
}

module "haproxy" {
  source = "../proxmox-vm"
  count  = var.haproxy_nodes

  vm_name       = local.haproxy_nodes[count.index].name
  target_node   = var.proxmox_nodes[local.haproxy_nodes[count.index].node_idx]
  template_name = var.template_name
  vmid          = var.haproxy_vmid_start + count.index

  cpu_cores    = var.haproxy_cpu
  memory       = var.haproxy_memory
  disk_size    = var.haproxy_disk_size
  storage      = var.storage

  network_bridge = var.network_bridge
  vlan_tag       = var.dmz_vlan_tag

  ip_address  = "${local.haproxy_nodes[count.index].ip}/24"
  gateway     = var.dmz_gateway
  dns_servers = var.dns_servers

  ssh_public_key = var.ssh_public_key
  ciuser         = var.ciuser
  cipassword     = var.cipassword

  ha_enabled     = var.ha_enabled
  ha_group       = var.ha_group
  ha_state       = "started"

  tags = concat(var.tags, ["haproxy", "dmz"])
}

module "proxysql" {
  source = "../proxmox-vm"
  count  = var.proxysql_nodes

  vm_name       = local.proxysql_nodes[count.index].name
  target_node   = var.proxmox_nodes[local.proxysql_nodes[count.index].node_idx]
  template_name = var.template_name
  vmid          = var.proxysql_vmid_start + count.index

  cpu_cores    = var.proxysql_cpu
  memory       = var.proxysql_memory
  disk_size    = var.proxysql_disk_size
  storage      = var.storage

  network_bridge = var.network_bridge
  vlan_tag       = var.dmz_vlan_tag

  ip_address  = "${local.proxysql_nodes[count.index].ip}/24"
  gateway     = var.dmz_gateway
  dns_servers = var.dns_servers

  ssh_public_key = var.ssh_public_key
  ciuser         = var.ciuser
  cipassword     = var.cipassword

  ha_enabled     = var.ha_enabled
  ha_group       = var.ha_group
  ha_state       = "started"

  tags = concat(var.tags, ["proxysql", "dmz"])
}