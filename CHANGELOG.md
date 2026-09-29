# Changelog

## Unreleased — platform workflow additions

- Add seven top-level reusable workflows for hybrid app delivery, Azure Terraform, secure containers, Helm validation and Ansible.
- Add Azure DevOps templates, reference modules/chart, release failure-path tests and portfolio/runbook documentation.
- Preserve the existing workflow collection; document its legacy subdirectory limitation.

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Because these are reusable workflows consumed via `@v1`, **a major version bump
means a breaking change to an input, secret, or output name** — something that
would make a consuming repo's pipeline fail until it is updated.

## [Unreleased]

## [1.0.0]

First tagged release. The workflows were rewritten from an earlier draft state;
if you were referencing `@main` before, this is the version to pin to.

### Added

- `ci.yml` — the repo now lints its own workflows with `actionlint` on every PR,
  and enforces that all third-party actions are SHA-pinned
- `dependabot.yml` — weekly grouped action updates
- `examples/` — six copy-paste starter workflows, including a full
  `consume-reusable-workflows.yml` showing how the pieces fit together
- Docker workflow: multi-arch builds, semantic tagging via `metadata-action`,
  SBOM and provenance attestation, and an optional Trivy image scan
- Kubernetes workflow: rollout wait, connectivity verification, and credential
  cleanup on job exit
- Security workflow: `run_codeql` and `fail_on_findings` toggles
- Compliance workflow: `fail_on_findings` toggle and a structured job summary
- `SECURITY.md`, `CODE_OF_CONDUCT.md`, issue templates, and a PR template

### Changed

- **All third-party actions are now pinned to a full commit SHA** rather than a
  mutable tag. A tag can be repointed by whoever controls the action repo, and
  the new code then runs inside your pipeline with your secrets
- Every workflow now starts from `permissions: {}` and grants the minimum per
  job, instead of a broad workflow-level grant
- AI workflows are now **vendor-neutral**. `model` is a required input with no
  default, so no provider is implied. Presets exist for `anthropic`, `openai`,
  `groq`, `openrouter`, `together`, `mistral` and `deepseek`, plus
  `openai_compatible` + `api_url` for self-hosted endpoints
- Action versions updated across the board — several were three majors behind

### Fixed

- **Terraform PR comment could only ever report success.** The plan step had no
  `continue-on-error`, so a failing plan aborted the job before the comment step
  ran. The comment now posts the real outcome and the full plan output
- **A dependency finding silently skipped secret scanning.** Trivy ran with
  `exit-code: 1`, which failed the job before the Gitleaks step, so one CVE
  could hide a leaked credential. Scans now always run; gating is a separate
  final step
- **PR content could forge step outputs.** The AI review wrote the diff into
  `$GITHUB_OUTPUT` using an `EOF` heredoc delimiter, so a diff containing a line
  that is literally `EOF` could inject arbitrary outputs. The diff is now passed
  via a file, which also removes the 1 MB output cap
- **Kubernetes rollout wait could silently do nothing.** The jsonpath assumed a
  `.items` list; a single-resource manifest returns a bare object, so the loop
  never ran and the job reported success without waiting
- **Docker image scan referenced an image that did not exist** for multi-arch
  builds with `push: false`, which are never loaded into the local daemon. The
  scan is now skipped with an explicit warning
- Compliance workflow no longer aborts before uploading SARIF or running OPA

### Security

- Fork pull requests now require approval before workflows run
- Secret scanning and push protection enabled on the repository
- `main` protected against force-push and deletion

[Unreleased]: https://github.com/iampopye/devops-workflows/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/iampopye/devops-workflows/releases/tag/v1.0.0
