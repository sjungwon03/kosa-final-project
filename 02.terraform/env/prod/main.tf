terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }

  backend "s3" {
    # key는 02-run.sh에서 -backend-config로 주입 (서비스별 state 분리)
    bucket = "terraform-state"
    region = "us-east-1"

    endpoints = {
      s3 = "http://172.16.30.70:9000"
    }
    access_key                  = "kosa"
    secret_key                  = "kosa1004"

    skip_credentials_validation  = true
    skip_metadata_api_check      = true
    skip_region_validation       = true
    skip_requesting_account_id   = true
    use_path_style               = true
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
