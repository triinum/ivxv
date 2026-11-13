# `verification` — Hääle kontroll

| | |
|--|--|
| **Kaust koodirepos** | `services/verification/` |
| **Dockerfile** | `services/verification/Dockerfile` (koodirepos) |
| **Image** | `ivxv/verification` |
| **Port (K8s)** | 443 |
| **Tüüp** | Online mikroteenus |

Toetab kontrollrakendust (verification). Samuti ainult klastris / proxy kaudu.

## Seosed

- Kubernetes baas: `k8s/base/verification/` 
- Avalik ligipääs: **ei** (vaid `proxy` on avalik)
