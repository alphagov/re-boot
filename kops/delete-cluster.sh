#!/usr/bin/env bash
set -ueo pipefail

env_name="$1"
cluster_name="${env_name}.k8s.local"

kops delete cluster \
     --name="${cluster_name}" \
     --state=s3://gds-paas-k8s-shared-state \
     --yes

cd "deployments/${env_name}"
terraform init
terraform destroy -var "env=${cluster_name}"
cd -
