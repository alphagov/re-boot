shellcheck:
	shellcheck scripts/*.sh

format:
	terraform fmt terraform/

bootstrap:
	./scripts/terraform-backend.sh create

init:
	./scripts/terraform-backend.sh init

plan: init
	./scripts/terraform-run.sh plan

apply:  init
	./scripts/terraform-run.sh apply

