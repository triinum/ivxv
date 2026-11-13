# `sessionstatus` — Sessiooni olek

| | |
|--|--|
| **Kaust koodirepos** | `services/sessionstatus/` |
| **Dockerfile** | `services/sessionstatus/Dockerfile` (koodirepos) |
| **Image** | `ivxv/sessionstatus` |
| **Port (K8s)** | 443 |
| **Tüüp** | Online mikroteenus |

Hoiab sessiooni olekut. Sisaldab ka `api/` klientmoodulit, mida teised Go teenused importivad.

## Seosed

- Kubernetes baas: `k8s/base/sessionstatus/` 
- Avalik ligipääs: **ei** (vaid `proxy` on avalik)
