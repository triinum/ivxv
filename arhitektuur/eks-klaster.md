# EKS klaster AWS-is — kirjeldus sammude kaupa

Üks **Amazon EKS** klaster (keskkonna kohta, nt `ivxv-aws`). Seal jooksevad
kõik online-mikroteenused pod’idena. Andmebaas (Postgres) on klastrist
**väljas** (RDS), samas VPC-s.

```text
Internet
   │
   ▼
4. Avalik koormusjaotur (NLB :443)
   │
   ▼
3. proxy (EKS pod) — SNI / TLS edasi
   │
   ├─► voting, choices, verification, …
   ├─► mid / smartid / webeid
   └─► sessionstatus, …
          │
          ▼
2. etcd asendus → RDS PostgreSQL (PutGetter)
```

---

## 1. Pod’id klastris

- Üks EKS klaster, üks namespace (nt `ivxv-aws`).
- Iga mikroteenus = üks **Deployment** → sellest tekivad **pod’id**.
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
- Klient avab TLS-i; SNI ütleb, millist teenust tahta (`voting`, `choices`, …).
- Proxy edastab liikluse klastrisiseselt õigele ClusterIP teenusele
  (**TLS passthrough** — NLB/proxy ei lõpeta hääletusraja TLS-i HTTP-na).
- Ilma proxyta ei tohiks ükski teine collector-teenus olla internetist
  otse kättesaadav.

## 4. Avalik koormusjaotur

- AWS **Network Load Balancer (NLB)**, TCP port **443**.
- Tekib, kui `proxy` Service on `type: LoadBalancer` (+ NLB annotatsioonid)
  overlay’s `k8s/overlays/aws`.
- NLB → **ainult proxy** pod’idele.
- DNS (Route 53) osutab NLB hostname’ile.
- **Ingressit / ALB-d AWS teel ei ole vaja** (need segaksid SNI/TLS mudelit).
- `collector-admin` ja kõik teised teenused **ei** saa avalikku LB-d —
  ligipääs VPN / bastion / `kubectl port-forward`.

---

## Kokkuvõte

| # | Osa | Mis see on |
|---|-----|------------|
| 1 | Pod’id | Üks EKS; teenus = Deployment → pod’id; peale proxy kõik ClusterIP |
| 2 | etcd → Postgres | RDS + `protocol: postgres`; etcd aws peal ei kasutata |
| 3 | Proxy | Ainus app-taseme uks; SNI → backend |
| 4 | NLB | Ainus avalik koormusjaotur; TCP 443 → proxy |

Seotud: [`aws.md`](aws.md), koodirepos `k8s/AWS.md` ja `k8s/overlays/aws/`.
