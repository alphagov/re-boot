#!/usr/bin/env bash
set -ueo pipefail

env_name="$1"
DEPLOY_ENV="$2"
cluster_name="${DEPLOY_ENV}.k8s.local"

SCRIPT_DIR=$(cd "$(dirname "${0}")" && pwd)
ROOT_DIR="${SCRIPT_DIR}/.."

cd "${ROOT_DIR}/deployments/${env_name}"
terraform init
terraform apply -var "env=${DEPLOY_ENV}"

vpc_id="$(terraform output vpc_id)"
subnet_ids="$(terraform output subnet_ids)"
azs="$(terraform output azs)"
cd -

vpc_id="${vpc_id/.*=/}"
subnet_ids="${subnet_ids/.*=/}"
azs="${azs/.*=/}"

echo "${vpc_id}"
echo "${subnet_ids}"
echo "${azs}"

kops create cluster \
  --name="${cluster_name}" \
  --state=s3://gds-paas-k8s-shared-state \
  --networking flannel \
  --cloud=aws \
  --node-count=3 \
  --zones="${azs}" \
  --master-count=3 \
  --master-zones="${azs}" \
  --vpc="${vpc_id}" \
  --subnets="${subnet_ids}" \
  --yes
