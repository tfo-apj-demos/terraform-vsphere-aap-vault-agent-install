terraform {
  required_version = ">= 1.14"
  required_providers {
    aap = {
      source  = "ansible/aap"
      version = "~> 1.4.0"
    }
  }
}
