# This file contains the configuration for the virtual machines.
# It defines the properties for each VM, including hostname, domain, backup policy, environment, OS type, distribution, security profile, site, size, storage profile, and tier.
vm_config = {
  db-server = {
    hostname           = "database-server-01"
    os_type            = "linux"
    linux_distribution = "rhel"
    site               = "melbourne"
    size               = "large"
    security_profile   = "db-server"
    environment        = "dev"
    ad_domain          = "hashicorp.local"
    backup_policy      = "daily"
    storage_profile    = "standard"
    tier               = "gold"
  }
}

# This ID is used to identify the specific job template that will be executed in Ansible Automation Platform (AAP).
# Job for installing the vault agent
job_template_id = "36"
