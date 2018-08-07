#!/usr/bin/env bash
set -ueo pipefail

: "${GOOGLE_AUTH_CLIENT_ID}"

export GOOGLE_AUTH_CLIENT_ID

name="$1"
cluster_name="${name}.k8s.local"
state_bucket='s3://gds-paas-k8s-shared-state'

script_dir="$( realpath . )"

kops export kubecfg "${cluster_name}" --state="${state_bucket}"
kubectl apply -f "${script_dir}/mgmt/users.yaml"

kops replace --state=${state_bucket} -f  <( \
	spruce merge \
		<(kops get cluster ${cluster_name} --state=${state_bucket} --full -o yaml | grep -v \/\/) \
		mgmt/oidc.yaml \
)

kops update cluster ${cluster_name} --state=${state_bucket} --yes
kops rolling-update cluster ${cluster_name} --state=${state_bucket} --yes
