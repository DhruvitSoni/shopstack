# Learning roadmap

Work through the phases in order. Each one ends with something you can demo.

## Beginner — understand each tool on its own (week 1–2)

| Topic | Do this in the repo | Check yourself |
|---|---|---|
| Git | Branch, commit, open a PR, resolve a merge conflict | Can you explain rebase vs merge? |
| Docker | Read each `Dockerfile`; build one with `docker build`; run it with `docker run -p` | Why multi-stage? Why non-root? |
| Compose | `make up`; read `docker-compose.yml`; break a service and watch Prometheus | How do containers find each other by name? |
| Prometheus | Run queries: `rate(http_requests_total[5m])`, `up` | What's a counter vs histogram? |
| Grafana | Edit a panel; add one for `orders_placed_total` | What does p95 mean? |

## Intermediate — cloud + automation (week 3–4)

| Topic | Do this | Check yourself |
|---|---|---|
| Terraform | Bootstrap state, `plan`, `apply`; read the VPC/EKS modules | What is state and why lock it? |
| AWS | Find your VPC, subnets, NAT, EKS, ECR in the console | Why are nodes in private subnets? |
| Kubernetes | `kubectl get/describe/logs/exec`; scale a deployment; `rollout undo` | Readiness vs liveness probe? |
| Kustomize | Compare `kubectl kustomize k8s/overlays/dev` vs `prod` | Why base + overlays? |
| GitHub Actions | Follow a PR through CI and a merge through CD | How does OIDC replace AWS keys? |

## Advanced — production patterns (week 5+)

Pick a few and add them — each one is a great resume line:

1. **GitOps** — switch `DEPLOY_MODE=gitops`, let Argo CD deploy.
2. **Managed data** — move Postgres to Amazon RDS and Redis to ElastiCache with Terraform.
3. **Secrets** — install External Secrets Operator; read the DB password from AWS Secrets Manager.
4. **TLS + DNS** — cert-manager + Let's Encrypt, Route 53 record for the ingress.
5. **Prod environment** — copy `terraform/envs/dev` to `envs/prod`; add a manual-approval
   GitHub Environment before deploying to prod.
6. **Progressive delivery** — Argo Rollouts canary using Prometheus error rate as the gate.
7. **Logs & traces** — Loki + Promtail for logs, OpenTelemetry + Tempo for traces, all in Grafana.
8. **Policy & security** — Kyverno policies (no `latest` tags, require limits), Checkov/tfsec on Terraform.
9. **Cost** — Karpenter for node autoscaling with spot; Kubecost dashboard.
10. **Chaos** — kill pods/nodes during load and prove the PDBs, HPA and alerts work.

## Resume bullets you can claim when done

- Built a polyglot microservices platform (Python, Node.js) containerized with multi-stage Docker images and deployed to **AWS EKS**.
- Provisioned VPC, EKS, ECR and IAM with **Terraform** modules and S3/DynamoDB remote state.
- Implemented **GitHub Actions** CI/CD with automated tests, Trivy image scanning and keyless AWS access via **OIDC**.
- Deployed with **Kubernetes/Kustomize** (HPA, PDB, NetworkPolicies, probes) and **Argo CD** GitOps.
- Set up **Prometheus + Grafana** monitoring with custom RED-metrics dashboards and alerting.

## Interview questions this project prepares you for

- Walk me through what happens from `git push` to a pod running in production.
- How do you roll back a bad deploy? (`kubectl rollout undo`, or `git revert` in GitOps)
- How do you keep secrets out of Git?
- How would you make this highly available / cheaper / more secure?
- An alert fires for high latency at 3 AM — how do you debug it?
