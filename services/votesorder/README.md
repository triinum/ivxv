# `votesorder` — Häälte order / feed

| | |
|--|--|
| **Kaust koodirepos** | `services/votesorder/` |
| **Dockerfile** | `services/votesorder/Dockerfile` (koodirepos) |
| **Image** | `ivxv/votesorder` |
| **Port (K8s)** | 443 |
| **Tüüp** | Online mikroteenus |

Häälte järjekorra või order-vooga seotud teenus.

## Seosed

- Kubernetes baas: `k8s/base/votesorder/` 
- Avalik ligipääs: **ei** (vaid `proxy` on avalik)
