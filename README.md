# Wait On Check Action

![Build](https://img.shields.io/github/actions/workflow/status/lewagon/wait-on-check-action/review.yaml)
![Version](https://img.shields.io/github/v/tag/lewagon/wait-on-check-action)
![License](https://img.shields.io/github/license/lewagon/wait-on-check-action)

Pause until a job in another workflow completes successfully.

This action uses GitHub's [Checks API](https://docs.github.com/rest/checks) to poll for check results. On success, the action exits allowing the workflow to resume. Otherwise, the action exits with status code 1 and fails the workflow.

## When to use this action

- You need to wait for checks on **non-default branches** (PRs, feature branches)
- You need **multiple workflows to wait atomically** until all checks pass
- You need **flexible check filtering** (regex patterns, specific names, exclusions)
- You're coordinating workflows triggered by `repository_dispatch` or external events

### Consider native GitHub Actions features when

- All your jobs are in the **same workflow** → use [`needs`](#using-needs)
- You only work on the **default branch** and simple triggers suffice → use [`workflow_run`](#using-workflow_run)

## Quickstart

**Workflow A** - Runs tests

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

**Workflow B** - Waits for tests before publishing

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
          check-name: "Run tests"
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          wait-interval: 10

      - uses: actions/checkout@v4
      - run: npm publish
```

## Inputs

### Required inputs

| Input | Description                              | Example             |
| ----- | ---------------------------------------- | ------------------- |
| `ref` | Git ref to check (branch/tag/commit SHA) | `${{ github.ref }}` |

### Optional inputs

| Input                   | Description                                        | Example                               | Default           |
| ----------------------- | -------------------------------------------------- | ------------------------------------- | ----------------- |
| `allowed-conclusions`   | Comma-separated list of acceptable conclusions     | `success,skipped`                     | `success,skipped` |
| `api-endpoint`          | Custom GitHub API endpoint (for GHE)               | `https://github.mycompany.com/api/v3` | -                 |
| `check-name`            | Specific check name to wait for                    | `"Run tests"`                         | -                 |
| `check-regexp`          | Filter checks using regex pattern                  | `"test-.*"`                           | -                 |
| `ignore-checks`         | Comma-separated list of checks to ignore           | `optional-lint,coverage-report`       | -                 |
| `repo-token`            | GitHub token for API access                        | `${{ secrets.GITHUB_TOKEN }}`         | -                 |
| `running-workflow-name` | Name of current workflow (to exclude from waiting) | `"Deploy"`                            | -                 |
| `verbose`               | Print detailed logs                                | `true`                                | `true`            |
| `wait-interval`         | Seconds between API requests                       | `10`                                  | `10`              |

## Usage examples

### Wait for a specific check

```yaml
- name: Wait for tests
  uses: lewagon/wait-on-check-action@v1.4.1
  with:
    ref: ${{ github.ref }}
    check-name: "Run tests"
    repo-token: ${{ secrets.GITHUB_TOKEN }}
```

### Wait for all checks (except current workflow)

```yaml
jobs:
  publish:
    name: Publish the package
    runs-on: ubuntu-latest
    steps:
      - name: Wait for other checks to succeed
        uses: lewagon/wait-on-check-action@v1.4.1
        with:
          ref: ${{ github.ref }}
          running-workflow-name: "Publish the package"
          repo-token: ${{ secrets.GITHUB_TOKEN }}
```

### Wait for checks matching a pattern

```yaml
- name: Wait for all test jobs
  uses: lewagon/wait-on-check-action@v1.4.1
  with:
    ref: ${{ github.sha }}
    check-regexp: "test-.*"
    repo-token: ${{ secrets.GITHUB_TOKEN }}
```

### Accept cancelled checks

```yaml
- name: Wait for checks (allow cancelled)
  uses: lewagon/wait-on-check-action@v1.4.1
  with:
    ref: ${{ github.ref }}
    check-name: "Run tests"
    repo-token: ${{ secrets.GITHUB_TOKEN }}
    allowed-conclusions: success,skipped,cancelled
```

### Ignore specific checks

```yaml
- name: Wait for checks (ignore some)
  uses: lewagon/wait-on-check-action@v1.4.1
  with:
    ref: ${{ github.sha }}
    running-workflow-name: "Deploy"
    ignore-checks: "optional-lint,coverage-report"
    repo-token: ${{ secrets.GITHUB_TOKEN }}
```

## Understanding check names

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

## Reusable workflows

When using this action in a reusable workflow, the check name includes both the caller and callee job names:

``.github/workflows/caller.yml``

```yaml
on: push
jobs:
  caller:
    uses: ./.github/workflows/callee.yml
```

``.github/workflows/callee.yml``

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
          running-workflow-name: "caller / callee"
          repo-token: ${{ secrets.GITHUB_TOKEN }}
```

## GitHub Enterprise support

Pass your GHE API endpoint:

```yaml
- name: Wait for tests (GHE)
  uses: lewagon/wait-on-check-action@v1.4.1
  with:
    ref: ${{ github.ref }}
    check-name: "Run tests"
    repo-token: ${{ secrets.GITHUB_TOKEN }}
    api-endpoint: https://github.mycompany.com/api/v3
```

## Known limitations

- **Pagination**: The action handles up to 100 concurrent workflow runs. If you have more, some may not be detected.
- **API Rate Limits**: Frequent polling may hit GitHub API rate limits. Increase `wait-interval` if needed.

## Alternatives

### Using `needs`

For jobs **in the same workflow**, use the native `needs` keyword:

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: npm test

  deploy:
    needs: test # Waits for test to complete successfully
    runs-on: ubuntu-latest
    steps:
      - run: npm run deploy
```

### Using `workflow_run`

For triggering workflows **on the default branch** after another workflow completes:

```yaml
name: Deploy

on:
  workflow_run:
    workflows: ["Test"]
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

## Development

### Dependencies

To install dependencies:

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

This repository uses [semantic versioning](https://semver.org).

[`bump2version`](https://github.com/c4urself/bump2version) is used to version and tag changes, for example:

```bash
bump2version patch  # 1.4.1 → 1.4.2
bump2version minor  # 1.4.1 → 1.5.0
bump2version major  # 1.4.1 → 2.0.0
```

### License

See the [LICENSE](LICENSE) file.
