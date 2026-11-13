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
