# Terraform vSphere VM Build with AAP + Vault Agent

Provisions vSphere VMs via HCP Terraform, then hands off to Ansible Automation Platform (AAP) for Day 2 configuration — specifically installing and configuring the HashiCorp Vault Agent with TLS authentication via vTPM.

This repo follows the [HashiCorp Validated Pattern for AAP + Terraform](https://developer.hashicorp.com/validated-patterns) integration and draws on [Glenn Chia's guide](https://medium.com/@glenn.chia) for the Terraform-to-AAP handoff pattern.

## Prerequisites

- **Terraform >= 1.14** — required for `action` block support
- **HCP Terraform** workspace with vSphere, AAP, and HCP credentials configured
- **Ansible Automation Platform** with the `1-install-vault-agent` job template
- **vSphere** environment with RHEL 9 templates (built via HCP Packer)

## Architecture Flow

```
HCP Terraform (plan/apply)
  │
  ├─ module.single_virtual_machine  ─►  vSphere VMs provisioned
  ├─ aap_inventory / aap_host       ─►  AAP inventory populated
  └─ action_trigger (after_create)   ─►  AAP job launched
                                           └─ Vault Agent installed + configured
```

### Action Block Pattern (Terraform 1.14+)

Instead of using `resource "aap_job"` (which persists in Terraform state), this repo uses an `action "aap_job_launch"` block. Actions are fire-and-forget operations that execute during `terraform apply` but are not tracked in state. The `action_trigger` lifecycle hook on `terraform_data.vm_provisioned` fires the AAP job after VMs are created or updated.

```hcl
action "aap_job_launch" "vault_agent" {
  config {
    job_template_id = data.aap_job_template.vault_agent.id
    inventory_id    = aap_inventory.vm_inventory.id
    ...
  }
}

resource "terraform_data" "vm_provisioned" {
  input = local.vm_names

  lifecycle {
    action_trigger {
      events  = [after_create, after_update]
      actions = [action.aap_job_launch.vault_agent]
    }
  }
}
```

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `vm_config` | Map of VM configurations (hostname, OS, site, size, etc.) | — |
| `TFC_PROJECT_NAME` | HCP Terraform project name (auto-injected) | `"Default Project"` |
| `TFC_WORKSPACE_NAME` | HCP Terraform workspace name (auto-injected) | `"terraform-vsphere-vm-aap-vault-agent"` |
| `ad_domain_name` | Active Directory domain name | `null` |
| `domain_admin_user` | Domain administrator username | `null` |

## Outputs

| Output | Description |
|--------|-------------|
| `vm_names` | Map of VM keys to their names |
| `vm_ip_addresses` | Map of VM keys to their IP addresses |
| `aap_inventory_id` | AAP inventory ID for downstream use |
| `aap_inventory_name` | AAP inventory name for traceability |

## File Structure

| File | Purpose |
|------|---------|
| `main.tf` | VM module, AAP inventory/hosts/groups, action block + trigger |
| `provider.tf` | Provider and Terraform version constraints |
| `variables.tf` | Input variable definitions |
| `demo.auto.tfvars` | VM configuration values |
| `output.tf` | Output definitions |
