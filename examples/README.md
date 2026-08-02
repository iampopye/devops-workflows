# Examples

Complete, working workflows you can copy into your own project.

**How to use any file here:** copy it into `.github/workflows/` in **your** repository, rename it to something meaningful, and edit the parts that are specific to you — image names, directories, target URLs, secret names. Nothing in this folder runs from here; these are starting points, not shared workflows.

```bash
mkdir -p .github/workflows
curl -o .github/workflows/ci.yml \
  https://raw.githubusercontent.com/iampopye/devops-workflows/main/examples/consume-reusable-workflows.yml
```

Then open it and delete the jobs you do not need.

---

## The main entry point

### [`consume-reusable-workflows.yml`](consume-reusable-workflows.yml)

**Start here.** A full platform pipeline that calls every reusable workflow in this repo: security scanning, compliance validation, Terraform plan, Docker build, and a Kubernetes deploy that runs only on `main` and only after the image build and security scan pass.

Shows you: how to call a reusable workflow with `uses:`, how to grant permissions from the calling job, how to chain jobs with `needs:`, how to pass a secret through, and how to make behaviour conditional on the branch (`push: ${{ github.ref == 'refs/heads/main' }}`).

Edit before use: `image_name`, `working_directory`, `namespace`, `manifests_path`, and the `KUBECONFIG_B64` secret name. Delete any job you are not ready for — none of them depend on each other except where `needs:` says so.

### [`ai-pr-review.yml`](ai-pr-review.yml)

The optional AI pull request review, with **one block per provider**: Anthropic, OpenAI, Groq, OpenRouter, and a fully self-hosted OpenAI-compatible endpoint (Ollama, vLLM, llama.cpp, LM Studio).

Uncomment exactly one block, delete the rest, and add the matching API key as a repository secret. The self-hosted option needs a runner that can reach your endpoint, and no API key at all if the endpoint is unauthenticated on your own network.

Shows you: how a required input with no default keeps a workflow vendor-neutral.

---

## Standalone pipelines

These do not call the reusable workflows. They are self-contained pipelines for common jobs, modernised from older drafts — useful both to copy and to read as before/after examples of what "modernising a workflow" actually means.

### [`go-test-and-sonarqube.yml`](go-test-and-sonarqube.yml)

Go build, `go vet`, race-enabled tests with coverage, a tidiness check on `go.mod`, then a SonarQube scan **and quality gate** in a second job.

Shows you: reading the Go version from `go.mod` instead of hardcoding it (so it cannot drift), passing coverage between jobs as an artifact, and why a scan without a quality gate is a dashboard rather than a gate. The original draft used `sonarqube-scan-action@master` — a moving target running with your `SONAR_TOKEN` in scope.

Requires: `SONAR_TOKEN` and `SONAR_HOST_URL` secrets.

### [`cucumber-godog.yml`](cucumber-godog.yml)

BDD acceptance tests with [Godog](https://github.com/cucumber/godog), the Cucumber implementation for Go.

Shows you: keeping the BDD suite in its own job so a failure tells you which layer broke, and uploading a test report with `if: always()` so you still get artifacts from a failed run.

Edit before use: the `./features/...` path and the `-run TestFeatures` target.

### [`k6-load-test.yml`](k6-load-test.yml)

Load testing with [k6](https://k6.io/), with virtual users and duration exposed as `workflow_dispatch` inputs, plus a results table written to the job summary.

Shows you: why **thresholds** matter. Without a `thresholds` block in your k6 script, k6 exits `0` no matter how bad the numbers are, and the whole run is decorative. A companion `loadtest.js` with a working thresholds block is included as a comment at the bottom of the file.

Requires: a `LOAD_TEST_BASE_URL` repository variable and a `loadtest.js` at your repo root.

### [`zap-baseline-scan.yml`](zap-baseline-scan.yml)

OWASP ZAP baseline DAST scan against a deployed environment, with the HTML/Markdown/JSON reports uploaded as artifacts.

Shows you: replacing about 30 lines of hand-rolled shell (download a tarball, start the daemon, poll for readiness, scrape the output) with the official action, and using a `.zap/rules.tsv` file to downgrade known-accepted findings so they stop failing the build.

Baseline mode is passive — it spiders the target and reports what it sees without attacking. **Only point it at systems you are authorised to test.**

Requires: a `ZAP_TARGET_URL` repository variable, or a `target_url` supplied at dispatch time.

---

## Things to remember when you copy these

- **Pin to a release tag.** The reusable-workflow references use `@v1`, not `@main`, so an upstream change here cannot alter your pipeline until you choose it.
- **Permissions are granted by the caller.** A reusable workflow can only narrow the permissions it is given, never widen them. If you delete a `permissions:` block from a calling job, that job's steps lose the access they need. The [main README](../README.md#workflow-reference) lists the required grants for each workflow.
- **Every file starts with `permissions: {}`.** Keep it. It denies everything at the workflow level so each job has to ask for what it needs.
- **Third-party actions are SHA-pinned.** If you edit an action reference, keep the 40-character SHA and the `# vX.Y.Z` comment. The reasoning is in the [main README](../README.md#1-every-third-party-action-is-pinned-to-a-commit-sha).
- **Secret names are examples.** `SONAR_TOKEN`, `KUBECONFIG_B64`, `ANTHROPIC_API_KEY` and friends are whatever you named them in **Settings → Secrets and variables → Actions**.

Something here not working, or not clear? [Open an issue](https://github.com/iampopye/devops-workflows/issues) — an example that does not run is a bug.
