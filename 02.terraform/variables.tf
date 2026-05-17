# TODO: 추후 제거 예정 - 운영 환경에서는 패스워드 인증 비활성화 후
#       컨트롤 노드(Ansible) SSH 키 인증만 허용 (배스천/컨트롤 노드 경유)
variable "vm_password" {
  type        = string
  description = "VM cloud-init 계정 비밀번호 (kosa 계정) — 초기 세팅용 임시값"
  default     = "kosa1004"
  sensitive   = true
}

variable "template_node" {
  type        = string
  default     = "kosa22"
  description = "템플릿이 등록된 Proxmox 노드 (clone 소스 노드)"
}

variable "vms" {
  type = map(object({
    vm_id          = number
    ip             = string
    vlan           = number
    bridge         = string
    storage_ip     = optional(string)
    storage_bridge = optional(string, "vmbr1")
    storage_cidr   = optional(number, 24)
    storage_mtu    = optional(number, 9000)
    node           = string
    cores          = optional(number, 2)
    memory         = optional(number, 2048)
    disk_size      = optional(number, 10)
    datastore_id   = optional(string, "rbd-storage")
    template_vm_id = optional(number, 9003)
  }))
  default     = {}
  description = "VM 목록 — template_vm_id 미지정 시 9003(common) 사용, K8s 노드는 9005 지정"
}

variable "vm_nameserver" {
  type        = string
  default     = "8.8.8.8 1.1.1.1"
  description = "DNS 네임서버 (공백 구분, CoreDNS 구성 후 변경 예정)"
}

variable "ssh_public_key" {
  type        = list(string)
  description = "VM에 주입할 SSH 공개키"
}
