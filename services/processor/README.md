# `processor` — Offline: töötlus

| | |
|--|--|
| **Kaust koodirepos** | `services/processor/` |
| **Dockerfile** | `services/processor/Dockerfile` (koodirepos) |
| **Image** | `ivxv/processor` |
| **Port (K8s)** | — |
| **Tüüp** | Offline tööriist (mitte püsiv Deployment) |

Java. Häältekasti valideerimine / anonüümimine pärast hääletust.

## Seosed

- Kubernetes baas: `k8s/base/processor/` (offline — tavaliselt pole Deployment’i)
- Avalik ligipääs: **ei** (vaid `proxy` on avalik)
