# `xroad-service` — X-tee sild

| | |
|--|--|
| **Kaust koodirepos** | `services/xroad-service/` |
| **Dockerfile** | `services/xroad-service/Dockerfile` (koodirepos) |
| **Image** | `ivxv/xroad-service` |
| **Port (K8s)** | 8080 |
| **Tüüp** | Online mikroteenus |

Eraldiseisev Go moodul (ei sõltu common/collector’ist samamoodi). Oma config Secret.

## Seosed

- Kubernetes baas: `k8s/base/xroad-service/` 
- Avalik ligipääs: **ei** (vaid `proxy` on avalik)
