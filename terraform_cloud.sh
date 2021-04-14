#!/bin/bash

# Complete script for API-driven runs.
# Documentation can be found at:
# https://www.terraform.io/docs/cloud/run/api.html

# 1. Define Variables

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <CONTENT_DIRECTORY_PATH> <ORGANIZATION>/<WORKSPACE>"
  exit 0
fi

CONTENT_DIRECTORY="$1"
ORG_NAME="$(cut -d'/' -f1 <<<"$2")"
WORKSPACE_NAME="$(cut -d'/' -f2 <<<"$2")"

# 2. Create the File for Upload

UPLOAD_FILE_NAME="./content-$(date +%s).tar.gz"
tar -zcvf "$UPLOAD_FILE_NAME" --exclude='.github/*' --exclude='gifs/*' --exclude='README.md' --exclude='.git/*' -C "$CONTENT_DIRECTORY" .

# 3. Look Up the Workspace ID

WORKSPACE_ID=($(curl \
  --header "Authorization: Bearer $Token" \
  --header "Content-Type: application/vnd.api+json" \
  https://app.terraform.io/api/v2/organizations/$ORG_NAME/workspaces/$WORKSPACE_NAME \
  | jq -r '.data.id'))

# 4. Create a New Configuration Version

echo '{"data":{"type":"configuration-versions"}}' > ./create_config_version.json

UPLOAD_URL=($(curl \
  --header "Authorization: Bearer $Token" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @create_config_version.json \
  https://app.terraform.io/api/v2/workspaces/$WORKSPACE_ID/configuration-versions \
  | jq -r '.data.attributes."upload-url"'))

# 5. Upload the Configuration Content File

curl \
  --header "Content-Type: application/octet-stream" \
  --request PUT \
  --data-binary @"$UPLOAD_FILE_NAME" \
  $UPLOAD_URL

# 6. Delete Temporary Files

rm "$UPLOAD_FILE_NAME"
rm ./create_config_version.json
