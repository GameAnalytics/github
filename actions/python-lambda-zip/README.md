# Python Lambda zip

Builds a zip-file deployment package for a Python AWS Lambda and checks that it actually loads in
the AWS Lambda runtime.

Dependencies with compiled extensions (`cryptography`, `numpy`, ...) ship platform-specific wheels.
A plain `pip install` on a GitHub runner picks wheels built for the runner's (new) glibc, which the
Lambda runtime may be too old to load, giving errors like
``version `GLIBC_2.28' not found`` only at import time in AWS. This action

1. installs the dependencies with `pip --platform ... --only-binary=:all:`, so that only wheels
   compatible with the Lambda runtime are used, and
2. imports your modules inside the matching `public.ecr.aws/lambda/python` image, so that any
   remaining problem fails the build instead of the deployment.

The action does not upload the zip anywhere; use the `zip-path` output (or `output-dir`) for that.

## Usage

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-python@v7
        with:
          python-version: '3.11'
      - run: pip install pipenv
      - uses: gameanalytics/github/actions/python-lambda-zip@v0
        with:
          python-version: '3.11'
          source-dir: app
          requirements-command: pipenv requirements
          smoke-test-glob: 'lambda_*.py'
```

Run it in your pull request workflow too, not only on releases, to find problems before release.
The runner needs `pip`, `zip`, `unzip` and Docker, which `ubuntu-latest` has.

## Inputs

| Input | Default | Description |
|---|---|---|
| `python-version` | (required) | Python version of the Lambda runtime, e.g. `3.11` |
| `architecture` | `x86_64` | `x86_64` or `arm64` (arm64 is smoke tested using QEMU emulation) |
| `source-dir` | `src` | Directory with the Lambda code; its contents end up at the root of the zip |
| `requirements-file` | `requirements.txt` | Fully resolved requirements file |
| `requirements-command` | | Command printing the requirements, e.g. `pipenv requirements`; used instead of the file when set |
| `smoke-test-glob` | `*.py` | Modules (relative to the zip root) to import; build fails if nothing matches |
| `output-dir` | `build` | Where to put the zip |
| `zip-name` | `package.zip` | File name of the zip |

Output: `zip-path`, the absolute path of the zip.

## How `python-version` maps to wheels and image

| Python version | Lambda OS | glibc | Wheels installed | Smoke test image |
|---|---|---|---|---|
| 3.9 - 3.11 | Amazon Linux 2 | 2.26 | `manylinux2014` | `public.ecr.aws/lambda/python:<version>` |
| 3.12 and later | Amazon Linux 2023 | 2.34 | `manylinux_2_28` | `public.ecr.aws/lambda/python:<version>` |

The dependencies are installed with `--no-deps`, so the requirements must already be fully
resolved, as with a lock file. If a dependency has no compatible wheel (only an sdist, or only
newer manylinux wheels), the build fails instead of building something that breaks at runtime.

When a new Lambda runtime moves to a newer OS, update the mapping in `build.sh`.
