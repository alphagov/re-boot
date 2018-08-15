#!/usr/bin/env bash
set -ueo pipefail

: "${GOOGLE_AUTH_CLIENT_ID}"

export GOOGLE_AUTH_CLIENT_ID

dns="$1"
owner_id="aws route53 list-hosted-zones-by-name --dns-name "${dns}." | jq -r '.HostedZones[0].Id'"
state_bucket='s3://gds-paas-k8s-shared-state'

script_dir="$(pwd)"

aws route53 create-hosted-zone --name "${dns}." --caller-reference "external-dns-test-$(date +%s)"

kops export kubecfg "${cluster_name}" --state="${state_bucket}"
kubectl apply -f "${script_dir}/mgmt/users.yaml"

kops replace --state=${state_bucket} -f  <( \
	spruce merge \
		<(kops get cluster ${cluster_name} --state=${state_bucket} --full -o yaml | grep -v \/\/) \
		dns-iam.yaml \
)

kops update cluster ${cluster_name} --state=${state_bucket} --yes
kops rolling-update cluster ${cluster_name} --state=${state_bucket} --yes

kubectl apply -f  <(spruce merge "${script_dir}/deploy-dns.yaml")