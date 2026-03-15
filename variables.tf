# Define a map for VM configuration
variable "vm_config" {
  description = "Configuration for multiple VMs"
  type = map(object({
    hostname           = string
    ad_domain          = string
    backup_policy      = string
    environment        = string
    os_type            = string
    linux_distribution = string
    security_profile   = string
    site               = string
    size               = string
    storage_profile    = string
    tier               = string
  }))
}

# HCP Terraform workspace metadata — auto-injected by HCP Terraform at runtime
variable "TFC_PROJECT_NAME" {
  description = "The name of the HCP Terraform project. Auto-injected by HCP Terraform."
  type        = string
  default     = "Default Project"
}

variable "TFC_WORKSPACE_NAME" {
  description = "The name of the HCP Terraform workspace. Auto-injected by HCP Terraform."
  type        = string
  default     = "terraform-vsphere-vm-aap-vault-agent"
}

variable "ad_domain_name" {
  description = "The name of the Active Directory domain."
  type        = string
  default     = null
}
variable "admin_password" {
  description = "The password for the administrator account."
  type        = string
  sensitive   = true
  default     = null
}

variable "domain_admin_user" {
  description = "The username of the domain administrator."
  type        = string
  default     = null
}

variable "domain_admin_password" {
  description = "The password for the domain administrator."
  type        = string
  sensitive   = true
  default     = null
}

variable "ad_domain" {
  description = "The Active Directory domain to join."
  type        = string
  default     = null
}