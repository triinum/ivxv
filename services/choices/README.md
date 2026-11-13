# `choices` — Valikute / nimekirjade teenus

| | |
|--|--|
| **Kaust koodirepos** | `services/choices/` |
| **Dockerfile** | `services/choices/Dockerfile` (koodirepos) |
| **Image** | `ivxv/choices` |
| **Port (K8s)** | 443 |
| **Tüüp** | Online mikroteenus |

Annab valijale valikud, ringkonnad jms. Kasutab sessionstatus API-t ja storage’t.

## Seosed

- Kubernetes baas: `k8s/base/choices/` 
- Avalik ligipääs: **ei** (vaid `proxy` on avalik)
