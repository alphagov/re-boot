#!/bin/bash

set -euo pipefail

CONCOURSE_HOST=$(kubectl get service/concourse-web -o json | jq -r '.status.loadBalancer.ingress[0].hostname')
CONCOURSE_ATC_USERNAME=$(kubectl get secret concourse-concourse -o json | jq -r '.data."basic-auth-username"')
CONCOURSE_ATC_PASSWORD=$(kubectl get secret concourse-concourse -o json | jq -r '.data."basic-auth-password"')
export CONCOURSE_HOST
export CONCOURSE_ATC_USERNAME
export CONCOURSE_ATC_PASSWORD
