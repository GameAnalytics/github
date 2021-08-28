# Build and push docker image to AWS ECR repo
This action relies on provided AWS credentials, builds and
pushes the docker image to the ECR repo

# Usage

```yaml
    - uses: actions/checkout@v2 # needed if Dockerfile within the repo
    - uses: gameanalytics/github/actions/build-push-ecr@v1
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }} # set in GH Secrets
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-east-1
        ecr-repo: my-ecr-repo
        ecr-tag: 0.0.1
        dockerfile: ./Dockerfile
```

# Depends
It depends on [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials)
and [aws-actions/amazon-ecr-login](https://github.com/aws-actions/amazon-ecr-login).
See docs on how to setup credentials in those repose.
