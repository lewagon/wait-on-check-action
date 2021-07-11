# Wait On Check Action

![RSpec Tests][rspec_shield]

Pause a workflow until a job in another workflow completes successfully.

This action uses the [Checks API][checks_api] to poll for check results. On success, the action exit allowing the workflow resume. Otherwise, the action will exit with status code 1 and fail the whole workflow.

This is a workaround to GitHub's limitation of non-interdependent workflows :tada:

You can **run your workflows in parallel** and pause a job until a job in another workflow completes successfully.

## Minimal example

```yml
name: Test

on: [push]

jobs:
  test:
    name: Run tests
    runs-on: ubuntu-latest
      steps:
        ...
```

```yml
name: Publish

on: [push]

jobs:
  publish:
    name: Publish the package
    runs-on: ubuntu-latest
    steps:
      - name: Wait for tests to succeed
        uses: lewagon/wait-on-check-action@v0.2
        with:
          ref: ${{ github.ref }}
          check-name: 'Run tests'
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          wait-interval: 10
      ...
```

## Alternatives

If you can keep the dependent jobs in a single workflow:

```yml
name: Test and publish

on: [push]

jobs:
  test:
    runs-on: ubuntu-latest
    steps: ...

  publish:
    runs-on: ubuntu-latest
    needs: test
    steps: ...
```

If you can run dependent jobs in a separate workflows in series:

```yml
name: Publish

on:
  workflow_run:
    workflows: ['Test']
    types:
      - completed
```

## A real-world scenario

- Pushes to master trigger a `test` job to be run against the application code.

- Pushes to master also trigger a webhook that builds an image on external service such as Quay.

- Once an image is built, a `repository_dispatch` hook is triggered from a third-party service. This triggers a `deploy` job.

- We don't want the `deploy` job to start until the master branch passes its `test` job.

```yml
name: Trigger deployment on external event

on:
  # https://github.com/lewagon/quay-github-actions-dispatch
  repository_dispatch:
    types: [build_success]

jobs:
  deploy:
    if: startsWith(github.sha, github.event.client_payload.text)
    name: Deploy a new image
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@master

      - name: Wait for tests to succeed
        uses: lewagon/wait-on-check-action@v0.2
        with:
          ref: master
          check-name: test
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          wait-interval: 20

      - name: Save the DigitalOcean kubeconfig
        uses: digitalocean/action-doctl@master
        env:
          DIGITALOCEAN_ACCESS_TOKEN: ${{ secrets.DIGITALOCEAN_ACCESS_TOKEN }}
        with:
          args: kubernetes cluster kubeconfig show my-cluster > $GITHUB_WORKSPACE/.kubeconfig

      - name: Upgrade/install chart
        run: export KUBECONFIG=$GITHUB_WORKSPACE/.kubeconfig && make deploy latest_sha=$(echo $GITHUB_SHA | head -c7)}}
```

## Parameters

### Check name

Check name goes according to the jobs.<job_id>.name parameter.

In this case the job's name is 'test':

```yml
jobs:
  test:
    runs-on: ubuntu-latest
      steps:
      ...
```

In this case the name is 'Run tests':

```yml
jobs:
  test:
    name: Run tests
    runs-on: ubuntu-latest
      steps:
      ...
```

In this case the names will be:

- Run tests (3.6)

- Run tests (3.7)

```yml
jobs:
  test:
    name: Run tests
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python: [3.6, 3.7]
```

To inspect the names as they appear to the API:

```bash
curl -i -u username:$token \
https://api.github.com/repos/OWNER/REPO/commits/REF/check-runs \
-H 'Accept: application/vnd.github.antiope-preview+json' | jq '[.check_runs[].name]'
```

### Running workflow name

If you would like to wait for all other checks to complete you may set `running-workflow-name` to the name of the current job and not set a `check-name` parameter.

```yml
name: Publish

on: [push]

jobs:
  publish:
    name: Publish the package
    runs-on: ubuntu-latest
    steps:
      - name: Wait for other checks to succeed
        uses: lewagon/wait-on-check-action@v0.2
        with:
          ref: ${{ github.ref }}
          running-workflow-name: 'Publish the package'
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          wait-interval: 10
      ...
```

### Allowed conclusions

By default, checks that conclude with either `success` or `skipped` are allowed, and anything else is not. You may configure this with the `allowed-conclusions` option, which is a comma-separated list of conclusions.

```yml
name: Publish

on: [push]

jobs:
  publish:
    name: Publish the package
    runs-on: ubuntu-latest
    steps:
      - name: Wait for tests to succeed
        uses: lewagon/wait-on-check-action@v0.2
        with:
          ref: ${{ github.ref }}
          check-name: 'Run tests'
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          wait-interval: 10
          allowed-conclusions: success,skipped,cancelled
      ...
```

## Tests

There are sample workflows in the `.github/workflows` directory. Two of them are logging tasks to emulate real-world actions being executed that have to be waited. The important workflows are the ones that use the wait-on-check-action.

A workflow named "wait_omitting-check-name" waits for the two simple-tasks, while the one named "wait_using_check-name" only waits for "simple-task".

<!-- Links -->

[rspec_shield]: https://github.com/lewagon/wait-on-check-action/workflows/RSpec%20tests/badge.svg
[checks_api]: https://developer.github.com/v3/checks/runs/#list-check-runs-for-a-git-reference
