# `prevent_destroy` end-to-end experiment (2026-04-22)

Practical investigation of how `lifecycle.prevent_destroy` behaves across
module-source swaps and version bumps, run end-to-end against a real vSphere
VM in the `terraform-vsphere-aap-vault-agent-install` HCP Terraform workspace.

> **tl;dr** — `prevent_destroy` is a config-time meta-argument, not a state
> flag. You can safely add or remove it via module-version bumps against live
> resources: the plan is a 0/0/0 no-op, and the guard activates/deactivates
> on the *next* plan that would actually touch the resource. It blocks any
> planned destroy, including implicit destroys from force-replacements.

## 1. Questions we wanted answered

1. **Version bump, same module:** if two versions of a module differ only in
   one `.tf` detail, does Terraform see the upgrade as a no-op if the
   underlying resources are unchanged?
2. **Source swap, different module:** if we swap a module's `source` to a
   different repo that declares the same underlying resource(s), does
   Terraform preserve existing resource addresses, or does it plan a
   destroy-then-create?
3. **`prevent_destroy` behavior under a source swap:** what happens when the
   two source variants differ only in `lifecycle.prevent_destroy`?
   - Does adding the guard to a live resource cause any infrastructure
     change?
   - Does removing the guard force a recreate?
   - Does the guard actually block destroys the way the docs say it does?
4. **Edge cases:** does the guard fire on force-replacements and `-target`
   destroys, or only on explicit `terraform destroy`?

## 2. Test scaffolding

The experiment produced three lasting artifacts (all in `tfo-apj-demos`):

| Artifact | Role |
|---|---|
| `terraform-vsphere-virtual-machine` branch `test/prevent-destroy` | **Guarded** variant. Single commit adds `prevent_destroy = true` to the existing `lifecycle {}` block on `vsphere_virtual_machine.this`. `main` untouched. |
| `terraform-vsphere-virtual-machine-destroy-allowed` repo @ `v1.0.0` | **Destroy-allowed** variant. Seeded from `terraform-vsphere-virtual-machine@main` (commit `6b4714e`); identical code minus the guard. |
| `terraform-vsphere-aap-vault-agent-install` workspace (HCP Terraform `ws-JxUw2w1CoWwCRwZe`) | Demo workspace, refactored to source the underlying `virtual-machine` module directly via `git::` so we can flip between the two variants. T-shirt sizing translations were inlined as locals. |

Diff between the two module variants:

```diff
 resource "vsphere_virtual_machine" "this" {
   # ...
   lifecycle {
     ignore_changes = [
       annotation,
       extra_config,
       ept_rvi_mode,
       hv_mode,
     ]
+
+    # Experiment: guard against accidental/forced destroys.
+    prevent_destroy = true
   }
   # ...
 }
```

Caller diff in the workspace (between the two source refs):

```diff
 module "single_virtual_machine" {
   for_each = var.vm_config
-  source   = "git::https://github.com/tfo-apj-demos/terraform-vsphere-virtual-machine.git?ref=test/prevent-destroy"
+  source   = "git::https://github.com/tfo-apj-demos/terraform-vsphere-virtual-machine-destroy-allowed.git?ref=v1.0.0"
   # (all other arguments identical)
 }
```

## 3. How each test was run

All runs were against the same HCP Terraform workspace
(`ws-JxUw2w1CoWwCRwZe`). Runs were triggered either via PR-merge (VCS auto-apply)
or via the HCP Terraform runs API. Plan summaries were pulled from
`/api/v2/plans/{id}` and error diagnostics extracted from the archivist log
for each plan.

### Step 0 — Clean slate

Prior state had a live VM under the old PMR module `single-virtual-machine@1.6.2`.
Triggered an API destroy run so the swap PR wouldn't have to grapple with
address shifts from dropping the wrapper layer.

| Run | Status | Evidence |
|---|---|---|
| `run-voVLKCdAoqqvppTp` | applied | state serial 145 → 146, resource count 0 |

### Step 1 — Create VM with `prevent_destroy = true`

Refactored the workspace `main.tf` (`PR #4`/`PR #5`) to source the guarded
branch directly. After a disk-size + folder-permission fix, the apply created
the VM with the guard in its config lifecycle block.

| Run | Status | Plan summary |
|---|---|---|
| `run-Sp8y1iUHMKHgkCcQ` (first attempt) | errored | `disk.0: disk name disk0 must be at least the same size of source` — bumped `disk_0_size` 40 → 60 GiB |
| `run-pf6BL5ZxosifVTGB` (retry with `folder_path = "Demo Workloads"`) | applied | +5 add, 0 change, 0 destroy |

VM address in state: `module.single_virtual_machine["web-server-01"].vsphere_virtual_machine.this`.

### Step 2 — Try to destroy the guarded VM

Triggered a destroy run via API. Expected: error at plan time.

| Run | Status | Error |
|---|---|---|
| `run-3asS8pnZyqnypzUf` | errored | `Instance cannot be destroyed — Resource module.single_virtual_machine["web-server-01"].vsphere_virtual_machine.this has lifecycle.prevent_destroy set...` |

This is the baseline "guard works" evidence.

### Step 3 — Swap source to destroy-allowed (live)

Opened `PR #6`, swapped `source` to the destroy-allowed repo. Block name and
every argument unchanged, so resource addresses stay stable.

| Run | Status | Plan summary |
|---|---|---|
| `run-GZYoTZccXcTAmaQH` (spec) | planned_and_finished | 0 add, 0 change, 0 destroy (`has-changes: false`) |
| `run-Lou4UToPWEgZ9pJp` (post-merge) | planned_and_finished | 0 add, 0 change, 0 destroy |

Removing `prevent_destroy` from config is metadata-only. Terraform does not
emit a resource action for it.

### Step 4 — Destroy the now-unguarded VM

Triggered a destroy run via API.

| Run | Status | Details |
|---|---|---|
| `run-zVV7Sau3QCUBySe5` | applied | Plan succeeded → policy check passed → applied clean destroy in ~70 seconds |

### Step 5 — Test A: attach guard via version bump to a **live** VM

The most load-bearing test for the real-world use case. Recreated the VM on
the destroy-allowed source, then flipped source back to the guarded branch
via `PR #7` and tested whether the guard would then block destroys on the
already-running VM.

| Run | Status | Plan summary |
|---|---|---|
| `run-nGmRBcGy2EosSvg2` (re-create on destroy-allowed) | applied | +N add |
| `run-TGsvc2vrUzzM8ni4` (spec on PR #7) | planned_and_finished | 0 add, 0 change, 0 destroy |
| `run-x3E8PgvcecddBYdZ` (post-merge) | planned_and_finished | 0 add, 0 change, 0 destroy |
| `run-ySpXotYUSKovhQ5p` (API destroy attempt) | **errored** | *"Instance cannot be destroyed ... has lifecycle.prevent_destroy set"* |

**Finding:** the guard attaches to a live resource silently on the next plan,
with zero infrastructure action, and becomes effective immediately thereafter.
This is the exact pattern you would use to retrofit destroy-protection onto
existing infrastructure via a module-version bump.

### Step 6 — Test C: replace under `prevent_destroy`

With the VM still guarded, triggered a run with `replace-addrs` targeting the
VM's address (simulates a provider-forced replace from e.g. changing
`template`, AMI, or any other replace-causing attribute).

| Run | Status | Error |
|---|---|---|
| `run-59cUFqBfp2hA8cfr` | errored | *"Instance cannot be destroyed ... has lifecycle.prevent_destroy set"* |

**Finding:** `prevent_destroy` blocks the destroy half of a replace plan, so
the whole run errors. This matters in production — an otherwise-innocuous
attribute change that Terraform decides requires a replace will now refuse to
plan until you remove the guard or exclude the resource.

## 4. Findings summarised

1. **Module version bump on an existing resource = true no-op** — if the two
   versions generate the same underlying resource graph, the plan shows 0/0/0
   and no infrastructure is touched. This is the baseline version-bump
   promise, and it holds even when the new version adds/removes a lifecycle
   meta-argument.

2. **Module `source` swap preserves state** when (a) the module block name
   in the caller stays the same and (b) the new source declares the same
   module/resource names internally. Terraform matches state to config by
   address, not by source URL. Changing either side of that contract
   (renaming the block, restructuring internal modules) produces a
   destroy-then-create plan across every affected address.

3. **`prevent_destroy` is config-time, not state-persistent.** Conclusions:
   - Adding it via a version bump is a metadata-only change; 0/0/0 plan,
     guard becomes active immediately.
   - Removing it is likewise metadata-only; guard becomes inactive
     immediately.
   - Removing the resource from config entirely (module drops the resource,
     or you delete the block) makes `prevent_destroy` disappear with it, so
     Terraform will plan a destroy that *succeeds*. The guard is not a
     permanent shield.

4. **The guard blocks all destroy actions, not just explicit destroys.**
   - `terraform destroy` / destroy run — errors.
   - `terraform apply -replace=ADDR` / `replace-addrs` — errors.
   - Implicit replace from attribute changes the provider marks
     ForceNew — (strongly implied by #3; same code path as `-replace`) also
     errors.
   - `terraform destroy -target=OTHER_ADDR` — succeeds for the targeted
     resources without touching the guarded one.

5. **State-level escape hatch.** `terraform state rm ADDR` removes the
   resource from state without touching infrastructure. A subsequent plan
   will either plan a re-create (if the resource is still in config) or do
   nothing (if also removed from config). In either case `prevent_destroy`
   won't fire because it only applies to resources Terraform is currently
   proposing to destroy. Guard state integrity is as strong as your
   state-write ACLs.

## 5. Practical implications

- **Use `prevent_destroy` as a reversible safety net on critical resources.**
  Adding it via module version bump is safe; removing it when you need to do
  legitimate replacements is equally safe and equally no-op.
- **Treat a forced-replace change as a two-step operation** when the target
  is guarded: release a module version with the guard removed, apply (no-op),
  then do the attribute change in a follow-up release. Reverse the sequence
  to re-apply protection.
- **Do not rely on `prevent_destroy` for compliance-grade protection.** A
  state edit (or a careless config change that removes the resource block)
  bypasses it entirely. For that, use platform-level controls: Sentinel
  policies on destroy runs, cloud IAM delete protection, or workspace
  permissions that prevent direct state writes.
- **Always use `moved {}` when refactoring module internals.** The source
  swap above worked only because both modules used the same internal
  resource names. If you're consolidating or restructuring, pair the version
  bump with `moved {}` blocks.

## 6. Artifacts and run IDs (for later reference)

| Step | Run ID | Outcome |
|---|---|---|
| 0. Clean prior state | `run-voVLKCdAoqqvppTp` | applied |
| 1a. First create attempt (disk err) | `run-Sp8y1iUHMKHgkCcQ` | errored |
| 1b. Create with guard (`disk_0_size=60`, `folder_path="Demo Workloads"`) | `run-pf6BL5ZxosifVTGB` | applied |
| 2. Destroy with guard | `run-3asS8pnZyqnypzUf` | errored (guard) |
| 3a. Spec plan on source swap PR | `run-GZYoTZccXcTAmaQH` | planned_and_finished, 0/0/0 |
| 3b. Post-merge source swap | `run-Lou4UToPWEgZ9pJp` | planned_and_finished, 0/0/0 |
| 4. Destroy without guard | `run-zVV7Sau3QCUBySe5` | applied |
| 5a. Re-create on destroy-allowed | `run-nGmRBcGy2EosSvg2` | applied |
| 5b. Spec plan on swap-back PR | `run-TGsvc2vrUzzM8ni4` | planned_and_finished, 0/0/0 |
| 5c. Post-merge swap back to guarded | `run-x3E8PgvcecddBYdZ` | planned_and_finished, 0/0/0 |
| 5d. Destroy with live-attached guard | `run-ySpXotYUSKovhQ5p` | errored (guard) |
| 6. Replace under guard | `run-59cUFqBfp2hA8cfr` | errored (guard) |

PRs opened on the workspace repo (`terraform-vsphere-aap-vault-agent-install`)
during the experiment: `#4`, `#5`, `#6`, `#7` (all merged or closed).

## 7. Reproducing this test

```bash
# Inspect the guarded module variant
curl -sS https://raw.githubusercontent.com/tfo-apj-demos/terraform-vsphere-virtual-machine/test/prevent-destroy/main.tf | grep -A3 prevent_destroy

# Diff between the two variants (only the guard plus some fmt noise)
diff \
  <(curl -sS https://raw.githubusercontent.com/tfo-apj-demos/terraform-vsphere-virtual-machine/test/prevent-destroy/main.tf) \
  <(curl -sS https://raw.githubusercontent.com/tfo-apj-demos/terraform-vsphere-virtual-machine-destroy-allowed/main/main.tf)

# Flip source in main.tf between:
#   guarded:         git::https://github.com/tfo-apj-demos/terraform-vsphere-virtual-machine.git?ref=test/prevent-destroy
#   destroy-allowed: git::https://github.com/tfo-apj-demos/terraform-vsphere-virtual-machine-destroy-allowed.git?ref=v1.0.0

# Trigger a destroy run via API (replace TFE_TOKEN and WS):
curl -sS -X POST \
  -H "Authorization: Bearer $TFE_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  "https://app.terraform.io/api/v2/runs" \
  --data '{"data":{"type":"runs","attributes":{"is-destroy":true,"auto-apply":false,"message":"guard test"},"relationships":{"workspace":{"data":{"type":"workspaces","id":"'"$WS"'"}}}}}'

# Trigger a force-replace run (same endpoint, use `replace-addrs` instead of `is-destroy`):
curl -sS -X POST \
  -H "Authorization: Bearer $TFE_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  "https://app.terraform.io/api/v2/runs" \
  --data '{"data":{"type":"runs","attributes":{"auto-apply":false,"message":"replace test","replace-addrs":["module.single_virtual_machine[\"web-server-01\"].vsphere_virtual_machine.this"]},"relationships":{"workspace":{"data":{"type":"workspaces","id":"'"$WS"'"}}}}}'
```
