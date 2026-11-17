#!/usr/bin/env bash
# Builds a Lambda deployment zip for the given Python version and architecture,
# then imports it inside the matching AWS Lambda base image as a smoke test.
# Configured through environment variables, see action.yml.
set -euo pipefail

: "${PYTHON_VERSION:?}" "${ARCHITECTURE:?}" "${OUTPUT_DIR:?}" "${ZIP_NAME:?}"
: "${SMOKE_TEST_GLOB:?}"

if [[ -z "${SOURCE_DIR:-}" && -z "${INCLUDE:-}" ]]; then
  echo "at least one of source-dir and include must be set" >&2
  exit 1
fi

if [[ ! "$PYTHON_VERSION" =~ ^3\.[0-9]+$ ]]; then
  echo "python-version must look like '3.11', got '$PYTHON_VERSION'" >&2
  exit 1
fi
minor="${PYTHON_VERSION#3.}"

# Lambda runtimes up to python3.11 run on Amazon Linux 2 (glibc 2.26), so only
# manylinux2014 (glibc 2.17) wheels can be loaded. python3.12 and later run on
# Amazon Linux 2023 (glibc 2.34), which can load manylinux_2_28 wheels.
if (( minor <= 11 )); then
  manylinux=manylinux2014
else
  manylinux=manylinux_2_28
fi

case "$ARCHITECTURE" in
  x86_64) docker_platform=linux/amd64 ;;
  arm64)  docker_platform=linux/arm64 ;;
  *) echo "architecture must be x86_64 or arm64, got '$ARCHITECTURE'" >&2; exit 1 ;;
esac
arch=$([[ $ARCHITECTURE == arm64 ]] && echo aarch64 || echo x86_64)
# Also accept manylinux2014 wheels, which pip does not do implicitly for newer tags
wheel_platforms=(--platform "manylinux2014_${arch}")
[[ $manylinux == manylinux2014 ]] || wheel_platforms+=(--platform "${manylinux}_${arch}")
image="public.ecr.aws/lambda/python:${PYTHON_VERSION}"

# pip evaluates environment markers in the requirements (python_version etc.) against the
# host Python, so a mismatch would silently drop or add dependencies
host_version="$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
if [[ "$host_version" != "$PYTHON_VERSION" ]]; then
  echo "Host Python is $host_version but python-version is $PYTHON_VERSION: set up the same version first, e.g. with actions/setup-python" >&2
  exit 1
fi
if [[ "$ARCHITECTURE" != "$(uname -m)" ]]; then
  echo "::warning::Building for $ARCHITECTURE on a $(uname -m) host: platform markers in the requirements are evaluated for the host"
fi

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/package" "$OUTPUT_DIR"
zip_path="$(cd "$OUTPUT_DIR" && pwd)/$ZIP_NAME"
rm -f "$zip_path"

if [[ -n "${REQUIREMENTS_COMMAND:-}" ]]; then
  bash -c "$REQUIREMENTS_COMMAND" > "$stage/requirements.txt"
else
  cp "$REQUIREMENTS_FILE" "$stage/requirements.txt"
fi

# --no-deps because the requirements are expected to be fully resolved (a lock file). It also
# allows pip to fall back to building a source distribution when a package has no wheel
# for the target; the check below makes sure that this only happens for pure Python packages.
echo "::group::Install dependencies for $manylinux $arch, Python $PYTHON_VERSION"
python3 -m pip install -r "$stage/requirements.txt" --no-deps -t "$stage/package" \
  "${wheel_platforms[@]}" --python-version "$PYTHON_VERSION" \
  --implementation cp
echo "::endgroup::"

bad=0
for wheel_file in "$stage"/package/*.dist-info/WHEEL; do
  if grep '^Tag: ' "$wheel_file" | grep -qv -e '-any$' -e 'manylinux'; then
    echo "::error::$(dirname "$wheel_file" | xargs basename) is not a pure Python or manylinux package (built from source for the host?): $(grep '^Tag: ' "$wheel_file" | tr '\n' ' ')"
    bad=1
  fi
done
(( bad == 0 ))

if [[ -n "${SOURCE_DIR:-}" ]]; then
  cp -r "$SOURCE_DIR"/. "$stage/package/"
fi
while IFS= read -r path; do
  [[ -n "$path" ]] && cp -r --parents "$path" "$stage/package/"
done <<< "${INCLUDE:-}"
zip_excludes=(-x "*__pycache__*" -x "*.pyc")
while IFS= read -r pattern; do
  [[ -n "$pattern" ]] && zip_excludes+=(-x "$pattern")
done <<< "${EXCLUDE:-}"
(cd "$stage/package" && zip -qr "$zip_path" . "${zip_excludes[@]}")
echo "Built $zip_path"

mkdir -p "$stage/smoke"
unzip -q "$zip_path" -d "$stage/smoke"
echo "::group::Smoke test in $image ($docker_platform)"
# The Lambda runtime always sets the region, and code often creates AWS clients at import time
smoke_env=(-e AWS_REGION=us-east-1 -e AWS_DEFAULT_REGION=us-east-1)
while IFS= read -r var; do
  [[ -n "$var" ]] && smoke_env+=(-e "$var")
done <<< "${SMOKE_TEST_ENV:-}"
docker run --rm --platform "$docker_platform" --entrypoint python \
  -v "$stage/smoke:/var/task:ro" -w /var/task -e GLOB="$SMOKE_TEST_GLOB" "${smoke_env[@]}" "$image" \
  -c "import glob, importlib, os
files = glob.glob(os.environ['GLOB'], recursive=True)
mods = sorted(f[:-3].replace('/', '.') for f in files if not os.path.basename(f).startswith('_'))
assert mods, 'no modules matched ' + os.environ['GLOB']
for m in mods:
    importlib.import_module(m)
    print('imported', m)"
echo "::endgroup::"

echo "zip-path=$zip_path" >> "${GITHUB_OUTPUT:-/dev/null}"
