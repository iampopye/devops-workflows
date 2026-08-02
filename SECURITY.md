# Security Policy

This repository ships CI/CD workflows that other people run inside their own
pipelines, often with production credentials in scope. A vulnerability here can
become a vulnerability in every repo that consumes these workflows. Reports are
taken seriously.

## Reporting a vulnerability

**Do not open a public issue for a security problem.**

Use GitHub's private vulnerability reporting:

1. Go to the [Security tab](https://github.com/iampopye/devops-workflows/security)
2. Click **Report a vulnerability**
3. Describe the issue, the impact, and how to reproduce it

This creates a private advisory that only you and the maintainer can see. You
will get an acknowledgement within 7 days.

If private reporting is unavailable for any reason, open a public issue titled
only `Security contact request` with no technical detail, and you will be given
a private channel.

## What counts as a vulnerability here

Things worth reporting:

- **Secret exposure** — a workflow that could leak `GITHUB_TOKEN`, a cloud
  credential, a registry password, or an API key into logs, artifacts, PR
  comments, or an outbound request
- **Injection** — untrusted input (a PR title, branch name, commit message, or
  diff body) reaching a shell command, a `github-script` block, or a step output
  in a way that lets an attacker execute code or forge data
- **Privilege escalation** — a workflow requesting or exercising more permission
  than it needs, or a path where a fork PR gains write access
- **Supply chain** — an unpinned or mutable action reference, or a dependency
  that could be substituted
- **Silent failure of a security control** — a scan or gate that reports success
  without actually running. A check that cannot fail is worse than no check,
  because it produces false confidence

Not vulnerabilities, but still worth an issue:

- A workflow failing on a valid input
- Missing documentation
- An outdated action version with no security impact

## Scope

In scope: everything under `.github/workflows/` and `examples/`.

Out of scope: vulnerabilities in the third-party actions themselves
(`aquasecurity/trivy-action`, `gitleaks/gitleaks-action`, etc.). Report those to
their maintainers. Do tell us if this repo pins a version known to be
vulnerable, so the pin can be moved.

## Supported versions

| Version | Supported |
| --- | --- |
| `main` | Yes |
| Latest `v1.x` tag | Yes |
| Anything older | No — please upgrade |

## Disclosure

Once a fix is available, an advisory is published crediting the reporter unless
they prefer otherwise. Please allow a reasonable window to ship the fix before
disclosing publicly — 90 days is the usual expectation, sooner for something
actively exploitable.

## A note on the design

Several deliberate choices here are security controls, not style preferences.
If you are reviewing this repo, these are the ones that matter:

- **Third-party actions are pinned to a full commit SHA.** A tag is mutable;
  whoever controls the action can repoint `@v1` at new code that then runs with
  your secrets. CI enforces this on every PR.
- **Every workflow starts `permissions: {}`** and grants the minimum per job,
  rather than inheriting broad repo-wide write access.
- **Scan steps never abort the job early.** A finding in one scanner must not
  skip the scanners after it. Gates are separate, explicit final steps.
- **Fork PRs require approval before workflows run**, so an outside PR cannot
  execute code against this repo's secrets.
