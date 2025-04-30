# Terraform vSphere VM Build using Ansible Automation Platform for Vault Agent installation

This repository demonstrates the process of building a vSphere virtual machine using Terraform, HCP Packer image, and Ansible Automation Platform (AAP). The goal is to automatically deploy a vSphere VM from a custom image, install the HashiCorp Vault Agent, and configure authentication via TLS using the vTPM (Virtual TPM) on the VM.

## Architecture Overview

- **HCP Terraform**: Automates the provisioning of the vSphere VM and calls the Ansible Automation Platform (AAP) to run workflows.
- **Ansible Automation Platform**: Executes a job to install and configure the Vault Agent on the VM.
- **Vault Agent**: Configures authentication for HashiCorp Vault using TLS and vTPM.
