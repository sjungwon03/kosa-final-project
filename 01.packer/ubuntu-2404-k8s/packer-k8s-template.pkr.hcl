packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

variable "git_commit" {
  type    = string
  default = ""
}

variable "git_branch" {
  type    = string
  default = ""
}

variable "built_by" {
  type    = string
  default = ""
}

variable "proxmox_api_url" {
  type = string
}

variable "proxmox_api_token_id" {
  type = string
}

variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
}

variable "proxmox_node" {
  type = string
}

variable "proxmox_host" {
  type    = string
  default = "192.168.34.4"
}


variable "ssh_username" {
  type    = string
  default = "kosa"
}

variable "ssh_password" {
  type      = string
  sensitive = true
}

variable "template_vm_id" {
  type    = number
  default = 9005
}

source "proxmox-clone" "ubuntu-k8s" {
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true

  node                 = var.proxmox_node
  clone_vm_id          = 9003
  full_clone           = true
  vm_id                = var.template_vm_id
  vm_name              = "ubuntu-2404-k8s-1.32"
  template_description = "Ubuntu 24.04 LTS K8s 노드 템플릿 (kubeadm/kubelet/kubectl 1.32 + containerd)"
  machine              = "q35"

  cores           = 2
  memory          = 4096
  cpu_type        = "host"
  os              = "l26"
  scsi_controller = "virtio-scsi-single"

  network_adapters {
    model    = "virtio"
    bridge   = "vmbr0"
    vlan_tag = "20"
  }

  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = "15m"
  ssh_handshake_attempts = 100

  qemu_agent = true
  task_timeout = "10m"
}

build {
  sources = ["source.proxmox-clone.ubuntu-k8s"]

  provisioner "shell" {
    inline = [
      "sudo cloud-init status --wait || true",
      "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf || true",
      "sudo sed -i 's/KbdInteractiveAuthentication no/KbdInteractiveAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf || true",
      "sudo systemctl restart ssh",
      "while sudo fuser /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock /var/lib/dpkg/lock-frontend > /dev/null 2>&1; do echo 'apt lock 대기 중...'; sleep 5; done"
    ]
  }

  provisioner "shell" {
    script = "ubuntu-2404-k8s/install-k8s.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "GIT_COMMIT=${var.git_commit}",
      "GIT_BRANCH=${var.git_branch}",
      "BUILT_BY=${var.built_by}"
    ]
    inline = [
      "echo \"TEMPLATE_NAME=ubuntu-2404-k8s\" | sudo tee /home/kosa/build-info.txt",
      "echo \"TEMPLATE_VMID=${var.template_vm_id}\" | sudo tee -a /home/kosa/build-info.txt",
      "echo \"BUILD_TIMESTAMP=$(date --iso-8601=seconds)\" | sudo tee -a /home/kosa/build-info.txt",
      "echo \"GIT_COMMIT=$GIT_COMMIT\" | sudo tee -a /home/kosa/build-info.txt",
      "echo \"GIT_BRANCH=$GIT_BRANCH\" | sudo tee -a /home/kosa/build-info.txt",
      "echo \"BUILT_BY=$BUILT_BY\" | sudo tee -a /home/kosa/build-info.txt"
    ]
  }

  # 골든 이미지 정리
  provisioner "shell" {
    inline = [
      "sudo cloud-init clean --logs --seed",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo rm -f /var/lib/dbus/machine-id",
      "sudo ln -s /etc/machine-id /var/lib/dbus/machine-id",
      "sudo apt-get clean",
      "sudo sync"
    ]
  }

  post-processor "shell-local" {
    inline = [
      "ssh root@${var.proxmox_host} 'qm set ${var.template_vm_id} --delete serial0 --vga std'"
    ]
  }
}
