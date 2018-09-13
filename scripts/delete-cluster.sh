#!/usr/bin/env bash
set -ueo pipefail

env_name="${1}"
DEPLOY_ENV="${2}"
cluster_name="${DEPLOY_ENV}.k8s.local"

SCRIPT_DIR=$(cd "$(dirname "${0}")" && pwd)
ROOT_DIR="${SCRIPT_DIR}/.."

kops delete cluster \
  --name="${cluster_name}" \
  --state=s3://gds-paas-k8s-shared-state \
  --yes

cd "${ROOT_DIR}/deployments/${env_name}"
terraform init
terraform destroy -var "env=${cluster_name}"
cd -
