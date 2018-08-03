#!/usr/bin/env bash
set -ueo pipefail

function cluster_up () {
  kops validate cluster \
       --name=longboy.k8s.local \
       --state=s3://gds-paas-k8s-shared-state &> /dev/null
}

echo '🆗  Starting bootstrap procedure'
echo '❓  Checking if cluster is ready'

if ! cluster_up; then
  echo '‼️  Cluster not ready, exiting';
  exit 1
fi

echo '✅  Cluster is ready, proceeding'

cat <<MSG
🔧  Installing untrusted software
      - prometheus-operator
      - kubernetes-dashboard
MSG

kubectl apply \
  -f https://raw.githubusercontent.com/kubernetes/kops/master/addons/prometheus-operator/v0.19.0.yaml \
  -f https://raw.githubusercontent.com/kubernetes/kops/master/addons/kubernetes-dashboard/v1.8.3.yaml

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

cat <<EOF

-------------------------------------------------------------------------------

💻  In a separate terminal open a tunnel to the cluster with "kubectl proxy"

🔑  You will be able to log in with the following token:

$service_account_token

-------------------------------------------------------------------------------

EOF

echo '✅  Finished bootstrap procedure'
