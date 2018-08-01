#!/bin/bash

set -eu

OUT_DIR="./out"
mkdir -p "${OUT_DIR}"

terraform output config-map-aws-auth > "${OUT_DIR}/config-map-aws-auth.yaml"
terraform output kubeconfig > "${OUT_DIR}/kubeconfig"

export KUBECONFIG="${OUT_DIR}/kubeconfig"

kubectl $@
