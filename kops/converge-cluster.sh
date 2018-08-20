#!/usr/bin/env bash
set -ueo pipefail

env_name="$1"
cluster_name="${env_name}.k8s.local"
state_bucket='s3://gds-paas-k8s-shared-state'

script_dir="$PWD"

cd "deployments/${env_name}"
domain_name="$(terraform output domain_name)"
domain_zone_id="$(terraform output domain_zone_id)"
cd -
domain_name="${domain_name/.*=/}"
domain_name="${domain_name%.}" # remove dot at end of zone
domain_zone_id="${domain_zone_id/.*=/}"
domain_owner_id="/hostedzone/${domain_zone_id}"

function cluster_up () {
  kops validate cluster \
       --name="${cluster_name}" \
       --state="${state_bucket}"
}

echo '🆗  Starting bootstrap procedure'
echo "🔀   Switching kubectl to \"${cluster_name}\""

kops export kubecfg --name "${cluster_name}" --state="${state_bucket}"

echo "👏   Switched kubectl to \"${cluster_name}\""

echo '❓  Checking if cluster is ready'

if ! cluster_up; then
  echo '‼️  Cluster not ready, exiting';
  exit 1
fi

echo '✅  Cluster is ready, proceeding'

kops export kubecfg "${cluster_name}" --state="${state_bucket}"

kops replace --state=${state_bucket} -f  <( \
	spruce merge dns-iam.yaml \
		<(kops get cluster ${cluster_name} --state=${state_bucket} -o yaml ) \
)

kops update cluster "${cluster_name}" --state=${state_bucket} --yes
kops rolling-update cluster "${cluster_name}" --state=${state_bucket} --yes
cp "${script_dir}/deploy-dns-pod.yaml" deploy-dns-pod-merged.yaml
perl -pi -e s,--domain-filter=DNS,--domain-filter="${domain_name}",g deploy-dns-pod-merged.yaml
perl -pi -e s,--txt-owner-id=OWNER,--txt-owner-id="${domain_owner_id}",g deploy-dns-pod-merged.yaml

kubectl apply -f "${script_dir}/deploy-dns.yaml"
kubectl apply -f "${script_dir}/deploy-dns-pod-merged.yaml"
rm deploy-dns-pod-merged.yaml
echo '✅  DNS has been set up'

echo '    🔧  Installing Concourse'
cp "${script_dir}/mgmt/concourse.yaml" concourse-merged.yaml
perl -pi -e s,KUBECTL_CONCOURSE_URL,"concourse.${domain_name}",g concourse-merged.yaml
kubectl apply -f concourse-merged.yaml
rm concourse-merged.yaml
echo '✅  Concourse is installed'

echo '    🔧  Installing Vault'
kubectl apply -f "${script_dir}/mgmt/vault-operator.yaml"
echo '💤  Waiting for custom resources'
sleep 10
kubectl apply -f "${script_dir}/mgmt/vault-operator-deploy.yaml"
echo '💤  Setting up Vault'
sh ${script_dir}/setup-vault.sh
echo '✅  Vault is installed'

echo '    🔧  Installing Concourse'
cp "${script_dir}/mgmt/concourse.yaml" concourse-merged.yaml
perl -pi -e s,KUBECTL_CONCOURSE_URL,"concourse.${DEPLOY_ENV}.govsvc.uk",g concourse-merged.yaml
sed -i.bak s/\(\(VAULT_URL\)\)/vault-service.default.${name}.k8s.local/g concourse-merged.yaml
sed -i.bak s#\(\(VAULT_CA_CERT\)\)#"$(pwd)/ca.crt"#g concourse-merged.yaml
sed -i.bak s/\(\(VAULT_CLIENT_TOKEN\)\)/"$(cat account-token.txt)"/g concourse-merged.yaml
kubectl apply -f concourse-merged.yaml
rm concourse-merged.yaml concourse-merged.yaml.bak
echo '✅  Concourse is installed'

echo '🔧  Installing Prometheus'
echo '    🔧  Installing Prometheus custom resources'
kubectl apply -f "${script_dir}/mgmt/prometheus-custom-resources.yaml"
echo '💤  Waiting for custom resources'
sleep 5
echo '    🔧  Installing Prometheus, AlertManager, Grafana'
kubectl apply -f "${script_dir}/mgmt/prometheus.yaml"
echo '✅  Prometheus is installed'

echo '🔧  Installing Dashboard'
kubectl apply -f "${script_dir}/mgmt/dashboard.yaml"
echo '✅  Dashboard is installed'

if [ ! -z ${LOGIT_API_KEY+x} ] && [ ! -z ${LOGIT_ELASTICSEARCH_HOST+x} ]; then
  echo '🔧  Installing logging'
  # Use `kubectl create` to output YAML configuration, which is then applied.
  # We have to do this because `create` is not akin to upsert, so will fail
  # when run repeatedly.
  kubectl create secret generic logit \
          --namespace kube-system \
          --from-literal "logitApiKey=${LOGIT_API_KEY}" \
          --from-literal "logitElasticsearchHost=${LOGIT_ELASTICSEARCH_HOST}" \
          --output yaml \
          --dry-run \
  | kubectl apply -f -

  kubectl apply -f "${script_dir}/mgmt/logging.yaml"
  echo '✅  Logging is installed'
else
  echo '🤷  LOGIT_API_KEY and LOGIT_ELASTICSEARCH_HOST are not set. Skipping.'
fi

service_account_name="default"

kubectl apply -f <(cat <<EOF
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: ${service_account_name}-user-cluster-admin
  labels:
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: ${service_account_name}
  namespace: default
EOF
)

service_account_secret_name="$(
  kubectl get serviceaccount default -o jsonpath='{.secrets[0].name}'
)"
service_account_token="$(
  kubectl get secret "$service_account_secret_name" -o jsonpath='{.data.token}' |\
  base64 --decode
)"

echo '💤  Waiting for ELBs'
sleep 30

dashboard_host="$(kubectl get service -n kube-system kubernetes-dashboard -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
dashboard_port="$(kubectl get service -n kube-system kubernetes-dashboard -o jsonpath='{.spec.ports[0].port}')"
dashboard_url="https://${dashboard_host}:${dashboard_port}"

grafana_host="$(kubectl get service -n monitoring grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
grafana_port="$(kubectl get service -n monitoring grafana -o jsonpath='{.spec.ports[0].port}')"
grafana_url="http://${grafana_host}:${grafana_port}"

prometheus_host="$(kubectl get service -n monitoring prometheus-dashboard -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
prometheus_port="$(kubectl get service -n monitoring prometheus-dashboard -o jsonpath='{.spec.ports[0].port}')"
prometheus_url="http://${prometheus_host}:${prometheus_port}"

cat <<EOF

-------------------------------------------------------------------------------

💻  Dashboard
    💻  ${dashboard_url}
    🔑  You will be able to log in with the following token:

$service_account_token

✈️  Concourse
    💻  http://concourse.${domain_name}:8080
    😎  concourse
    🔑  concourse

📈  Grafana
    💻  ${grafana_url}/dashboards
    😎  admin
    🔑  admin

🔥  Prometheus
    💻  ${prometheus_url}

-------------------------------------------------------------------------------

EOF

echo '✅  Finished bootstrap procedure'
