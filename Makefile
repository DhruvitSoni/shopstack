.DEFAULT_GOAL := help
TF_DIR := terraform/envs/dev
NS     := shopstack-dev

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n",$$1,$$2}'

# ---------- Local
up: ## Run the full stack locally (app + Prometheus + Grafana)
	docker compose up --build -d
	@echo "App http://localhost:8080 | Prometheus http://localhost:9090 | Grafana http://localhost:3001"

down: ## Stop the local stack
	docker compose down -v

test: ## Run unit tests for both services
	cd services/product-service && pytest -q
	cd services/order-service && npm test

load: ## Generate traffic so dashboards have data (URL=http://localhost:8080)
	./scripts/load.sh $(or $(URL),http://localhost:8080)

# ---------- AWS
bootstrap: ## One-time: create S3/DynamoDB for Terraform state
	cd terraform/bootstrap && terraform init && terraform apply

infra: ## Create VPC + EKS + ECR + monitoring on AWS
	cd $(TF_DIR) && terraform init && terraform apply

kubeconfig: ## Point kubectl at the EKS cluster
	$$(cd $(TF_DIR) && terraform output -raw kubeconfig_command)

deploy: ## Manual deploy of the dev overlay + monitoring rules/dashboards
	kubectl apply -k k8s/overlays/dev
	kubectl apply -k monitoring

url: ## Print the public app URL
	@echo "http://$$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"

grafana: ## Port-forward Grafana to http://localhost:3001
	kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3001:80

argocd: ## Port-forward Argo CD to https://localhost:8443 and print admin password
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
	kubectl -n argocd port-forward svc/argocd-server 8443:443

destroy: ## Tear everything down (stops AWS billing)
	./scripts/teardown.sh

.PHONY: help up down test load bootstrap infra kubeconfig deploy url grafana argocd destroy
