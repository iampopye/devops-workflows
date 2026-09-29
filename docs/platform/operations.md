# Hybrid release, migration and incident runbooks

## Azure slot configuration

Provision Windows App Service on a slot-capable plan and confirm .NET 10 support in the chosen region/stack before release. Set production and staging configuration using IaC; use slot-sticky environment settings, connection strings and Key Vault references. Assign least-privilege vault permissions separately to each slot identity. Do not write resolved secrets into ZIP packages. The SPA uses relative API paths or public runtime settings.

Set `WEBSITE_SWAP_WARMUP_PING_PATH=/health/ready` and accepted warm-up statuses to `200`, and validate behavior with the actual authentication/network configuration. Disable build-on-deploy for the prebuilt package. Private endpoints/SCM restrictions require a network-connected deployment runner; the provided hosted-runner workflow must be adapted to that runner group before use.

The release script verifies a healthy production rollback target, ZIP integrity, candidate readiness and release version, then swaps. If post-swap validation fails, it swaps back and verifies the previous version. If the swap API itself fails/times out, its state is ambiguous: query Azure activity logs and both slot versions before manual recovery. Do not blindly swap again. Cancellation/runner loss follows the same recovery procedure. Keep the staging slot containing the previous release untouched until the rollback window closes.

## Database release gate: SQL Server and PostgreSQL

Use a dedicated approved migration job before Azure delivery; IIS adapter implements or verifies the same gate. Package migration scripts/bundles with a version and checksum, reviewed alongside the app. Use database-scoped credentials obtained from a vault, not the application admin account. Test migrations against a restored copy and rehearse backup restore/RPO/RTO.

1. Acquire a database deployment lock, verify expected schema version and backup evidence.
2. Review lock duration and production workload impact; configure lock/statement timeouts.
3. Apply **expand** changes compatible with both old and new applications. Record release/schema version and checksum transactionally where supported.
4. Validate reads/writes and application parity. Switch application traffic only after success.
5. After the rollback window, approve a separate **contract** change to remove old columns/interfaces.

A traffic rollback does not undo writes. Never automatically run a destructive down migration or restore a production database during an application rollback. Stop the release on unknown migration state; reconcile history and investigate before retrying. PostgreSQL operations such as concurrent index creation may require non-transactional handling; SQL Server changes may acquire schema locks. Select migration tooling for the application and rehearse those cases.

## IIS to Azure cutover

Inventory IIS dependencies: Windows auth, COM, file system writes, scheduled tasks, certificates, network shares, session affinity, data-protection keys, database latency and outbound IP allowlists. Resolve unsupported dependencies before migration. Establish VPN/ExpressRoute/private DNS where required; App Service VNet integration is outbound connectivity, not inbound private access.

Deploy the exact same artifact to Azure. Test authentication, cookies, redirects, time zones, culture, paths, dependency connectivity, secrets rotation, background jobs, performance and restore. Avoid running duplicate schedulers/consumers during parallel operation unless coordinated.

Lower DNS TTL ahead of cutover, verify certs/custom domains and route a small percentage through a traffic manager where possible. Observe errors, p95 latency, business transactions and database writes. Increase only against agreed thresholds and owner approval. DNS caches and long-lived connections mean DNS changes are not instantaneous switches. Keep IIS serving and compatible until TTL, connection drain and rollback windows pass. Define how writes remain consistent if traffic moves back.

## Incident management and alert validation

Incident management restores service and limits impact: detect, triage, declare severity/owner, communicate, mitigate, validate recovery and write a blameless post-incident review with preventive actions.

An alert alone is not proof of user impact. Correlate external synthetic probes, real request error rates/latency, Windows Event Logs, IIS logs, performance counters, distributed traces and recent changes. Check whether the telemetry pipeline itself is failing. A single healthy probe does not disprove an incident; reproduce from affected networks/identities. Record why an alert was actionable, duplicate, transient or a false positive before tuning it. AI-generated summaries are advisory and must not close incidents or execute remediation automatically.

For hybrid observability, forward through an approved egress proxy using OpenTelemetry Collector and/or Azure Monitor Agent with the appropriate supported ingestion path. Use Azure Arc where approved for server management. Redact credentials/PII, bound local queues, define loss/backpressure behavior and alert on collector failure. Use a common release version, service name, environment and trace ID across both targets. Define SLOs and error-budget burn alerts, plus rollback thresholds, before cutover.

## Terraform state and access

Bootstrap the Azure Storage backend separately: restricted networking, Entra authentication, versioning/soft-delete, encryption and scoped Storage Blob Data Contributor access. Configure nonsecret backend attributes in the root module or an approved backend configuration mechanism. The reusable workflow uses the root's backend configuration and `ARM_USE_AZUREAD=true`; it does not create the backend.

Use separate state keys and credentials per environment. Terraform workspaces alone are not an access-control boundary. Commit `.terraform.lock.hcl` from a reviewed initialization: the workflow deliberately uses `-lockfile=readonly`. Plan identity needs read permissions plus backend lease access; apply identity needs the minimal resource write permissions. Both need environment-scoped OIDC trust. Protect the apply environment with an independent reviewer.

The plan is an artifact restricted to one-day retention and applied without replanning. It may contain secrets despite `sensitive=true`; do not use this artifact pattern in a public repository holding confidential infrastructure data. Use an appropriately private deployment repository and restrict Actions/read access. Stale plans fail; regenerate and review rather than forcing state. Serialize other writers as well as this workflow. Never automatically unlock someone else's state lock.
