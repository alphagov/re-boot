#!/bin/bash
set -eu

: DEPLOY_ENV
: AWS_DEFAULT_REGION

SCRIPT_DIR=$(cd "$(dirname "${0}")" && pwd)

ACTION="${1:-}"
KEYNAME="${2:-id_rsa}"

terraform "${ACTION}" \
  -var-file=terraform/prod.tfvars \
  -var="env=${DEPLOY_ENV}" \
  -var="region=${AWS_DEFAULT_REGION}" \
  -var="public_key=$(cat "${SCRIPT_DIR}"/../assets/"${KEYNAME}".pub)" \
  terraform/
