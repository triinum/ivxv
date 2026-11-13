# `auditor` — Offline: audit

| | |
|--|--|
| **Kaust koodirepos** | `services/auditor/` |
| **Dockerfile** | `services/auditor/Dockerfile` (koodirepos) |
| **Image** | `ivxv/auditor` |
| **Port (K8s)** | — |
| **Tüüp** | Offline tööriist (mitte püsiv Deployment) |

Java. Tõestuste / auditi kontroll.

## Seosed

- Kubernetes baas: `k8s/base/auditor/` (offline — tavaliselt pole Deployment’i)
- Avalik ligipääs: **ei** (vaid `proxy` on avalik)
