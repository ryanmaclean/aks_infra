variable "win_user" {
  description = "Windows node pool admin username"
  type        = string
}

variable "win_pass" {
  description = "Windows node pool admin password"
  type        = string
  sensitive   = true
}

# Variables for Workload Identity test configuration
variable "workload_identity_namespace" {
  description = "Kubernetes namespace for workload identity test"
  type        = string
  default     = "workload-identity-test"
}

variable "workload_identity_service_account" {
  description = "Kubernetes service account name for workload identity"
  type        = string
  default     = "workload-identity-sa"
}