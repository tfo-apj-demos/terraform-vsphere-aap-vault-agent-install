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

# Job template ID for the AAP job
variable "job_template_id" {
  description = "The ID of the job template to run."
  type        = string
}

# TFC Workspace ID for inventory naming
variable "TFC_WORKSPACE_ID" {}

variable "ad_domain_name" {
  description = "The name of the Active Directory domain."
  type        = string
  default = null
}
variable "admin_password" {
  description = "The password for the administrator account."
  type        = string
  sensitive   = true
  default = null
}

variable "domain_admin_username" {
  description = "The username of the domain administrator."
  type        = string
  default = null
}

variable "domain_admin_password" {
  description = "The password for the domain administrator."
  type        = string
  sensitive   = true
  default = null
}