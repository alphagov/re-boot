#!/usr/bin/env bash
set -ueo pipefail

cluster_name="$1"
dns="$2"
owner_id=$(aws route53 list-hosted-zones-by-name --dns-name "${dns}." | jq -r '.HostedZones[0].Id')
state_bucket='s3://gds-paas-k8s-shared-state'

script_dir="$(pwd)"

currentdns="aws route53 list-hosted-zones-by-name | jq -r '.HostedZones[].Name'"

if [ "${owner_id}" != "null" ]; then
    echo "Domain already exists"
else
    echo "Domain doesn't exist, creating"
    aws route53 create-hosted-zone --name "${dns}." --caller-reference "external-dns-test-$(date +%s)"
fi

kops export kubecfg "${cluster_name}.k8s.local" --state="${state_bucket}"

kops replace --state=${state_bucket} -f  <( \
	spruce merge \
		<(kops get cluster ${cluster_name}.k8s.local --state=${state_bucket} --full -o yaml | grep -v \/\/) \
		dns-iam.yaml \
)

kops update cluster ${cluster_name}.k8s.local --state=${state_bucket} --yes
kops rolling-update cluster ${cluster_name}.k8s.local --state=${state_bucket} --yes

kubectl apply -f  <(spruce merge "${script_dir}/deploy-dns.yaml")