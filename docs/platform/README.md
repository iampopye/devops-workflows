# Platform engineering workflow collection

This additive collection is organized around Karan Garg's DevSecOps profile: infrastructure as code, container/Kubernetes security, secure CI/CD, configuration automation and operational reliability. Hybrid IIS/Azure delivery is a new reference implementation aligned with the supplied role requirements.

These are demonstrable engineering assets, not claims that every integration has run in a client production environment. Keep an evidence record for each lab run; do not describe the templates as production-tested until those checks exist.

## Start here

| Area | New entry point | What to demonstrate |
|---|---|---|
| .NET / React | [Hybrid build](../../.github/workflows/reusable-hybrid-build.yml) | Locked dependencies, mandatory tests, one ZIP + checksum manifest |
| Windows / IIS | [Blue-green release](../../.github/workflows/reusable-iis-blue-green.yml) | Three nodes, readiness, LB adapter boundary, rollback after partial switch |
| Azure App Service | [Slot release](../../.github/workflows/reusable-azure-slot-release.yml) | OIDC, staging warm-up, swap, post-swap verification |
| Terraform | [Azure plan/apply](../../.github/workflows/reusable-azure-terraform.yml) | Remote state, separate plan/apply identities, approved saved plan |
| Docker | [Secure container build](../../.github/workflows/reusable-container-secure-build.yml) | Scan before push, SPDX SBOM, immutable deployment digest |
| Kubernetes / Helm | [Helm validation](../../.github/workflows/reusable-kubernetes-helm-validate.yml) | Read-only PR validation, hardened chart, Argo CD promotion |
| Ansible | [Windows baseline](../../.github/workflows/reusable-ansible-windows.yml) | Check mode, serial changes, Kerberos over verified TLS |
| Azure DevOps YAML | [Build](../../azure-pipelines/build-hybrid.yml) / [release](../../azure-pipelines/release-hybrid.yml) | Same package and PowerShell implementation across CI systems |

All new callable GitHub workflows live directly in `.github/workflows/`. The legacy nested workflows are retained; GitHub does not support calling workflows from subdirectories. This addition does not repair or certify the legacy collection.

## Consumption and release contract

1. Review this branch, merge it when ready, and obtain its full commit SHA. New workflows are **not available at the existing `v1` tag**. Pin caller `uses:` references to that reviewed SHA. Workflows using toolkit scripts also require `toolkit_ref` set to the same SHA.
2. Configure protected environments *before* enabling deploys: required reviewers, default-branch-only rules, deployment identities and self-hosted runner group restrictions. A YAML environment name alone does not create approval protection.
3. Consumer app: ASP.NET Core `net10.0` serves the React build from `wwwroot`, including a SPA fallback. Commit NuGet lock files and `package-lock.json`; provide `npm run test:ci`. Use relative `/api` URLs or a public runtime config endpoint so environment URLs are not embedded during React compilation. Never put secrets in SPA runtime config.
4. `/health/ready` returns HTTP 200 and JSON `{"status":"Healthy","version":"<release version>"}` only when required dependencies are available. Read the version from package `release.json`. `/health/live` measures process liveness without depending on the database. Readiness requires three consecutive valid HTTPS responses. Configure real end-to-end smoke tests in the IIS adapter and the application delivery process too.
5. The build produces `application.zip` and `manifest.json` once. Both release targets download the **same run artifact**. Release-time settings are external to this ZIP. Checksums detect corruption, not a malicious authorized publisher; restrict artifact and workflow write access.
6. Build/test runs on hosted workers. On-prem deployment runs only from the default branch on an isolated Windows runner behind the firewall. Never run PR code on privileged internal runners. Windows PowerShell 7 is required for release scripts; WebAdministration provisioning uses Windows PowerShell 5.1 on the server where needed.
7. GitHub concurrency serializes deployments per target. IIS adapter must additionally implement a distributed deployment lock shared with Azure DevOps/manual operators. Pre-provision Azure DevOps environment checks and exclusive locks. Do not run two CI systems against one target concurrently without a shared lock.

Use the [caller example](../../examples/platform/hybrid-delivery.yml), [input reference](workflow-inputs.md), [IIS contract](iis-operations.md), [operations guide](operations.md) and [interview walkthrough](portfolio.md).

## Boundaries

- IIS adapter is intentionally a failing stub. ARR, F5, NetScaler and NLB require different traffic-control implementations; none is fabricated here.
- Azure needs existing Windows App Service + staging slot, supported .NET 10 runtime, identities, sticky configuration and database migration gate. First deployment/bootstrap is separate; this release path requires a healthy previous version.
- Terraform example provisions only a VNet foundation. App Service, Key Vault, private endpoints, connectivity, observability and governance must be composed and reviewed for the target environment.
- Helm validation does not contact a cluster. A successful render is not proof of runtime health or admission compatibility. Argo CD application is an example requiring a real GitOps repo and restricted AppProject.
- Ansible baseline installs IIS prerequisites; Hosting Bundle, certificate rollout and reboots require a drained maintenance window. No unconditional reboot is automated.
- Databricks, ADF/Synapse, SonarQube and incident response are covered by the [extension guide](data-and-security.md), not advertised as completed deployment integrations. Amazon-internal tools require authorized internal access and are outside this public collection.

## Primary references

- [GitHub reusable workflow placement](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows)
- [ASP.NET Core IIS hosting](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/iis/?view=aspnetcore-10.0)
- [Azure deployment slots](https://learn.microsoft.com/en-us/azure/app-service/deploy-staging-slots)
- [AzureRM OIDC authentication](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_oidc)
- [Ansible Windows management](https://docs.ansible.com/projects/ansible/latest/os_guide/intro_windows.html)
- [Argo CD automated sync](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/)

## Validation commands

```bash
actionlint .github/workflows/*.yml .github/workflows/*/*.yml examples/*.yml examples/platform/*.yml
pwsh -NoProfile -File tests/Test-Hybrid.ps1
pwsh -NoProfile -File tests/Test-AzureRelease.ps1
helm lint charts/service --strict
terraform fmt -check -recursive terraform
terraform -chdir=terraform/modules/azure-network init -backend=false
terraform -chdir=terraform/modules/azure-network validate
ansible-galaxy collection install -r ansible/requirements.yml
ansible-playbook -i ansible/inventory.example.yml ansible/iis-baseline.yml --syntax-check
ansible-lint ansible/iis-baseline.yml
```

The isolated Ansible runner needs reviewed `ansible-core==2.18.6`, `ansible-lint==25.5.0`, `pywinrm==0.5.0`, the pinned collection, Kerberos libraries/ticket and corporate CA trust. Review and update tool versions regularly. The workflow does not download privileged tools at deployment time.
