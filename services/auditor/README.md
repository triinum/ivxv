# `auditor` — Offline: audit

| | |
|--|--|
| **Kaust koodirepos** | `services/auditor/` |
| **Dockerfile** | `services/auditor/Dockerfile` (koodirepos) |
| **Image** | `ivxv/auditor` |
| **Port (K8s)** | — |
| **Tüüp** | Offline tööriist (mitte püsiv Deployment) |

Java. Kontrollib shuffle/decrypt **tõestusi** ning processor’i terviklikkust /
auditirada. Ei ole online API.

## Seosed

- Kasutatakse koos `processor` ja `key` tulemustega
- Avalik ligipääs: **ei**
