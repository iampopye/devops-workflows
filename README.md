# my-Workflows: Reusable GitHub Actions for DevSecOps

This repository has been modernized from legacy `.txt` workflow drafts into reusable GitHub Actions workflows using `workflow_call`.

## What is included

Reusable workflows are grouped by domain:

```text
.github/workflows/
  terraform/
    reusable-terraform-infra.yml
  docker/
    reusable-docker-build.yml
  kubernetes/
    reusable-kubernetes-deploy.yml
  security/
    reusable-security-scanning.yml
  ai/
    reusable-ai-pr-review.yml
    reusable-ai-incident-analysis.yml
  observability/
    reusable-compliance-validation.yml
```

## Security and modernization highlights

- Uses current major versions of core actions (`checkout@v4`, `setup-*` latest stable, `build-push-action@v6`, `codeql-action@v3`).
- All reusable workflows are triggerable via `workflow_call`.
- Least-privilege permissions are defined at workflow/job scope.
- Security coverage includes SAST (CodeQL), dependency/IaC scanning (Trivy), secrets scanning (Gitleaks), and optional DAST (ZAP).
- Compliance baseline workflow supports HIPAA/GDPR-aligned controls through policy validation + security scanning.
- AI workflows support PR review automation and incident analysis.

## Reusable workflow catalog

### 1) Security scanning
- File: `.github/workflows/security/reusable-security-scanning.yml`
- Features:
  - CodeQL scan
  - Trivy file-system vulnerability scan + SARIF upload
  - Gitleaks secret scanning
  - Optional OWASP ZAP baseline DAST scan

### 2) Terraform infrastructure automation
- File: `.github/workflows/terraform/reusable-terraform-infra.yml`
- Features:
  - `fmt`, `init`, `validate`, `plan`
  - Optional `apply`
  - PR comment with plan status

### 3) Docker build and push
- File: `.github/workflows/docker/reusable-docker-build.yml`
- Features:
  - Buildx cache-enabled builds
  - Optional registry login and push

### 4) Kubernetes deployment
- File: `.github/workflows/kubernetes/reusable-kubernetes-deploy.yml`
- Features:
  - Kubeconfig from secret (base64)
  - Server-side dry-run validation
  - Optional deployment

### 5) AI-assisted PR review
- File: `.github/workflows/ai/reusable-ai-pr-review.yml`
- Features:
  - Extracts PR diff
  - Uses OpenAI API to generate review feedback
  - Posts bot review comment to PR

### 6) AI incident analysis
- File: `.github/workflows/ai/reusable-ai-incident-analysis.yml`
- Features:
  - Summarizes recent failed workflow runs
  - Uses OpenAI API to generate incident analysis
  - Opens a GitHub issue with findings/remediation

### 7) Compliance validation (HIPAA/GDPR aligned)
- File: `.github/workflows/observability/reusable-compliance-validation.yml`
- Features:
  - Trivy config/IaC scan + SARIF upload
  - OPA policy testing support
  - Compliance coverage summary in workflow output

## Usage examples

Create a calling workflow in another repository (or this repository) such as:

```yaml
name: Platform CI/CD

on:
  pull_request:
  push:
    branches: [main]

jobs:
  security:
    uses: your-org/my-Workflows/.github/workflows/security/reusable-security-scanning.yml@main
    with:
      language: go
      zap_target_url: ""

  terraform-plan:
    uses: your-org/my-Workflows/.github/workflows/terraform/reusable-terraform-infra.yml@main
    with:
      working_directory: terraform
      apply: false

  docker-build:
    uses: your-org/my-Workflows/.github/workflows/docker/reusable-docker-build.yml@main
    with:
      image_name: ghcr.io/your-org/your-app
      push: false

  compliance:
    uses: your-org/my-Workflows/.github/workflows/observability/reusable-compliance-validation.yml@main
```

### AI usage example

```yaml
name: AI PR Review
on:
  pull_request:

jobs:
  ai-review:
    uses: your-org/my-Workflows/.github/workflows/ai/reusable-ai-pr-review.yml@main
    secrets:
      openai_api_key: ${{ secrets.OPENAI_API_KEY }}
```

## Required secrets (by workflow)

- Security: optional `github_token`
- Terraform: optional `tf_api_token`
- Docker: optional `registry`, `registry_username`, `registry_password`
- Kubernetes: required `kubeconfig` (base64-encoded)
- AI: required `openai_api_key`

## Migration note

The legacy `.txt` workflow files are still present as historical references. The reusable YAML workflows above are the new canonical implementation.
