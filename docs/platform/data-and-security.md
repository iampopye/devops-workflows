# Extension tracks: security and Azure data platforms

These are follow-on designs, not completed integrations. Build them as independently testable additions after the core lab demonstrations.

## SonarQube and security gates

The existing `examples/sonarqube-scan.yml` is a starting reference, not a verified .NET 10 integration. For .NET, run the supported SonarScanner for .NET begin step, build/tests with coverage, and end step; wait for the quality gate before publishing/promoting. Use a supported Java/scanner/server combination and least-privilege token. Host internal SonarQube connectivity on an isolated agent, never expose its token to untrusted PR code. Handle new-code findings separately from baselines, with time-limited reviewed exceptions.

Complement SAST with dependency, IaC and image scanning. The new container workflow blocks HIGH/CRITICAL findings before publishing and emits an SPDX SBOM. It is single-platform `linux/amd64`; SBOM is an inventory artifact, **not** a signed attestation. A later signing/admission-policy track should bind provenance and signature to the exact image digest and verify it at cluster admission.

## Databricks Unity Catalog external location

In Azure, separate infrastructure ownership from data governance:

1. Provision ADLS Gen2 and an Azure Databricks Access Connector with managed identity using reviewed Terraform.
2. Grant the identity narrowly scoped storage data permissions and configure network access.
3. In a Unity Catalog-enabled workspace/metastore, create a storage credential referencing the Access Connector identity.
4. Create an external location for the approved `abfss://container@account.dfs.core.windows.net/prefix` using that credential; validate read/write and isolation.
5. Create a catalog with its approved managed storage location if needed, or create external tables/volumes under the external location. A catalog and an external location are different objects; an external location does not itself create a catalog.
6. Grant required catalog/schema/table privileges and external-location privileges to groups, not everyone. Separate account/metastore administration from workspace job identities. Do not use skip-validation to mask permission/network failures.

Use a dedicated Databricks Terraform provider configuration, pinned versions and isolated state; use bundle validation/deployment for notebooks/jobs. Run a small workload and verify catalog access from the intended job identity before promotion. Record permissions and revoke negative-test access.

References: [ADLS external locations](https://learn.microsoft.com/en-us/azure/databricks/connect/unity-catalog/cloud-storage/storage-credentials), [Unity Catalog architecture](https://learn.microsoft.com/en-us/azure/databricks/lakehouse-architecture/deployment-guide/unity-catalog).

## Data Factory and Synapse

Azure DevOps orchestrates CI/CD for both services; it is not the data execution engine. Choose one orchestration owner for a given pipeline to avoid duplicated scheduling. Use managed identities and approved linked services/private endpoints where supported; use a self-hosted integration runtime for appropriate on-prem connectivity. Test the precise authentication path for the selected connector.

Validate source-controlled artifacts in CI, parameterize environment endpoints, approve deployment, coordinate triggers, run smoke pipelines and monitor failures. Keep credentials in Key Vault references. ADF-to-Synapse or Databricks integration depends on the activity/workload; do not invent one universal 'best connection'. Track deployment rollback separately from data correctness/reprocessing.

## Learning priorities and exclusions

Complete: local syntax and release failure-path tests in this contribution, with CI checks attached to the PR.

Lab-required: Docker push/scan evidence, Terraform plan/apply in a sandbox, AKS/Argo reconciliation, Ansible idempotency, IIS load-balanced traffic, Azure slot swap/rollback and DB migration drill.

Future: full AKS landing zone, Databricks/ADF/Synapse deployment workflows, signed provenance/admission enforcement and richer policy tests. Amazon Brazil/Apollo/Coral and related internal platforms cannot be credibly demonstrated without authorized access; this repository makes no claim of implementing them.
