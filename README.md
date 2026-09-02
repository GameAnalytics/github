# github
Public repo containing github related stuff

# versioning
It is under development at the moment, **things may change**.
It is advised to use particular commits references in your GH action yaml to
avoid breaking things. If you feel lucky you might use `v0` branch.

# actions
Number of helpful actions for GitHub Actions

* [build-push-ecr](./actions/build-push-ecr/README.md)

* [download-private-asset](./actions/download-private-asset/README.md)

# reusable workflows
Workflows that a caller repo runs with `uses` at job level. Intentionally sit at 
a different level to composite actions.
Useful if you want to preserve access to secrets from the calling workflow.

* [monthly-rebuild](./.github/workflows/monthly-rebuild.md)

# License
This code is made available under the MIT license.
