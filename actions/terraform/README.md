# Terraform linting and security checks

This action is intended to be used with Terraform projects, providing the following for your CI:

* Format linting
* Optional checks that tags are applied to resources
* Security scanning and PR commenting via tfsec

# Usage

```yaml
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: gameanalytics/github/actions/terraform@v0
        with:
          tags: "CostCentre,Service"
          resources: "aws_dynamodb_table,aws_ec2_instance"
```

The tag check uses the [custom checks](https://aquasecurity.github.io/tfsec/v1.16.2/guides/configuration/custom-checks/)
configuration from tfsec to match arbitrary tags against specified resources. See below for an example of the check file
that the action generates.

Note that the check only confirms existence of the tag, not that the content is valid.

```yaml
  checks:
    - code: GHA001
      description: Check if resources have the required tags.
      requiredTypes:
        - resource
      requiredLabels:
        - aws_dynamodb_table
        - aws_ec2_instance
  severity: ERROR
  matchSpec:
    action: "and"
    predicateMatchSpec:
      - name: tags
        action: contains
        value: CostCentre
      - name: tags
        action: contains
        value: Service
  errorMessage: Resource is missing tags declared as necessary in github action
```
