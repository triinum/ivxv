# `collector-admin` — Haldusdaemon (Python)

| | |
|--|--|
| **Kaust koodirepos** | `services/collector-admin/` |
| **Dockerfile** | `services/collector-admin/Dockerfile` (koodirepos) |
| **Image** | `ivxv/collector-admin` |
| **Port (K8s)** | 8080 |
| **Tüüp** | Online mikroteenus |

Operaatori API/UI backend. Privaatne — VPN / port-forward, mitte avalik Ingress.

## Seosed

- Kubernetes baas: `k8s/base/collector-admin/` 
- Avalik ligipääs: **ei** (vaid `proxy` on avalik) — admin erandina privaatne
