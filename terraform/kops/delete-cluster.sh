#!/usr/bin/env bash
set -ueo pipefail

name="$1"

kops delete cluster \
     --name="${name}.k8s.local" \
     --state=s3://gds-paas-k8s-shared-state \
     --yes

cd "deployments/${name}"
terraform init
terraform destroy
cd -
