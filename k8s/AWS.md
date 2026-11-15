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

## Samm-sammuline plaan: test → dev → staging → prod → AWS

Sama Dockeri tõmmis (soovituslikult märgitud giti commit’i lühikese SHA-ga)
liigub keskkonnast keskkonda edasi. Igas järgmises keskkonnas jookseb
põhimõtteliselt sama tarkvara; muutub peamiselt see, **millises Kubernetes
overlay’s** see käivitatakse, **kus andmebaas elab** ja **kas proxy on
väljastpoolt kättesaadav**. Allolevas tabelis on ainult keskkonnad. Veerg
„Mis toimub“ selgitab olukorda täislausetega; veerg „Mida teha“ ütleb
konkreetsed tegevused.

| Keskkond | Mis toimub | Mida teha |
|----------|------------|-----------|
| **Test** | Selles etapis sa veel ei juuruta süsteemi päris kasutajatele. Sa kontrollid oma masinas või CI-s, et iga online-teenuse kaustas olev `Dockerfile` ehitsub veatult Dockeri tõmmiseks ja et konteiner üldse käivitub. Amazon ECR-i sa tõmmiseid veel ei lae ja päris Kubernetes klastrit sa tavaliselt veel ei vaja. Proxy’t ega teisi teenuseid internetti ei avata. Repositooriumis ei ole eraldi kausta `overlays/test`, sest „test“ tähendab siin just build’i ja kiiret smoke-kontrolli enne, kui midagi `dev` keskkonda pannakse. | Ehita repo juurest iga online-teenus käsuga `docker build -f services/<nimi>/Dockerfile -t ivxv/<nimi>:test .` (kaasa arvatud `proxy`). Käivita vähemalt üks konteiner smoke’iks (`docker run`); vajadusel monteeri seadistus kataloogi `/etc/ivxv`. Kui tahad klastrit juba proovida, võid tõsta üles kind või minikube ja rakendada ajutiselt `kubectl apply -k k8s/overlays/dev`. Ära tee `docker push` ECR-i enne, kui build ja smoke on korras. |
| **Dev** | Arenduskeskkonnas käivitad kogu kogumisteenuse stack’i Kubernetes’is. Kustomize loeb kõigepealt ühise baasi `k8s/base/` (seal on iga teenuse Deployment ja Service, config Secret’i stub ja klastri-sisene Postgres) ning paneb peale keskkonna erinevused failist `k8s/overlays/dev`. Tulemuseks on nimeruum `ivxv-dev`, tavaliselt üks replica teenuse kohta, tõmmise silt `:dev` ja kerged ressursipiirangud. Proxy teenus jookseb nagu teisedki, aga selle Service on tüüpi ClusterIP: see tähendab, et väljastpoolt klastrit otse ühenduda ei saa ja testimiseks kasutad `kubectl port-forward`. Hääletusandmed kirjutatakse klastris jooksvasse Postgresisse, mitte Amazoni RDS-i. Eesmärk on, et arendaja saaks kogu ahela turvaliselt ja odavalt proovida. | Ehita või märgi tõmmised sildiga `:dev` (või suuna overlay `images:` plokk oma registrile). Loo või täida Secret `ivxv-config` trust-, election- ja technical-materjaliga; technical configis peab olema `storage.protocol: postgres`. Käivita stack käsuga `kubectl apply -k k8s/overlays/dev`. Kontrolli olekut: `kubectl -n ivxv-dev get pods,svc`. Proxy testimiseks tee `kubectl -n ivxv-dev port-forward svc/proxy 8443:443` ja proovi SNI/smoke läbi selle ühenduse. Loe etapp lõppenuks, kui proxy, storage ja vähemalt üks backend on Ready ning PutGetter Postgresiga töötab. |
| **Staging** | Staging on „proovi enne päris prod’i“ keskkond. Siia lähevad **samad** tõmmised (sama git SHA), mis testis ja dev’is juba läbi said — uut koodi siin ei leiutata. Overlay `k8s/overlays/staging` võtab sama baasi, aga seab nimeruumiks `ivxv-staging`, tõstab replica’te arvu, paneb image sildiks `:staging` ja lisab faili `ingress.yaml`. Alates sellest etapist tuleb väline HTTPS liiklus klastrisse Ingressi kaudu ja Ingress suunab selle **proxy** teenusele; adminile on eraldi Ingress. Andmebaas on endiselt klastri-sisene Postgres. Siin tehakse integatsioon- ja regressioonteste peaaegu prod-sarnases paigutuses, et vead ei jõuaks tootmisse. | Kasuta sama SHA tõmmist; sea overlay’s image tag väärtuseks `staging` (`images:` plokk või `kustomize edit set image`). Kirjuta `k8s/overlays/staging/ingress.yaml` sisse päris hostinimed. Uuenda Secretid stagingu seadistustega. Rakenda keskkond: `kubectl apply -k k8s/overlays/staging`. Testi TLS-i ja SNI-d **läbi Ingressi** proxy peale, mitte ainult port-forwardiga. Loe etapp lõppenuks, kui smoke ja kokkulepitud regressioon on edukad. |
| **Prod** (on-prem / tavaline Kubernetes) | See rida kirjeldab tootmist **väljaspool AWS-i** (oma klaster või tavaline on-prem Kubernetes). Overlay `k8s/overlays/prod` annab nimeruumi `ivxv-prod`, kõrge kättesaadavuse (rohkem replica’sid), image sildi `:prod`, Ingressi proxy’le (ja adminile) ning klastri-sisese Postgresi. Avalik liiklus tuleb jälle Ingress → proxy kaudu, nagu stagingus, aga suurema koormuse ja rangema go-live protsessiga. Kui teie tegelik tootmine elab **ainult AWS-is**, seda overlay’d juurutamiseks ei kasutata; pärast stagingut liigute otse reale **AWS**. | Võta juurutusse ainult see SHA, mis stagingus edukalt läbi sai. Seadista `k8s/overlays/prod/ingress.yaml` hostid. Käivita `kubectl apply -k k8s/overlays/prod` ja kontrolli `kubectl -n ivxv-prod get pods,ingress`. Tee go-live checklist ning ole valmis rollback’iks eelmise image sildi peale. Kui tootmine on AWS, jäta see rida vahele ja järgi rida **AWS**. |
| **AWS** | AWS keskkonnas ehitatakse kõigepealt infrastruktuur Terraformiga: võrk (VPC), tõmmiste register (ECR), Kubernetes klaster (EKS) ja hallatud andmebaas (RDS PostgreSQL). Seejärel Ansible (või samad sammud käsitsi) ehitab Dockerfile’dest tõmmised, laeb need ECR-i, kirjutab `k8s/overlays/aws` failis `images:` ploki peale ECR aadressid ja teeb `kubectl apply -k`. See overlay **ei** käivita klastri-sisest Postgresit (patch `delete-incluster-postgres`); storage kasutab RDS-i URI-d ja protokoliks `postgres`. Proxy Service muudetakse tüübiks LoadBalancer ning AWS annotatsioonid loovad avaliku **NLB**; internetist on näha ainult see uks (NLB → proxy). Admin ja ülejäänud mikroteenused jäävad VPC / klastri sisse. AWS-is Ingressit selle mudeli järgi ei kasutata. | Käivita `terraform apply` kaustas `terraform/envs/aws-dev` (või vastav prod env), et ECR, EKS ja RDS tekiksid. Täida `ansible/inventory/group_vars/aws_dev.yml` väljad `ecr_registry`, `eks_cluster_name` ja `image_tag` (SHA). Seejärel kas käivita `cd ansible && ansible-playbook playbooks/site.yml -e @inventory/group_vars/aws_dev.yml`, või tee käsitsi: ECR login, `docker build` ja `push`, `kustomize edit set image`, loo Secret `ivxv-config`, siis `kubectl apply -k k8s/overlays/aws`. Kontrolli `kubectl -n ivxv-aws get pods,svc` — proxy Service peab saama EXTERNAL-IP (NLB). Suuna DNS selle NLB nimele ja tee SNI smoke avaliku pordi 443 peal. Pea meeles: Ansible ei loo Secret’eid, DNS-kirjeid ega Terraformi ressursse; need jäävad käsitsi või eraldi protsessi kätte. |

**Kuidas Kustomize siin töötab**

Igas keskkonnas peale Testi juurutad sa mitte üksikuid YAML-faile käsitsi, vaid
ühe overlay kausta. Overlay viitab ühisele baasile ja lisab ainult selle
keskkonna erinevused.

| Osa | Mis see on | Kus see elab |
|-----|------------|--------------|
| Teenuse base | Ühe mikroteenuse Deployment ja Service | `k8s/base/<teenus>/` |
| Stack base | Kogu koguja stack ühes kohas kokku seotud | `k8s/base/kustomization.yaml` |
| Overlay | Baas + nimeruum + patch’id + image silt (+ Ingress või NLB) | `k8s/overlays/<keskkond>/` |
| Rakendamine | Kustomize koostab lõpliku YAML-i ja saadab klastrisse | `kubectl apply -k k8s/overlays/<keskkond>` |

**Proxy:** Proxy pod peab olema Dev, Staging, Prod ja AWS keskkonnas alati olemas,
sest see on SNI/TLS sisenemispunkt teiste mikroteenuste juurde. Avalikku ust
proxy’le Testis ja Dev’is ei avata (kasuta port-forwardi). Stagingus ja
on-prem Prod’is avab ukse Ingress; AWS-is avab ukse NLB.

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
