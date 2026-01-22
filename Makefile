.PHONY: deploy datadog app repos lint format test help kind kind-delete kind-deploy

DEPLOY_CLI = python k8s/deploy.py

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Local development (Kind):"
	@echo "  kind         Create Kind cluster and deploy app"
	@echo "  kind-deploy  Deploy app to existing Kind cluster"
	@echo "  kind-delete  Delete Kind cluster"
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

# Kind local development
kind:
	./kind/setup.sh all

kind-deploy:
	./kind/setup.sh deploy

kind-delete:
	./kind/setup.sh delete
