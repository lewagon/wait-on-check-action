# Wait on Check action

This action can be used to halt any workflow until required checks for a given ref pass successfully. It uses [GitHub Check Runs API](https://developer.github.com/v3/checks/runs/#list-check-runs-for-a-git-reference) to poll for a given check result agains a given git ref — until a check either succeeds or fails.

On a failed check the action will exit with 1 and stop the workflow. On success it will yield control to next step.

:tada: It allows to work around a GitHub Actions limitation of non-interdependent _workflows_ (we can only depend on `job`s [inside a single workflow](https://help.github.com/en/actions/reference/workflow-syntax-for-github-actions#jobsjob_idneeds)).

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
  build:
    # see https://github.com/lewagon/quay-github-actions-dispatch for use-case
    if: startsWith(github.sha, github.event.client_payload.text)
    name: Deploy new image
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@master

      # This step will retry until required check passes
      # and will fal the whole workflow if the check conclusion is not a success
      - name: Wait on tests
        uses: lewagon/wait-on-check-action@v0.1-beta
        with:
          ref: master # can be commit SHA or tag too
          check-name: test # name of the existing check
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
