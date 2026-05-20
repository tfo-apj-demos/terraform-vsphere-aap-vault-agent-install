# Better Together: On-Prem VM Lifecycle

A reference pattern showing the **HashiCorp × Red Hat "Better Together"**
integration for on-prem VM lifecycle on vSphere: **Terraform** provisions
the VM, **Ansible Automation Platform (AAP)** configures it, and
**HashiCorp Vault** (via the Vault Agent) supplies its runtime secrets.

The aim is a single, declarative workflow that takes a VM from "doesn't
exist" to "running, configured, and pulling secrets from Vault" — and
back down again — without imperative scripting.

## Architecture

![Better Together — On-Prem VM Lifecycle architecture](docs/architecture.svg)

The flow above is what the code in this repo executes end-to-end:

1. **Commit** — An engineer pushes Terraform config to this GitHub repo.
2. **VCS webhook** — The push triggers a plan in the HCP Terraform workspace.
3. **Playbook sync** — Independently, AAP keeps its project synced from a separate source owned by the automation team. This decoupling lets the platform and automation teams iterate on their own cadence.
4. **Register & trigger** — On apply, Terraform creates the AAP inventory entries (`aap_inventory`, `aap_group`, `aap_host`) and triggers jobs via Terraform 1.14 **actions** wired to lifecycle events.
5. **Provision** — Terraform creates the Linux VM in vSphere via the private `single-virtual-machine` module.
6. **Configure** — AAP SSHes into the VM and runs the after-create playbook stack.
7. **Secrets at runtime** — The Vault Agent on the VM authenticates to Vault and pulls runtime secrets — no static credentials in the VM image.

Sentinel sits between plan and apply in HCP Terraform to enforce policy
guardrails before any change reaches vSphere.

## Lifecycle Hooks (Terraform 1.14 Actions)

This workspace exposes **fifteen** AAP job templates as ad-hoc and
lifecycle-bound operations. They are wired to two `terraform_data`
resources that act as scheduling anchors:

| Resource | Sequenced | Hosts events |
|----------|-----------|--------------|
| `terraform_data.vm_lifecycle_pre` | **before** the VM module | `before_create`, `before_update` |
| `terraform_data.vm_provisioned`   | **after** the VM module  | `after_create`, `after_update` |

### `before_create` — before the VM exists

| Action | AAP Job Template | What it does |
|--------|------------------|--------------|
| `action.aap_job_launch.cmdb_change_open` | `pre-cmdb-change-open` | Opens a ServiceNow change record with CAB-ready fields, linked to the TFC run ID |
| `action.aap_job_launch.ipam_reserve` | `pre-ipam-reserve` | Reserves the next-available IP and DNS record in Infoblox |

### `after_create` — after the VM is up

| Action | AAP Job Template | What it does |
|--------|------------------|--------------|
| `action.aap_job_launch.rhel_register` | `rhel-register` | Registers with Red Hat Subscription Manager |
| `action.aap_job_launch.cis_hardening` | `rhel-cis-hardening` | Applies a CIS L1 / DISA STIG-aligned baseline |
| `action.aap_job_launch.chrony_timesync` | `rhel-chrony-timesync` | Configures chrony against bank stratum-1 NTP |
| `action.aap_job_launch.ad_domain_join` | `rhel-ad-domain-join` | Joins Active Directory via realmd / SSSD |
| `action.aap_job_launch.vault_agent` | `rhel-install-vault-agent` | Installs and configures the Vault Agent |
| `action.aap_job_launch.splunk_uf_install` | `rhel-splunk-uf-install` | Installs the Splunk Universal Forwarder and points it at the bank SIEM |
| `action.aap_job_launch.crowdstrike_install` | `rhel-crowdstrike-install` | Installs the CrowdStrike Falcon EDR sensor |
| `action.aap_job_launch.qualys_install` | `rhel-qualys-install` | Installs and activates the Qualys Cloud Agent |
| `action.aap_job_launch.install_nginx` | `rhel-install-nginx` | Installs and configures Nginx |

### `before_update` — before Terraform mutates the VM

| Action | AAP Job Template | What it does |
|--------|------------------|--------------|
| `action.aap_job_launch.cmdb_change_open` | `pre-cmdb-change-open` | Re-opens / extends the ServiceNow change record |
| `action.aap_job_launch.vsphere_snapshot` | `pre-vsphere-snapshot` | Takes a pre-change vSphere snapshot via REST (TTL-tagged) |
| `action.aap_job_launch.lb_pool_drain` | `pre-lb-pool-drain` | Drains the VM from its F5 BIG-IP pool with a grace window |

### `after_update` — after the change applies

Re-runs the after_create stack (all of those playbooks are idempotent),
plus:

| Action | AAP Job Template | What it does |
|--------|------------------|--------------|
| `action.aap_job_launch.post_change_validate` | `rhel-post-change-validate` | TCP / systemd / HTTP / clock-skew checks; fails the action on regression |
| `action.aap_job_launch.lb_pool_reenable` | `post-lb-pool-reenable` | Re-adds the VM to F5, waits for monitor:up, triggers a Qualys rescan |

> **Note**: `before_destroy` / `after_destroy` actions aren't yet in
> Terraform 1.14 — when they land, the natural extensions are
> `cmdb-close-change`, `ipam-release`, `backup-archive`, and
> `cmdb-retire-ci`.

## Playbook source

All playbooks and roles live in
[hashi-demo-lab/ansible-rhel-post-deploy](https://github.com/hashi-demo-lab/ansible-rhel-post-deploy)
under `playbooks/` and `roles/`. AAP project ID `57` in the demo
controller (`ansible-rhel-post-deploy`) keeps it synced on `main`.

Every role that talks to vendor SaaS (ServiceNow, Infoblox, Qualys, F5)
ships with `*_simulate: true` in its defaults so the full lifecycle
runs end-to-end in lab without real backends. Flip to `false` in prod.

## What gets passed to AAP per host

The `aap_host` resource encodes the variables every role needs:

```hcl
{
  os_type, backup_policy, storage_profile, tier, cert_service_type,
  site, env, security_profile, ad_domain,
  tfc_workspace_name, tfc_run_id,
  ansible_host  # FQDN — DNS resolves to the VM's IP once provisioned
}
```

Secrets (RHSM credentials, Falcon CID, F5 service account, Infoblox
WAPI, ServiceNow OAuth, etc.) are never in here — every role reads them
at runtime from Vault via the `community.hashi_vault` collection using
AppRole auth.
