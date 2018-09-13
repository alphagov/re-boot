.PHONY: up down converge
.DEFAULT_GOAL := help

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

check-env:
	$(if ${DEPLOY_ENV},,$(error Must pass DEPLOY_ENV=<name>))
	$(if ${AWS_SESSION_TOKEN},,$(error You must be STS authorised with AWS to continue.))
	@true

lint:
	shellcheck ./scripts/*.sh

.PHONY: dev
dev: ## Set Environment to DEV
	$(eval export AWS_DEFAULT_REGION ?= eu-west-2)
	$(eval export AWS_ACCOUNT=dev)
	@true

up: check-env ## Spin up kubernetes cluster
	@./scripts/create-cluster.sh ${AWS_ACCOUNT} ${DEPLOY_ENV}

down: check-env ## Tear down kubernetes cluster
	@./scripts/delete-cluster.sh ${AWS_ACCOUNT} ${DEPLOY_ENV}

converge: check-env ## Apply default environment to previously created kubernetes cluster
	@./scripts/converge-cluster.sh ${AWS_ACCOUNT} ${DEPLOY_ENV}
