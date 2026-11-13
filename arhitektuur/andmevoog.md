# Andmevoog (lihtsustatud)

## 1. Hääletamine (skeem)

```text
Klient (valija / kontrollrakendus)
  → avalik sissepääs (Ingress TLS passthrough VÕI AWS NLB TCP :443)
  → proxy (SNI valib backend’i; hääletusrajal TLS ei lõpe ALB/Ingress HTTP-na)
  → ClusterIP: choices | voting | verification | mid | smartid | webeid | …
       ↘ sessionstatus (sessiooni olek; klient-API: services/sessionstatus/api)
       ↘ storage (:2379) → etcd (:2379/:2380)
```

1. Klient avab TLS-ühenduse avaliku hostinime peale (DNS → NLB või Ingress).
2. Liiklus jõuab **proxy** teenuseni.
3. Proxy vaatab SNI / marsruuti ja edastab päringu õigele backendile —
   klastris **ClusterIP** DNS-nimedega (nt `voting`, `choices` nimeruumis
   `ivxv-aws`), **mitte** avalike hostinimedega.
4. Online teenused kasutavad `sessionstatus` ja `storage` teenuseid.
5. `storage` hoiab andmeid PutGetter abstraktsiooni taga (klassikaliselt etcd).

## 2. Identiteet

`mid`, `smartid`, `webeid` on abiteenused autentimiseks / allkirjastamiseks.
Neid ei eksponeerita internetti otse — ainult proxy kaudu või klastrisiseselt.

## 3. X-tee

`xroad-service` (:8080) sildub X-tee ja IVXV vahel; klastris peamine partner
on `votesorder`. Oma Secret `/etc/xroad-service`.

## 4. Haldus

`collector-admin` on operaatori liides. **Ärge** pange seda avaliku Ingressi
taha tootmises (AWS-is jääb privaatseks). Ligipääs: VPN, bastion või
`kubectl port-forward`.

## 5. Pärast hääletust (offline)

`processor` (check→squash→revoke→anonymize) → `key` (dekrüpteerimine) →
`auditor` (tõestused). Job / operaatori masin — mitte püsivad EKS Deployment’id.

## 6. Seadistus

Enamik collector-pode mountib Secret’i `ivxv-config` → `/etc/ivxv`
(trust / election / technical). Ansible **ei** täida seda automaatselt.
