.PHONY: deploy datadog app repos lint format test help kind kind-cilium kind-deploy kind-delete

DEPLOY_CLI = python k8s/deploy.py

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Local development (Kind - $$0/month):"
	@echo "  kind         Create cluster and deploy app"
	@echo "  kind-cilium  Create cluster with Cilium (NetworkPolicy)"
	@echo "  kind-deploy  Deploy to existing cluster"
	@echo "  kind-delete  Delete cluster"
	@echo ""
	@echo "Deployment targets:"
	@echo "  deploy     Run full deployment (repos + datadog + app)"
	@echo "  datadog    Install Datadog via Helm"
	@echo "  app        Deploy AKS Store Demo sample app"
	@echo "  repos      Add and update Helm repositories"
	@echo ""
	@echo "Development targets:"
	@echo "  lint       Run linters (ruff, terraform validate)"
	@echo "  format     Run formatters (ruff, terraform fmt)"
	@echo "  test       Run tests"
	@echo ""
	@echo "Environment variables:"
	@echo "  DD_API_KEY    Datadog API key (required for deploy/datadog)"

deploy:
	$(DEPLOY_CLI) all

datadog:
	$(DEPLOY_CLI) datadog

app:
	$(DEPLOY_CLI) app

repos:
	$(DEPLOY_CLI) repos

lint:
	ruff check k8s/
	cd terraform && terraform fmt -check -recursive

format:
	ruff format k8s/
	ruff check --fix k8s/
	cd terraform && terraform fmt -recursive

test:
	pytest k8s/ -v

# Kind local development ($0/month)
kind:
	python kind/setup.py up

kind-cilium:
	python kind/setup.py up --cilium

kind-deploy:
	python kind/setup.py deploy

kind-delete:
	python kind/setup.py delete
