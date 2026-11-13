# IVXV arhitektuur — selgitused meeskonnale

See repo **ei sisalda lähtekoodi**. Siin on sama kaustapuu mis koodilahenduses,
aga iga kausta juures on lühike selgitus: mis see on ja miks see olemas on.

Kood ja Dockerfailid: [triinum/ivxv](https://github.com/triinum/ivxv)
(haru `cursor/microservices-dockerfiles-625e`).

## Suur pilt

```text
Internet → NLB / Ingress → proxy (:443)
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
           voting         choices      verification …
              │               │               │
              └───────┬───────┴───────┬───────┘
                      ▼               ▼
                sessionstatus      storage → etcd
```

- **proxy** on ainus avalik sissepääs (SNI/TLS).
- Ülejäänud teenused on klastris privaatsed (`ClusterIP`).
- AWS-is **Ingressit ei ole vaja** — NLB → proxy.
- Terraform loob infra (VPC/ECR/EKS); Ansible ehitab/pushib/rakendab.

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

## Kuidas lugeda

1. See README + [`SERVICES.md`](SERVICES.md)
2. [`arhitektuur/ylevaade.md`](arhitektuur/ylevaade.md) ja [`andmevoog.md`](arhitektuur/andmevoog.md)
3. Vajadusel üksik teenus: `services/<nimi>/README.md`
4. Kubernetes / AWS: `k8s/` ja [`arhitektuur/aws.md`](arhitektuur/aws.md)
5. Infra vs ops: [`arhitektuur/terraform-vs-ansible.md`](arhitektuur/terraform-vs-ansible.md)
