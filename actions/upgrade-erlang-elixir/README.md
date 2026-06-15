# Upgrade Erlang and Elixir

Resolves target Erlang/Elixir versions via `erlef/setup-beam`, updates `OTP_VER` and `ELIXIR_VER` in `.github/workflows/ci.yml` and `.github/workflows/release.yml`, and opens a pull request with the changes.

## Usage

```yaml
name: Create pull request to upgrade Erlang and Elixir

on:
  workflow_dispatch:
    inputs:
      target_erlang_version:
        description: 'Target Erlang version, e.g. "22.3.4", "22.x" or ">22"'
        required: true
      target_elixir_version:
        description: 'Target Elixir version, e.g. "1.19.5", "1.x" or ">1.19"'
        required: true

jobs:
  upgrade-erlang-elixir:
    runs-on: ubuntu-latest
    steps:
      - uses: gameanalytics/github/actions/upgrade-erlang-elixir@v0
        with:
          target_erlang_version: ${{ inputs.target_erlang_version }}
          target_elixir_version: ${{ inputs.target_elixir_version }}
          deploy_github_token: ${{ secrets.DEPLOY_GITHUB_TOKEN }}
```
