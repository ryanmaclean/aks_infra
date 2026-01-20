variable "ad_sp_pass" {
  description = "Password used for service principal"
  type        = string
  sensitive   = true
}

variable "ad_sp_id" {
  description = "Service principal ID"
  type        = string
}

variable "win_user" {
  description = "Windows admin username"
  type        = string
}

variable "win_pass" {
  description = "Windows admin password"
  type        = string
  sensitive   = true
}
