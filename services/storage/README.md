# `storage` — Andmesalvesti (PutGetter)

| | |
|--|--|
| **Kaust koodirepos** | `services/storage/` |
| **Dockerfile** | `services/storage/Dockerfile` (koodirepos) |
| **Image** | `ivxv/storage` |
| **Port (K8s)** | 2379 |
| **Tüüp** | Online mikroteenus |

Abstraktsioon valimiste andmete hoidmiseks. Klassikaliselt etcd; võib asendada pilves DynamoDB või Postgres’iga, kui PutGetter backend seda toetab.

## Seosed

- Kubernetes baas: `k8s/base/storage/` 
- Avalik ligipääs: **ei** (vaid `proxy` on avalik)
