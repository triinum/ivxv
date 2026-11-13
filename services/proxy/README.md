# `proxy` — SNI/TLS dispatcher

| | |
|--|--|
| **Kaust koodirepos** | `services/proxy/` |
| **Dockerfile** | `services/proxy/Dockerfile` (koodirepos) |
| **Image** | `ivxv/proxy` |
| **Port (K8s)** | 443 |
| **Tüüp** | Online mikroteenus |

Ainus teenus, mis peaks olema internetist nähtav. HAProxy + Go kontroller valib SNI põhjal backend’i. AWS-is seisab selle ees NLB (TLS passthrough).

## Seosed

- Kubernetes baas: `k8s/base/proxy/` 
- Avalik ligipääs: **ei** (vaid `proxy` on avalik)
