#!/bin/bash
set -eu

: DEPLOY_ENV

SCRIPT="${0}"
SCRIPT_DIR=$(cd "$(dirname "${0}")" && pwd)

ACTION="${1:-}"
KEYNAME="${2:-id_rsa}"

case "${ACTION}" in
create)
  echo -n "Generating new SSH key... "

  ssh-keygen -t rsa -b 4096 -C "${DEPLOY_ENV}-bosh" -N '' -f "${SCRIPT_DIR}/../assets/${KEYNAME}" > /dev/null

  echo "DONE"
  ;;
delete)
  echo -n "Deleting SSH key... "

  rm "${SCRIPT_DIR}/../assets/${KEYNAME}"

  echo "DONE"
  ;;
*)
  echo "ACTION needs to be provided. Use: ${SCRIPT} <create|delete> [key-name]"
  exit 1
  ;;
esac
