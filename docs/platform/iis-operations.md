# IIS delivery and adapter contract

## Three-server blue-green sequence

Run two isolated sites/app pools per host (blue and green) with distinct backend hostnames or ports. The load balancer routes users to only one colour across all three hosts. All nodes must support the full release during the rollback window. Shared sessions, compatible auth/data-protection keys, durable external storage and backward-compatible database schemas are prerequisites for continuity.

`Invoke-IisRelease.ps1` prepares all three inactive sites, checks each, runs the database expand gate once, rechecks readiness, switches traffic, verifies production and drains old connections. Old sites remain available for rollback. It never writes `app_offline.htm`, overwrites the active deployment, or restarts all nodes together. Cancellation, runner loss and LB timeouts still need durable state and an out-of-band recovery runbook; no script can promise zero downtime without application/LB integration testing.

The caller supplies a reviewed PowerShell adapter. It accepts `Action`, `Inventory`, `ReleaseDirectory`, `Manifest`, `State`, and `Node`. Every native command must check its exit code; every failed API response must throw. Never swallow errors. Only Inspect emits structured state; other actions return no data.

| Action | Required behavior |
|---|---|
| Inspect | Query actual LB routing. Return `activeColour`, `previousVersion`, `snapshotId`; durably record full current routing and release ID. Reject a mixed or ambiguous starting state. |
| Preflight | Acquire/verify shared deployment lock; confirm inactive colour has zero user traffic, capacity, remote connectivity, .NET 10 Hosting Bundle, ACLs, bindings, TLS SAN/expiry and rollback target. Fail before changes if not safe. |
| PrepareInactive | Via WinRM HTTPS/Kerberos, verify checksum on destination, expand into a fresh version directory, inject external configuration, configure inactive site/pool, warm it. Re-check inactivity before modifying any existing pool. |
| VerifyInactive | Validate each node directly with correct hostname/SNI, trusted TLS, expected release version and dependency readiness. Add application smoke tests. |
| ExpandDatabase | Validate approved migration evidence or apply an idempotent additive migration under a database lock exactly once. If a caller migration stage already ran, verify its marker instead of applying twice. |
| SwitchTraffic | Shift the whole farm to the candidate using the vendor-supported operation. Preserve old connections, do not disable both colours. A timeout is a potentially applied operation. |
| VerifyProduction | Probe through the public LB and inspect per-node traffic, error rate, latency, dependency failures and release version during the soak interval. |
| DrainPrevious | Stop assigning new traffic to old colour; wait for connections/requests to drain. Retain old pools/files. Release distributed lock after durable success record. |
| RestoreTraffic | Idempotently restore the durable prior LB snapshot, including after partially successful switch. Never derive rollback from a guessed colour. |
| VerifyRollback | Verify previous version through the LB, node health and connection draining; record incident/evidence and release lock. |

If preparation/migration fails before switch, production stays on its existing colour. The adapter must release/expire its lock safely on failure before traffic switching. If switch/production checks/drain fails, orchestration attempts restore and verifies it. If restore fails, stop and invoke manual recovery using the saved snapshot.

## Server reproducibility

Use `ansible/iis-baseline.yml` for prerequisites. Stage an approved Hosting Bundle from the corporate artifact mirror; verify vendor signature and hash. Install IIS first; repair the Hosting Bundle if installed before IIS. Check `dotnet --list-runtimes` and ANCM, OS support and patch policy. Runtime installation/reboots happen during rolling maintenance, not during app release.

`New-IisInactiveSite.ps1` provides a provisioning helper with `-WhatIf`, isolated pool, No Managed Code and SNI certificate binding. It refuses existing sites/pools rather than silently changing live resources. Use it on the server with WebAdministration; grant the pool identity read/execute to package files and write only to dedicated data/log directories. Test certificate hostname, chain, expiry and backend TLS health. Certificate rotation is its own staged operation.

Use publish-generated `web.config`; do not hand-replace its ANCM handlers. In-process hosts inside `w3wp`; out-of-process proxies to Kestrel. Pick and test one hosting model consistently. Set ASPNETCORE_ENVIRONMENT and connection strings through protected per-pool/server configuration or a secret provider. Avoid machine-wide settings shared between colours. Share ASP.NET Core data-protection keys appropriately across nodes and protect them at rest.

On-prem does not assume Managed Identity. Prefer a domain service identity/gMSA where supported, enterprise vault with short-lived credentials, or encrypted configuration accessible only to the service identity. Run secrets retrieval server-side; avoid command-line secrets, logs, artifacts and Git. Standardize WinRM HTTPS and certificate validation; never enable Basic over HTTP or disable TLS checks. MSDeploy may populate only the inactive path/site with narrowly scoped delegation. Avoid AppOffline rules on the serving site.

## Prove it in a lab

Generate continuous traffic during prepare, switch and rollback. Inject one failed readiness endpoint, one LB timeout after applying, an expired cert and one node loss. Capture status codes, p95 latency, active requests, version per node and rollback duration. Include long-lived requests/WebSockets and session continuity. Publish sanitized evidence, with observed downtime rather than an unsupported guarantee.
