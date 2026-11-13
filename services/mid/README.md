# `mid` — Mobiil-ID abi

| | |
|--|--|
| **Kaust koodirepos** | `services/mid/` |
| **Dockerfile** | `services/mid/Dockerfile` (koodirepos) |
| **Image** | `ivxv/mid` |
| **Port (K8s)** | 443 |
| **Tüüp** | Online mikroteenus |

Autentimine / allkiri Mobiil-ID kaudu. Mitte avalik LB.

## Seosed

- Kubernetes baas: `k8s/base/mid/` 
- Avalik ligipääs: **ei** (vaid `proxy` on avalik)
