packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# TODO: Vault 구성 시 credentials.pkr.hcl / ssh-credentials.pkrvars.hcl 제거하고
#       아래 변수들을 vault() 함수로 대체
#       예: proxmox_api_token_secret = vault("secret/packer/proxmox", "token_secret")
#           ssh_password             = vault("secret/packer/ssh", "password")

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

variable "ssh_username" {
  type = string
}

variable "ssh_password" {
  type      = string
  sensitive = true
}

variable "template_vm_id" {
  type    = number
  default = 9003
}

variable "proxmox_host" {
  type    = string
  default = "192.168.34.4"
}

source "proxmox-clone" "ubuntu-template" {
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true # TODO: Proxmox 공식 TLS 인증서 발급 시 제거

  node                 = var.proxmox_node
  clone_vm_id          = 9000
  full_clone           = true
  vm_id                = var.template_vm_id
  vm_name              = "ubuntu-2404-common-v1"
  template_description = "Ubuntu 24.04 LTS Ansible 관리용 템플릿"
  machine              = "q35"

  cores           = 2
  memory          = 2048
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

  cloud_init              = true
  cloud_init_storage_pool = "rbd-storage"
}

build {
  sources = ["source.proxmox-clone.ubuntu-template"]

  provisioner "shell" {
    inline = [
      "sudo cloud-init status --wait || true",
      "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf || true",
      "sudo sed -i 's/KbdInteractiveAuthentication no/KbdInteractiveAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf || true",
      "printf 'PasswordAuthentication yes\\nKbdInteractiveAuthentication yes\\n' | sudo tee /etc/ssh/sshd_config.d/10-password.conf",
      "sudo systemctl enable ssh",
      "sudo systemctl restart ssh",
      "while sudo fuser /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock /var/lib/dpkg/lock-frontend > /dev/null 2>&1; do echo 'apt lock 대기 중...'; sleep 5; done",
      "sudo timedatectl set-timezone Asia/Seoul",
      # 부팅 시 네트워크 대기 서비스 비활성화 (cloud-init 환경에서 2분 타임아웃 발생)
      # 주의: 네트워크 의존 서비스가 network ready 전에 뜰 수 있음 → 문제 발생 시 아래 줄 제거 후 재빌드
      # "sudo systemctl disable systemd-networkd-wait-online.service",
      "sudo apt-get update",
      "sudo apt-get install -y curl wget git vim net-tools auditd python3-apt",
      "sudo systemctl disable auditd",

      # Promtail (Grafana APT)
      "sudo apt-get install -y apt-transport-https software-properties-common",
      "wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /usr/share/keyrings/grafana.gpg > /dev/null",
      "echo 'deb [signed-by=/usr/share/keyrings/grafana.gpg] https://apt.grafana.com stable main' | sudo tee /etc/apt/sources.list.d/grafana.list",
      "sudo apt-get update",
      "sudo apt-get install -y promtail",
      "sudo systemctl disable promtail",

      # Wazuh Agent 4.x
      "curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor | sudo tee /usr/share/keyrings/wazuh.gpg > /dev/null",
      "sudo chmod 644 /usr/share/keyrings/wazuh.gpg",
      "echo 'deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main' | sudo tee /etc/apt/sources.list.d/wazuh.list",
      "sudo apt-get update",
      "sudo apt-get install -y wazuh-agent",
      "sudo systemctl disable wazuh-agent",

      "sudo apt-get clean"
    ]
  }

  provisioner "shell" {
    environment_vars = [
      "GIT_COMMIT=${var.git_commit}",
      "GIT_BRANCH=${var.git_branch}",
      "BUILT_BY=${var.built_by}"
    ]
    inline = [
      "echo \"TEMPLATE_NAME=ubuntu-2404-common\" | sudo tee /home/kosa/build-info.txt",
      "echo \"TEMPLATE_VMID=${var.template_vm_id}\" | sudo tee -a /home/kosa/build-info.txt",
      "echo \"BUILD_TIMESTAMP=$(date --iso-8601=seconds)\" | sudo tee -a /home/kosa/build-info.txt",
      "echo \"GIT_COMMIT=$GIT_COMMIT\" | sudo tee -a /home/kosa/build-info.txt",
      "echo \"GIT_BRANCH=$GIT_BRANCH\" | sudo tee -a /home/kosa/build-info.txt",
      "echo \"BUILT_BY=$BUILT_BY\" | sudo tee -a /home/kosa/build-info.txt"
    ]
  }

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

  # [중복 정보] ciuser/cipassword/ipconfig0은 9000(create-ubuntu-template.sh)에도 동일하게 설정되어 있음
  # cloud_init=true가 cloud-init 드라이브를 새로 생성하면서 해당 값을 초기화하므로 여기서 재주입
  post-processor "shell-local" {
    inline = [
      "ssh root@${var.proxmox_host} 'qm set ${var.template_vm_id} --ciuser ${var.ssh_username} --cipassword ${var.ssh_password} --ipconfig0 ip=dhcp'",
      "ssh root@${var.proxmox_host} 'qm set ${var.template_vm_id} --delete serial0 --vga std'"
    ]
  }
}
