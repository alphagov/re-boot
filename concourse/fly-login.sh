#!/bin/bash

set -euo pipefail

CONCOURSE_HOST=$(kubectl get service/concourse-web -o json | jq -r '.status.loadBalancer.ingress[0].hostname')
CONCOURSE_ATC_USERNAME=$(kubectl get secret concourse-concourse -o json | jq -r '.data."basic-auth-username"' | base64 -D)
CONCOURSE_ATC_PASSWORD=$(kubectl get secret concourse-concourse -o json | jq -r '.data."basic-auth-password"' | base64 -D)

fly login -c "http://${CONCOURSE_HOST}:8080/" -k -u "$CONCOURSE_ATC_USERNAME" -p "$CONCOURSE_ATC_PASSWORD" -t "$KOPS_CLUSTER_NAME"
