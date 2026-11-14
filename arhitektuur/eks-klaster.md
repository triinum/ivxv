# EKS klaster AWS-is — kirjeldus sammude kaupa

Üks **Amazon EKS** klaster (keskkonna kohta, nt `ivxv-aws`). Seal jooksevad
kõik online-mikroteenused pod’idena. Andmebaas (Postgres) on klastrist
**väljas** (RDS), samas VPC-s.

## Joonis (repo → ECR/EKS → liiklus)

```text
REPO
├── services/<teenus>/Dockerfile     ──build/push──►  ECR  ivxv/<teenus>:<tag>
│      proxy, voting, choices, …
│
└── k8s/
    ├── base/<teenus>/               Deployment + Service (pod’i kirjeldus)
    └── overlays/aws/                ECR image’id, replicas, NLB→proxy
              │
              │  kubectl apply -k
              ▼
         EKS klaster (namespace ivxv-aws)
              │
Internet      │
   │          │
   ▼          │
4. NLB :443 ──┼──► 3. proxy pod(id)     ← LoadBalancer Service
              │         │ SNI
              │         ├─► voting / choices / verification / …  (ClusterIP)
              │         ├─► mid / smartid / webeid
              │         └─► sessionstatus / …
              │                    │
              │                    ▼
              │         2. RDS PostgreSQL   ← etcd asendus (PutGetter)
              │
              └── 1. iga teenus = Deployment → pod’id
                   (image tuleb ECR-ist; spek tuleb k8s manifestidest)
```

| Repo fail | Mis roll |
|-----------|----------|
| `services/<nimi>/Dockerfile` | Ehitab tõmmise → ECR |
| `k8s/base/<nimi>/` | Deployment + Service baas |
| `k8s/overlays/aws/` | AWS: image tag’id, NLB ainult proxy’l, RDS (mitte in-cluster DB) |

---

## 1. Pod’id klastris

- Üks EKS klaster, üks namespace (nt `ivxv-aws`).
- Iga mikroteenus = üks **Deployment** (`k8s/base/<teenus>/deployment.yaml`)
  → sellest tekivad **pod’id**; image = ECR tõmmis Dockerfile’ist.
- Näited: `proxy`, `voting`, `choices`, `verification`, `storage`,
  `sessionstatus`, `mid`, `smartid`, `webeid`, `votesorder`,
  `xroad-service`, `collector-admin`.
- Ülejäänud teenused peale proxy on **ClusterIP** — neid näeb ainult klaster
  / VPC, mitte internet.
- `replicas` määrab, mitu pod’i teenusel jookseb (overlay `aws`).
- Offline tööriistad (`key`, `processor`, `auditor`) **ei** ole püsivad pod’id.

## 2. etcd asendus

- Klassikaliselt hoidis `storage` andmeid **etcd** klastris.
- AWS-is asendame etcd **PostgreSQL**-iga (tavaliselt **Amazon RDS**).
- Teenused kasutavad sama `PutGetter` liidest; technical configis:
  `storage.protocol: postgres` + RDS URI.
- In-cluster Postgres / etcd aws overlay’s **ei** jookse — DB on hallatud
  teenus privaatses alamvõrgus.
- `storage` teenus Postgresi režiimis ainult kontrollib ühendust / skeemi;
  etcd protsessi ei käivita.

## 3. Proxy

- **proxy** on IVXV ainus loogiline sisenemispunkt.
- Dockerfile: `services/proxy/Dockerfile` → image `ivxv/proxy`.
- Manifest: `k8s/base/proxy/` + aws patch teeb Service’ist `LoadBalancer`.
- Klient avab TLS-i; SNI ütleb, millist teenust tahta (`voting`, `choices`, …).
- Proxy edastab liikluse klastrisiseselt õigele ClusterIP teenusele
  (**TLS passthrough** — NLB/proxy ei lõpeta hääletusraja TLS-i HTTP-na).

## 4. Avalik koormusjaotur

- AWS **Network Load Balancer (NLB)**, TCP port **443**.
- Tekib, kui `proxy` Service on `type: LoadBalancer` (+ NLB annotatsioonid)
  overlay’s `k8s/overlays/aws` (nt `patches/patch-proxy-service.yaml`).
- NLB → **ainult proxy** pod’idele.
- DNS (Route 53) osutab NLB hostname’ile.
- **Ingressit / ALB-d AWS teel ei ole vaja** (need segaksid SNI/TLS mudelit).
- `collector-admin` ja kõik teised teenused **ei** saa avalikku LB-d —
  ligipääs VPN / bastion / `kubectl port-forward`.

---

## Kokkuvõte

| # | Osa | Mis see on |
|---|-----|------------|
| — | Dockerfile | `services/<nimi>/Dockerfile` → ECR image |
| — | Manifestid | `k8s/base` + `overlays/aws` → Deployment/Service → pod’id |
| 1 | Pod’id | Üks EKS; teenus = Deployment → pod’id; peale proxy kõik ClusterIP |
| 2 | etcd → Postgres | RDS + `protocol: postgres`; etcd aws peal ei kasutata |
| 3 | Proxy | Ainus app-taseme uks; SNI → backend |
| 4 | NLB | Ainus avalik koormusjaotur; TCP 443 → proxy |

Seotud: [`aws.md`](aws.md), koodirepos `k8s/AWS.md` ja `k8s/overlays/aws/`.
