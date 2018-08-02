#!/usr/bin/env bash
set -ueo pipefail

kops delete cluster \
     --name=longboy.k8s.local \
     --state=s3://gds-paas-k8s-shared-state \
     --yes

cd longboy-network
terraform init
terraform destroy
cd -
