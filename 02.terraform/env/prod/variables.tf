variable "proxmox_api_url" {
  type        = string
  description = "Proxmox API URL (예: https://192.168.34.4:8006/api2/json)"
}

variable "proxmox_api_token_id" {
  type        = string
  description = "Proxmox API 토큰 ID (예: terraform@pve!token)"
}

variable "proxmox_api_token_secret" {
  type        = string
  sensitive   = true
  description = "Proxmox API 토큰 시크릿"
}

variable "template_node" {
  type    = string
  default = "kosa22"
}

variable "vms" {
  type = map(object({
    vm_id          = number
    ip             = string
    vlan           = number
    bridge         = string
    node           = string
    storage_ip     = optional(string)
    storage_bridge = optional(string, "vmbr1")
    storage_cidr   = optional(number, 24)
    storage_mtu    = optional(number, 9000)
    cores          = optional(number, 2)
    memory         = optional(number, 2048)
    disk_size      = optional(number, 10)
    datastore_id   = optional(string, "rbd-storage")
    template_vm_id = optional(number, 9003)
    tags           = optional(list(string), [])
    protection     = optional(bool, false)
  }))
  description = "배포할 VM 목록 — 반드시 -var-file로 주입 (tfvars/ 참고)"
}

variable "vm_nameserver" {
  type    = string
  default = "172.16.30.10"
}

# TODO: 추후 제거 - 운영 환경에서는 패스워드 인증 비활성화 (배스천/컨트롤 노드 경유 키 인증만 허용)
variable "vm_password" {
  type      = string
  default   = "kosa1004"
  sensitive = true
}

variable "ssh_public_key" {
  type    = list(string)
  default = []
}
