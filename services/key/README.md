# `key` — Offline: võtmed

| | |
|--|--|
| **Kaust koodirepos** | `services/key/` |
| **Dockerfile** | `services/key/Dockerfile` (koodirepos) |
| **Image** | `ivxv/key` |
| **Port (K8s)** | — |
| **Tüüp** | Offline tööriist (mitte püsiv Deployment) |

Java. Võtmeparameetrid / genereerimine (sh nutikaardi jagud), testvõti, anonüümse
häältekasti **dekrüpteerimine** koos tõestustega. Job / kohalik jooks.

## Seosed

- Sisend tihti `processor` väljundist; kontrollib `auditor`
- Avalik ligipääs: **ei**
