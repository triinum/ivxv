# IVXV microservices

All deployable units live under `services/<name>/`. Each service directory
contains its own source and a co-located `Dockerfile` so the service can be
developed and released independently.

Dockerfile layout, build patterns, and the service↔image catalog are documented
in **`services/README.md`**.

```text
services/
  proxy/              # Dockerfile + Go module
  choices/
  voting/
  verification/
  storage/
  sessionstatus/      # includes api/ client module
  mid/
  smartid/
  webeid/
  votesorder/
  xroad-service/
  collector-admin/
  key/                # offline Java tool
  processor/
  auditor/
common/               # shared libraries (not a deployable service)
core/                 # crypto library (tivi.io/core)
docker/               # shared build helpers only (no per-service Dockerfiles)
```

Build any service image from the repository root:

```bash
docker build -f services/voting/Dockerfile -t ivxv/voting .
```

Or build everything:

```bash
make docker
```

## Online collector microservices

| Service | Directory | Role |
|---------|-----------|------|
| **proxy** | `services/proxy/` | SNI/TLS dispatcher (HAProxy) |
| **choices** | `services/choices/` | Voter/choices/district lists |
| **voting** | `services/voting/` | Vote acceptance and qualification |
| **verification** | `services/verification/` | Vote verification |
| **storage** | `services/storage/` | Election data storage (etcd) |
| **sessionstatus** | `services/sessionstatus/` | Session status tracking |
| **mid** | `services/mid/` | Mobile-ID helper |
| **smartid** | `services/smartid/` | Smart-ID helper |
| **webeid** | `services/webeid/` | Web eID helper |
| **votesorder** | `services/votesorder/` | Vote order feed |
| **xroad-service** | `services/xroad-service/` | X-Road bridge |
| **collector-admin** | `services/collector-admin/` | Management API / UI backend |

Shared libraries (not services):

- `common/collector` — collector framework
- `services/sessionstatus/api` — session-status client API
- `core` (`tivi.io/core`) — crypto primitives

## Offline processing applications

| Application | Directory | Role |
|-------------|-----------|------|
| **processor** | `services/processor/` | Ballot-box validation / anonymization |
| **key** | `services/key/` | Key generation and decryption |
| **auditor** | `services/auditor/` | Audit / proof verification |

## Independent development

1. Work in `services/<name>/` (and shared libs only when needed).
2. Build with that directory’s `Dockerfile`.
3. Mount election/technical/trust config at `/etc/ivxv` when running.

## Kubernetes

Kustomize manifests live under `k8s/`:

- `k8s/base/<service>/` — Deployment + Service per microservice
- `k8s/overlays/{dev,staging,prod,aws}/` — environment overlays (replicas, resources, image tags, Ingress/NLB)

```bash
kubectl apply -k k8s/overlays/dev
kubectl apply -k k8s/overlays/aws   # ECR + EKS; public traffic only to proxy
```

See `k8s/README.md` and `k8s/AWS.md`.
