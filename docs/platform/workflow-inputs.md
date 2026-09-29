# New workflow inputs

All caller inputs are listed below. New workflows declare no reusable secrets. Azure releases use OIDC IDs; Terraform reads environment-scoped `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` variables. Ansible/IIS use pre-provisioned internal identities. No secret should be passed as an input.

## reusable-ansible-windows.yml

| Input | Required | Default | Purpose |
|---|---|---|---|
| `playbook` | no | `ansible/iis-baseline.yml` | Reviewed playbook path. |
| `inventory` | no | `ansible/inventory.example.yml` | Inventory file path. |
| `environment` | no | `onprem-lab` | Protected environment with runner credentials. |
| `runner_labels` | no | `["self-hosted", "Linux", "ansible-deploy"]` | JSON labels for isolated Linux runner with WinRM connectivity. |
| `apply` | no | `False` | Apply changes; false runs Ansible check mode. |

## reusable-azure-slot-release.yml

| Input | Required | Default | Purpose |
|---|---|---|---|
| `toolkit_ref` | yes | `—` | Full reviewed 40-character commit SHA of this toolkit; use the same SHA as the workflow reference. |
| `artifact_name` | yes | `—` | Artifact from reusable-hybrid-build in the same workflow run. |
| `environment` | yes | `—` | Pre-created protected GitHub environment; configure required reviewers and branch restrictions. |
| `resource_group` | yes | `—` | Existing resource group. |
| `app_name` | yes | `—` | Existing Windows App Service name. |
| `slot` | no | `staging` | Existing non-production deployment slot. |
| `client_id` | yes | `—` | Entra application client ID with environment-scoped OIDC federation. |
| `tenant_id` | yes | `—` | Entra tenant ID. |
| `subscription_id` | yes | `—` | Azure subscription ID. |

## reusable-azure-terraform.yml

| Input | Required | Default | Purpose |
|---|---|---|---|
| `working_directory` | no | `infra` | Root module directory. |
| `terraform_version` | no | `1.14.3` | Reviewed exact Terraform version. |
| `environment` | no | `azure-infra` | Protected apply environment. |
| `plan_environment` | no | `azure-plan` | Separate read-only OIDC environment for planning. |
| `apply` | no | `False` | Apply saved plan after environment approval; default branch only. |

## reusable-container-secure-build.yml

| Input | Required | Default | Purpose |
|---|---|---|---|
| `image_name` | yes | `—` | Lowercase GHCR image name, for example ghcr.io/owner/service. |
| `context` | no | `.` | Docker build context. |
| `dockerfile` | no | `Dockerfile` | Path to Dockerfile. |
| `push` | no | `False` | Push scanned image from default branch only. |

Outputs: `digest`: Published digest; empty for validation-only builds.

## reusable-hybrid-build.yml

| Input | Required | Default | Purpose |
|---|---|---|---|
| `toolkit_ref` | yes | `—` | Full reviewed 40-character commit SHA of this toolkit; use the same SHA as the workflow reference. |
| `project` | yes | `—` | ASP.NET Core project path, targeting net10.0. |
| `test_project` | yes | `—` | Test project or solution path; tests are mandatory. |
| `spa_directory` | yes | `—` | React directory with package-lock.json and build/test:ci scripts. |
| `spa_output` | no | `dist` | Build output directory relative to spa_directory. |

Outputs: `artifact_name`: Immutable artifact name for this run.

## reusable-iis-blue-green.yml

| Input | Required | Default | Purpose |
|---|---|---|---|
| `toolkit_ref` | yes | `—` | Full reviewed 40-character commit SHA of this toolkit; use the same SHA as the workflow reference. |
| `artifact_name` | yes | `—` | Artifact from reusable-hybrid-build in the same workflow run. |
| `environment` | yes | `—` | Pre-created protected GitHub environment; configure required reviewers and branch restrictions. |
| `runner_labels` | no | `["self-hosted", "Windows", "iis-deploy"]` | JSON runner labels for an isolated internal Windows runner. |
| `inventory` | yes | `—` | Path to reviewed JSON inventory in caller repository. |
| `adapter` | yes | `—` | Path to reviewed load-balancer/server adapter PowerShell script in caller repository. |

## reusable-kubernetes-helm-validate.yml

| Input | Required | Default | Purpose |
|---|---|---|---|
| `chart` | no | `charts/service` | Helm chart directory. |
| `values_file` | no | `charts/service/values.yaml` | Environment values file. |
| `helm_version` | no | `v3.17.3` | Reviewed exact Helm version. |
