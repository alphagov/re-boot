#!/usr/bin/env bash
set -ueo pipefail

SCRIPT_DIR=$(cd "$(dirname "${0}")" && pwd)
ROOT_DIR="${SCRIPT_DIR}/.."

SEALED_VAULT="$(kubectl -n vault get vault vault-service -o jsonpath='{.status.vaultStatus.sealed[0]}')"
ACTIVE_VAULT="$(kubectl -n vault get vault vault-service -o jsonpath='{.status.vaultStatus.active}')"
kubectl -n vault port-forward "${SEALED_VAULT:-${ACTIVE_VAULT}}" 8200 &
export VAULT_ADDR="https://127.0.0.1:8200"
export VAULT_SKIP_VERIFY="true"

sleep 5

if [ ! -z "${SEALED_VAULT}" ]; then
  echo "Unsealing the vault"
  vault_status="$(curl -k -s -o /dev/null -w "%{http_code}" "${VAULT_ADDR}/v1/sys/health")"
  if [ "${vault_status}" == 501 ]; then
    vault operator init | tee "${ROOT_DIR}/assets/vault-keys.txt"
    vault operator unseal "$(awk '/Unseal Key 1/ {print $NF}' "${ROOT_DIR}/assets/vault-keys.txt")"
    vault operator unseal "$(awk '/Unseal Key 3/ {print $NF}' "${ROOT_DIR}/assets/vault-keys.txt")"
    vault operator unseal "$(awk '/Unseal Key 5/ {print $NF}' "${ROOT_DIR}/assets/vault-keys.txt")"
    sleep 10
  fi
  if [ "${vault_status}" == 503 ]; then
    vault operator unseal "$(awk '/Unseal Key 1/ {print $NF}' "${ROOT_DIR}/assets/vault-keys.txt")"
    vault operator unseal "$(awk '/Unseal Key 3/ {print $NF}' "${ROOT_DIR}/assets/vault-keys.txt")"
    vault operator unseal "$(awk '/Unseal Key 5/ {print $NF}' "${ROOT_DIR}/assets/vault-keys.txt")"
  fi
fi

echo "Logging into vault"
vault login "$(awk '/Initial Root Token/ {print $NF}' "${ROOT_DIR}/assets/vault-keys.txt")"

echo "Creating ServiceAccount"
kubectl -n vault get serviceaccount vault-tokenreview &> /dev/null || kubectl -n vault create serviceaccount vault-tokenreview

echo "Creating ServiceAccount"
kubectl -n vault apply -f "${ROOT_DIR}/kubernetes/vault/cluster-role-binding.yaml"

SECRET_NAME=$(kubectl -n vault get serviceaccount vault-tokenreview -o jsonpath='{.secrets[0].name}')
TR_ACCOUNT_TOKEN=$(kubectl -n vault get secret "${SECRET_NAME}" -o jsonpath='{.data.token}' | base64 --decode)
export SECRET_NAME TR_ACCOUNT_TOKEN

if [ ! -z "$(vault auth list | grep kubernetesx)" ]; then
  echo "Enabling kubernetes"
  vault auth enable kubernetes
  awk '/certificate-authority-data/ {print $NF}' ~/.kube/kubeconfig | base64 -D > "${ROOT_DIR}/assets/ca.crt"
  vault write auth/kubernetes/config kubernetes_host="$(kubectl config view --minify | awk '/server/ {print $NF}')" kubernetes_ca_cert="@${ROOT_DIR}/assets/ca.crt" token_reviewer_jwt="${TR_ACCOUNT_TOKEN}"
  vault secrets enable -path=/concourse -description="Secrets for concourse pipelines" generic
fi

echo "Applying policies"
vault write sys/policy/concourse-policy policy="@${ROOT_DIR}/kubernetes/vault/vault-policies.hcl"
vault write auth/kubernetes/role/concourse-role \
  bound_service_account_names=default \
  bound_service_account_namespaces=vault \
  policies=concourse-policy \
  ttl=1h

echo "Preparing environment"

SECRET_NAME=$(kubectl -n vault get serviceaccount default -o jsonpath='{.secrets[0].name}')
DEFAULT_ACCOUNT_TOKEN=$(kubectl -n vault get secret "${SECRET_NAME}" -o jsonpath='{.data.token}' | base64 --decode)
export SECRET_NAME DEFAULT_ACCOUNT_TOKEN

vault write auth/kubernetes/login role=concourse-role jwt="${DEFAULT_ACCOUNT_TOKEN}"

vault token-create --policy=policy-concourse -period="600h" -format=json | jq -r .auth.client_token > "${ROOT_DIR}/assets/account-token.txt"
