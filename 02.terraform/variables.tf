variable "template_vm_id" {
  type        = number
  default     = 9007
  description = "클론 대상 템플릿 VMID (Packer 생성 템플릿)"
}

variable "template_node" {
  type        = string
  default     = "kosa22"
  description = "템플릿이 등록된 Proxmox 노드 (clone 소스 노드)"
}

variable "vms" {
  type = map(object({
    vm_id  = number
    ip     = string
    vlan   = number
    bridge = string
    node   = string
  }))
  default     = {}
  description = "VM 목록 (이름 → vm_id, ip, vlan, bridge, node)"
}

variable "vm_cores" {
  type    = number
  default = 2
}

variable "vm_memory" {
  type        = number
  default     = 2048
  description = "메모리 (MB)"
}

variable "vm_disk_size" {
  type        = number
  default     = 10
  description = "디스크 크기 (GB)"
}

variable "vm_nameserver" {
  type        = string
  default     = "8.8.8.8 1.1.1.1"
  description = "DNS 네임서버 (공백 구분, CoreDNS 구성 후 변경 예정)"
}
