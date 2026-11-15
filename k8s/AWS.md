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

## Samm-sammuline plaan: Test → Dev → Prod

Sama Dockeri tõmmis (silt = git SHA) liigub edasi. AWS teekonnas on kolm
keskkonda. **Ingressit AWS-is ei kasutata** — avalik uks on NLB → proxy.
(On-prem staging/prod overlay’d Ingressiga jäävad valikuliseks; vt allpool.)

| Keskkond | Mis see on | Mida seal tehakse | Arendajale: mida käivitada | Valmis, kui |
|----------|------------|-------------------|----------------------------|-------------|
| **1. Test** | Kontroll **oma arvutis** või automaatses ehitusliinis (CI). AWS-i kontot ega päris klastrit ei kasutata ja päris kasutajad seda ei näe. Siin selgub, kas kood üldse ehitub, konteiner käivitub ja automaattestid on rohelised. **Kes:** arendaja (või CI robot).<br><br>**Millest tõmmis teha (Dockerfile jah):** vt allolevat Testi teenuste tabelit — kõik online mikroteenused + soovi korral offline tööriistad. **Mida mitte ehitada teenusena:** `common/`, `core/`, `docker/` helper’id. | **1)** Igast **online** mikroteenusest tehakse Dockeri tõmmis (`services/<nimi>/Dockerfile`).<br>**2)** Käivitatakse proovimiseks vähemalt üks konteiner (`docker run`).<br>**3)** Käivitatakse salvestuskihi / collector testid kohaliku andmebaasi vastu (nt DynamoDB Local või Postgres).<br>**4)** AWS-i seadistuse faile kontrollitakse kirjavigade suhtes; **midagi AWS-i ei looda**.<br>**5)** Offline tööriistad (`key`, `processor`, `auditor`) võib samuti buildida, mida ei paigaldata püsiva Deployment’ina. | `docker build -f services/<nimi>/Dockerfile -t ivxv/<nimi>:test .` **iga online-teenuse** kohta (nimekiri all).<br>`docker run` smoke’iks; vajadusel DynamoDB Local / Postgres + `go test` (nt `./common/collector/storage/...`).<br>`terraform -chdir=terraform/envs/aws-dev validate` (ja `ansible-lint`).<br>Soovi korral kind: `kubectl apply -k k8s/overlays/dev`.<br>**Ära** tee `docker push` ega `terraform apply`. **Ära** oota eraldi Dockerfile’i kaustadesse `common/`, `core/`, `docker/`. | Kõik **online** mikroteenuste tõmmised ehituvad, konteinerid käivituvad ja automaattestid on rohelised. Terraform/Ansible validate ei anna vigu. |
| **2. Dev** | Esimene **päris AWS-i keskkond** (konto nt `ivxv-dev`). Kogu süsteem töötab seal testandmetega; valijad / avalikkus sinna ei pääse. Siin leitakse vead, mida arvutis ei näe: IAM õigused, turvagrupid, VPC, ECR tõmbamine, NLB → proxy. **Kes:** arendaja ja DevOps. | **1)** Terraformiga luuakse AWS-i võrk (VPC), klaster (EKS), tõmmiste hoidla (ECR), andmebaas (RDS Postgres) ja õigused.<br>**2)** Sama SHA tõmmised lükatakse ECR-i.<br>**3)** Valmis tehakse klastri seadistus ja saladused (`ivxv-config`; hiljem Secrets Manager).<br>**4)** Teenused paigaldatakse EKS-i overlay’ga (NLB ainult proxy ees; Ingressit ei ole).<br>**5)** Tehakse üks läbimängu hääl / smoke ja tulemust võrreldakse oodatuga (sh et AccessDenied / võrguvigu pole). | Kihtide kaupa (tänane skelett): `terraform -chdir=terraform/envs/aws-dev apply` (sihtstruktuuris `infra/envs/dev/` kihid network → data → platform).<br>ECR login; `docker push` pildid sildiga `<git-sha>`.<br>Sea overlay image’id; `kubectl apply -k k8s/overlays/aws` (sihtnimi `k8s/overlays/aws-dev`) **või** `ansible-playbook playbooks/site.yml -e @inventory/group_vars/aws_dev.yml`.<br>Smoke: Ansible/käsitsi kontroll + `kubectl -n ivxv-aws get pods,svc` (kõik Running/Ready; proxy’l EXTERNAL-IP / NLB).<br>DNS või test-host → NLB :443 ainult proxy’le. | Üks hääl / kriitiline voog läheb algusest lõpuni läbi. Tulemus klapib oodatuga. Logides pole `AccessDenied` ega ECR/tõmbamise vigu. Pod’id Ready; ainult proxy on avalik. |
| **3. Prod** | Päris keskkond **eraldi AWS-i kontol** (nt `ivxv-prod`), kõige rangemate turvareeglitega. Siin **ei katsetata** uut koodi — ainult see, mis Dev’is juba läbi sai. **Kes:** DevOps; kinnitab teine inimene ja tellija (nt Valimisteenistus). | **1)** Sama Terraformi kood mis Dev’is, aga muudatuse kinnitab teine inimene (`plan` → ülevaade → `apply` ainult ehitusliinis).<br>**2)** Kasutatakse Dev’is testitud tõmmiseid (sama digest/SHA); uusi pilte Prod’is ei ehitata.<br>**3)** Saladused tulevad turvahoidlast (AWS Secrets Manager), mitte juhuslikest failidest töölaual.<br>**4)** Enne hääletust: taastamisharjutus, koormustest, õiguste ülevaade.<br>**5)** Hääletusajal on muudatused külmutatud (change freeze).<br>**6)** Avalik uks endiselt **NLB → proxy** (Ingressit ei ole). | `terraform -chdir=terraform/envs/aws-prod plan -out=tfplan`, ülevaade, siis `terraform apply tfplan` ainult CI/CD-s.<br>Enne paigaldust: `kubectl kustomize k8s/overlays/aws` (sihtnimi `aws-prod`) — kontrolli image digest’e.<br>Paigaldus kinnitusega (siht: Argo CD / sama Ansible `aws_prod` + teise inimese approve); pildid **digest’i** järgi, mitte ujuv `latest`.<br>**Ära** muuda midagi AWS-i konsoolis ega käsuga `kubectl edit`. | Allolev **Prod kontrollnimekiri** on täidetud ja Valimisteenistuse / tellija kinnitus on olemas. |

### Test: teenuste nimekiri — Dockerfile jah / ei

Testi etapis ehita tõmmised **ainult** nendest, millel on `services/<nimi>/Dockerfile`.
Teegid ja helper’id ei ole mikroteenused ega saa oma juurutustõmmist.

| Tüüp | Nimed | Dockerfile? | Testis mida teha | Hiljem EKS-is? |
|------|-------|-------------|------------------|----------------|
| **Online mikroteenus** | `proxy`, `choices`, `voting`, `verification`, `storage`, `sessionstatus`, `mid`, `smartid`, `webeid`, `votesorder`, `xroad-service`, `collector-admin` | **Jah** — `services/<nimi>/Dockerfile` | `docker build` + smoke (`docker run`); need peavad kõik roheliseks saama | **Jah** — Deployment + Service (proxy → NLB Dev/Prod’is) |
| **Offline tööriist** | `key`, `processor`, `auditor` | **Jah** — sama muster | Soovi korral `docker build` / käivitus Job’ina; **ei** ole kohustuslik iga CI smoke’i osa | **Ei** püsiva Deployment’ina (Job / operaatori masin) |
| **Jagatud teek** | `common/`, `core/` | **Ei** | Kaetakse `go test` / online-teenuste buildiga (COPY Dockerfile’sse); eraldi image’t pole | Ei juurutata eraldi |
| **Build helper** | `docker/` (nt `go-build.sh`) | **Ei** | Kasutatakse buildi ajal; ära märgi seda teenuseks | Ei |

Kokkuvõte Testiks: **12 online mikroteenust peavad buildima**; offline kolm on valikulised;
`common` / `core` / `docker` ei saa oma Dockerfile-teenust.

### Tee-kaart (tänane repo ↔ tabeli nimed)

| Tabelis / siht | Tänases repos |
|----------------|---------------|
| `infra/envs/dev/` kihid network → data → platform | `terraform/envs/aws-dev/` (skelett; kihid veel liidetud) |
| `k8s/overlays/aws-test` | kind + seni `k8s/overlays/dev` või `aws` mall |
| `k8s/overlays/aws-dev` / `aws-prod` | üks mall `k8s/overlays/aws/` (kohanda account, tag, namespace) |
| Ansible smoke | `ansible/playbooks/site.yml` / `apply.yml` (+ laienda `smoke.yml` vajadusel) |
| Andmebaas AWS-is | **RDS PostgreSQL** (`storage.protocol: postgres`); DynamoDB Local on Testi valik/harjutus |

### Proxy ja Ingress selles plaanis

| Keskkond | Proxy | Avalik uks |
|----------|-------|------------|
| Test | Võib olla konteineris / kind’is | Ei (pole internetti) |
| Dev (AWS) | Jah, EKS-is | **NLB → proxy** (Ingress ei) |
| Prod (AWS) | Jah, EKS-is | **NLB → proxy** (Ingress ei) |

On-prem overlay’d `k8s/overlays/staging` ja `k8s/overlays/prod` (Ingress → proxy) jäävad kasutada **ainult** siis, kui juurutate väljaspool AWS-i.

### 0. Test (kohalik / CI)

Eesmärk: tõmmised ehituvad ja teenus käivitub vähemalt konteinerina.

1. Repo juurest: `docker build -f services/<nimi>/Dockerfile -t ivxv/<nimi>:test .`
   või kõik: `make docker` (kui Makefile seda toetab).
2. Smoke: `docker run --rm …` ühe teenusega + `/etc/ivxv` mount (või vähemalt
   et binaar / protsess ei kuku kohe).
3. Soovi korral kind/minikube: `kubectl apply -k k8s/overlays/dev` ja
   `kubectl -n ivxv-dev get pods`.
4. Ära push’i ECR-i enne kui build + smoke on OK.

**Läbiminek:** kõik online-teenuste Dockerfiled buildivad; kriitilised pod’id
(või vähemalt `proxy` + `storage` + üks backend) Ready.

### 1. Dev

Eesmärk: täis stack arenduseks; andmed **in-cluster Postgres** (`base/postgres`).

```bash
# Image tag overlay’s: tavaliselt :dev (või lae registrisse ja set image)
kubectl apply -k k8s/overlays/dev
kubectl -n ivxv-dev get pods,svc
# Täida Secret ivxv-config (trust / election / technical)
```

Kontrolli: technical configis `storage.protocol: postgres`; proxy ClusterIP;
admin mitte avalik.

**Läbiminek:** valija / kontrolli smoke läbi proxy; PutGetter töötab Postgresis.

### 2. Staging

Eesmärk: prod-lähedane (rohkem replica’sid, Ingress), enne päris prod’i.

1. Ehita **sama commit** uuesti (või kasuta sama SHA tag’i).
2. `kustomize edit set image` / overlay tag → `staging`.
3. Seadista `overlays/staging/ingress.yaml` hostid.
4. `kubectl apply -k k8s/overlays/staging`.
5. Integreeritud testid, TLS/SNI läbi Ingressi → proxy.

**Läbiminek:** staging smoke + regressioon OK; config Secretid staging
väärtustega.

### 3. Prod (klaster / on-prem overlay)

Eesmärk: HA (`overlays/prod`, Ingress). Kui prod on **ainult AWS**, võib selle
sammu asendada otse [4]-ga (ikka pärast stagingut).

```bash
kubectl apply -k k8s/overlays/prod
kubectl -n ivxv-prod get pods,ingress
```

**Läbiminek:** change freeze / go-live checklist; rollback plaan (eelmine image
tag).

### 4. AWS (ECR → EKS → NLB)

Eesmärk: sama image AWS-is; **RDS** (mitte in-cluster PG); avalik ainult
**NLB → proxy**.

| Samm | Mis toimub | Kus | Mida teha |
|------|------------|-----|-----------|
| 4a | Luuakse võrk, register, klaster ja hallatud Postgres | AWS / `terraform/` (nt `envs/aws-dev`) | `terraform apply` — VPC + ECR + EKS + RDS |
| 4b | Dockerfile’dest saavad ECR-i tõmmised (sama `TAG`) | Repo juur → ECR | Käsitsi `docker build`/`push` **või** Ansible `ecr_push` |
| 4c | Overlay viitab ECR aadressidele, mitte kohalikele tag’idele | `k8s/overlays/aws` | `kustomize edit set image` **või** sama Ansible roll |
| 4d | Online-teenused käivituvad EKS-is; in-cluster PG/etcd on välja lülitatud | namespace `ivxv-aws` | Secretid käsitsi; `kubectl apply -k` **või** Ansible `k8s_apply` / `site.yml` |
| 4e | Avalik liiklus jõuab ainult proxy’ni; ülejäänu jääb VPC sisse | NLB → `proxy` LoadBalancer | DNS → NLB; SNI smoke test |

AWS-is **eraldi keskkondade** (test/dev/prod) soovitus:

| AWS keskkond | Klaster / konto | Image tag | Märkus |
|--------------|-----------------|-----------|--------|
| aws-test / aws-dev | eraldi EKS (või vähemalt eraldi namespace + RDS) | git SHA või `dev` | `overlays/aws` koopia / patch |
| aws-staging | eraldi | sama SHA mis läbis stagingu | |
| aws-prod | eraldi konto soovituslik | sama SHA pärast staging go | RDS Multi-AZ jms |

Ära kasuta `overlays/prod` Ingressit AWS-is — seal on `overlays/aws` (NLB,
ilma Ingressita). Üks EKS klaster **keskkonna** kohta; ära sega
dev/staging/prod pod’e samasse prod klastrisse ilma selge isoleeringuta.

### Edutamise reegel (lühi)

1. **Build** Dockerfile’dest → üks `TAG` (git SHA).
2. **Test** lokaalselt / CI.
3. **Dev** → **staging** → (prod overlay või) **AWS**.
4. AWS-is: ECR push sama `TAG` → `apply -k overlays/aws` → NLB smoke.
5. Prod’i mine ainult SHA-ga, mis on stagingus (või aws-stagingus) läbi saanud.

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

## Kontrollnimekiri (Test → Dev → Prod)

Märgi linnuke alles siis, kui selle keskkonna kriteerium on täidetud.

### Test

| # | Kontroll |
|---|----------|
| 1 | [ ] Kõik **12 online** mikroteenust on ehitatud (`proxy`, `choices`, `voting`, `verification`, `storage`, `sessionstatus`, `mid`, `smartid`, `webeid`, `votesorder`, `xroad-service`, `collector-admin`). |
| 2 | [ ] Offline (`key`, `processor`, `auditor`) on teadlikult builditud või teadlikult vahele jäetud; `common/` / `core/` / `docker/` jaoks **ei** oodata eraldi Dockerfile’i. |
| 3 | [ ] Konteinerid käivituvad; salvestuskihi / collector testid on rohelised. |
| 4 | [ ] `terraform validate` (ja `ansible-lint`) OK; **ei** ole tehtud `terraform apply` ega ECR `push`. |
| 5 | [ ] Midagi ei ole internetti avatud. |

### Dev (AWS konto `ivxv-dev`)

| # | Kontroll |
|---|----------|
| 1 | [ ] Terraformiga on olemas VPC, ECR, EKS, RDS; tõmmised on ECR-is sildiga `<git-sha>`. |
| 2 | [ ] `k8s/overlays/aws` (aws-dev) `images:` viitavad õigele account / region / SHA. |
| 3 | [ ] `ivxv-config` (ja vajadusel `xroad-service-config`) on täidetud; `storage.protocol: postgres` + RDS URI. |
| 4 | [ ] `kubectl apply -k` (või Ansible `site.yml`) õnnestus; pod’id Ready / Running. |
| 5 | [ ] Ainult `proxy` on LoadBalancer / NLB; DNS või test → NLB :443; teised teenused ClusterIP. |
| 6 | [ ] Üks läbimängu hääl / smoke OK; logides pole `AccessDenied`; `collector-admin` ei ole avalik. |

### Prod (AWS konto `ivxv-prod`)

| # | Kontroll |
|---|----------|
| 1 | [ ] Kasutusel on **sama** Dev’is testitud image digest/SHA; Prod’is uusi pilte ei ehitatud. |
| 2 | [ ] `terraform plan` on teise inimese poolt üle vaadatud; `apply` ainult CI/CD-s. |
| 3 | [ ] Saladused tulevad Secrets Manager’ist (või samaväärsest); `kubectl edit` / konsooli käsitsi muudatusi pole. |
| 4 | [ ] NLB → ainult proxy; teised teenused ClusterIP; admin privaatne. |
| 5 | [ ] Taastamisharjutus / koormus / õiguste ülevaade enne hääletust tehtud; change freeze kehtib. |
| 6 | [ ] Tellija (nt Valimisteenistus) kinnitus olemas. |

---

## Seotud failid selles repos (keskkonna kaupa)

| Keskkond | Tee | Sisu / roll |
|----------|-----|-------------|
| **Kõik** | `services/<nimi>/Dockerfile`, `services/README.md` | Tõmmiste build Test→Prod |
| **Kõik** | `k8s/base/<teenus>/`, `k8s/base/kustomization.yaml` | Deployment + Service baas |
| **Kõik** | `k8s/README.md` | Kustomize ülevaade |
| **Test** | `docker-compose.yml` (kui kasutusel) | Kohalik jooks ilma AWS-ita |
| **Test** | `terraform/envs/aws-*/` (ainult `validate`) | Süntaksikontroll, ilma `apply`-ta |
| **Dev** | `terraform/envs/aws-dev/`, `ansible/inventory/group_vars/aws_dev.yml` | Esimene AWS infra + ops |
| **Dev** | `k8s/overlays/aws/` (siht: `aws-dev`) | ECR + NLB → proxy + RDS |
| **Dev** | `ansible/playbooks/site.yml` | build / push / apply |
| **Prod** | `terraform/envs/aws-prod/`, `ansible/inventory/group_vars/aws_prod.yml` | Eraldi konto, rangem protsess |
| **Prod** | `k8s/overlays/aws/` (siht: `aws-prod`) | Sama mall, prod image digest’id |
| **Valik (mitte-AWS)** | `k8s/overlays/dev\|staging\|prod/` | Kohalik/on-prem; staging/prod kasutavad Ingressi |

Küsimuste korral: `kubectl kustomize k8s/overlays/aws` — seal on näha, mis klastrisse läheb.
