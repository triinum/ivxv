# Ülevaade

IVXV e-hääletuse **kogumisteenus** on jaotatud mikroteenusteks. Iga online-teenus
on eraldi juurutatav üksus (oma kood + Dockerfile + Kubernetes Deployment).

```text
                    Valija / kontrollrakendus
                              │
                              ▼
                    ┌───────────────────┐
                    │  proxy (:443)     │  ← ainus avalik teenus
                    │  SNI → backend    │
                    └─────────┬─────────┘
           ┌──────────┬───────┴────────┬────────────┐
           ▼          ▼                ▼            ▼
        choices     voting        verification   mid/smartid/webeid
           │          │                │
           └──────────┴───────┬────────┘
                              ▼
                 storage (+ etcd) · sessionstatus
                 (ainult klastri / VPC sees)
```

## Kihid

| Kiht | Kaust | Mis seal on |
|------|-------|-------------|
| Äriloogika | `services/*` | Teenused ja offline tööriistad |
| Jagatud kood | `common/`, `core/` | Raamistiku ja krüpto |
| Konteinerid | `services/*/Dockerfile`, `docker/` | Tõmmiste ehitus |
| Orkestreerimine | `k8s/` | Kustomize base + keskkonnad |
| Pilve infra | `terraform/` | VPC, ECR, EKS |
| Operatsioonid | `ansible/` | Build, push, `kubectl apply` |

## Miks proxy on keskel?

Proxy lõpetab (või vahendab) TLS-i **SNI** põhjal: klient ütleb, millist
teenust ta tahab, proxy suunab edasi. Seetõttu peab avalik koormusjaotur
säilitama TLS passthrough’i — AWS-is **NLB**, mitte klassikaline HTTP Ingress/ALB.
