terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }

  # MinIO 백엔드 — minio-01 재배포 후 아래 블록 복원 및 로컬 state 마이그레이션
  # backend "s3" {
  #   bucket = "terraform-state"
  #   region = "us-east-1"
  #   endpoints = {
  #     s3 = "http://172.16.30.70:9000"
  #   }
  #   access_key                  = "kosa"
  #   secret_key                  = "kosa1004"
  #   skip_credentials_validation  = true
  #   skip_metadata_api_check      = true
  #   skip_region_validation       = true
  #   skip_requesting_account_id   = true
  #   use_path_style               = true
  # }
  backend "local" {}
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
