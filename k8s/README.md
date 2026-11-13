# `k8s/` — Kubernetes (Kustomize)

```text
k8s/
  base/<teenus>/     # Deployment + Service
  base/etcd/         # storage backend
  base/config/       # Secret’ite kohatäited (/etc/ivxv)
  overlays/dev|staging|prod|aws/
```

## Overlay erinevused

| | dev | staging | prod | aws |
|---|-----|---------|------|-----|
| Namespace | `ivxv-dev` | `ivxv-staging` | `ivxv-prod` | `ivxv-aws` |
| Replikad | 1 | ~2 | ~3 | ~2–3 |
| Avalik sissepääs | ei | Ingress (proxy + admin) | Ingress | **NLB → ainult proxy** |

## Ingress?

- **aws:** ei kasutata — vt `overlays/aws/README.md` ja `arhitektuur/aws.md`
- **staging/prod:** nginx Ingress + ssl-passthrough (kui pole pilve-NLB-d)
