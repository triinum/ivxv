# `smartid` — Smart-ID abi

| | |
|--|--|
| **Kaust koodirepos** | `services/smartid/` |
| **Dockerfile** | `services/smartid/Dockerfile` (koodirepos) |
| **Image** | `ivxv/smartid` |
| **Port (K8s)** | 443 |
| **Tüüp** | Online mikroteenus |

Autentimine / allkiri Smart-ID kaudu. Mitte avalik LB.

## Seosed

- Kubernetes baas: `k8s/base/smartid/` 
- Avalik ligipääs: **ei** (vaid `proxy` on avalik)
