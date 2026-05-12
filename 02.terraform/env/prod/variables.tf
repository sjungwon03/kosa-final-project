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

variable "template_vm_id" {
  type    = number
  default = 9007
}

variable "template_node" {
  type    = string
  default = "kosa22"
}

variable "vms" {
  type = map(object({
    vm_id  = number
    ip     = string
    vlan   = number
    bridge = string
    node   = string
  }))
  description = "배포할 VM 목록 — 반드시 -var-file로 주입 (tfvars/ 참고)"
}

variable "vm_cores" {
  type    = number
  default = 4
}

variable "vm_memory" {
  type    = number
  default = 4096
}

variable "vm_disk_size" {
  type    = number
  default = 20
}

variable "vm_nameserver" {
  type    = string
  default = "8.8.8.8 1.1.1.1"
}
