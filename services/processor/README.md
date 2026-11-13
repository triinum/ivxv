# `processor` — Offline: häältekasti töötlus

| | |
|--|--|
| **Kaust koodirepos** | `services/processor/` |
| **Dockerfile** | `services/processor/Dockerfile` (koodirepos) |
| **Image** | `ivxv/processor` |
| **Port (K8s)** | — |
| **Tüüp** | Offline tööriist (mitte püsiv Deployment) |

Java. Offline toru pärast hääletust: **check → squash → revoke → anonymize**.
Käivitatakse Job’ina / operaatori masinal, mitte pideva EKS teenusena.

## Seosed

- Järgneb sageli `key` (dekrüpteerimine) ja `auditor` (tõestuste kontroll)
- Avalik ligipääs: **ei**
