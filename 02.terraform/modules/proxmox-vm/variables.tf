variable "vm_name" {
  description = "Name of the VM"
  type        = string
}

variable "target_node" {
  description = "Proxmox node to create VM on"
  type        = string
}

variable "template_name" {
  description = "Template name to clone"
  type        = string
  default     = "ubuntu-22.04-template"
}

variable "template_vmid" {
  description = "Template VM ID (9001)"
  type        = number
  default     = 9001
}

variable "cpu_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "memory" {
  description = "Memory in MB"
  type        = number
  default     = 4096
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 60
}

variable "storage" {
  description = "Storage backend name (rbd-storage)"
  type        = string
  default     = "rbd-storage"
}

variable "network_bridge" {
  description = "Network bridge name"
  type        = string
  default     = "vmbr1"
}

variable "vlan_tag" {
  description = "VLAN tag for network interface"
  type        = number
  default     = 30
}

variable "ip_address" {
  description = "Static IP address with CIDR"
  type        = string
}

variable "gateway" {
  description = "Gateway IP address"
  type        = string
}

variable "dns_servers" {
  description = "List of DNS servers"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

variable "onboot" {
  description = "Start VM on boot"
  type        = bool
  default     = true
}

variable "ha_enabled" {
  description = "Enable HA for VM"
  type        = bool
  default     = true
}

variable "ha_group" {
  description = "HA group name"
  type        = string
  default     = "percona-ha"
}

variable "ha_state" {
  description = "HA state (started, stopped, ignored)"
  type        = string
  default     = "started"
}

variable "ssh_public_key" {
  description = "SSH public key for access"
  type        = string
}

variable "ciuser" {
  description = "Cloud-init username"
  type        = string
  default     = "kosa"
}

variable "cipassword" {
  description = "Cloud-init password"
  type        = string
  default     = "kosa1004"
}

variable "tags" {
  description = "List of tags for the VM"
  type        = list(string)
  default     = []
}