#!/usr/bin/env bash
# Build the site and sync it to AWS S3.
#
#   ./deploy.sh          upload changes
#   ./deploy.sh --dry    show what would change, upload nothing
set -euo pipefail

cd "$(dirname "$0")"

BUCKET="wray-website"
REGION="us-east-1"
S3="aws s3 cp --region ${REGION}"
DISTRIBUTION_ID="E25JVLYU8DPPUC"  # Replace with your CloudFront Distribution ID

DRY=""
[[ "${1:-}" == "--dry" ]] && DRY="--dryrun" && echo "DRY RUN — nothing will be uploaded."

python3 build.py

# index.html: short cache so edits show up quickly.
$S3 site/index.html s3://${BUCKET}/index.html \
  --content-type text/html \
  --cache-control "public, max-age=300"

# materials/: long cache, they rarely change once uploaded.
if [ -n "$(find materials -type f ! -name '.*' -print -quit)" ]; then
  aws s3 sync materials/ s3://${BUCKET}/ \
    --region ${REGION} \
    --exclude ".DS_Store" --exclude "Thumbs.db" \
    --delete --cache-control "public, max-age=86400"
else
  echo "materials/ is empty — skipping file sync."
fi

echo
# Invalidate CloudFront cache for all paths
if [[ -z "${DRY}" ]]; then
  aws cloudfront create-invalidation \
    --distribution-id ${DISTRIBUTION_ID} \
    --paths "/*"
echo "Live at: https://${BUCKET}.s3.amazonaws.com/index.html"
fi
