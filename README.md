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
        uses: lewagon/wait-on-check-action@v1.2.0
        with:
          ref: ${{ github.ref }}
          check-name: 'Run tests'
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          wait-interval: 10
      ...
```

## GHE Support

For GHE support you just need to pass in `api-endpoint` as an input.

```yml
name: Publish

on: [push]

jobs:
  publish:
    name: Publish the package
    runs-on: ubuntu-latest
    steps:
      - name: Wait for tests to succeed
        uses: lewagon/wait-on-check-action@v1.2.0
        with:
          ref: ${{ github.ref }}
          check-name: 'Run tests'
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          api-endpoint: YOUR_GHE_API_BASE_URL # Fed to https://octokit.github.io/octokit.rb/Octokit/Configurable.html#api_endpoint-instance_method
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
      - uses: actions/checkout@v2

      - name: Wait for tests to succeed
        uses: lewagon/wait-on-check-action@v1.2.0
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
curl -u username:$token \
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
        uses: lewagon/wait-on-check-action@v1.2.0
        with:
          ref: ${{ github.ref }}
          running-workflow-name: 'Publish the package'
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          wait-interval: 10
      ...
```

#### Using running workflow name in reusable workflows

Using this action in a reusable workflow means accepting a constraint that all calling jobs will have the same name.  For example, all calling workflows must call their jobs `caller` (or some more relevant constant) so that if the reused workflow containing the job that uses this action to wait is called `callee` then the task can successfully wait on `caller / callee`.  Working example follows.

.github/workflows/caller.yml

```yml
on:
  push:
jobs:
  caller:
    uses: ./.github/workflows/callee.yml
```

.github/workflows/callee.yml

```yml
on:
  workflow_call:
jobs:
  callee:
    runs-on: ubuntu-latest
    steps:
      - name: Wait for Other Workflows
        uses: lewagon/wait-on-check-action@v1.0.0
        with:
          ref: ${{ github.ref }}
          running-workflow-name: 'caller / callee'
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          wait-interval: 10
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
        uses: lewagon/wait-on-check-action@v1.2.0
        with:
          ref: ${{ github.ref }}
          check-name: 'Run tests'
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          wait-interval: 10
          allowed-conclusions: success,skipped,cancelled
      ...
```
  ### Using check-regexp
  Similar to the `check-name` parameter, this filters the checks to be waited but using a Regular Expression (aka regexp) to match the check name (jobs.<job_id>.name)

  Example of use:
  ```yaml
  name: Wait using check-regexp
  on:
    push:

  jobs:
    wait-for-check-regexp:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v2

        - name: Wait on tests
          uses: ./
          with:
            ref: ${{ github.sha }}
            repo-token: ${{ secrets.GITHUB_TOKEN }}
            running-workflow-name: wait-for-check-regexp
            check-regexp: .?-task
  ```

  ### Wait interval (optional, default: 10)
  As it could be seen in many examples, there's a parameter `wait-interval`, and sets a time in seconds to be waited between requests to the GitHub API. The default time is 10 seconds.

  ### Verbose (optional, default: true)
  If true, it prints some logs to help understanding the process (checks found, filtered, conclussions, etc.)

## Auto-pagination

Since we are using Octokit for using GitHub API, we are subject to their limitations. One of them is the pagination max size: if we have more than 100 workflows running, the auto-pagination won't help.
More about Octokit auto-pagination can be found [here](https://octokit.github.io/octokit.rb/file.README.html#Pagination:~:text=get.data-,Auto%20Pagination,-For%20smallish%20resource)
The solution would be to fetch all pages to gather all running workflows if they're more than 100, but it's still no implemented.

## Tests

There are sample workflows in the `.github/workflows` directory. Two of them are logging tasks to emulate real-world actions being executed that have to be waited. The important workflows are the ones that use the wait-on-check-action.

A workflow named "wait_omitting-check-name" waits for the two simple-tasks, while the one named "wait_using_check-name" only waits for "simple-task".

<!-- Links -->

[rspec_shield]: https://github.com/lewagon/wait-on-check-action/workflows/RSpec%20tests/badge.svg
[checks_api]: https://developer.github.com/v3/checks/runs/#list-check-runs-for-a-git-reference
