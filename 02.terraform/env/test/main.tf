terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  insecure  = true
}

module "vms" {
  source          = "../../"
  template_node   = var.template_node
  vms             = var.vms
  vm_nameserver   = var.vm_nameserver
  vm_password     = var.vm_password
  ssh_public_key  = var.ssh_public_key
}
