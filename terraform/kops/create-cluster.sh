#!/usr/bin/env bash
set -ueo pipefail

name="$1"

cd "deployments/${name}"
terraform init
terraform apply

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
     --name="${name}.k8s.local" \
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
