# Portfolio and interview walkthrough

## Positioning

This collection supports a Senior Security & DevSecOps Engineer profile through inspectable source, explicit security boundaries and repeatable validation. Describe what you designed, what you tested and what remains a reference. Keep customer names, addresses, credentials and private architecture out of public examples.

## Suggested 15-minute demonstration

| Time | Show | Explain |
|---|---|---|
| 0–2 min | Workflow catalog and architecture | Build once, promote immutable artifacts, separate CI from privileged delivery |
| 2–5 min | Docker workflow and Helm chart | Scan before push; why digest pinning, non-root, resource limits, readiness and PDB matter |
| 5–8 min | Terraform module and plan/apply workflow | Module reuse, provider lock, backend lease, OIDC, approvals and saved plan |
| 8–10 min | Ansible check mode and IIS baseline | Idempotency, serial execution, credential isolation and reboot control |
| 10–13 min | Hybrid PowerShell tests | Failed readiness blocks traffic; ambiguous switch triggers restore; corrupt ZIP fails |
| 13–15 min | Incident/cutover runbook | SLOs, observed health, compatible DB schema and reversible traffic changes |

## Questions you should be able to answer from the code

- **Module call vs 'TF call'?** 'TF call' is ambiguous; ask whether they mean Terraform CLI or a resource block. A module block instantiates a reusable group of resources. `terraform plan/apply` evaluates and executes the overall configuration; it is not a module type.
- **Module vs data source?** A module packages configuration and can contain resources and data sources. A data source reads information from a provider; it does not create the object it reads. Show `module "network"` and contrast it with looking up an existing VNet.
- **Why not rebuild for production?** Rebuilding changes the artifact under review. The ZIP checksum or container digest identifies what was actually tested; environment configuration is supplied separately.
- **Why is a Kubernetes PDB insufficient for zero downtime?** It constrains voluntary disruptions, not every failure. Readiness, capacity, application shutdown/drain behavior, compatible schemas and rollout settings also matter. The example PDB assumes at least three replicas.
- **Why not just run app_offline?** It stops the serving app. Side-by-side release prepares another pool/site and changes routing only after readiness. Sessions, long-lived connections and DB writes still need explicit design.
- **What if rollback fails?** Stop automated promotion, declare/continue the incident, use durable routing state, validate dependencies and execute the manual recovery plan with an owner.
- **How do you distinguish a false alert?** Correlate user-visible symptoms with independent signals, recent deployments and telemetry health; preserve evidence before changing thresholds.

## Evidence ledger

For each workflow, record: commit SHA, sanitized run URL, environment, validation performed, injected failure, result, rollback time, limitations and cleanup. A green YAML linter is not an IIS deployment test. A rendered Helm chart is not a running AKS service. Replace reference labels only after a real lab run.

Suggested evidence: successful and failed image scan; Terraform rejected/approved plan; two identical Ansible runs with the second reporting no changes; Kubernetes readiness failure and recovery; three-node IIS traffic measurements; Azure swap-back; database expand compatibility; incident timeline. Remove Azure resources after labs and record the cleanup plan/cost estimate before provisioning.
