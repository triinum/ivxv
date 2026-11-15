# AWS-i evitamise juhend (ECR + EKS)

See juhend selgitab, kuidas IVXV mikroteenused Amazon Web Services’isse viia,
kasutades selles repos juba olevaid `services/*/Dockerfile` faile ja `k8s/`
Kustomize manifestid.

## Mida me teeme (lühidalt)

IVXV kogumisteenus on juba disainitud **mikroteenustena**. Enne AWS samme on
oluline, **millistel üksustel on Dockerfile** ja millistel mitte.

### Dockerfile — mis tuleb / mis ei tule

| | Üksused | Dockerfile? | Miks |
|--|---------|-------------|------|
| **Online mikroteenused** | `proxy`, `choices`, `voting`, `verification`, `storage`, `sessionstatus`, `mid`, `smartid`, `webeid`, `votesorder`, `xroad-service`, `collector-admin` | **Jah** — `services/<nimi>/Dockerfile` | Jooksevad pidevalt EKS-is pod'idena; ECR + Deployment |
| **Offline tööriistad** | `key`, `processor`, `auditor` | **Jah** (image võib olla ECR-is) | Job / operaatori masin; **ei** ole püsivad EKS Deployment'id |
| **Jagatud kood** | `common/`, `core/` | **Ei** | Teegid, mida Docker build sisse kopeerib; iseenesest ei juurutata |
| **Build helper'id** | `docker/` (nt `go-build.sh`) | **Ei** (ei ole teenuse image) | Ainult ehituse abi; teenuse Dockerfile elab `services/` all |

Kokkuvõte: **iga juurutatav teenus / offline app = oma kaust + oma Dockerfile**.
Teegid ja helper'id Dockerfile'i ei saa, sest need pole eraldi konteinerteenused.

### AWS sammud

1. **Ehitame** online-teenuste (ja vajadusel offline) `Dockerfile`-idest
   tõmmised ja **laeme** need **Amazon ECR**-i.
2. **Loome** AWS-is **Amazon EKS** klastri ja **käivitame** online-teenused
   `k8s/` manifestidega (`kubectl apply -k k8s/overlays/aws`).
3. **Suuname** avaliku liikluse läbi koormusjaoturi **ainult proxy teenusele**,
   jättes ülejäänud mikroteenused omavaheliseks suhtluseks **privaatvõrku**.

See järjekord on teadlik: kõigepealt on olemas käivitatavad tõmmised (ECR),
siis koht kus neid jooksutada (EKS), siis võrgureegel et internet ei näeks
midagi peale proxy.

---

## EKS klaster AWS-is — kirjeldus (1–4)

Üks EKS klaster keskkonna kohta. Seal pod’id teenuste kaupa; andmed RDS-is;
internet näeb ainult NLB → proxy.

### 1. Pod’id klastris

- Üks klaster, namespace nt `ivxv-aws` (`k8s/overlays/aws`).
- Iga mikroteenus = **Dockerfile** (`services/<nimi>/`) → ECR image +
  **Deployment** (`k8s/base/<nimi>/`) → **pod’id**.
- Peale proxy on teenused **ClusterIP** (ainult klastri / VPC sees).
- `replicas` / image tag’id tulevad overlay’st `aws`; offline tööriistad
  (`key` / `processor` / `auditor`) ei ole püsivad pod’id.

### 2. etcd asendus

- etcd asemel **Amazon RDS PostgreSQL** (`storage.protocol: postgres`).
- PutGetter liides jääb samaks; URI technical configis (või Secret /
  `IVXV_POSTGRES_URI`).
- Aws overlay **ei** käivita in-cluster Postgresit ega etcd’t — DB on
  hallatud teenus privaatses alamvõrgus.
- `storage` teenus Postgresi režiimis ainult ühenduse / skeemi kontrolliks.

### 3. Proxy

- Ainus rakendustaseme sisenemispunkt.
- Klient TLS + SNI → proxy valib backend’i (`voting`, `choices`, …).
- Liiklus klastrisiseselt ClusterIP nimedele; hääletusrajal TLS passthrough.

### 4. Avalik koormusjaotur

- **NLB** TCP **:443** → ainult `proxy` (`Service type: LoadBalancer`).
- DNS → NLB hostname.
- **Ingressit / ALB-d ei ole vaja** (SNI/TLS mudel).
- Admin ja teised teenused ilma avaliku LB-ta (VPN / bastion / port-forward).

## Miks just nii?

IVXV kogumisteenus on juba disainitud mikroteenustena. **Proxy** on ainus
avalik sisenemispunkt: klient ühendub TLS-iga, paneb SNI-sse soovitud teenuse
nime, ja proxy vahendab liiklust edasi (ilma TLS-sessiooni sisu nägemata).

Seega AWS-is:

| Komponent | Roll |
|-----------|------|
| **ECR** | Iga teenuse Docker-tõmmise hoidla (nagu privaatne Docker Hub) |
| **EKS** | Kubernetes, kus jooksevad kõik pod’id / teenused |
| **NLB → proxy** | Ainus internetist nähtav uks (TCP 443) |
| **ClusterIP teenused** | Ülejäänud mikroteenused — ainult klastri / VPC sees |

```text
REPO
├── services/<teenus>/Dockerfile  ──build/push──►  ECR  ivxv/<teenus>:<tag>
│
└── k8s/base/<teenus>/ + overlays/aws/   ──kubectl apply -k──►  EKS
         Deployment + Service                    namespace ivxv-aws

Internet (valija / kontrollrakendus)
         │
         ▼
┌─────────────────────────┐
│ 4. AWS NLB  (TCP :443)  │  ← avalik koormusjaotur
└────────────┬────────────┘     (proxy Service = LoadBalancer)
             │
             ▼
┌─────────────────────────┐
│ 3. proxy  (EKS pod)     │  ← image: ECR …/ivxv/proxy
│    services/proxy/Dockerfile + k8s/base/proxy/
└────────────┬────────────┘
     ┌───────┼────────┬────────────┐
     ▼       ▼        ▼            ▼
 choices  voting  verification  mid / …     ← ClusterIP pod’id
     │       │        │            │         (1. iga teenus = Deployment)
     └───────┴────┬───┴────────────┘
                  ▼
        2. RDS PostgreSQL / sessionstatus
           (etcd asemel protocol: postgres)
```

**Ära** pane interneti-koormusjaoturit `voting`, `choices`, `storage` ega
muude teenuste ette. Need peavad jääma privaatseks.

`collector-admin` (haldus) jäägu samuti privaatseks — ligipääs VPN-i,
bastioni või `kubectl port-forward` kaudu, mitte avaliku URL-iga.

---

## Terraform + Ansible (soovituslik skelett)

Käsitsi sammud allpool jäävad kehtima. Samas repos on ka **skeletid**:

| Tööriist | Kaust | Roll |
|----------|-------|------|
| **Terraform** | `terraform/` | VPC, ECR repositooriumid, EKS (infra) |
| **Ansible** | `ansible/` | `docker build` / ECR push / `kubectl apply -k` (ops) |

```text
cd terraform/envs/aws-dev && terraform apply   # ECR + EKS
cd ansible && ansible-playbook playbooks/site.yml -e @inventory/group_vars/aws_dev.yml
```

Täpsemalt: `terraform/README.md`, `ansible/README.md`.
`modules/eks` ja `modules/network` on teadlikult pooleli — asenda tootmise
moodulitega enne päris `apply`-d. `modules/ecr` on kasutatav peaaegu kohe.

---

## Eeldused

Enne alustamist oleks vaja:

- AWS konto, õigused ECR / EKS / VPC / ELB peale
- Kohalikud tööriistad: `docker`, `aws` CLI, `kubectl` (soovituslikult ka
  `eksctl` või Terraform klastri loomiseks; vt `terraform/` skelett)
- Repo juurkaustas töötamine (Dockerfile’ide `COPY` teed eeldavad seda)
- IVXV seadistusmaterjal (trust / election / technical jms), mida hiljem
  Secret’ina klastrisse panna

Muutujad, mida allpool asendada:

| Muutuja | Näide | Tähendus |
|---------|-------|----------|
| `ACCOUNT` | `123456789012` | AWS account ID |
| `REGION` | `eu-north-1` | AWS piirkond |
| `TAG` | `a1b2c3d` või `prod` | Tõmmise silt (soovituslikult git SHA) |
| `CLUSTER` | `ivxv` | EKS klastri nimi |

---

## Samm 1 — Docker-tõmmised ECR-i

### Mis toimub?

Iga teenuse kaustas (`services/<nimi>/`) on oma `Dockerfile`. Sellest ehitatakse
konteineritõmmis. ECR on AWS-i privaatne konteineriregister: EKS sõlmed
tõmbavad hiljem tõmmised sealt, mitte su arvutist.

### Kuidas

```bash
ACCOUNT=123456789012
REGION=eu-north-1
TAG=$(git rev-parse --short HEAD)
REGISTRY="${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"

# Logi ECR-i sisse
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

SERVICES=(
  proxy choices voting verification storage sessionstatus
  mid smartid webeid votesorder xroad-service collector-admin
)

for s in "${SERVICES[@]}"; do
  # Loo repositoorium, kui seda veel pole
  aws ecr describe-repositories --repository-names "ivxv/${s}" --region "$REGION" \
    >/dev/null 2>&1 \
    || aws ecr create-repository --repository-name "ivxv/${s}" --region "$REGION"

  # Ehita alati repo JUUREST (-f osutab teenuse Dockerfile'ile)
  docker build -f "services/${s}/Dockerfile" -t "ivxv/${s}:${TAG}" .
  docker tag "ivxv/${s}:${TAG}" "${REGISTRY}/ivxv/${s}:${TAG}"
  docker push "${REGISTRY}/ivxv/${s}:${TAG}"
done
```

### Seosta Kustomize overlay ECR aadressidega

Fail `k8s/overlays/aws/kustomization.yaml` sisaldab kohatäiteid
`ACCOUNT.dkr.ecr.REGION.amazonaws.com/...`. Asenda need päris väärtustega,
nt:

```bash
cd k8s/overlays/aws
for s in proxy choices voting verification storage sessionstatus \
         mid smartid webeid votesorder xroad-service collector-admin; do
  kustomize edit set image "ivxv/${s}=${REGISTRY}/ivxv/${s}:${TAG}"
done
cd -
```

Või muuda `images:` plokki käsitsi redaktoriga.

---

## Samm 2 — EKS klaster

### Mis toimub?

EKS on hallatud Kubernetes. Klastris jooksevad kõik IVXV teenuste pod’id.
Töösõlmed (worker nodes) võiksid olla **privaatsetes** alamvõrkudes; avalikke
alamvõrke vaja peamiselt NLB / NAT jaoks.

### Kuidas (kontseptsioon)

1. Loo VPC (või kasuta olemasolevat) privaatsete + avalike alamvõrkudega.
2. Loo EKS klaster (`eksctl`, Console või IaC).
3. Paigalda / kontrolli lisandmooduleid: VPC CNI, CoreDNS, kube-proxy.
4. **AWS Load Balancer Controller** on soovituslik, et `Service type:
   LoadBalancer` looks lookseks korralikult NLB-ks.
5. Veendu, et sõlmede IAM roll lubab ECR-ist tõmmiseid tõmmata.

Ühenda `kubectl` klastriga:

```bash
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER"
kubectl get nodes
```

---

## Samm 3 — Käivita teenused `k8s/` manifestidega

### Mis toimub?

`k8s/base/` kirjeldab iga teenuse Deployment’i ja Service’i.
`k8s/overlays/aws/` võtab selle baasi ja lisab:

- nimeruumi `ivxv-aws`
- ECR-i image’id
- mõistlikud replica / resource väärtused
- **ainult proxy** peale interneti-suunalise NLB (`LoadBalancer`)

Ülejäänud teenused jäävad `ClusterIP` — neid näeb ainult klaster (privaatvõrk).

### Seadistus (Secret)

Enne kui teenused päriselt tööle jäävad, vaja `/etc/ivxv` sisu (trust,
election, technical jms). Overlay kasutab Secret’it `ivxv-config`
(vt `k8s/base/config/`). Täida see päris materjaliga; muidu protsessid
lõpetavad pärast seadistuse kontrolli.

`xroad-service` kasutab eraldi Secret’it `xroad-service-config`.

### Käivitus

```bash
# Vaata, mis rakendub (kuivjooks)
kubectl kustomize k8s/overlays/aws

# Rakenda kogu stack
kubectl apply -k k8s/overlays/aws

# Olek
kubectl -n ivxv-aws get pods,svc
```

| Overlay väli | Käitumine |
|--------------|-----------|
| Images | ECR (`…amazonaws.com/ivxv/<teenus>:…`) |
| Namespace | `ivxv-aws` |
| Avalik sissepääs | **ainult** `proxy` → NLB, port 443 |
| Teised teenused | `ClusterIP` (privaatne) |
| Admin | **ei** ole avalik Ingress/LB |

---

## Samm 4 — Avalik liiklus ainult proxyle

### Mis toimub?

Kui `proxy` Service on `LoadBalancer` + AWS annotatsioonid, loob AWS
**Network Load Balancer**i TCP 443 peale. NLB ei lõpeta TLS-i — see
edastab baidid proxy pod’ile (*passthrough*), et SNI ja IVXV TLS mudel
säiliks.

### DNS

```bash
kubectl -n ivxv-aws get svc proxy
```

Oota, kuni `EXTERNAL-IP` / hostname ilmub. Seo avalik DNS nimi (nt
`vote.example.ee`) selle NLB külge (Route 53 alias või CNAME).

### Siseturundus klastris

IVXV technical seadistuses peaksid proxy backend’id kasutama **klastri DNS
nimesid**, nt `voting`, `choices`, `verification` (Kubernetes Service’i nimed
nimeruumis `ivxv-aws`), mitte avalikke hostinimesid.

### Haldusliides

```bash
# Ajutine turvaline ligipääs adminile (ainult sinu masinale)
kubectl -n ivxv-aws port-forward svc/collector-admin 8080:8080
```

Tootmises eelistada VPN-i või bastioni, mitte avalikku Ingressit.

---

## Offline tööriistad

`key`, `processor` ja `auditor` **ei** ole pikaajalised online-teenused.
Neid ei pea EKS-is kogu aeg jooksma. Vajadusel:

- ehita / pushi nende Dockerfile’id samuti ECR-i, või
- käivita turvalisel operaatori masinal / CI Job’ina pärast hääletust

---

## Kontrollnimekiri

- [ ] Iga online-teenuse tõmmis on ehitatud `services/<nimi>/Dockerfile`-ist
- [ ] Tõmmised on ECR-is; EKS sõlmed saavad neid tõmmata
- [ ] `k8s/overlays/aws` image’id viitavad õigele `ACCOUNT` / `REGION` / `TAG`
- [ ] `ivxv-config` (ja vajadusel `xroad-service-config`) on täidetud
- [ ] `kubectl apply -k k8s/overlays/aws` õnnestus; pod’id on Ready
- [ ] Ainult `proxy` Service on `LoadBalancer` / internet-facing
- [ ] DNS → NLB :443
- [ ] Teised teenused on `ClusterIP`; technical config kasutab klastri DNS-i
- [ ] `collector-admin` ei ole avalikult avatud

---

## Seotud failid selles repos

| Tee | Sisu |
|-----|------|
| `services/README.md` | Dockerfile’ide struktuur ja build |
| `k8s/README.md` | Kustomize base / overlay ülevaade |
| `k8s/base/<teenus>/` | Deployment + Service baas |
| `k8s/overlays/aws/` | AWS-spetsiifiline overlay (ECR + proxy NLB) |
| `terraform/` | AWS infra skelett (VPC / ECR / EKS) |
| `ansible/` | Build/push/apply playbook’id |
| `docker-compose.yml` | Kohalik (mitte-AWS) jooks |

Küsimuste korral: alusta alati `kubectl kustomize k8s/overlays/aws`
väljundi ülevaatamisest — seal on näha, mis päriselt klastrisse läheb.
