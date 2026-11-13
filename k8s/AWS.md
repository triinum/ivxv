# AWS deployment (ECR + EKS)

Yes — the intended path on AWS is:

1. **Build** each service image from `services/<name>/Dockerfile`
2. **Push** images to **Amazon ECR**
3. **Create** an **Amazon EKS** cluster
4. **Apply** the existing Kustomize manifests (`kubectl apply -k …`)
5. **Expose** public traffic **only** through the **proxy** (load balancer); keep all other microservices on the cluster-private network (`ClusterIP`)

That matches IVXV’s design: proxy is the single internet entry point (SNI/TLS dispatch); choices, voting, verification, storage, mid, … talk to each other inside the VPC.

```text
Internet
   │
   ▼
AWS NLB (TCP 443) ──► proxy  ──SNI/TLS──► choices / voting / …
                         │                    mid / smartid / …
                         └──────────────────► verification / …
Private VPC / EKS only:   storage, sessionstatus, votesorder,
                          xroad-service, collector-admin, etcd
```

## 1. Build and push to ECR

Replace `ACCOUNT`, `REGION`, and `TAG` (example: `prod` or a git SHA).

```bash
ACCOUNT=123456789012
REGION=eu-north-1
TAG=$(git rev-parse --short HEAD)
REGISTRY="${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"

aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

SERVICES=(
  proxy choices voting verification storage sessionstatus
  mid smartid webeid votesorder xroad-service collector-admin
)

for s in "${SERVICES[@]}"; do
  aws ecr describe-repositories --repository-names "ivxv/${s}" --region "$REGION" \
    >/dev/null 2>&1 || aws ecr create-repository --repository-name "ivxv/${s}" --region "$REGION"

  docker build -f "services/${s}/Dockerfile" -t "ivxv/${s}:${TAG}" .
  docker tag "ivxv/${s}:${TAG}" "${REGISTRY}/ivxv/${s}:${TAG}"
  docker push "${REGISTRY}/ivxv/${s}:${TAG}"
done
```

Point the AWS overlay at your registry (edit `k8s/overlays/aws/kustomization.yaml` `images:` block, or):

```bash
cd k8s/overlays/aws
# example for one service; repeat / script for all
kustomize edit set image "ivxv/proxy=${REGISTRY}/ivxv/proxy:${TAG}"
```

## 2. EKS cluster

Create a cluster in private subnets for worker nodes (public subnets only as needed for the NLB). Wire `kubectl`:

```bash
aws eks update-kubeconfig --region "$REGION" --name ivxv
```

Install the usual cluster add-ons (VPC CNI, CoreDNS, kube-proxy; for NLB, the AWS Load Balancer Controller is recommended).

## 3. Apply Kubernetes manifests

Populate `ivxv-config` (and `xroad-service-config`) Secrets with real election material before expecting services to stay up — see `base/config/`.

```bash
# Preview
kubectl kustomize k8s/overlays/aws

# Deploy full stack into namespace ivxv-aws
kubectl apply -k k8s/overlays/aws
```

What this overlay does on top of `k8s/base`:

| Concern | Behaviour |
|---------|-----------|
| Images | `ACCOUNT.dkr.ecr.REGION.amazonaws.com/ivxv/<service>:…` |
| Namespace | `ivxv-aws` |
| Public entry | **only** `proxy` → `Service type: LoadBalancer` (AWS NLB, TCP 443) |
| Other services | remain `ClusterIP` (private) |
| Admin UI | **not** published on the internet (use VPN / bastion / port-forward) |

## 4. Public traffic only to proxy

After apply, wait for the NLB hostname:

```bash
kubectl -n ivxv-aws get svc proxy
```

Point your public DNS (e.g. vote.example.ee) at that NLB. Clients connect with TLS SNI as in IVXV; the proxy forwards to internal services without terminating the voter TLS session in the load balancer (TCP passthrough).

Do **not** put an internet-facing load balancer in front of `voting`, `choices`, `storage`, etc. Those must stay private.

`collector-admin` should stay private as well (management plane). Access via VPN, SSM bastion, or:

```bash
kubectl -n ivxv-aws port-forward svc/collector-admin 8080:8080
```

## Checklist

- [ ] Every online service image built from `services/<name>/Dockerfile` and pushed to ECR
- [ ] EKS nodes can pull from ECR (node role / IRSA image pull)
- [ ] `ivxv-config` Secret filled
- [ ] `kubectl apply -k k8s/overlays/aws` succeeds
- [ ] Only `proxy` has an internet-facing LB
- [ ] DNS → NLB on port 443
- [ ] Technical config inside IVXV uses in-cluster DNS names (`voting`, `choices`, …) as backends for the proxy

Offline tools (`key`, `processor`, `auditor`) are not part of this long-running stack; run them as Jobs/CI or on secured operators’ hosts from their ECR images if needed.
