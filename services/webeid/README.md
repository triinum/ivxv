# `webeid` — Web eID abi

| | |
|--|--|
| **Kaust koodirepos** | `services/webeid/` |
| **Dockerfile** | `services/webeid/Dockerfile` (koodirepos) |
| **Image** | `ivxv/webeid` |
| **Port (K8s)** | 443 |
| **Tüüp** | Online mikroteenus |

Veebi-eID voog. Mitte avalik LB.

## Seosed

- Kubernetes baas: `k8s/base/webeid/` 
- Avalik ligipääs: **ei** (vaid `proxy` on avalik)
