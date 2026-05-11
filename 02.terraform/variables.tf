variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token ID"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification"
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "Percona cluster name"
  type        = string
  default     = "pxc-prod"
}

variable "proxmox_nodes" {
  description = "List of Proxmox cluster nodes"
  type        = list(string)
  default     = ["pve1", "pve2", "pve3", "pve4"]
}

variable "template_vmid" {
  description = "Template VM ID"
  type        = number
  default     = 9001
}

variable "template_name" {
  description = "VM template name"
  type        = string
  default     = "ubuntu-22.04-template"
}

variable "ciuser" {
  description = "Cloud-init username for all VMs"
  type        = string
  default     = "kosa"
}

variable "cipassword" {
  description = "Cloud-init password for all VMs"
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
  description = "Memory MB for Percona nodes"
  type        = number
  default     = 4096
}

variable "percona_disk_size" {
  description = "Disk size GB for Percona nodes"
  type        = number
  default     = 60
}

variable "haproxy_nodes" {
  description = "Number of HAProxy nodes"
  type        = number
  default     = 2
}

variable "haproxy_cpu" {
  description = "CPU cores for HAProxy nodes"
  type        = number
  default     = 2
}

variable "haproxy_memory" {
  description = "Memory MB for HAProxy nodes"
  type        = number
  default     = 2048
}

variable "haproxy_disk_size" {
  description = "Disk size GB for HAProxy nodes"
  type        = number
  default     = 20
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
  description = "Memory MB for ProxySQL nodes"
  type        = number
  default     = 4096
}

variable "proxysql_disk_size" {
  description = "Disk size GB for ProxySQL nodes"
  type        = number
  default     = 30
}

variable "storage" {
  description = "Proxmox storage backend (rbd-storage)"
  type        = string
  default     = "rbd-storage"
}

variable "network_bridge" {
  description = "Network bridge"
  type        = string
  default     = "vmbr1"
}

variable "dmz_vlan_tag" {
  description = "DMZ VLAN tag"
  type        = number
  default     = 20
}

variable "internal_vlan_tag" {
  description = "Internal network VLAN tag"
  type        = number
  default     = 30
}

variable "dmz_ip_prefix" {
  description = "DMZ IP prefix (172.16.20)"
  type        = string
  default     = "172.16.20"
}

variable "internal_ip_prefix" {
  description = "Internal IP prefix (172.16.30)"
  type        = string
  default     = "172.16.30"
}

variable "dmz_gateway" {
  description = "DMZ Gateway IP"
  type        = string
  default     = "172.16.20.1"
}

variable "internal_gateway" {
  description = "Internal Gateway IP"
  type        = string
  default     = "172.16.30.1"
}

variable "dns_servers" {
  description = "DNS servers"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

variable "ssh_public_key" {
  description = "SSH public key"
  type        = string
}

variable "ha_enabled" {
  description = "Enable HA for all VMs"
  type        = bool
  default     = true
}

variable "ha_group" {
  description = "HA group name (percona-ha)"
  type        = string
  default     = "percona-ha"
}

variable "tags" {
  description = "Tags for VMs"
  type        = list(string)
  default     = ["percona", "production"]
}