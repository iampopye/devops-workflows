# devops-workflows

> A free, production-grade collection of reusable GitHub Actions workflows for security scanning, Terraform, Docker, and Kubernetes — written so a new DevOps engineer can read them, understand them, and copy them into real projects.

[![CI](https://github.com/iampopye/devops-workflows/actions/workflows/ci.yml/badge.svg)](https://github.com/iampopye/devops-workflows/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

Most CI/CD tutorials show you a toy pipeline. Most real pipelines are copied from a coworker who copied them from Stack Overflow. This repo sits in between: complete, working workflows you can call from your own repository today, with comments that explain *why* each decision was made — not just what the YAML does.

Every workflow here is a **reusable workflow**. You do not fork this repo or paste 150 lines into your project. You write six lines that say "run that one", and you get the whole pipeline.

---

## Quick start

Create `.github/workflows/ci.yml` in **your** repository and paste this in:

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]

permissions: {}

jobs:
  security:
    uses: iampopye/devops-workflows/.github/workflows/security/reusable-security-scanning.yml@v1
    permissions:
      contents: read
      security-events: write
      actions: read
    with:
      language: go          # or python, javascript-typescript, java-kotlin, ...
```

Push it. On the next pull request you get static analysis (CodeQL), a dependency and filesystem vulnerability scan (Trivy), and a secret scan across your whole git history (Gitleaks) — with the results in your repository's **Security** tab.

That is the entire setup. Add more jobs from the [catalog](#workflow-catalog) as you need them.

> **Note on `permissions:`** — a reusable workflow can only *narrow* the permissions it is given, never widen them. If the calling job does not grant `security-events: write`, the scan results cannot be uploaded. Each workflow section below lists exactly what the caller must grant.

---

## Workflow catalog

| Workflow | What it does | Reference |
|---|---|---|
| **Security scanning** | CodeQL SAST, Trivy filesystem scan, Gitleaks secret detection, optional OWASP ZAP DAST | [details](#security-scanning) · [source](.github/workflows/security/reusable-security-scanning.yml) |
| **Terraform infrastructure** | `fmt` → `init` → `validate` → `plan`, optional gated `apply`, full plan posted as a PR comment | [details](#terraform-infrastructure) · [source](.github/workflows/terraform/reusable-terraform-infra.yml) |
| **Docker build and push** | Buildx, multi-architecture builds, semantic tagging, SBOM + provenance attestations, Trivy image scan | [details](#docker-build-and-push) · [source](.github/workflows/docker/reusable-docker-build.yml) |
| **Kubernetes deploy** | Server-side dry-run validation, apply, rollout wait, credential cleanup | [details](#kubernetes-deploy) · [source](.github/workflows/kubernetes/reusable-kubernetes-deploy.yml) |
| **Compliance validation** | Trivy IaC misconfiguration scan + OPA policy-as-code tests, evidence summary | [details](#compliance-validation) · [source](.github/workflows/observability/reusable-compliance-validation.yml) |
| **AI PR review** *(optional)* | Posts an advisory AI-generated review comment on a pull request | [details](#ai-pr-review-optional) · [source](.github/workflows/ai/reusable-ai-pr-review.yml) |
| **AI incident analysis** *(optional)* | Summarises recent failed workflow runs and opens an issue with the analysis | [details](#ai-incident-analysis-optional) · [source](.github/workflows/ai/reusable-ai-incident-analysis.yml) |

Ready-to-copy calling workflows live in [`examples/`](examples/).

---

## Why these are different

There are thousands of GitHub Actions snippets on the internet. Here is what this collection does that most of them do not.

### 1. Every third-party action is pinned to a commit SHA

Look at any action reference in this repo and you will see something like:

```yaml
uses: aquasecurity/trivy-action@ed142fd0673e97e23eac54620cfb913e5ce36c25 # v0.36.0
```

instead of the more common `uses: aquasecurity/trivy-action@v0.36.0`.

**Why this matters, plainly:** a Git tag like `v1` is just a label pointing at a commit, and the person who owns the action repository can move that label whenever they want. If they move `v1` to point at malicious code — or if someone steals their account and does it for them — then the next time your pipeline runs, that new code executes **inside your job, with access to your secrets**. Your registry password. Your cloud credentials. Your `GITHUB_TOKEN`. You never approved the change, and nothing in your repository changed.

A 40-character commit SHA cannot be moved. It identifies exactly one commit, forever. Pinning to a SHA means the code that runs today is the code you reviewed, until you deliberately update it.

This is what people mean by **supply chain security**: you are not just trusting your own code, you are trusting everything your build pulls in. The trailing `# v0.36.0` comment keeps it human-readable, and [Dependabot](.github/dependabot.yml) updates the SHA and the comment together every week — so **SHA pinning does not mean going stale**.

Actions under `actions/*` and `github/*` are first-party GitHub and use major-version tags, which is [GitHub's own documented guidance](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions).

### 2. Least privilege by default

Every workflow starts with:

```yaml
permissions: {}
```

That means "this workflow's token can do nothing", and then each job gets back only what it actually needs. Compare that with the common alternative — no `permissions:` block at all — where the job silently inherits whatever the repository default is, often read *and write* on everything. If a workflow-level grant is used instead, every job in the file gets the union of all permissions, including the jobs that only needed `contents: read`.

The point is not paranoia. The point is that when something does go wrong, the damage is bounded by what you granted.

### 3. The repo lints its own workflows

A collection of "best practice" workflows that is never itself validated is just a collection of untested YAML. Every pull request here runs [`ci.yml`](.github/workflows/ci.yml), which:

- runs **actionlint** (plus shellcheck on every `run:` block) over all workflows and examples, and
- runs a **custom pin checker** that fails the build if any third-party action is not SHA-pinned.

The rules in this README are enforced by machine, not by good intentions.

### 4. The AI workflows are optional and vendor-neutral

Two workflows use a language model. **Nothing else in this repo depends on them** — delete the `ai/` folder and everything else still works.

They are also not tied to a vendor. The `model` input is **required and has no default**, so no provider is implied by using this repo. Built-in presets cover `anthropic`, `openai`, `groq`, `openrouter`, `together`, `mistral`, and `deepseek`; `openai_compatible` plus an `api_url` covers anything OpenAI-shaped, including a model running entirely on your own hardware via Ollama, vLLM, llama.cpp, LM Studio, or Azure OpenAI.

Both workflows are explicitly advisory. Neither one gates a merge, and neither replaces a human reviewer.

### 5. Real bugs were found and fixed

These workflows were rewritten from earlier drafts. Three things that were genuinely broken and are worth understanding, because the same mistakes are everywhere:

- **The Terraform PR comment could only ever say "success".** The `plan` step had no `continue-on-error`, so a failed plan aborted the job before the comment step ran. The only comments anyone ever saw were green ones. Fixed by letting the plan step complete, capturing its real exit code, reporting the outcome, and failing in a separate step afterwards.
- **One Trivy finding used to skip the secret scan entirely.** Trivy ran with a non-zero `exit-code`, so a single dependency CVE failed the step — and every step after it, including the SARIF upload and Gitleaks. A routine outdated library could silently hide a leaked credential. Fixed by scanning with `exit-code: 0` and putting the pass/fail decision in a dedicated gate step at the end.
- **The AI PR review could have its step outputs forged by PR content.** The diff was written into `$GITHUB_OUTPUT` using an `EOF` heredoc delimiter. Any pull request containing a line that is literally `EOF` ends the block early, and everything after it is parsed as new step outputs — attacker-controlled data becoming workflow variables. (Step outputs also cap at 1 MB.) Fixed by writing the diff to a plain file instead.

---

## Learning path for new DevOps engineers

If you are new to CI/CD and want to actually understand this rather than paste it, do them in this order. Each one builds on the last.

**1. Start with security scanning.** It needs no cloud account, no registry, and no cluster — just your source code. Add it to a repo you already have and watch the Security tab fill up. Read [`reusable-security-scanning.yml`](.github/workflows/security/reusable-security-scanning.yml) top to bottom; it is the best introduction to how jobs, permissions, and SARIF uploads fit together. This is the "Sec" in **DevSecOps**: security checks that run automatically on every change instead of once a year in an audit.

**2. Then Docker.** Build an image from your own Dockerfile with `push: false` and no secrets at all. Once that is green, turn on `push: true` to GitHub Container Registry. Along the way you will meet image tagging strategy, multi-architecture builds, and SBOM/provenance attestations — the metadata that says what is inside your image and how it was built.

**3. Then Terraform.** Run it with `apply: false` against a real (small) piece of infrastructure and read the plan comment on your pull request. `plan` is read-only and safe. Only after you are comfortable reading plans should you set `apply: true`, and only behind a GitHub environment with protection rules.

**4. Then Kubernetes.** Start with `dry_run: true`, which validates your manifests against the real API server without changing anything. When that passes consistently, set `dry_run: false` on a non-production namespace. Pay attention to the rollout wait — it is the difference between "the API server accepted my YAML" and "my application is actually running".

**5. Finally, compliance validation and the optional AI workflows.** By now you will understand what the IaC misconfiguration scan is complaining about and why an OPA policy is worth writing.

Read the comments in the workflow files as you go. They explain the reasoning, which is the part that transfers to your next job.

---

## Workflow reference

All examples below reference `@v1`. Pinning your caller to a release tag rather than `@main` means an upstream change here cannot alter your pipeline until you choose it.

### Security scanning

`.github/workflows/security/reusable-security-scanning.yml`

Three jobs: **CodeQL SAST**, **Trivy filesystem scan + Gitleaks secret scan**, and an optional **OWASP ZAP baseline DAST** scan that only runs when you supply a target URL.

**Inputs**

| Name | Type | Default | Description |
|---|---|---|---|
| `language` | string | `go` | Primary language for CodeQL. One of: `go`, `javascript-typescript`, `python`, `java-kotlin`, `ruby`, `csharp`, `c-cpp`, `swift`, `rust`, `actions`. |
| `run_codeql` | boolean | `true` | Run the CodeQL SAST job. Set `false` for languages CodeQL does not support. |
| `trivy_severity` | string | `CRITICAL,HIGH` | Comma-separated severities to report on. |
| `fail_on_findings` | boolean | `true` | Fail the job when Trivy finds issues at or above `trivy_severity`. |
| `zap_target_url` | string | `""` | Target URL for a baseline DAST scan. Leave empty to skip the DAST job entirely. |

**Secrets**

| Name | Required | Description |
|---|---|---|
| `github_token` | no | Token passed to Gitleaks. Falls back to the job's built-in `github.token` if omitted. |

**Permissions the caller must grant**

`contents: read`, `security-events: write`, `actions: read` — plus `issues: write` only if you use the ZAP DAST job.

**Usage**

```yaml
jobs:
  security:
    uses: iampopye/devops-workflows/.github/workflows/security/reusable-security-scanning.yml@v1
    permissions:
      contents: read
      security-events: write
      actions: read
      issues: write        # only needed for the ZAP job
    with:
      language: python
      trivy_severity: CRITICAL,HIGH
      fail_on_findings: true
      zap_target_url: https://staging.example.com
```

Notes:

- The checkout uses `fetch-depth: 0` because Gitleaks scans commit *history*. A secret that was committed and then deleted is still in your history, and still leaked.
- Trivy scans with `exit-code: 0` on purpose, so a finding cannot skip the SARIF upload or the secret scan. The pass/fail decision happens in a dedicated gate step at the end.
- ZAP baseline mode is passive — it spiders the target and reports what it sees without attacking. **Only point it at systems you are authorised to test.**

### Terraform infrastructure

`.github/workflows/terraform/reusable-terraform-infra.yml`

Runs `fmt -check` → `init` → `validate` → `plan`, posts the full plan as a collapsible pull request comment, and optionally applies the saved plan file.

**Inputs**

| Name | Type | Default | Description |
|---|---|---|---|
| `working_directory` | string | `terraform` | Directory containing your Terraform files. |
| `terraform_version` | string | `1.14.3` | Terraform version to install. |
| `apply` | boolean | `false` | Apply the plan after it succeeds. |
| `environment` | string | `nonprod` | GitHub environment name. Use its protection rules to gate `apply`. |

**Secrets**

| Name | Required | Description |
|---|---|---|
| `tf_api_token` | no | Terraform Cloud / Enterprise API token, written to the CLI credentials config. |

**Permissions the caller must grant**

`contents: read`, `id-token: write` (for OIDC federation to AWS/GCP/Azure), `pull-requests: write` (to post the plan comment).

**Usage**

```yaml
jobs:
  terraform-plan:
    uses: iampopye/devops-workflows/.github/workflows/terraform/reusable-terraform-infra.yml@v1
    permissions:
      contents: read
      id-token: write
      pull-requests: write
    with:
      working_directory: infra/prod
      terraform_version: 1.14.3
      environment: production
      apply: ${{ github.ref == 'refs/heads/main' }}
```

Notes:

- `apply` runs `terraform apply` against the **saved plan file** produced earlier in the same job, not a fresh plan. What you reviewed is what gets applied.
- Gate real applies with a [GitHub environment](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments) that has required reviewers. The workflow gives you the hook; you configure the rule.
- Prefer OIDC federation over long-lived cloud keys stored as repository secrets. That is why `id-token: write` is in the permission set.
- The plan comment is truncated to 60,000 characters (GitHub caps comment bodies at 65,536). The **tail** is kept, because that is where the resource summary and any error message live.

### Docker build and push

`.github/workflows/docker/reusable-docker-build.yml`

Buildx build with GitHub Actions layer caching, semantic tag derivation, SBOM and provenance attestations, and an optional Trivy image scan.

**Inputs**

| Name | Type | Default | Description |
|---|---|---|---|
| `image_name` | string | **required** | Full image name without a tag, e.g. `ghcr.io/owner/app`. |
| `context` | string | `.` | Build context path. |
| `dockerfile` | string | `./Dockerfile` | Path to the Dockerfile. |
| `platforms` | string | `linux/amd64` | Comma-separated target platforms, e.g. `linux/amd64,linux/arm64`. |
| `push` | boolean | `false` | Push to the registry after a successful build. |
| `scan_image` | boolean | `true` | Run a Trivy vulnerability scan on the built image. |
| `scan_severity` | string | `CRITICAL,HIGH` | Severities that fail the image scan. |

**Secrets**

| Name | Required | Description |
|---|---|---|
| `registry` | no | Registry host. Defaults to `ghcr.io`. |
| `registry_username` | no | Defaults to `github.actor`. |
| `registry_password` | no | Defaults to the job's `github.token`, which is enough for GHCR. |

**Outputs**

| Name | Description |
|---|---|
| `digest` | The immutable digest of the built image. |
| `tags` | Newline-separated list of tags applied to the image. |

**Permissions the caller must grant**

`contents: read`, `packages: write`, `id-token: write` (required to sign the provenance attestation).

**Usage**

```yaml
jobs:
  docker-build:
    uses: iampopye/devops-workflows/.github/workflows/docker/reusable-docker-build.yml@v1
    permissions:
      contents: read
      packages: write
      id-token: write
    with:
      image_name: ghcr.io/${{ github.repository }}
      platforms: linux/amd64,linux/arm64
      push: ${{ github.ref == 'refs/heads/main' }}
```

Notes:

- Tags are derived automatically: branch name, PR ref, semver from git tags, long commit SHA, and `latest` **only on the default branch**. Tagging every feature branch as `latest` is how a half-finished build ends up in production.
- `sbom: true` and `provenance: mode=max` attach supply-chain metadata to the image: what is inside it, and how it was built.
- When `push: false` and a single platform is targeted, the image is loaded into the local Docker daemon so the scan has something to read. Multi-platform builds cannot be loaded locally — if you want the image scanned on a multi-arch build, either push it or set `scan_image: false`.

### Kubernetes deploy

`.github/workflows/kubernetes/reusable-kubernetes-deploy.yml`

Validates manifests against the live API server, optionally applies them, waits for the rollout to actually become ready, and always deletes the kubeconfig afterwards.

**Inputs**

| Name | Type | Default | Description |
|---|---|---|---|
| `namespace` | string | `default` | Target namespace. |
| `manifests_path` | string | `k8s/` | Path to manifests (file or directory). |
| `kubectl_version` | string | `v1.34.1` | kubectl version to install. |
| `dry_run` | boolean | `true` | Validate only. Set `false` to actually apply. |
| `environment` | string | `""` | GitHub environment name. Use its protection rules to gate deploys. |
| `rollout_timeout` | string | `5m` | How long to wait for workloads to become ready. |

**Secrets**

| Name | Required | Description |
|---|---|---|
| `kubeconfig` | **yes** | Base64-encoded kubeconfig. Produce it with `base64 -w0 < ~/.kube/config`. |

**Permissions the caller must grant**

`contents: read`.

**Usage**

```yaml
jobs:
  deploy:
    needs: [docker-build, security]
    if: github.ref == 'refs/heads/main'
    uses: iampopye/devops-workflows/.github/workflows/kubernetes/reusable-kubernetes-deploy.yml@v1
    permissions:
      contents: read
    with:
      namespace: production
      manifests_path: k8s/
      environment: production
      dry_run: false
      rollout_timeout: 10m
    secrets:
      kubeconfig: ${{ secrets.KUBECONFIG_B64 }}
```

Notes:

- Validation uses `--dry-run=server`, which sends the manifests to the real API server for admission and schema checking. That catches things a client-side check never will.
- The rollout wait exists because `kubectl apply` returning `0` only means the API server *accepted* the object. Without waiting, a pod stuck in `CrashLoopBackOff` still reports a green pipeline.
- The kubeconfig is written with `umask 077` so it is never briefly world-readable, and removed in an `if: always()` step so it does not survive a failed run.
- **Prefer OIDC federation to your cluster over a base64 kubeconfig secret.** A kubeconfig is long-lived, hard to rotate, and usually over-privileged. This workflow supports it because many clusters still need it — treat it as the fallback, not the goal.

### Compliance validation

`.github/workflows/observability/reusable-compliance-validation.yml`

Trivy IaC misconfiguration scanning plus Open Policy Agent policy-as-code tests, with a summary table written to the job summary.

**Inputs**

| Name | Type | Default | Description |
|---|---|---|---|
| `policy_path` | string | `policy/` | Directory containing OPA Rego policies. Skipped with a warning if the directory is missing or contains no `.rego` files. |
| `trivy_severity` | string | `CRITICAL,HIGH` | Severities to report on. |
| `fail_on_findings` | boolean | `true` | Fail the job when misconfigurations are found. |

**Secrets**: none.

**Permissions the caller must grant**

`contents: read`, `security-events: write`.

**Usage**

```yaml
jobs:
  compliance:
    uses: iampopye/devops-workflows/.github/workflows/observability/reusable-compliance-validation.yml@v1
    permissions:
      contents: read
      security-events: write
    with:
      policy_path: policy/
      fail_on_findings: true
```

> **Be honest about what this is.** This workflow produces *evidence*, not a compliance certificate. Passing it does not make a system HIPAA or GDPR compliant. It checks a technical baseline that supports some of the controls those frameworks require. Mapping controls to your actual architecture is work only your organisation can do.

### AI PR review (optional)

`.github/workflows/ai/reusable-ai-pr-review.yml`

Sends the pull request diff to a model of your choice and posts the response as a PR comment. Only runs on `pull_request` events. Advisory only — it does not gate the merge, and a failing model endpoint produces a warning rather than a failed check.

**Inputs**

| Name | Type | Default | Description |
|---|---|---|---|
| `provider` | string | **required** | One of `anthropic`, `openai`, `groq`, `openrouter`, `together`, `mistral`, `deepseek`, `openai_compatible`. |
| `model` | string | **required** | Model identifier. No default, so no vendor is assumed. |
| `api_url` | string | `""` | Full chat/completions endpoint. Required for `openai_compatible`; overrides the built-in URL for any other provider. |
| `system_prompt` | string | a DevSecOps reviewer persona | System prompt for the reviewer persona. |
| `max_diff_bytes` | number | `60000` | Truncate the diff to this many bytes before sending. |
| `max_tokens` | number | `2000` | Maximum tokens in the model response. |

**Secrets**

| Name | Required | Description |
|---|---|---|
| `ai_api_key` | no | API key for the chosen provider. Omit for a local endpoint that needs no auth. |

**Permissions the caller must grant**

`contents: read`, `pull-requests: write`.

**Usage**

```yaml
jobs:
  review:
    uses: iampopye/devops-workflows/.github/workflows/ai/reusable-ai-pr-review.yml@v1
    permissions:
      contents: read
      pull-requests: write
    with:
      provider: groq
      model: llama-3.3-70b-versatile   # check your provider's current model list
    secrets:
      ai_api_key: ${{ secrets.GROQ_API_KEY }}
```

Fully self-hosted, no third party involved (needs a runner that can reach your endpoint):

```yaml
    with:
      provider: openai_compatible
      api_url: http://ollama.internal:11434/v1/chat/completions
      model: qwen2.5-coder:32b
```

See [`examples/ai-pr-review.yml`](examples/ai-pr-review.yml) for one block per provider, ready to uncomment.

### AI incident analysis (optional)

`.github/workflows/ai/reusable-ai-incident-analysis.yml`

Collects your repository's recent failed workflow runs, asks a model for probable root cause, blast radius, mitigations, and prevention steps, then opens a GitHub issue with the result. Typically run on a schedule or via `workflow_dispatch`, not on every push.

**Inputs**

| Name | Type | Default | Description |
|---|---|---|---|
| `provider` | string | **required** | Same provider list as the PR review workflow. |
| `model` | string | **required** | Model identifier. No default. |
| `api_url` | string | `""` | Full endpoint URL. Required for `openai_compatible`. |
| `incident_context` | string | `""` | Extra context to give the model (recent deploys, known issues). |
| `lookback_runs` | number | `10` | How many recent failed runs to analyse. |
| `max_tokens` | number | `2000` | Maximum tokens in the model response. |
| `dry_run` | boolean | `false` | Write the analysis to the job summary instead of opening an issue. |

**Secrets**

| Name | Required | Description |
|---|---|---|
| `ai_api_key` | no | API key for the chosen provider. |

**Permissions the caller must grant**

`actions: read`, `contents: read`, `issues: write`.

**Usage**

```yaml
name: Nightly incident analysis

on:
  schedule:
    - cron: "0 6 * * *"
  workflow_dispatch:

permissions: {}

jobs:
  analyse:
    uses: iampopye/devops-workflows/.github/workflows/ai/reusable-ai-incident-analysis.yml@v1
    permissions:
      actions: read
      contents: read
      issues: write
    with:
      provider: anthropic
      model: claude-opus-5        # check your provider's current model list
      lookback_runs: 20
      dry_run: true          # start here; flip to false once you trust the output
    secrets:
      ai_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
```

Start with `dry_run: true`. It writes to the job summary instead of filing issues, so you can judge the output quality before it starts creating tickets.

---

## Requirements and assumptions

- **GitHub-hosted `ubuntu-latest` runners.** Every workflow assumes Linux. `jq`, `curl`, `git`, and `shellcheck` are preinstalled there.
- **A public repository, or GitHub Advanced Security.** CodeQL analysis and SARIF uploads to the Security tab are free on public repositories; on private repositories they require GitHub Advanced Security.
- **Reusable workflow permission model.** The calling job must grant the permissions listed for each workflow. A called workflow can narrow them but never widen them.
- **Pin to a release tag.** Reference these workflows as `@v1`, not `@main`, so an upstream change cannot alter your pipeline without you choosing it. This is the same reasoning as SHA pinning, one level up.
- **Cloud credentials.** The Terraform workflow requests `id-token: write` so you can use OIDC federation. Configuring the trust relationship in AWS/GCP/Azure is on your side.
- **Gitleaks licensing.** `gitleaks/gitleaks-action` is free for personal accounts and public repositories; organisations may need a `GITLEAKS_LICENSE`. Check the action's own README before rolling it out org-wide.
- **Third-party service accounts** are only needed for what you actually enable: Terraform Cloud (`tf_api_token`), a container registry (defaults to GHCR with the built-in token), a Kubernetes cluster, or an AI provider.

## Examples

The [`examples/`](examples/) directory contains complete calling workflows you can copy straight into `.github/workflows/` in your own repository — including standalone pipelines for Go tests with SonarQube, Cucumber/Godog BDD tests, k6 load testing, and OWASP ZAP scanning. See [`examples/README.md`](examples/README.md).

## Contributing

Contributions and questions are both welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) for the house rules — SHA-pinned actions, `permissions: {}` by default, actionlint must pass, every input documented.

If you are new to DevOps and something here does not make sense, **that is a documentation bug, and reporting it helps**. Open an issue or a discussion.

## License

MIT — see [LICENSE](LICENSE). Copy these workflows, modify them, use them at work. Attribution appreciated, not required.
