# Contributing

Thanks for wanting to help. This repo exists so that people learning DevOps can read real, working GitHub Actions workflows — so contributions that make a workflow **clearer** are as valuable as contributions that make it more capable.

Two things before anything else:

- **Beginner questions are welcome.** If a workflow does not make sense to you, that is useful signal. Open a [Discussion](https://github.com/iampopye/devops-workflows/discussions) or an [Issue](https://github.com/iampopye/devops-workflows/issues) and ask. "I don't understand why this step exists" is a legitimate documentation bug report, not a bother.
- **You do not need to be an expert to contribute.** Fixing a confusing comment, correcting an input table, or reporting that a workflow failed on your repo all count.

---

## How to propose a new workflow

Open an issue first, before writing YAML. It saves you from building something that gets declined for scope reasons. In the issue, cover:

1. **The problem.** What does someone have to do by hand today, or copy-paste into every repo?
2. **Who it is for.** Which stack, which stage of the pipeline.
3. **Why it belongs here.** This repo is a curated set of production-grade, generally applicable pipelines — not a directory of every possible integration. A workflow tied to one company's internal tooling is better off in that company's repo.
4. **What it would take as inputs**, roughly.

If it fits, the next step is a pull request with the workflow, its documentation, and an example.

Bug reports and documentation fixes do not need an issue first. Just open the PR.

---

## House rules

These are not style preferences. Each one is enforced by CI or exists because it prevents a specific failure.

### 1. SHA-pin every third-party action

```yaml
# Yes
uses: aquasecurity/trivy-action@ed142fd0673e97e23eac54620cfb913e5ce36c25 # v0.36.0

# No
uses: aquasecurity/trivy-action@v0.36.0
uses: aquasecurity/trivy-action@master
```

A Git tag is mutable. Whoever controls the action repository can repoint `v0.36.0` at different code, and your pipeline will run it — with your secrets in scope — on the next push. A 40-character commit SHA cannot be repointed.

Always include the trailing `# vX.Y.Z` comment. It keeps the file readable, and Dependabot updates the SHA and the comment together.

**Exception:** actions under `actions/*` and `github/*` are first-party GitHub and may use major-version tags (`@v7`, `@v3`). This matches GitHub's own documented guidance.

To find the SHA for a version:

```bash
git ls-remote https://github.com/aquasecurity/trivy-action refs/tags/v0.36.0
```

If the tag is annotated, dereference it with `refs/tags/v0.36.0^{}` and use that SHA.

### 2. Start with `permissions: {}`

Every workflow file begins with a workflow-level `permissions: {}` — deny everything — and then each job declares only what it needs:

```yaml
permissions: {}

jobs:
  scan:
    permissions:
      contents: read
      security-events: write
```

Granting at the workflow level hands every job the union of all permissions, including the jobs that only needed to read code. Grant per job.

### 3. It must pass actionlint

CI runs [actionlint](https://github.com/rhysd/actionlint) over `.github/workflows/*.yml`, `.github/workflows/*/*.yml`, and `examples/*.yml`. actionlint also runs shellcheck against every `run:` block, so shell quoting and unset-variable problems get caught too.

Run it locally before you push (see below). A PR that fails actionlint will not be reviewed until it is green.

### 4. Document every input

Every `workflow_call` input needs:

- a `description` written for someone who has not read the file,
- an explicit `type`,
- an explicit `required`,
- a `default` unless the input is genuinely required.

Then add it to the input table in `README.md`. An undocumented input is an input nobody will use.

Same for secrets: declare them under `secrets:` with a `description` and the correct `required` value, and list them in the README.

### 5. Write shell defensively

```yaml
- name: Do the thing
  run: |
    set -euo pipefail
    ...
```

Pass untrusted or user-supplied values through `env:` rather than interpolating `${{ }}` directly into a shell command. Anything that reaches a `run:` block through `${{ }}` is substituted as text before the shell sees it, which is how script injection happens.

### 6. Explain the non-obvious in comments

If a step has a `continue-on-error`, an `exit-code: 0`, or an `if: always()`, say why in a comment. Somebody is reading this repo to learn. A workflow that works but cannot be explained is only half the deliverable.

Keep the comments about reasoning, not narration. `# checkout the code` above a checkout step helps nobody.

---

## Running the checks locally

### actionlint

Install it (this is the same one-liner CI uses):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/rhysd/actionlint/main/scripts/download-actionlint.bash)
./actionlint --version
```

Or with Homebrew / Go:

```bash
brew install actionlint
# or
go install github.com/rhysd/actionlint/cmd/actionlint@latest
```

Run it over everything CI checks:

```bash
./actionlint -color \
  .github/workflows/*.yml \
  .github/workflows/*/*.yml \
  examples/*.yml
```

Install `shellcheck` too (`brew install shellcheck` / `apt install shellcheck`) — without it, actionlint silently skips the shell linting that CI performs.

### The SHA pin check

CI runs a small script that fails if any third-party action is not SHA-pinned. To check the same thing by hand, look for any `uses:` line that is not `actions/*`, not `github/*`, and does not end in a 40-character hex string:

```bash
grep -rn --include='*.yml' -E '^\s*(-\s*)?uses:' .github/workflows examples
```

The exact logic lives in the `pin-check` job of [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

### Testing a workflow for real

There is no substitute for running it. Push your branch to a fork and call the reusable workflow from a test repository with `@your-branch-name`:

```yaml
jobs:
  test:
    uses: your-username/devops-workflows/.github/workflows/security/reusable-security-scanning.yml@my-feature-branch
    permissions:
      contents: read
      security-events: write
      actions: read
```

Include a link to a successful run in your pull request description. That is the strongest possible review evidence.

---

## Commit conventions

Use [Conventional Commits](https://www.conventionalcommits.org/). The subject line is `type(scope): summary`, lowercase, imperative mood, no trailing period.

| Type | Use for |
|---|---|
| `feat` | a new workflow, input, or capability |
| `fix` | a workflow that was doing the wrong thing |
| `docs` | README, CONTRIBUTING, comments, examples' explanatory text |
| `ci` | changes to this repo's own `ci.yml` or `dependabot.yml` |
| `refactor` | restructuring with no behaviour change |
| `chore` | housekeeping that fits nowhere else |

Scope is the workflow folder where one applies: `security`, `terraform`, `docker`, `kubernetes`, `observability`, `ai`, `examples`.

```
feat(docker): add build_args input for multi-stage builds
fix(terraform): report real plan outcome in the PR comment
docs(readme): document the kubeconfig encoding step
ci: pin actionlint installer to a release tag
```

Explain *why* in the commit body when the subject line cannot carry it. A reader six months from now has the diff already; what they need is the reasoning.

---

## Pull request checklist

- [ ] `actionlint` passes locally, with shellcheck installed
- [ ] Every third-party action is SHA-pinned with a `# vX.Y.Z` comment
- [ ] The workflow starts with `permissions: {}` and grants per job
- [ ] Every input and secret has a description, type, and required flag
- [ ] `README.md` tables updated to match
- [ ] An example added or updated in `examples/` if the change affects how people call it
- [ ] A link to a successful run on a fork, for behavioural changes

Pull requests are reviewed by [@iampopye](https://github.com/iampopye). Reviews aim for a couple of days — docs should not be a bottleneck. If a PR goes quiet, a polite nudge on the thread is welcome.

## Code of conduct

Be decent to people. Assume the person asking a basic question is doing their best with what they know today — every one of us was there. Condescension toward beginners is the one thing that will get a comment removed.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE) that covers this project.
