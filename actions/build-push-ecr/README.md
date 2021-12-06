# Build and push docker image to AWS ECR repo
This action relies on provided AWS role or credentials, builds and
pushes the docker image to the ECR repo.

# Usage

```yaml
    # These permissions are needed to interact with GitHub's OIDC
    # Token endpoint. Don't need them if you use credentials instead.
    permissions:
      id-token: write
      contents: read
    steps:
    - uses: actions/checkout@v2 # needed if Dockerfile within the repo
    - uses: gameanalytics/github/actions/build-push-ecr@v0
      with:
        aws-role-to-assume: arn:aws:iam::123456789012:role/my-gh-repo-role
        aws-region: us-east-1
        ecr-repo: my-ecr-repo
        ecr-tag: 0.0.1
        dockerfile: ./Dockerfile
```

# Depends
It depends on [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials)
and [aws-actions/amazon-ecr-login](https://github.com/aws-actions/amazon-ecr-login).
See docs on how to setup credentials in those repos.

It can use only role or credentials, not both.
Docs how one can seutp aws role suitable for github actions could be
found [here](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services).
