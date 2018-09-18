#!/usr/bin/env bash
set -ueo pipefail

env_name="${1}"
DEPLOY_ENV="${2}"
export CLUSTER_NAME="${DEPLOY_ENV}.k8s.local"
state_bucket="s3://gds-paas-k8s-shared-state"

SCRIPT_DIR=$(cd "$(dirname "${0}")" && pwd)
ROOT_DIR="${SCRIPT_DIR}/.."

cd "${ROOT_DIR}/deployments/${env_name}"
DOMAIN_NAME="$(terraform output domain_name)"
DOMAIN_ZONE_ID="$(terraform output domain_zone_id)"
cd -

DOMAIN_NAME="${DOMAIN_NAME/.*=/}"
DOMAIN_NAME="${DOMAIN_NAME%.}" # remove dot at end of zone
DOMAIN_ZONE_ID="${DOMAIN_ZONE_ID/.*=/}"
DOMAIN_OWNER_ID="/hostedzone/${DOMAIN_ZONE_ID}"

export DOMAIN_NAME DOMAIN_OWNER_ID

function cluster_up () {
  kops validate cluster \
    --name="${CLUSTER_NAME}" \
    --state="${state_bucket}"
}

echo "🆗  Starting bootstrap procedure"
echo "🔀   Switching kubectl to \"${CLUSTER_NAME}\""

kops export kubecfg --name "${CLUSTER_NAME}" --state="${state_bucket}"

echo "👏   Switched kubectl to \"${CLUSTER_NAME}\""

echo "❓  Checking if cluster is ready"

if ! cluster_up; then
  echo "‼️  Cluster not ready, exiting";
  exit 1
fi

echo "✅  Cluster is ready, proceeding"

echo "    🔧  Setting up DNS"
kops export kubecfg "${CLUSTER_NAME}" --state="${state_bucket}"

kops replace --state=${state_bucket} -f  <( \
	spruce merge "${ROOT_DIR}/kubernetes/system/dns/iam.yml" \
		<(kops get cluster "${CLUSTER_NAME}" --state="${state_bucket}" -o yaml ) \
)

kops update cluster "${CLUSTER_NAME}" --state="${state_bucket}" --yes
kops rolling-update cluster "${CLUSTER_NAME}" --state="${state_bucket}" --yes
cat $(find "${ROOT_DIR}/kubernetes/system/dns" -type f -name '*.yaml') | interpolator -f | kubectl apply -f -

echo "✅  DNS has been set up"

echo '    🔧  Installing Vault Operator'
kubectl apply -f "${ROOT_DIR}/kubernetes/vault/namespace.yaml"
kubectl -n vault apply -f "${ROOT_DIR}/kubernetes/vault/role.yaml"
kubectl -n vault apply -f "${ROOT_DIR}/kubernetes/vault/role-binding.yaml"
kubectl apply -f "${ROOT_DIR}/kubernetes/vault/etcd/custom-resource-definition.yaml"
kubectl -n vault apply -f "${ROOT_DIR}/kubernetes/vault/etcd/deployment.yaml"
kubectl apply -f "${ROOT_DIR}/kubernetes/vault/custom-resource-definition.yaml"
kubectl -n vault apply -f "${ROOT_DIR}/kubernetes/vault/deployment.yaml"
kubectl -n vault apply -f "${ROOT_DIR}/kubernetes/vault/vault-service.yaml"
SEALED_VAULT="$(kubectl -n vault get vault vault-service -o jsonpath='{.status.vaultStatus.sealed[0]}')"
if [ ! -z "${SEALED_VAULT}" ]; then
  echo '💤  Leaving some headroom for vault to stabilise - 5m - you may need to wait and restart it if following fails'
  # You might have come here to see WHY ON EARH you need to wait 5 minutes...
  # Well, we're deploying something called vault-operator. It's basically, yet
  # another set of bash scripts developed by CoreOS, that setup other resources
  # Vault requires. It also runs some operations like making it ready to accept
  # traffic. It may take 30s but it may take 3 minutes. Just to be safe, we're
  # setting it to 5 minutes to make sure all is ready and you can walk away
  # without the fear of the procedure failing.
  sleep 300
fi
echo '💤  Setting up Vault'
sh ${SCRIPT_DIR}/setup-vault.sh

export VAULT_URL="https://vault-service.vault.svc.cluster.local:8200/"

echo "✅  Vault is installed"

echo "    🔧  Installing Concourse"
export EXTERNAL_CONCOURSE_URL="concourse.${DEPLOY_ENV}.govsvc.uk"

####
# These need to stay as they were...
###
export LIVENESS_PROBE_FATAL_ERRORS="\${LIVENESS_PROBE_FATAL_ERRORS}"
export FATAL_ERRORS="\${FATAL_ERRORS}"
export HOSTNAME="\${HOSTNAME}"
export KUBERNETES_SERVICE_TOKEN="\${KUBERNETES_SERVICE_TOKEN}"
####

mkdir -p "${ROOT_DIR}/assets/concourse"
if [[ ! -e "${ROOT_DIR}/assets/concourse/host" ]]; then
  ssh-keygen -t rsa -b 4096 -N '' -f "${ROOT_DIR}/assets/concourse/host"
fi
if [[ ! -e "${ROOT_DIR}/assets/concourse/session" ]]; then
  ssh-keygen -t rsa -b 4096 -N '' -f "${ROOT_DIR}/assets/concourse/session"
fi
if [[ ! -e "${ROOT_DIR}/assets/concourse/worker" ]]; then
  ssh-keygen -t rsa -b 4096 -N '' -f "${ROOT_DIR}/assets/concourse/worker"
fi
if [[ ! -e "${ROOT_DIR}/assets/concourse/vault-key.pem" ]]; then
  openssl req -nodes -new  -x509 -keyout "${ROOT_DIR}/assets/concourse/vault-key.pem" -out "${ROOT_DIR}/assets/concourse/vault-cert.pem"
fi

CONCOURSE_HOST_SECRET="$(cat "${ROOT_DIR}/assets/concourse/host" | base64)"
CONCOURSE_HOST_PUBLIC="$(cat "${ROOT_DIR}/assets/concourse/host.pub" | base64)"
CONCOURSE_SESSION_SECRET="$(cat "${ROOT_DIR}/assets/concourse/session" | base64)"
CONCOURSE_WORKER_SECRET="$(cat "${ROOT_DIR}/assets/concourse/worker" | base64)"
CONCOURSE_WORKER_PUBLIC="$(cat "${ROOT_DIR}/assets/concourse/worker.pub" | base64)"
CONCOURSE_VAULT_KEY="$(cat "${ROOT_DIR}/assets/concourse/vault-key.pem" | base64)"
CONCOURSE_VAULT_CERTIFICATE="$(cat "${ROOT_DIR}/assets/concourse/vault-cert.pem" | base64)"
CONCOURSE_USERNAME="$(echo -n "admin" | base64)"
CONCOURSE_PASSWORD="$(openssl rand -base64 32 | tr -d '\n' | base64)"
export CONCOURSE_HOST_SECRET CONCOURSE_HOST_PUBLIC CONCOURSE_SESSION_SECRET CONCOURSE_WORKER_SECRET CONCOURSE_WORKER_PUBLIC CONCOURSE_VAULT_KEY CONCOURSE_VAULT_CERTIFICATE CONCOURSE_USERNAME CONCOURSE_PASSWORD

kubectl apply -f "${ROOT_DIR}/kubernetes/concourse/namespace.yaml"
cat $(find "${ROOT_DIR}/kubernetes/concourse" -type f -name '*.yaml') | interpolator -f | kubectl -n concourse apply -f -
VAULT_SKIP_VERIFY="true" vault write concourse/main/concourse username="$(echo "${CONCOURSE_USERNAME}" | base64 -D)" password="$(echo "${CONCOURSE_PASSWORD}" | base64 -D)"
echo "✅  Concourse is installed"

echo "🔧  Installing Prometheus"
echo "    🔧  Installing Prometheus custom resources"
kubectl apply -f "${ROOT_DIR}/kubernetes/prometheus/namespace.yaml"
kubectl -n monitoring apply -f "${ROOT_DIR}/kubernetes/prometheus/custom-resource-definition.yaml"
echo "💤  Waiting for custom resources"
sleep 5
echo "    🔧  Installing Prometheus, AlertManager, Grafana"
kubectl -n monitoring apply -f "${ROOT_DIR}/kubernetes/prometheus" -R
echo "✅  Prometheus is installed"

echo "🔧  Installing Dashboard"
kubectl apply -f "${ROOT_DIR}/kubernetes/dashboard" -R
echo "✅  Dashboard is installed"

if [ ! -z ${LOGIT_API_KEY+x} ] && [ ! -z ${LOGIT_ELASTICSEARCH_HOST+x} ]; then
  echo "🔧  Installing logging"
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

  kubectl apply -f "${ROOT_DIR}/kubernetes/logging" -R
  echo "✅  Logging is installed"
else
  echo "🤷  LOGIT_API_KEY and LOGIT_ELASTICSEARCH_HOST are not set. Skipping."
fi

service_account_name="default"

kubectl apply -f <(cat <<EOF
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: ${service_account_name}-user-cluster-admin
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

echo "💤  Waiting for ELBs"
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
    💻  http://concourse.${DOMAIN_NAME}:8080
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

echo "✅  Finished bootstrap procedure"
