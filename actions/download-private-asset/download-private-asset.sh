#!/bin/sh -l

REPO=$1
VERSION=$2
FILE=$3

GITHUB="https://api.github.com"

# Ensure that the PAT is included in the env
if [[ -z "$TOKEN" ]]; then
  echo "Set the TOKEN (PAT) env variable."
  exit 1
fi

echo "Start downloading $FILE from $REPO (version: $VERSION)"

function gh_curl() {
  curl -H "Authorization: token $TOKEN" \
       -H "Accept: application/vnd.github.v3.raw" \
       $@
}

if [ "$VERSION" = "latest" ]; then
  # Github should return the latest release first.
  parser=".[0].assets | map(select(.name == \"$FILE\"))[0].id"
else
  parser=". | map(select(.tag_name == \"$VERSION\"))[0].assets | map(select(.name == \"$FILE\"))[0].id"
fi;

asset_id=`gh_curl -s $GITHUB/repos/$REPO/releases | jq "$parser"`

if [ "$asset_id" = "null" ]; then
  echo "ERROR: version not found $VERSION"
  exit 1
fi;

curl -Lj \
     -o $FILE \
     -H 'Accept:application/octet-stream' \
     https://$TOKEN:@api.github.com/repos/$REPO/releases/assets/$asset_id

# Output
location="`pwd`/$FILE"
echo ::set-output name=location::$location
