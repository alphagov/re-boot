#!/bin/bash
set -eu

: DEPLOY_ENV
: AWS_DEFAULT_REGION

SCRIPT="${0}"
SCRIPT_DIR=$(cd "$(dirname "${0}")" && pwd)

ACTION="${1:-}"
BUCKET="${DEPLOY_ENV}-bosh-terraform-state"

case "${ACTION}" in
create)
  echo -n "Creating BOSH environment... "

  mkdir "${SCRIPT_DIR}/../deployment" && cd "${SCRIPT_DIR}/../deployment"
  git clone https://github.com/cloudfoundry/bosh-deployment.git

  bosh create-env bosh-deployment/bosh.yml \
    --state=state.json \
    --vars-store=creds.yml \
    -o bosh-deployment/aws/cpi.yml \
    -v director_name="${DEPLOY_ENV}-bosh" \
    -v internal_cidr=10.0.0.0/24 \
    -v internal_gw=10.0.0.1 \
    -v internal_ip=10.0.0.6 \
    -v access_key_id=AKI... \
    -v secret_access_key=wfh28... \
    -v region=us-east-1 \
    -v az=us-east-1a \
    -v default_key_name=bosh \
    -v default_security_groups=[bosh] \
    --var-file private_key=~/Downloads/bosh.pem \
    -v subnet_id=subnet-ait8g34t

  echo "DONE"
  ;;
delete)
  echo -n "Deleting BOSH environmnet... "



  echo "DONE"
  ;;
*)
  echo "ACTION needs to be provided. Use: ${SCRIPT} <create|delete>"
  exit 1
  ;;
esac
