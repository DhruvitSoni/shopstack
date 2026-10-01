#!/usr/bin/env bash
# Destroys the dev environment. Deletes the app first so the NLB and EBS volumes created
# by Kubernetes are removed before Terraform tears down the VPC (otherwise destroy hangs).
set -euo pipefail
cd "$(dirname "$0")/.."

echo ">> Deleting Kubernetes workloads (frees load balancers & volumes)"
kubectl delete -k k8s/overlays/dev --ignore-not-found || true
kubectl delete -k monitoring --ignore-not-found || true
kubectl -n ingress-nginx delete svc ingress-nginx-controller --ignore-not-found || true
sleep 30

echo ">> terraform destroy"
cd terraform/envs/dev
terraform destroy

echo "Done. The state bucket in terraform/bootstrap is kept on purpose (prevent_destroy)."
