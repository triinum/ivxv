# `voting` — Hääle vastuvõtt

| | |
|--|--|
| **Kaust koodirepos** | `services/voting/` |
| **Dockerfile** | `services/voting/Dockerfile` (koodirepos) |
| **Image** | `ivxv/voting` |
| **Port (K8s)** | 443 |
| **Tüüp** | Online mikroteenus |

Võtab vastu hääle, teeb kvalifikatsiooni. Kriitiline online-teenus; jääb ClusterIP taha.

## Seosed

- Kubernetes baas: `k8s/base/voting/` 
- Avalik ligipääs: **ei** (vaid `proxy` on avalik)
