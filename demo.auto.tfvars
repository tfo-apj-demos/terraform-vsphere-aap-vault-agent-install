# This file contains the configuration for the virtual machines.
# It defines the properties for each VM, including hostname, domain, backup policy, environment, OS type, distribution, security profile, site, size, storage profile, and tier.
vm_config = {
  web-server-01 = {
    hostname           = "web-server-01"
    os_type            = "linux"
    linux_distribution = "rhel"
    site               = "melbourne"
    size               = "medium"
    security_profile   = "web-server"
    environment        = "dev"
    ad_domain          = "hashicorp.local"
    backup_policy      = "daily"
    storage_profile    = "standard"
    tier               = "gold"
  },
  # web-server-02 = {
  #   hostname           = "web-server-02"
  #   os_type            = "linux"
  #   linux_distribution = "rhel"
  #   site               = "sydney"
  #   size               = "large"
  #   security_profile   = "web-server"
  #   environment        = "dev"
  #   ad_domain          = "hashicorp.local"
  #   backup_policy      = "daily"
  #   storage_profile    = "standard"
  #   tier               = "gold"
}
