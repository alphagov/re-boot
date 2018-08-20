#!/usr/bin/env bash
set -ueo pipefail

env_name="$1"
cluster_name="${env_name}.k8s.local"

cd "deployments/${env_name}"
terraform init
terraform apply -var "env=${env_name}"

vpc_id="$(terraform output vpc_id)"
subnet_ids="$(terraform output subnet_ids)"
azs="$(terraform output azs)"
cd -

vpc_id="${vpc_id/.*=/}"
subnet_ids="${subnet_ids/.*=/}"
azs="${azs/.*=/}"

echo "$vpc_id"
echo "$subnet_ids"
echo "$azs"

kops create cluster \
     --name="$cluster_name" \
     --state=s3://gds-paas-k8s-shared-state \
     --networking flannel \
     --cloud=aws \
     --node-count=3 \
     --zones="$azs" \
     --master-count=3 \
     --master-zones="$azs" \
     --vpc="${vpc_id}" \
     --subnets="${subnet_ids}" \
     --yes
