variable "cluster_name" {
  description = "Name of the Percona cluster"
  type        = string
}

variable "proxmox_nodes" {
  description = "List of Proxmox nodes for HA"
  type        = list(string)
}

variable "template_name" {
  description = "Template name to clone"
  type        = string
  default     = "ubuntu-22.04-template"
}

variable "ciuser" {
  description = "Cloud-init username (kosa)"
  type        = string
  default     = "kosa"
}

variable "cipassword" {
  description = "Cloud-init password (kosa1004)"
  type        = string
  default     = "kosa1004"
}

variable "percona_nodes" {
  description = "Number of Percona XtraDB Cluster nodes"
  type        = number
  default     = 3
}

variable "percona_cpu" {
  description = "CPU cores for Percona nodes"
  type        = number
  default     = 2
}

variable "percona_memory" {
  description = "Memory in MB for Percona nodes"
  type        = number
  default     = 4096
}

variable "percona_disk_size" {
  description = "Disk size in GB for Percona nodes"
  type        = number
  default     = 60
}

variable "proxysql_nodes" {
  description = "Number of ProxySQL nodes"
  type        = number
  default     = 2
}

variable "proxysql_cpu" {
  description = "CPU cores for ProxySQL nodes"
  type        = number
  default     = 2
}

variable "proxysql_memory" {
  description = "Memory in MB for ProxySQL nodes"
  type        = number
  default     = 4096
}

variable "proxysql_disk_size" {
  description = "Disk size in GB for ProxySQL nodes"
  type        = number
  default     = 30
}

variable "storage" {
  description = "Storage backend name (rbd-storage for Ceph)"
  type        = string
  default     = "rbd-storage"
}

variable "network_bridge" {
  description = "Network bridge name"
  type        = string
  default     = "vmbr1"
}

variable "internal_vlan_tag" {
  description = "Internal network VLAN tag"
  type        = number
  default     = 30
}

variable "internal_ip_prefix" {
  description = "Internal IP prefix (172.16.30)"
  type        = string
  default     = "172.16.30"
}

variable "internal_gateway" {
  description = "Internal Gateway IP address"
  type        = string
  default     = "172.16.30.1"
}

variable "dns_servers" {
  description = "List of DNS servers"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

variable "ssh_public_key" {
  description = "SSH public key"
  type        = string
}

variable "percona_ip_start" {
  description = "Starting IP for Percona nodes in Internal network"
  type        = number
  default     = 10
}

variable "percona_vmid_start" {
  description = "Starting VM ID for Percona nodes"
  type        = number
  default     = 101
}

variable "proxysql_ip_start" {
  description = "Starting IP for ProxySQL nodes in Internal network"
  type        = number
  default     = 25
}

variable "proxysql_vmid_start" {
  description = "Starting VM ID for ProxySQL nodes"
  type        = number
  default     = 121
}

variable "ha_enabled" {
  description = "Enable HA for VMs"
  type        = bool
  default     = true
}

variable "ha_group" {
  description = "HA group name for all VMs"
  type        = string
  default     = "percona-ha"
}

variable "tags" {
  description = "Tags for VMs"
  type        = list(string)
  default     = ["percona"]
}