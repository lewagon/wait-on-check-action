# Wait on Check action

This action can be used to halt any workflow until required checks for a given git ref (branch, tag, or commit SHA) pass successfully. It uses [GitHub Check Runs API](https://developer.github.com/v3/checks/runs/#list-check-runs-for-a-git-reference) to poll for a check result—until a check either succeeds or else.

On successful check, the action will yield control to next step.
In any other case, the action will exit with status 1, failing the whole workflow.

:tada: It allows to work around a GitHub Actions limitation of non-interdependent _workflows_ (we can only depend on `job`s [inside a single workflow](https://help.github.com/en/actions/reference/workflow-syntax-for-github-actions#jobsjob_idneeds)).

In other words, you can **run your workflows in parallel** and only proceed with workflow B after workflow A completes and reports success.

### A real-world scenario

- A push to master triggers a `test` workflow that runs tests on application code.
- A push to master triggers a webhook that builds an image on external service (Quay, DockerHub, etc.)
- Once the image is built, a `repository_dispatch` hook is triggered from a third-party service that launches a `deploy` workflow.
- We don't want the `deploy` workflow to succeed until we're sure that the `master` branch is green in `test` workflow.
- We add the "Wait on tests" step to make sure `deploy` does not succeed before `test` for a master branch.

#### Example workflow code

```yml
# .github/workflows/deploy-dispatch.yml
name: Trigger deploy on external event
on:
  repository_dispatch:
    types: [build_success]

jobs:
  deploy:
    # see https://github.com/lewagon/quay-github-actions-dispatch for use-case
    if: startsWith(github.sha, github.event.client_payload.text)
    name: Deploy new image
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@master

      # This step will retry until required check passes
      # and will fail the whole workflow if the check conclusion is not a success
      - name: Wait on tests
        # or lewagon/wait-on-check-action@v0.2 for most recent stable version
        uses: lewagon/wait-on-check-action@master
        with:
          ref: master # can be commit SHA or tag too
          check-name: test # name of the existing check - omit to wait for all checks
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          wait-interval: 20 # seconds

      # Deploy step
      - name: Save DigitalOcean kubeconfig
        uses: digitalocean/action-doctl@master
        env:
          DIGITALOCEAN_ACCESS_TOKEN: ${{ secrets.DIGITALOCEAN_ACCESS_TOKEN }}
        with:
          args: kubernetes cluster kubeconfig show my-cluster > $GITHUB_WORKSPACE/.kubeconfig

      - name: Upgrade/install chart
        run: export KUBECONFIG=$GITHUB_WORKSPACE/.kubeconfig && make deploy latest_sha=$(echo $GITHUB_SHA | head -c7)}}
```

### Figruring out check name

```
curl -X GET https://api.github.com/repos/OWNER/REPO/commits/REF/check-runs \
-H 'Accept: application/vnd.github.antiope-preview+json' \
-H 'Authorization: token GITHUB_REPO_READ_TOKEN' | jq '[.check_runs[].name]'
```

To figure out a check name—use the `curl` command above.
Note that by default this will be a value of `jobs` key, unless the `name` is provided.

```yml
# .github/workflows/test.yml
name: Rspec
on:
  push:
    branches:
      - master
  # Will run once the PR is opened or a new commit is pushed against it
  pull_request:
    types:
      - opened
      - synchronize
jobs:
  test:
    runs-on: ubuntu-latest
      steps:
      ...
```

:point_up: Name is `test`.

```yml
# .github/workflows/test.yml
name: Rspec
on:
  push:
    branches:
      - master
  # Will run once the PR is opened or a new commit is pushed against it
  pull_request:
    types:
      - opened
      - synchronize
jobs:
  test:
    name: "My test workflow"
    runs-on: ubuntu-latest
      steps:
      ...
```

:point_up: Name is `My test workflow`


### Waiting for a specific check to finish OR waiting for all checks to finish

There are two variables to have in mind:
- `check-name`: Name of the check we want to wait to finish before continuing.
- `running-workflow-name`: Name of the check that will wait for the rest.

The first one is optional. If provided, the second one is not needed.
If none of them is given, the check will wait "forever" because it will be waiting for itself to finish.

Example:

```yml
name: Waiting for checks and deploy

on:
  push:

jobs:
  deploy: # This name is the one to be used in `running-workflow-name`
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Wait on tests
        uses: lewagon/wait-on-check-action@master
        with:
          ref: ${{ github.ref }}
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          wait-interval: 10
          running-workflow-name: 'deploy' # HERE

      - name: Step to deploy
        run: echo 'success!'
```

### How to use the test workflows

There are a few basic sample workflows in the `.github/workflows` directory. Two of them are just simple tasks that print something to the console. They are there just to emulate "real world" actions being executed that have to be waited. The important workflow are the ones that use the hereby implemented wait-on-check-action.
To watch them in action, you'll need to fork the repo and, from your local computer, run the bash script included in `.github/trigger-scripts` directory:
```bash
.github/trigger-scripts/trigger-test-workflows.sh
```
This script creates a couple of tags in your forked repo (make sure you use `origin` as your remote) that will trigger the mentioned workflows. These include a step to remove the created tag.
You'll see that the workflow named "wait_omitting-check-name" waits for the two simple-tasks, while the one named "wait_using_check-name" only waits for "simple-task".
