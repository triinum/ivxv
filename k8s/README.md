# Kubernetes manifests (Kustomize)

IVXV collector microservices are packaged as Kustomize **base** resources with
environment **overlays**.

```text
k8s/
  base/                     # shared desired state per service
    <service>/              # Deployment + Service (apply alone if needed)
    etcd/                   # storage backend
    config/                 # placeholder Secrets for /etc/ivxv
    kustomization.yaml      # full collector stack
  overlays/
    dev/                    # local / CI-like: 1 replica, light resources
    staging/                # more replicas + Ingress
    prod/                   # HA replicas + Ingress
```

## Services covered

| Service | Port | Base path |
|---------|------|-----------|
| proxy | 443 | `base/proxy` |
| choices | 443 | `base/choices` |
| voting | 443 | `base/voting` |
| verification | 443 | `base/verification` |
| storage | 2379 | `base/storage` |
| sessionstatus | 443 | `base/sessionstatus` |
| mid | 443 | `base/mid` |
| smartid | 443 | `base/smartid` |
| webeid | 443 | `base/webeid` |
| votesorder | 443 | `base/votesorder` |
| xroad-service | 8080 | `base/xroad-service` |
| collector-admin | 8080 | `base/collector-admin` |
| etcd | 2379/2380 | `base/etcd` |

Offline tools (`key`, `processor`, `auditor`) are not long-running Deployments;
run them as Jobs/CI or locally from their Docker images.

## Apply

Single service (base only):

```bash
kubectl apply -k k8s/base/voting
```

Full stack for an environment:

```bash
kubectl apply -k k8s/overlays/dev
kubectl apply -k k8s/overlays/staging
kubectl apply -k k8s/overlays/prod
```

Preview:

```bash
kubectl kustomize k8s/overlays/prod
```

## Configuration

Collector services expect IVXV configuration under `/etc/ivxv`. Populate the
`ivxv-config` Secret (see `base/config/secret.yaml`) with trust / election /
technical containers before pods can serve traffic.

`xroad-service` uses Secret `xroad-service-config` mounted at
`/etc/xroad-service`.

## Overlay differences

| | dev | staging | prod |
|---|-----|---------|------|
| namespace | `ivxv-dev` | `ivxv-staging` | `ivxv-prod` |
| replicas | 1 | 2 (most) | 3 (most) |
| image tag | `dev` | `staging` | `prod` |
| Ingress | no | proxy + admin | proxy + admin |

Edit hosts in `overlays/*/ingress.yaml` before using staging/prod Ingress.
