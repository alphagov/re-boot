#!/usr/bin/env bash
set -ueo pipefail

## RUN IT ONLY ONCE

/usr/bin/env bash -c "kubectl -n default get vault vault-service -o jsonpath='{.status.vaultStatus.sealed[0]}' | xargs -0 -I {} kubectl -n default port-forward {} 8200" &
export VAULT_ADDR="https://localhost:8200"
export VAULT_SKIP_VERIFY="true"

sleep 30
vault_status="$(curl -k -s -o /dev/null -I -w "%{http_code}" -X GET https://127.0.0.1:8200/v1/sys/health)"
if [ $vault_status == 501 ]; then
  vault operator init | tee vault-keys.txt
  vault operator unseal "$(cat vault-keys.txt | awk '/Unseal Key 1/ {print $NF}')"
  vault operator unseal "$(cat vault-keys.txt | awk '/Unseal Key 3/ {print $NF}')"
  vault operator unseal "$(cat vault-keys.txt | awk '/Unseal Key 5/ {print $NF}')"
  sleep 10
fi
if [ $vault_status == 503 ]; then
  vault operator unseal "$(cat vault-keys.txt | awk '/Unseal Key 1/ {print $NF}')"
  vault operator unseal "$(cat vault-keys.txt | awk '/Unseal Key 3/ {print $NF}')"
  vault operator unseal "$(cat vault-keys.txt | awk '/Unseal Key 5/ {print $NF}')"
fi
vault login "$(cat vault-keys.txt | awk '/Initial Root Token/ {print $NF}')"

CHECK_SERVICEACCOUNT=$(kubectl -n default get serviceaccount vault-tokenreview -o jsonpath='{.metadata.name}')
if [ $CHECK_SERVICEACCOUNT != "vault-tokenreview" ]; then
    kubectl -n default create serviceaccount vault-tokenreview
fi
kubectl create -f mgmt/vault-kubernetes-auth.yaml
export SECRET_NAME=$(kubectl -n default get serviceaccount vault-tokenreview -o jsonpath='{.secrets[0].name}')
export TR_ACCOUNT_TOKEN=$(kubectl -n default get secret ${SECRET_NAME} -o jsonpath='{.data.token}' | base64 --decode)
vault auth enable kubernetes
cat ~/.kube/config | awk '/certificate-authority-data/ {print $NF}' | base64 -D > ca.crt
vault write auth/kubernetes/config kubernetes_host="$(kubectl config view --minify | awk '/server/ {print $NF}')" kubernetes_ca_cert=@ca.crt token_reviewer_jwt=$TR_ACCOUNT_TOKEN
vault mount -path=/concourse -description="Secrets for concourse pipelines" generic

vault write sys/policy/concourse-policy policy=@mgmt/vault-policies.hcl
vault write auth/kubernetes/role/concourse-role \
    bound_service_account_names=default \
    bound_service_account_namespaces=default \
    policies=concourse-policy \
    ttl=1h

export SECRET_NAME=$(kubectl -n default get serviceaccount default -o jsonpath='{.secrets[0].name}')
export DEFAULT_ACCOUNT_TOKEN=$(kubectl -n default get secret ${SECRET_NAME} -o jsonpath='{.data.token}' | base64 --decode)
vault write auth/kubernetes/login role=concourse-role jwt=${DEFAULT_ACCOUNT_TOKEN}

echo "${DEFAULT_ACCOUNT_TOKEN}" > account-token.txt
