# ShopStack — an industrial-style DevOps project

A small e-commerce platform (industrial supplies store) built and operated the way real
companies do it: **Git + GitHub → Docker → GitHub Actions CI/CD → Terraform on AWS → EKS
(Kubernetes) → Prometheus + Grafana**, with an optional **Argo CD GitOps** track.

```
                         ┌──────────────── GitHub ────────────────┐
  git push ──► PR ──►    │  CI: test · lint · build · Trivy scan   │
                         │  CD: push images to ECR · deploy to EKS │
                         │  Terraform: plan on PR · apply on main  │
                         └───────────────┬────────────────────────┘
                                         │ OIDC (no AWS keys stored)
┌────────────────────────── AWS (Terraform) ───────────────────────────────┐
│ VPC (3 AZs, public + private subnets, NAT)        ECR (3 image repos)    │
│ ┌──────────────────────── EKS cluster ─────────────────────────────────┐ │
│ │  NLB ─► ingress-nginx ─┬─► frontend (nginx)                          │ │
│ │                        ├─► product-service (Python/FastAPI) ─► Postgres│
│ │                        └─► order-service  (Node/Express)   ─► Redis  │ │
│ │  kube-prometheus-stack: Prometheus · Alertmanager · Grafana          │ │
│ │  metrics-server (HPA autoscaling) · Argo CD (GitOps, optional)       │ │
│ └──────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────┘
```

## What's in the repo

| Path | Tool | What it does |
|---|---|---|
| `services/` | Docker | 3 microservices, multi-stage, non-root Dockerfiles, unit tests |
| `docker-compose.yml` | Docker Compose | Whole stack + Prometheus + Grafana on your laptop |
| `terraform/bootstrap` | Terraform | S3 + DynamoDB for remote state & locking |
| `terraform/modules` | Terraform | Reusable ECR and GitHub-OIDC modules |
| `terraform/envs/dev` | Terraform | VPC, EKS, EBS CSI, ECR, IAM, Helm add-ons |
| `k8s/base`, `k8s/overlays` | Kubernetes / Kustomize | Deployments, Services, Ingress, HPA, PDB, NetworkPolicy, dev/prod overlays |
| `monitoring/` | Prometheus / Grafana | Scrape config, alert rules, dashboard, kube-prometheus-stack values |
| `.github/workflows` | GitHub Actions | `ci.yml`, `cd.yml`, `terraform.yml` |
| `argocd/` | Argo CD | GitOps Applications (advanced) |
| `docs/ROADMAP.md` | — | Learning path from beginner to advanced + resume bullets |

---

## Phase 1 — Run it locally (free, ~15 min)

Prereqs: Git, Docker Desktop.

```bash
git clone https://github.com/<you>/shopstack.git && cd shopstack
make up            # or: docker compose up --build -d
make load          # in another terminal: generates traffic
```

- App: http://localhost:8080 — click **Buy** to place orders
- Prometheus: http://localhost:9090 → *Status → Targets* (both services should be UP); *Alerts*
- Grafana: http://localhost:3001 (admin/admin) → *Dashboards → ShopStack → ShopStack Overview*

Try breaking it: `docker compose stop order-service` and watch the **ServiceDown** alert fire after 1 minute.

## Phase 2 — Git & GitHub

```bash
git init && git add . && git commit -m "initial commit"
gh repo create shopstack --private --source=. --push    # or create the repo in the GitHub UI
```

Then in GitHub: **Settings → Branches → add a rule for `main`**: require a PR and require the
`CI` checks to pass. From now on, work in branches (`git checkout -b feature/x`) and open PRs —
CI runs tests, lints, builds every image and scans it with Trivy.

## Phase 3 — AWS infrastructure with Terraform

Prereqs: AWS account, `aws configure` done (an admin IAM user for setup), Terraform ≥ 1.6, kubectl, Helm.

> 💰 **Cost:** EKS control plane ($0.10/h) + 2× t3.large spot + NAT gateway + NLB ≈ **$4–6/day**.
> Run `make destroy` when you're done for the day. Set an AWS Budget alert first.

```bash
make bootstrap                 # once: creates state bucket + lock table
# edit terraform/envs/dev/versions.tf → replace <ACCOUNT_ID> in the bucket name
cp terraform/envs/dev/terraform.tfvars.example terraform/envs/dev/terraform.tfvars   # edit it
make infra                     # ~15–20 min: VPC, EKS, ECR, ingress, Prometheus, Grafana, Argo CD
make kubeconfig
kubectl get nodes
```

## Phase 4 — CI/CD to Kubernetes

1. Copy the Terraform outputs into GitHub (**Settings → Secrets and variables → Actions**):

   | Type | Name | Value |
   |---|---|---|
   | Secret | `AWS_ROLE_ARN` | `terraform output github_actions_role_arn` |
   | Secret | `TF_ROLE_ARN` | `terraform output terraform_role_arn` |
   | Secret | `TF_STATE_BUCKET` | output of the bootstrap step |
   | Secret | `GRAFANA_ADMIN_PASSWORD` | same as your tfvars |
   | Variable | `AWS_REGION` | `us-east-1` |
   | Variable | `EKS_CLUSTER` | `shopstack-dev` |

2. Merge any PR to `main`. Flow: **CI passes → CD builds images tagged with the commit SHA →
   pushes to ECR → `kubectl apply -k k8s/overlays/dev` → waits for rollout → smoke test**.
3. `make url` prints the public URL. `make load URL=http://<that-url>` to generate traffic.

## Phase 5 — Observability on Kubernetes

```bash
make grafana      # http://localhost:3001, user admin, password from tfvars
```

- **ShopStack Overview** dashboard (auto-loaded from a ConfigMap) — request rate, p95 latency, errors, orders
- Built-in **Kubernetes / Compute Resources** dashboards — CPU/memory per pod and node
- Alerts in `monitoring/k8s/prometheus-rules.yaml`; wire Alertmanager to Slack in
  `monitoring/k8s/kube-prometheus-stack-values.yaml`

Watch autoscaling: run `make load` from a few terminals and `kubectl -n shopstack-dev get hpa -w`.

## Phase 6 — GitOps with Argo CD (advanced)

1. Edit `repoURL` in `argocd/applications.yaml`, then `kubectl apply -f argocd/applications.yaml`.
2. Set the GitHub variable `DEPLOY_MODE=gitops`. CD now only commits the new image tags to
   `k8s/overlays/dev`; Argo CD notices the commit and syncs the cluster.
3. `make argocd` → https://localhost:8443 (user `admin`). Try `kubectl delete deploy frontend -n shopstack-dev` — Argo CD self-heals it.

## Tear down

```bash
make destroy      # deletes app + LB first, then terraform destroy
```

## Useful commands

```bash
make help                                   # all targets
kubectl -n shopstack-dev get pods,svc,ingress,hpa
kubectl -n shopstack-dev logs deploy/order-service -f
kubectl -n shopstack-dev rollout undo deploy/product-service    # instant rollback
```
