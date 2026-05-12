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
#           ansible_public_key       = vault("secret/packer/ssh", "ansible_public_key")

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

variable "ansible_public_key" {
  type    = string
  default = ""
}

variable "template_vm_id" {
  type    = number
  default = 9005
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

  cloud_init              = true
  cloud_init_storage_pool = "rbd-storage"
}

build {
  sources = ["source.proxmox-clone.ubuntu-template"]

  provisioner "shell" {
    inline = [
      "sudo cloud-init status --wait || true",
      "sudo timedatectl set-timezone Asia/Seoul",
      "sudo apt-get update",
      "sudo apt-get install -y curl wget git vim net-tools auditd",
      "sudo systemctl disable auditd",

      # Promtail (Grafana APT)
      "sudo apt-get install -y apt-transport-https software-properties-common",
      "wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /usr/share/keyrings/grafana.gpg > /dev/null",
      "echo 'deb [signed-by=/usr/share/keyrings/grafana.gpg] https://apt.grafana.com stable main' | sudo tee /etc/apt/sources.list.d/grafana.list",
      "sudo apt-get update",
      "sudo apt-get install -y promtail",
      "sudo systemctl disable promtail",

      # Wazuh Agent 4.x
      "curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | sudo gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import",
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
      "ANSIBLE_KEY=${var.ansible_public_key}",
      "SSH_USER=${var.ssh_username}"
    ]
    inline = [
      "mkdir -p /home/$SSH_USER/.ssh",
      "chmod 700 /home/$SSH_USER/.ssh",
      "echo \"$ANSIBLE_KEY\" >> /home/$SSH_USER/.ssh/authorized_keys",
      "chmod 600 /home/$SSH_USER/.ssh/authorized_keys",
      "chown -R $SSH_USER:$SSH_USER /home/$SSH_USER/.ssh",
      "sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf",
      "echo 'PubkeyAuthentication yes' | sudo tee /etc/ssh/sshd_config.d/99-packer.conf",
      "sudo systemctl restart ssh"
    ]
  }

  # 골든 이미지 정리: SSH로 실행 (qm agent exec 불가 대체)
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
      "ssh root@${var.proxmox_host} 'qm set ${var.template_vm_id} --ciuser ${var.ssh_username} --cipassword ${var.ssh_password} --ipconfig0 ip=dhcp'"
    ]
  }
}
