# Rebuild release

This reusable workflow cuts a PATCH-bumped release when the source did not
change. Use it in a repo that builds a container image and pins no package
versions. A rebuild with no source change picks up base-image and OS security
patches.

The workflow creates a release only. It builds nothing. The release starts the
`release: [published]` trigger in the build workflow of the calling repo.

# Usage

Add a caller workflow to the repo that holds the image. The caller owns the
cron schedule and the manual dispatch inputs.

Pin the `uses` reference to a tag or a commit. See the versioning note in the
[repo README](../../README.md).

```yaml
name: Monthly Rebuild Release

on:
  schedule:
    # 10:00 UTC on each of the first 7 days of the month. The recency guard
    # keeps the release to one per window. Do not filter weekdays here: GitHub
    # ORs day-of-month with day-of-week when both are restricted, so
    # `1-7 * 1-5` fires every weekday of the month. The workflow checks the
    # weekday itself.
    - cron: "0 10 1-7 * *"
  workflow_dispatch:
    inputs:
      force:
        description: "Ignore the recency guard"
        type: boolean
        default: false
      dry_run:
        description: "Report the decision without creating a release"
        type: boolean
        default: false

permissions:
  contents: read

jobs:
  rebuild:
    uses: GameAnalytics/github/.github/workflows/monthly-rebuild.yml@v0
    with:
      # `inputs` is empty on a scheduled run, so give each one a default.
      force: ${{ inputs.force || false }}
      dry-run: ${{ inputs.dry_run || false }}
    secrets: inherit
```

# Inputs

| Name | Default | Description |
| --- | --- | --- |
| `min-days-since-release` | `14` | Minimum days since the most recent release. The workflow skips if a release is newer than this. Pre-releases count. |
| `skip-weekends` | `true` | Skip a scheduled run on Saturday and Sunday, UTC. |
| `work-hours-start` | `10` | First UTC hour of the work-hours window. Inclusive. |
| `work-hours-end` | `16` | Last UTC hour of the work-hours window. Exclusive. |
| `release-branch` | default branch | Branch to release from. |
| `tag-prefix` | `v` | Literal prefix before `MAJOR.MINOR.PATCH` in a tag name. Use `""` for bare `1.2.3` tags. |
| `release-notes` | generated | Body of the release. |
| `force` | `false` | Ignore the recency guard. |
| `dry-run` | `false` | Report the decision without creating a release. |
| `runs-on` | `ubuntu-latest` | Runner label for the job. |

To release at any hour, set `work-hours-start: 0`, `work-hours-end: 24` and
`skip-weekends: false`.

# Outputs

| Name | Description |
| --- | --- |
| `released` | `true` if the workflow created a release. |
| `version` | Tag of the new release. Empty if no release was computed. |
| `previous-version` | Tag the new release was bumped from. |

# Secrets

`DEPLOY_GITHUB_TOKEN` is required. Use `secrets: inherit` in the caller.

The token must be a PAT. `GITHUB_TOKEN` does not work: events raised by the
default token do not start other workflow runs, so the build workflow of the
calling repo would never run.

# Guards

The workflow skips, and does not fail, in these cases:

* The run is scheduled, `skip-weekends` is set and the day is a weekend.
* The run is scheduled and the UTC hour is outside the work-hours window.
  GitHub delays scheduled runs under load, so the workflow checks the hour
  again at run time.
* A release is newer than `min-days-since-release` days. Set `force` to ignore
  this guard.

The workflow fails if it finds no `MAJOR.MINOR.PATCH` tag on the tip of the
release branch, or if the next tag already exists outside that branch.

# Requirements for the calling repo

* The release branch must carry a tag in the form `<tag-prefix>MAJOR.MINOR.PATCH`.
* The build workflow must have a `release: [published]` trigger.
* `DEPLOY_GITHUB_TOKEN` must be available to the repo.
