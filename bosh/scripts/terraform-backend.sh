#!/bin/bash
set -eu

: DEPLOY_ENV
: AWS_DEFAULT_REGION

SCRIPT="${0}"

ACTION="${1:-}"
BUCKET="${DEPLOY_ENV}-bosh-terraform-state"

case "${ACTION}" in
create)
  echo -n "Creating S3 bucket... "

  aws s3api create-bucket \
    --acl private \
    --bucket "${BUCKET}" \
    --create-bucket-configuration LocationConstraint="${AWS_DEFAULT_REGION}" \
    > /dev/null

  aws s3api put-bucket-versioning \
    --bucket "${BUCKET}" \
    --versioning-configuration Status=Enabled \
    > /dev/null

  echo "DONE"
  ;;
delete)
  echo -n "Deleting S3 bucket... "

  aws s3 rb "s3://${BUCKET}" --force > /dev/null

  echo "DONE"
  ;;
init)
  echo -n "Initialising terraform backend... "

  terraform init \
		-backend=true \
		-backend-config="bucket=${DEPLOY_ENV}-bosh-terraform-state" \
    -backend-config="region=${AWS_DEFAULT_REGION}" \
    -backend-config="key=bosh" \
		terraform/ \
    > /dev/null

  echo "DONE"
  ;;
*)
  echo "ACTION needs to be provided. Use: ${SCRIPT} <create|delete|init>"
  exit 1
  ;;
esac
