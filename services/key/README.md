# `key` — Offline: võtmed

| | |
|--|--|
| **Kaust koodirepos** | `services/key/` |
| **Dockerfile** | `services/key/Dockerfile` (koodirepos) |
| **Image** | `ivxv/key` |
| **Port (K8s)** | — |
| **Tüüp** | Offline tööriist (mitte püsiv Deployment) |

Java. Võtmete genereerimine ja dekrüpteerimine. Job / kohalik jooks.

## Seosed

- Kubernetes baas: `k8s/base/key/` (offline — tavaliselt pole Deployment’i)
- Avalik ligipääs: **ei** (vaid `proxy` on avalik)
