# DNS GSS-TSIG Investigation — Recurring "unexpected acceptor flag" on dns_a_record_set

**Status:** ✅ **RESOLVED 2026-05-19** — see the "Resolution" section immediately below. The rest of the document is preserved as the investigation log.

---

## Resolution (TL;DR)

**Root cause:** `hashicorp/dns` provider **v3.6.0** (released 2026-05-13) bumped its `bodgit/tsig` dependency from **v1.2.2 → v1.3.0** (released 2026-04-28). The v1.3.0 release was a "Refactor to use GSSAPI wrapper" (closing [bodgit/tsig#111](https://github.com/bodgit/tsig/issues/111)) that **regressed acceptor-subkey-flag handling against Windows AD DNS servers**. Windows DCs respond to UPDATEs with MIC tokens that the new wrapper rejects, and the rejection surfaces as the misleading `unexpected acceptor flag is not set` error.

This is an upstream regression in `bodgit/gssapi` — specifically a missing `ctx.hasPeerSubkey()` check in `context.go:142`. Fix pending in [bodgit/gssapi PR #50](https://github.com/bodgit/gssapi/pull/50). Until that lands in a new tsig release and the dns provider picks it up, **pin `hashicorp/dns < 3.6.0`**.

**Tracking issues:**
- [hashicorp/terraform-provider-dns#642](https://github.com/hashicorp/terraform-provider-dns/issues/642) — opened 2026-05-13 by `onno204`. HashiCorp's `ansgarm` confirmed root cause and recommends pinning `< 3.6.0`.
- [bodgit/tsig#178](https://github.com/bodgit/tsig/issues/178) — opened 2026-05-14, where the bug was localized to `bodgit/gssapi/context.go:142`.

**The fix applied in this repo's chain:**

| Layer | Old | New |
|---|---|---|
| `better-together-vm-lifecycle/provider.tf` | `hashicorp/dns ~> 3.6` | `hashicorp/dns >= 3.4.3, < 3.6.0` |
| `terraform-dns-records` providers.tf (tagged **1.1.2**) | `~> 3.6` | `>= 3.4.3, < 3.6.0` |
| `terraform-vsphere-single-virtual-machine` providers.tf | `~> 3.3` (compatible, untouched) | `~> 3.3` |

With `< 3.6.0` in the constraint intersection, Terraform now installs **`hashicorp/dns 3.5.0`** which uses `bodgit/tsig v1.2.2` (the last known-good version). Confirmed working on `run-3xv3SAmk9WDZwQhQ` (2026-05-19) — `dns_a_record_set.a_record[0]` applied cleanly.

**Caveat — PMR stale-content gotcha encountered during the fix:**

The private module registry's first auto-publish of `terraform-dns-records 1.1.1` ingested a stale snapshot (commit-based publishing race), serving the pre-fix `providers.tf` content despite the tag pointing at the post-fix commit. Symptom: TFC plan errored at init with `Could not retrieve the list of available versions for provider hashicorp/dns: no available releases match the given constraints ~> 3.3, >= 3.4.3, ~> 3.6, < 3.6.0` — the rogue `~> 3.6` came from PMR's stale tarball, not any committed file.

Fix: pushed a follow-up commit (the new README), then **manually published `1.1.2` via the TFC UI** ("Publish a new version" button on the module page) to force a fresh VCS ingest. Verified by downloading the PMR tarball and inspecting `providers.tf` byte-for-byte.

**Lesson:** when PMR is branch-published and you change provider constraints, **verify the actual tarball content via `curl … /api/registry/v1/modules/<org>/<name>/<provider>/<version>/download`** before chasing constraint-resolution errors. Don't trust the PMR `version-statuses` list alone.

**When the upstream bug is fixed:**

Once `bodgit/gssapi#50` merges → new `bodgit/tsig` release → new `hashicorp/dns` release above 3.6.0 (e.g., 3.6.1 or 3.7.0), bump the constraints in this repo's chain back to allow that. The pinning comment in each `providers.tf` includes a pointer to this section.

---

## Resumption notes (no longer needed, but kept for traceability)

The rest of this file documents the investigation that led here — including dead ends and useful diagnostic assets. It's preserved as the persistent context for the original investigation. Skim if you want to know what was ruled out before the actual root cause was found.

---

## TL;DR

When the workspace `better-together-vm-lifecycle-dev` applies, the `dns_a_record_set` resource fails with:

> `Error: Error updating DNS record: unexpected acceptor flag is not set: expecting a token from the acceptor, not in the initiator`

This client-side message is **misleading**. Wire-level packet capture from the TFC agent (with all decoy explanations ruled out) shows the actual server response is **`RCODE 5 (REFUSED)`** from the AD DNS server (`dc-0.hashicorp.local`). The gokrb5 client library can't make sense of the TSIG signature on a REFUSED response (the DC returns the initiator's own MIC echoed back, with `SendByAcceptor=0` flag) and surfaces the parser failure as the misleading "acceptor flag" error.

**The bug-of-the-bug** — i.e., the misleading library error — is documented in [bodgit/tsig#54](https://github.com/bodgit/tsig/issues/54) and [hashicorp/terraform-provider-dns#160](https://github.com/hashicorp/terraform-provider-dns/issues/160). The maintainer of `bodgit/tsig` (the library the `hashicorp/dns` provider uses for GSS-TSIG) confirmed this is what happens when "the server rejects the request for some reason." There has been no upstream fix as of provider version 3.6.0.

**What we DON'T yet know** — and is the only remaining open question — is **why** the Windows AD DC is returning REFUSED, given that:
- The service account (`dns_terraform`) is a member of `DnsAdmins`
- The zone (`hashicorp.local`) explicitly grants both `DnsAdmins` (full rights, InheritanceType: **All**) and `Authenticated Users` (CreateChild) the permission to create new records
- The target record (`web-server-01.hashicorp.local`) does not currently exist (no conflict)
- The Kerberos auth flow (TKEY exchange) completes successfully
- The DC's clock is synced to within 1ms of the agent

---

## The architecture chain

```
better-together-vm-lifecycle/main.tf                                    ← consumer
  └── module "single_virtual_machine"  ~> 2.0                            (PMR slug: single-virtual-machine/vsphere)
        └── module "domain-name-system-management"  ~> 1.1               (PMR slug: domain-name-system-management/dns)
              └── provider "hashicorp/dns"  ~> 3.6                        (latest as of 2026-05-13)
                    └── bodgit/tsig + jcmturner/gokrb5/v8                 (Go libraries actually performing GSS-TSIG)
```

The failing resource is `module.single_virtual_machine["web-server-01"].module.domain-name-system-management.dns_a_record_set.a_record[0]` — registering `web-server-01.hashicorp.local` → the VM's IP.

---

## Environment facts

| Thing | Value |
|---|---|
| Workspace | `better-together-vm-lifecycle-dev` (`ws-JxUw2w1CoWwCRwZe`) in `tfo-apj-demos` |
| TFC agent pool | `gcve_agent_pool3` (`apool-CKBuay6edfcm1yRG`) |
| Agent VM | `hcp-tfc-agent0`, host IP `172.21.15.169` (ens192), Docker container running `ghcr.io/tfo-apj-demos/tfc-agent:latest` |
| Other agents (currently exited) | `hcp-tfc-agent-1`, `hcp-tfc-agent-2` |
| DNS server / KDC | `dc-0.hashicorp.local` → `172.21.15.150` |
| Zone | `hashicorp.local`, AD-integrated, `DynamicUpdate=Secure`, `ReplicationScope=Domain` |
| Service account | `dns_terraform` (CN=DNS Terraform,CN=Users,DC=hashicorp,DC=local) |
| Service account groups | `g_domain_join`, `DnsAdmins` |
| Service account enctype | `msDS-SupportedEncryptionTypes=16` (AES256-CTS-HMAC-SHA1-96) |
| Password last set | 2023-11-28 (no expiry) |
| krb5.conf (in agent container, bind-mounted from host) | `default_realm=HASHICORP.LOCAL`, `default_tkt_enctypes=aes256-cts aes256-cts-hmac-sha1-96`, `default_tgs_enctypes=aes256-cts aes256-cts-hmac-sha1-96`, `kdc=dc-0.hashicorp.local` |
| Variable set `__gcve_dns_variables` | `DNS_UPDATE_SERVER=dc-0.hashicorp.local`, `DNS_UPDATE_REALM=HASHICORP.LOCAL`, `DNS_UPDATE_USERNAME=dns_terraform`, `DNS_UPDATE_PASSWORD=<sensitive>` |

---

## Hypotheses ruled out (with evidence)

### ❌ Stale dns provider version
- **Test:** Bumped `hashicorp/dns` from `~> 3.3` (resolved to 3.3.2, Apr 2023) → `~> 3.6` (3.6.0, May 2026). Also fixed root-level pin in `provider.tf` (was `~> 3.3`, masking the chain bump).
- **Result:** Plan JSON confirmed `version_constraint=~> 3.6` was actually applied. Same error.
- **Conclusion:** Bug is not in 3.3.2 specifically — it's in the GSS-TSIG path unchanged since 3.1.0. Changelog shows no GSS-TSIG fixes 3.4→3.6.

### ❌ Per-record ACL transfer (my first theory)
- **Test:** Inspected the `dnsNode` AD object for the (then-existing) `web-server-01` record.
- **Result:** Owner is `HASHICORP\dns_terraform` (the service account itself). Per-record ACL grants `dns_terraform` `CreateChild, DeleteChild, DeleteTree, ExtendedRight, Delete, GenericWrite, WriteDacl, WriteOwner`. Full rights. Plus the record is no longer there anyway (deleted manually + via TF destroy).
- **Conclusion:** ACL isn't the blocker.

### ❌ Kerberos cipher mismatch (KB5018410-era hardening)
- **Test:** Verified `msDS-SupportedEncryptionTypes` on dns_terraform.
- **Result:** Value `16` = AES256-CTS-HMAC-SHA1-96 supported. Modern Windows DCs accept this.
- **Conclusion:** Cipher is fine.

### ❌ Clock skew / TSIG BADTIME
- **Test:** NTP-style query from agent to dc-0.
- **Result:** Skew = **+0.001 seconds**. Well within the 300s Kerberos fudge window.
- **Conclusion:** Not BADTIME.

### ❌ Multi-DC routing (TKEY established with one DC, UPDATE sent to another)
- **Test:** `dc-0.hashicorp.local` resolution from agent container.
- **Result:** Single IP `172.21.15.150`. Container's `resolv.conf` points only at this IP. ARP table confirms single MAC.
- **Conclusion:** Single-DC path.

### ❌ krb5.conf misconfiguration (matches a prior incident the user had)
- **Test:** Inspected `/etc/krb5.conf` in agent container.
- **Result:** Correct realm, KDC, enctypes. ALSO `gokrb5` (used by the dns provider) doesn't read `/etc/krb5.conf` anyway — it gets all config from the provider's `update {}` block.
- **Conclusion:** Not the cause for this specific error string.

### ❌ KDC / DNS reachability
- **Test:** TCP probes from agent.
- **Result:** ports 88, 53, 464 all reachable on dc-0.
- **Conclusion:** Network is fine.

### ❌ Phantom record in state
- **Test:** `Get-DnsServerResourceRecord` for `web-server-01` in `hashicorp.local`.
- **Result:** No record. (Verified on the most recent failed CREATE run.)
- **Conclusion:** No conflict — agent is genuinely trying a fresh insert.

### ❌ Zone-level CreateChild permission missing
- **Test:** Read the `dnsZone` AD object's `nTSecurityDescriptor`.
- **Result:** `HASHICORP\DnsAdmins` has `CreateChild, DeleteChild, ListChildren, ReadProperty, DeleteTree, ExtendedRight, Delete, GenericWrite, WriteDacl, WriteOwner` (InheritanceType: **All**). `NT AUTHORITY\Authenticated Users` also has `CreateChild` (InheritanceType: None). Either path should grant `dns_terraform` the create permission.
- **Conclusion:** Visible ACL says this should work. *Yet the DC refuses.*

---

## Wire-level evidence (definitive)

### Capture setup
- tcpdump on `hcp-tfc-agent0` (`172.21.15.169`), interface `any`, filter `(host 172.21.15.150) or (tcp port 88) or (udp port 88) or (port 464)`
- Other agents in pool (`agent-1`, `agent-2`) deliberately set to **exited** status so the failing run had to land on `agent-0`
- Verified via TFC API that the failing run actually executed on `agent-2JXZ1GdgiKMWjsrL` (`hcp-tfc-agent-0`)

### Run that produced the trace: `run-4nvmoNCR93mbrtzJ`
- Applying: `2026-05-19T10:17:44 UTC`
- Errored: `2026-05-19T10:18:09 UTC`

### Key packets (decoded with `tcpdump -nn`)

```
20:18:06.317118  AGENT → KDC (UDP 88)    Kerberos v5 AS-REQ/TGS-REQ
20:18:06.317832  KDC → AGENT             Kerberos response
20:18:06.326386  AGENT → DC  (TCP 88)    Kerberos over TCP (large ticket)
20:18:06.327828  DC → AGENT              Kerberos response (1448+266 bytes — TGS ticket)
20:18:06.336340  AGENT → DC  (TCP 53)    TKEY ANY? 1399212898.sig-dc-0.hashicorp.local. (1649 bytes)
20:18:06.337310  DC → AGENT              TKEY response (385 bytes) — GSS context established OK ✓
20:18:06.338085  AGENT → DC  (UDP 53)    UPDATE [1 record, 1 TSIG]  SOA? hashicorp.local. (179 bytes)
20:18:06.338356  DC → AGENT              UPDATE Refused (179 bytes)  ❌
```

### Decoded UPDATE request payload (what the agent tried to write)

```
ZONE:      hashicorp.local. (class IN, type SOA)
PREREQ:    (none — PRCOUNT=0)
UPDATE:    web-server-01.hashicorp.local. A 172.21.14.216 TTL=3600
TSIG:      algorithm gss-tsig, signed by 1399212898.sig-dc-0.hashicorp.local
```

A minimal "blind insert" with no prerequisites. No conflict possible from the request's own structure.

### Decoded REFUSED response (hex from pcap)

```
Flags = 0xa805 →
  QR=1 (response)
  OPCODE=5 (UPDATE)
  RCODE=5 (REFUSED) ←←← THE ACTUAL REJECTION
ZCOUNT=1, PRCOUNT=0, UPCOUNT=1, ADCOUNT=1

TSIG additional record's MAC starts: 04 04 00 ff ff ff ff ff …
  04 04   = GSS-API MIC token header (RFC 4121)
  00      = flag byte; bit 0 (SendByAcceptor) = 0
```

`SendByAcceptor=0` means "this MIC was generated by the initiator, not the acceptor" — gokrb5 expects it to be 1 (since the DC IS the acceptor), so it throws `"unexpected acceptor flag is not set: expecting a token from the acceptor, not in the initiator"`.

The DC isn't lying maliciously — when REFUSED, it doesn't generate a fresh acceptor MIC. The bodgit/tsig maintainer confirms this is the behavior they've seen too.

---

## Repo + module changes already made (don't redo)

These landed during the investigation:

- **`terraform-dns-records` (was `terraform-dns-management` / briefly `terraform-dns-domain-name-system-management`)** — Tagged **1.1.0** with:
  - `hashicorp/dns ~> 3.3` → `~> 3.6`
  - new optional `zone` variable (default `"hashicorp.local."` — backward-compatible)
  - input validations
  - `required_version = ">= 1.5.0"`
  - removed dead commented PTR block
  - new outputs `a_record_fqdns`, `cname_record_ids`
  - GH repo renamed; PMR slug **stays** as `domain-name-system-management/dns` (7 active consumers across other repos make a slug rename too disruptive)

- **`terraform-vsphere-single-virtual-machine`** — PR #2 (dns module bump to `~> 1.1`) merged to main; PR #3 (vm submodule bump to 2.0.3) **closed** because vm 2.0.3 didn't exist in PMR. **PMR now has `single-virtual-machine/vsphere 2.0.2`** (republished via the Release workflow once `semver:patch` label was applied and the stale `TFE_TOKEN` secret was refreshed in GH Actions).

- **`better-together-vm-lifecycle`** — `single-virtual-machine` pin `1.6.2` → `~> 2.0`; root `provider.tf` `hashicorp/dns ~> 3.3` → `~> 3.6`. Both committed and pushed to `main`.

- **Workspace** renamed from `terraform-dev-vsphere-aap-vault-agent-install` to `better-together-vm-lifecycle-dev` via TFC API. VCS link updated. The old VCS path is followed by GitHub's auto-redirect for any stragglers.

---

## What's still unknown — the one open question

**Why does the DC return RCODE 5 REFUSED when the visible ACL allows the operation?**

Hypotheses NOT yet tested:

1. **Registry override `AdminAccessOnly`** — Windows DNS Server can be configured via `HKLM:\SYSTEM\CurrentControlSet\Services\DNS\Parameters\AdminAccessOnly = 1` to require local (machine-level) DnsAdmins membership for updates, ignoring domain-group rights. `dns_terraform` is in the *domain* `DnsAdmins` but may not be in the *local* `DnsAdmins` on dc-0.
   - **Check:** `Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\DNS\Parameters' | Select AdminAccessOnly` on dc-0.

2. **Stale TGT/PAC group membership** — If `dns_terraform` was recently added to `DnsAdmins`, but the agent has a cached TGT issued before that change, the PAC inside the TGT wouldn't include the new group. AD-only ACL checks would still grant access, but DDNS may check group membership via the inbound PAC.
   - **Check:** When was `dns_terraform` added to `DnsAdmins`? `Get-ADGroup DnsAdmins -Properties whenChanged, Members`. Also force agent to fetch fresh TGT by restarting the agent container.

3. **Windows DNS Server "GuardSidValue" / restrictive principal list** — DDNS in some hardened environments uses a separate principal list that the DC checks against (separate from the AD ACL).
   - **Check:** `Get-DnsServerSetting -ComputerName dc-0 -All | Format-List` looking for anything related to update principals.

4. **TSIG signature actually fails server-side**, but the DC reports REFUSED instead of BADSIG — non-standard but observed in some Windows versions.
   - **Check:** Compare the MAC bytes the agent sent (in the UPDATE request) against what the DC would compute. Requires decoding the TSIG key from the TKEY response. Heavy.

5. **The zone is configured with a per-zone "allowed updaters" list** (Windows Server 2022+ feature) that's not in the standard ACL.
   - **Check:** `Get-DnsServerZone -ComputerName dc-0 -Name hashicorp.local | Format-List *`.

6. **Auditing / sub-class object permissions** — The ACL we see is at the zone level. There may be a separate "blackhole" or "delegation" config on the `web-server-01` name specifically that pre-allocates and refuses external DDNS.
   - **Check:** `Get-DnsServerZoneDelegation -Name hashicorp.local -ChildZoneName web-server-01` on dc-0.

---

## Resolution paths (in increasing order of effort)

### Path A — find the root cause and fix it permanently
Run the six checks above. Most likely the answer is #1 (`AdminAccessOnly` registry override) or #2 (stale TGT/PAC). Once identified, the fix is one cmdlet.

### Path B — replace the GSS-TSIG mechanism
Swap `dns_a_record_set` for a different update channel:
- **Local-exec `nsupdate -k`** — requires installing MIT krb5 client tools in the agent image. Robust but heavy.
- **PowerShell remoting `Add-DnsServerResourceRecord`** — requires WinRM to dc-0 from the agent. Avoids gokrb5/tsig entirely.
- **PR an alternative DNS provider** that uses Kerberos-bind-style update mechanisms.

### Path C — document and use the manual workaround
Before each apply: `Add-DnsServerResourceRecordA -ComputerName dc-0 -ZoneName hashicorp.local -Name web-server-01 -IPv4Address <ip>` from an admin session. Before each destroy: `Remove-DnsServerResourceRecord …`. Then the Terraform create/delete becomes idempotent no-ops and succeeds.

---

## Diagnostic assets in this repo

- **`scripts/diagnose-ddns-refused.ps1`** — read-only PowerShell on dc-0 that walks through hypotheses H1-H6 (record existence, zone update policy, per-record ACL, zone-level ACL, service account enctype, DC log events). Last run output is in the conversation history.
- **`scripts/capture-ddns-debug.ps1`** — manages Windows DNS Server debug logging (Enable/Show/Dump/Disable modes). Currently configured to write to `C:\dns-debug\dns.log` on dc-0. **Note:** the DNS Server debug logging filter (`FilterIPAddressList`) was set to the wrong agent IP for most of the investigation (`172.21.15.167` was the management IP; the actual agent IP on `ens192` is `172.21.15.169`). The filter is now unset / can be set to `.169` if reused.
- **`/tmp/agent-dns-capture.pcap`** on the agent VM — last good pcap. Locally available at `/tmp/agent-dns-capture.pcap` on Aaron's Mac (281KB). Read with `tcpdump -r /tmp/agent-dns-capture.pcap -nn -A -tttt`.

---

## How to resume

1. Skim §"Hypotheses ruled out" and §"Wire-level evidence" so you don't repeat work.
2. Pick a hypothesis from §"What's still unknown" — probably #1 (`AdminAccessOnly`) first since it's a one-line check.
3. SSH credentials for agent VM: `ssh -i ~/.ssh/gcve/id_ed25519 ubuntu@172.21.15.169`.
4. dc-0 access: PowerShell session as Administrator on dc-0 (the user accesses this directly via their environment).
5. TFC user token (rotate after use; the last one used in conversation was `PcQYN9yVHokgGA…` — likely already rotated by Aaron).
6. The agent pool has `hcp-tfc-agent-0` active and `agent-1`/`agent-2` exited from the investigation. Re-enable them when done if other workspaces in the pool need them.

---

## Reference issues

- [bodgit/tsig#54](https://github.com/bodgit/tsig/issues/54) — "Error updating DNS record: unexpected acceptor flag is not set: expecting a token from the acceptor, not in the initiator" — maintainer's explanation that this is a server-side rejection masquerading as a client parse error.
- [hashicorp/terraform-provider-dns#160](https://github.com/hashicorp/terraform-provider-dns/issues/160) — same error class reported against Windows AD DNS, no upstream fix.
- [terraform-provider-dns CHANGELOG.md](https://github.com/hashicorp/terraform-provider-dns/blob/main/CHANGELOG.md) — no GSS-TSIG fixes since v3.1.0 (Feb 2021).



🎯🎯🎯 FOUND THE EXACT BUG 🎯🎯🎯

  Two open issues, opened THE SAME DAY each release dropped:

  - bodgit/tsig#178 opened 2026-05-14 — "v1.3.0: GSS-TSIG broken with Windows AD DNS servers"
  - hashicorp/terraform-provider-dns#642 opened 2026-05-13 — "DNS updates using RFC 2136 are no longer possible with 3.6.0"

  The v1.3.0 refactor (which closed #111) broke GSS-TSIG against Windows DCs entirely. terraform-provider-dns 3.6.0 inherited the broken
  tsig. This matches our timeline perfectly — the new image rebuilt on 5/14 was pulling a tfc-agent binary that included the new tsig.

  Let me read both issues for the fix:

⏺ Bash(echo "############# bodgit/tsig#178 — full content #############"
      curl -s "https://api.github.com/repos/bodgit/tsig/issues/178" | python3 -c "…)
  ⎿  ############# bodgit/tsig#178 — full content #############
     Title: v1.3.0: GSS-TSIG broken with Windows AD DNS servers
     State: open
     … +80 lines (ctrl+o to expand)
  ⎿  Allowed by auto mode classifier

⏺ 🎉 100% CONFIRMED ROOT CAUSE — and the fix is straightforward.

  The complete story:

  1. 2026-04-28: bodgit/tsig v1.3.0 released with a GSSAPI wrapper refactor. The refactor introduced a regression in subkey handling for
  Windows AD DNS specifically.
  2. 2026-05-13: terraform-provider-dns v3.6.0 released, bumping tsig v1.2.2 → v1.3.0. ansgarm (HashiCorp) recommends "pinning the 
  provider to < 3.6.0 works in the meantime."
  3. 2026-05-14: Your tfc-agent image rebuilt that exact day — but actually that's a coincidence; the provider version is resolved
  per-run from the module's required_providers, not bundled in the agent.
  4. 2026-05-18: onno204 found the exact line: bodgit/gssapi/context.go:142 is missing a ctx.hasPeerSubkey() check. They opened PR #50 on
   bodgit/gssapi.

  The check that throws our error has always been there — what's new in v1.3.0 is that it now triggers on legitimate Windows DC
  responses. The fix in upstream is pending PR review.

  The fix (now)

  Pin hashicorp/dns < 3.6.0 in all three layers. 3.5.0 uses the working tsig v1.2.2