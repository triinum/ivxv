# IVXV arhitektuuri selgitused (meeskonnale)

See **ei ole** tootmise lähtekood. See on **selgituste repo**: sama kaustastruktuur
mis mikroteenuste lahenduses (`services/`, `k8s/`, `terraform/`, `ansible/`, …),
aga iga tee juures on **ainult tekst**, mis kirjeldab rolli, sõltuvusi ja
otsuseid.

**Lähtekood ja Dockerfailid:** [triinum/ivxv](https://github.com/triinum/ivxv)
(haru `cursor/microservices-dockerfiles-625e`, PR #1).

## Kellele

Meeskonnaliikmed, kes peavad mõistma **kogu arhitektuuri** ilma koodi
läbi lugemata: arendajad, DevOps, QA, tooteomanikud.

## Kuidas lugeda (soovituslik järjekord)

1. [`arhitektuur/ylevaade.md`](arhitektuur/ylevaade.md) — suur pilt
2. [`arhitektuur/andmevoog.md`](arhitektuur/andmevoog.md) — klient → proxy → teenused
3. [`SERVICES.md`](SERVICES.md) — teenuste kaart
4. [`services/`](services/) — iga teenuse üksikleht
5. [`k8s/`](k8s/) — Kubernetes / Kustomize
6. [`arhitektuur/aws.md`](arhitektuur/aws.md) — ECR + EKS + NLB (Ingress **ei** ole AWS-is vaja)
7. [`terraform/`](terraform/) ja [`ansible/`](ansible/) — infra vs ops
8. [`arhitektuur/terraform-vs-ansible.md`](arhitektuur/terraform-vs-ansible.md)

## Kaustapuu (sama mis koodirepos)

```text
services/     # mikroteenused + offline tööriistad (selgitused)
common/       # jagatud teegid
core/         # krüpto
docker/       # build helper’id (mitte teenuste Dockerfile’id)
k8s/          # Kustomize base + overlays
terraform/    # AWS infra skelett
ansible/      # build/push/apply
arhitektuur/  # läbilõiked (voog, AWS, TF vs Ansible)
```

## Olulised põhimõtted (lühidalt)

| Põhimõte | Tähendus |
|----------|----------|
| Üks kaust = üks teenus | `services/<nimi>/` sisaldab koodis ka Dockerfile’i |
| Proxy on ainus avalik uks | Internet → NLB/Ingress → **ainult proxy**; ülejäänud ClusterIP |
| AWS-is pole Ingressit vaja | `LoadBalancer` (NLB) + TLS passthrough proxy peale |
| Terraform ≠ Ansible | TF = VPC/ECR/EKS; Ansible = docker build/push + kubectl apply |
| Offline ≠ online | `key` / `processor` / `auditor` ei jookse pidevalt EKS-is |

## Seotud

- Kood: `https://github.com/triinum/ivxv`
- AWS juhend koodirepos: `k8s/AWS.md`
