# IVXV arhitektuur 

## Kaustapuu

```text
.
├── README.md                 ← sa oled siin
├── SERVICES.md               ← teenuste tabel (roll + port)
├── SOURCE.md                 ← seos koodirepoga
│
├── arhitektuur/              ← läbilõiked
│   ├── ylevaade.md           ← suur pilt
│   ├── andmevoog.md          ← klient → proxy → teenused
│   ├── aws.md                ← ECR + EKS + NLB
│   └── terraform-vs-ansible.md
│
├── services/                 ← üks kaust = üks teenus (+ oma Dockerfile)
│   ├── proxy/
│   │   └── Dockerfile
│   ├── choices/
│   │   └── Dockerfile
│   ├── voting/
│   │   └── Dockerfile
│   ├── verification/
│   │   └── Dockerfile
│   ├── storage/
│   │   └── Dockerfile
│   ├── sessionstatus/
│   │   └── Dockerfile
│   ├── mid/
│   │   └── Dockerfile
│   ├── smartid/
│   │   └── Dockerfile
│   ├── webeid/
│   │   └── Dockerfile
│   ├── votesorder/
│   │   └── Dockerfile
│   ├── xroad-service/
│   │   └── Dockerfile
│   ├── collector-admin/
│   │   └── Dockerfile
│   ├── key/                  ← offline (Java)
│   │   └── Dockerfile
│   ├── processor/            ← offline
│   │   └── Dockerfile
│   └── auditor/              ← offline
│       └── Dockerfile
│
├── common/                   ← jagatud teegid (ei ole teenus)
├── core/                     ← krüpto (ei ole teenus)
├── docker/                   ← ainult build helper’id (mitte teenuste Dockerfile’id)
│
├── k8s/
│   ├── AWS.md
│   ├── base/                 ← Deployment + Service iga teenuse jaoks
│   │   ├── proxy/
│   │   ├── …                 ← sama nimekiri mis services/
│   │   ├── etcd/
│   │   └── config/           ← Secret’id (/etc/ivxv)
│   └── overlays/
│       ├── dev/              ← 1 replica, ilma avaliku sissepääsuta
│       ├── staging/          ← Ingress
│       ├── prod/             ← Ingress + HA
│       └── aws/              ← ECR; NLB → ainult proxy
│
├── terraform/
│   ├── modules/
│   │   ├── network/          ← VPC (skelett)
│   │   ├── ecr/              ← tõmmiste repositooriumid
│   │   └── eks/              ← klaster (skelett)
│   └── envs/
│       ├── aws-dev/
│       └── aws-prod/
│
└── ansible/
    ├── playbooks/            ← site / build-push / apply
    ├── roles/
    │   ├── ecr_push/         ← docker build + ECR push
    │   └── k8s_apply/        ← kubectl apply -k
    └── inventory/            ← aws_dev / aws_prod muutujad
```

## Kuidas etcd asendada Postgresiga

See **ei ole** lihtsalt seadistuse vahetus. etcd on üks `PutGetter`
protokolle; Postgresi jaoks tuleb kirjutada **uus protokoll** sama liidese peale.

```text
teenused → storage.Client → PutGetter → etcd | file | memory
                                         └── (+ postgres, kui implementeerid)
```

Liides (`common/collector/storage` koodirepos): `Put`, `Get`, `GetWithPrefix`,
`CAS`, `GetWithSerial` (+ valikuline `Batcher` / txn).

### Sammud

1. **Uus pakk** nt `common/collector/storage/postgres/`
   - `init()`: `storage.Register("postgres", …)`
   - tabel nt `(key TEXT PRIMARY KEY, value BYTEA, serial BIGSERIAL)`
   - `Put` = `INSERT` (konflikt → võti juba olemas)
   - `Get` / `GetWithPrefix` (`LIKE 'prefix%'`) / `CAS` (tehing + `UPDATE … WHERE value = old`) / `GetWithSerial`
2. **Technical config**
   ```yaml
   storage:
     protocol: postgres
     conf:
       # DSN / host / SSL
   ```
3. **Infra**
   - EKS-is etcd StatefulSet ära (või ära kasuta)
   - RDS PostgreSQL (Multi-AZ)
   - teenustele DB ligipääs (IRSA / Secret)
4. **`services/storage` roll**
   - etcd bootstrap/prune enam ei vaja
   - õhuke client või otse Postgres (nagu praegu etcd client)

### Oluline

| | |
|--|--|
| Semantika | `Put` **ei kirjuta üle** — ainult uued võtmed; overwrite peamiselt `CAS` |
| Indeksid | prefix-päringud vajavad head `key` indeksit |
| Ei ole SQL ORM | ärikiht jääb võti–väärtus; Postgres on backend |
| Alternatiiv | DynamoDB sobib KV-le sageli loomulikumalt kui SQL |
| Staatus | koodirepos `postgres` protokolli **veel ei ole** — ainult `etcd` / `file` / `memory` |
