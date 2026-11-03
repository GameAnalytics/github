#!/usr/bin/env bash
# Builds a Lambda deployment zip for the given Python version and architecture,
# then imports it inside the matching AWS Lambda base image as a smoke test.
# Configured through environment variables, see action.yml.
set -euo pipefail

: "${PYTHON_VERSION:?}" "${ARCHITECTURE:?}" "${SOURCE_DIR:?}" "${OUTPUT_DIR:?}" "${ZIP_NAME:?}"
: "${SMOKE_TEST_GLOB:?}"

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

# --no-deps because the requirements are expected to be fully resolved (a lock file)
echo "::group::Install dependencies for $manylinux $arch, Python $PYTHON_VERSION"
python3 -m pip install -r "$stage/requirements.txt" --no-deps -t "$stage/package" \
  "${wheel_platforms[@]}" --python-version "$PYTHON_VERSION" \
  --implementation cp --only-binary=:all:
echo "::endgroup::"

cp -r "$SOURCE_DIR"/. "$stage/package/"
(cd "$stage/package" && zip -qr "$zip_path" .)
echo "Built $zip_path"

mkdir -p "$stage/smoke"
unzip -q "$zip_path" -d "$stage/smoke"
echo "::group::Smoke test in $image ($docker_platform)"
docker run --rm --platform "$docker_platform" --entrypoint python \
  -v "$stage/smoke:/var/task:ro" -w /var/task -e GLOB="$SMOKE_TEST_GLOB" "$image" \
  -c "import glob, importlib, os
mods = sorted(f[:-3] for f in glob.glob(os.environ['GLOB']))
assert mods, 'no modules matched ' + os.environ['GLOB']
for m in mods:
    importlib.import_module(m)
    print('imported', m)"
echo "::endgroup::"

echo "zip-path=$zip_path" >> "${GITHUB_OUTPUT:-/dev/null}"
