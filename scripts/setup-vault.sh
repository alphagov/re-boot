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

echo "Enabling kubernetes auth in vault"

vault auth disable cert
vault auth enable cert

vault secrets disable /concourse
vault secrets enable -path=/concourse -description="Secrets for concourse pipelines" generic

echo "Applying policies"
vault write sys/policy/concourse-policy policy="@${ROOT_DIR}/kubernetes/vault/vault-policies.hcl"
vault write auth/cert/certs/concourse display_name=concourse policies=concourse-policy certificate="@${ROOT_DIR}/assets/concourse/vault-cert.pem"
