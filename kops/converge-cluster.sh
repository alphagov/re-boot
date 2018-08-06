#!/usr/bin/env bash
set -ueo pipefail

name="$1"
cluster_name="${name}.k8s.local"
state_bucket='s3://gds-paas-k8s-shared-state'

: "$LOGIT_API_KEY"
: "$LOGIT_ELASTICSEARCH_HOST"

script_dir="$( realpath . )"

function cluster_up () {
  kops validate cluster \
       --name="${cluster_name}" \
       --state="${state_bucket}"
}

echo '🆗  Starting bootstrap procedure'
echo "🔀   Switching kubectl to \"${cluster_name}\""

kops export kubecfg "${cluster_name}" --state="${state_bucket}"

echo "👏   Switched kubectl to \"${cluster_name}\""

echo '❓  Checking if cluster is ready'

if ! cluster_up; then
  echo '‼️  Cluster not ready, exiting';
  exit 1
fi

echo '✅  Cluster is ready, proceeding'

echo '🔧  Installing Prometheus'
kubectl apply -f "${script_dir}/mgmt/prometheus.yaml"
echo '✅  Prometheus is installed'

echo '🔧  Installing Dashboard'
kubectl apply -f "${script_dir}/mgmt/dashboard.yaml"
echo '✅  Dashboard is installed'

echo '🔧  Installing logging'
kubectl create secret generic logit \
        --namespace kube-system \
        --from-literal "logitApiKey=${LOGIT_API_KEY}" \
        --from-literal "logitElasticsearchHost=${LOGIT_ELASTICSEARCH_HOST}" \
        --output yaml \
        --dry-run \
 | kubectl apply -f -

kubectl apply -f "${script_dir}/mgmt/logging.yaml"
echo '✅  Logging is installed'

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

grafana_host="$(kubectl get service -n monitoring grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
grafana_port="$(kubectl get service -n monitoring grafana -o jsonpath='{.spec.ports[0].port}')"
grafana_url="http://${grafana_host}:${grafana_port}"

cat <<EOF

-------------------------------------------------------------------------------

💻  In a separate terminal open a tunnel to the cluster with "kubectl proxy"

🔑  You will be able to log in with the following token:

$service_account_token

💻  http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/#!/

📈  Grafana
    💻  ${grafana_url}
    😎  admin
    🔑  admin

🔥  Prometheus
    💻  prometheus_url

-------------------------------------------------------------------------------

EOF

echo '✅  Finished bootstrap procedure'
