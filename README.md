# Better Together: On-Prem VM Lifecycle

A reference pattern showing the **HashiCorp × Red Hat "Better Together"** integration for on-prem VM lifecycle on vSphere: **Terraform** provisions the VM, **Ansible Automation Platform (AAP)** configures it, and **HashiCorp Vault** (via the Vault Agent) supplies its runtime secrets.

The aim is a single, declarative workflow that takes a VM from "doesn't exist" to "running, configured, and pulling secrets from Vault" — and back down again — without imperative scripting.

## Architecture

![Better Together — On-Prem VM Lifecycle architecture](docs/architecture.svg)

The flow above is what the code in this repo executes end-to-end:

1. **Commit** — An engineer pushes Terraform config to this GitHub repo.
2. **VCS webhook** — The push triggers a plan in the HCP Terraform workspace.
3. **Playbook sync** — Independently, AAP keeps its project synced from a separate source owned by the automation team (a different VCS repo or Automation Hub collection). This decoupling lets the platform and automation teams iterate on their own cadence.
4. **Register & trigger** — On apply, Terraform creates the AAP inventory entries (`aap_inventory`, `aap_group`, `aap_host`) and triggers the job (`aap_job`).
5. **Provision** — Terraform creates the Linux VM in vSphere via the private `single-virtual-machine` module.
6. **Configure** — AAP SSHes into the VM and runs the playbook from step 3 to install and configure the Vault Agent.
7. **Secrets at runtime** — The Vault Agent on the VM authenticates to Vault and pulls runtime secrets — no static credentials in the VM image.

Sentinel sits between plan and apply in HCP Terraform to enforce policy guardrails (e.g. allowed VM sizes, required tags, network placement) before any change reaches vSphere.
