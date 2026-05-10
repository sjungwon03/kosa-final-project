terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }

  required_version = ">= 1.0"
}

provider "proxmox" {
  pm_api_url      = var.proxmox_api_url
  pm_user         = var.proxmox_user
  pm_password     = var.proxmox_password
  pm_tls_insecure = true
}

variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
}

variable "proxmox_user" {
  description = "Proxmox username"
  type        = string
}

variable "proxmox_password" {
  description = "Proxmox password"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

variable "vlan_public_id" {
  description = "Public VLAN ID"
  type        = number
  default     = 100
}

variable "vlan_k8s_id" {
  description = "Kubernetes Private VLAN ID"
  type        = number
  default     = 200
}

variable "vlan_db_id" {
  description = "Database MHA Private VLAN ID"
  type        = number
  default     = 300
}

variable "cluster_nodes" {
  description = "Proxmox cluster node names"
  type        = list(string)
  default     = ["pve1", "pve2", "pve3", "pve4"]
}