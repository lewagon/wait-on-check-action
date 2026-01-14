# Wait On Check Action

Pause a workflow until a job in another workflow completes successfully.

![Build](https://img.shields.io/github/actions/workflow/status/lewagon/wait-on-check-action/review.yaml)
![Version](https://img.shields.io/github/v/tag/lewagon/wait-on-check-action)
![License](https://img.shields.io/github/license/lewagon/wait-on-check-action)

This action uses the [Checks API](https://docs.github.com/en/rest/checks) to poll for check results. On success, the action exits allowing the workflow to resume. Otherwise, the action exits with status code 1 and fails the workflow.

## When to Use This Action

**Use wait-on-check-action when:**

- You need to wait for checks on **non-default branches** (PRs, feature branches)
- You need **multiple workflows to wait atomically** until all checks pass
- You need **flexible check filtering** (regex patterns, specific names, exclusions)
- You're coordinating workflows triggered by `repository_dispatch` or external events

**Consider native GitHub Actions features when:**

- All your jobs are in the **same workflow** → use the [`needs` keyword](#alternative-within-workflow-dependencies)
- You only work on the **default branch** and simple triggers suffice → use [`workflow_run`](#alternative-workflow_run-event)

## Quick Start

**Workflow A** - Runs tests:

```yaml
name: Test

on: [push]

jobs:
  test:
    name: Run tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm test
```

**Workflow B** - Waits for tests before publishing:

```yaml
name: Publish

on: [push]

jobs:
  publish:
    name: Publish the package
    runs-on: ubuntu-latest
    steps:
      - name: Wait for tests to succeed
        uses: lewagon/wait-on-check-action@v1.4.1
        with:
          ref: ${{ github.ref }}
          check-name: 'Run tests'
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          wait-interval: 10

      - uses: actions/checkout@v4
      - run: npm publish
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `ref` | Git ref to check (branch/tag/commit SHA) | **Yes** | - |
| `repo-token` | GitHub token for API access | No | `""` |
| `check-name` | Specific check name to wait for | No | `""` |
| `check-regexp` | Filter checks using regex pattern | No | `""` |
| `running-workflow-name` | Name of current workflow (to exclude from waiting) | No | `""` |
| `allowed-conclusions` | Comma-separated list of acceptable conclusions | No | `success,skipped` |
| `ignore-checks` | Comma-separated list of checks to ignore | No | `""` |
| `wait-interval` | Seconds between API requests | No | `10` |
| `api-endpoint` | Custom GitHub API endpoint (for GHE) | No | `""` |
| `verbose` | Print detailed logs | No | `true` |

## Usage Examples

### Wait for a Specific Check

```yaml
- name: Wait for tests
  uses: lewagon/wait-on-check-action@v1.4.1
  with:
    ref: ${{ github.ref }}
    check-name: 'Run tests'
    repo-token: ${{ secrets.GITHUB_TOKEN }}
```

### Wait for All Checks (Except Current Workflow)

```yaml
name: Publish the package
runs-on: ubuntu-latest
steps:
  - name: Wait for other checks to succeed
    uses: lewagon/wait-on-check-action@v1.4.1
    with:
      ref: ${{ github.ref }}
      running-workflow-name: 'Publish the package'
      repo-token: ${{ secrets.GITHUB_TOKEN }}
```

### Wait for Checks Matching a Pattern

```yaml
- name: Wait for all test jobs
  uses: lewagon/wait-on-check-action@v1.4.1
  with:
    ref: ${{ github.sha }}
    check-regexp: 'test-.*'
    repo-token: ${{ secrets.GITHUB_TOKEN }}
```

### Accept Cancelled Checks

```yaml
- name: Wait for checks (allow cancelled)
  uses: lewagon/wait-on-check-action@v1.4.1
  with:
    ref: ${{ github.ref }}
    check-name: 'Run tests'
    repo-token: ${{ secrets.GITHUB_TOKEN }}
    allowed-conclusions: success,skipped,cancelled
```

### Ignore Specific Checks

```yaml
- name: Wait for checks (ignore some)
  uses: lewagon/wait-on-check-action@v1.4.1
  with:
    ref: ${{ github.sha }}
    running-workflow-name: 'Deploy'
    ignore-checks: 'optional-lint,coverage-report'
    repo-token: ${{ secrets.GITHUB_TOKEN }}
```

## Understanding Check Names

The check name corresponds to `jobs.<job_id>.name` in your workflow:

```yaml
# Check name: "test" (uses job ID)
jobs:
  test:
    runs-on: ubuntu-latest
    steps: [...]

# Check name: "Run tests" (uses explicit name)
jobs:
  test:
    name: Run tests
    runs-on: ubuntu-latest
    steps: [...]

# Check names: "Run tests (3.9)", "Run tests (3.10)", etc.
jobs:
  test:
    name: Run tests
    strategy:
      matrix:
        python: ['3.9', '3.10', '3.11']
```

To inspect check names via the API:

```bash
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/OWNER/REPO/commits/REF/check-runs \
  | jq '[.check_runs[].name]'
```

## Reusable Workflows

When using this action in a reusable workflow, the check name includes both the caller and callee job names:

**.github/workflows/caller.yml**

```yaml
on: push
jobs:
  caller:
    uses: ./.github/workflows/callee.yml
```

**.github/workflows/callee.yml**

```yaml
on: workflow_call
jobs:
  callee:
    runs-on: ubuntu-latest
    steps:
      - name: Wait for other workflows
        uses: lewagon/wait-on-check-action@v1.4.1
        with:
          ref: ${{ github.ref }}
          running-workflow-name: 'caller / callee'
          repo-token: ${{ secrets.GITHUB_TOKEN }}
```

## Real-World Scenario

A common use case: external service triggers deployment after tests pass.

- Pushes to master trigger a `test` job to run against the application code
- Pushes to master also trigger a webhook that builds an image on an external service (e.g., Quay)
- Once the image is built, a `repository_dispatch` hook is triggered from the third-party service
- The `deploy` job should not start until the master branch passes its `test` job

```yaml
name: Trigger deployment on external event

on:
  repository_dispatch:
    types: [build_success]

jobs:
  deploy:
    if: startsWith(github.sha, github.event.client_payload.text)
    name: Deploy a new image
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Wait for tests to succeed
        uses: lewagon/wait-on-check-action@v1.4.1
        with:
          ref: master
          check-name: test
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          wait-interval: 20

      - name: Deploy to Kubernetes
        run: |
          # Your deployment commands here
          kubectl apply -f deployment.yaml
```

## GitHub Enterprise Support

Pass your GHE API endpoint:

```yaml
- name: Wait for tests (GHE)
  uses: lewagon/wait-on-check-action@v1.4.1
  with:
    ref: ${{ github.ref }}
    check-name: 'Run tests'
    repo-token: ${{ secrets.GITHUB_TOKEN }}
    api-endpoint: https://github.mycompany.com/api/v3
```

## Alternatives

### Alternative: Within-Workflow Dependencies

For jobs **in the same workflow**, use the native `needs` keyword:

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: npm test

  deploy:
    needs: test  # Waits for test to complete successfully
    runs-on: ubuntu-latest
    steps:
      - run: npm run deploy
```

### Alternative: workflow_run Event

For triggering workflows **on the default branch** after another workflow completes:

```yaml
name: Deploy

on:
  workflow_run:
    workflows: ['Test']
    types: [completed]

jobs:
  deploy:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    runs-on: ubuntu-latest
    steps:
      - run: npm run deploy
```

**Limitations of `workflow_run`:**

- Only triggers on the **default branch**
- Triggers once per workflow completion (not atomic "wait for all")
- Requires manual success checking with `if` condition

## Known Limitations

- **Pagination**: The action handles up to 100 concurrent workflow runs. If you have more, some may not be detected.
- **API Rate Limits**: Frequent polling may hit GitHub API rate limits. Increase `wait-interval` if needed.

## Development

### Setup

```bash
bundle install
```

Some packages must be installed from npm and PyPI:

```bash
npm install cspell husky prettier
pip install bump2version trufflehog3
```

### Tests

To run tests:

```bash
bundle exec rspec
```

There are sample workflows in the `.github/workflows` directory that demonstrate the action. The `wait_omitting-check-name` workflow waits for two simple tasks, while `wait_using_check-name` only waits for a specific task.

### Documentation

To generate the documentation locally:

```bash
bundle exec yard
```

### Linters

To run linters:

```bash
npx cspell . --dot --gitignore
bundle exec rubocop
trufflehog3 --no-history
```

### Formatters

To run formatters:

```bash
prettier . --write
```

## Contributing

Please read our [Code of Conduct](CODE_OF_CONDUCT.md) and [Changelog](CHANGELOG.md) before contributing.


This repository uses [semantic versioning](https://semver.org). Bump2version is used to version and tag changes. For example:

```bash
bump2version patch  # 1.4.1 → 1.4.2
bump2version minor  # 1.4.1 → 1.5.0
bump2version major  # 1.4.1 → 2.0.0
```

## License

See [LICENSE](LICENSE) file.

