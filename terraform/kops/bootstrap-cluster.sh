#!/usr/bin/env bash
set -ueo pipefail

function cluster_up () {
  kops validate cluster \
       --name=longboy.k8s.local \
       --state=s3://gds-paas-k8s-shared-state &> /dev/null
}

echo 'Checking if cluster is ready'

if ! cluster_up; then
  echo 'Cluster not ready, exiting';
  exit 1
fi

echo 'Cluster is ready, proceeding'

cat <<MSG
Installing untrusted software
  - prometheus
MSG

kubectl apply \
  -f https://raw.githubusercontent.com/kubernetes/kops/master/addons/prometheus-operator/v0.19.0.yaml

echo 'Done'
