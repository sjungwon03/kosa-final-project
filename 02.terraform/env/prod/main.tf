terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  insecure  = true
}

module "vms" {
  source = "../../"

  template_vm_id = var.template_vm_id
  template_node  = var.template_node
  vms            = var.vms
  vm_cores       = var.vm_cores
  vm_memory      = var.vm_memory
  vm_disk_size   = var.vm_disk_size
  vm_nameserver  = var.vm_nameserver
}
