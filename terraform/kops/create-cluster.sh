#!/usr/bin/env bash
set -ueo pipefail

cd longboy-network
terraform init
terraform apply

vpc_id="$(terraform output vpc_id)"
subnet_ids="$(terraform output subnet_ids)"
cd -

vpc_id="${vpc_id/.*=/}"
subnet_ids="${subnet_ids/.*/}"

echo "$vpc_id"
echo "$subnet_ids"

kops create cluster \
     --name=longboy.k8s.local \
     --state=s3://gds-paas-k8s-shared-state \
     --cloud=aws \
     --zones eu-west-2a,eu-west-2b,eu-west-2c \
     --vpc "${vpc_id}" \
     --subnets "${subnet_ids}" \
     --yes
