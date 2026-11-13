# Andmevoog (lihtsustatud)

## 1. Hääletamine (skeem)

1. Klient avab TLS-ühenduse avaliku hostinime peale (DNS → NLB või Ingress).
2. Liiklus jõuab **proxy** teenuseni.
3. Proxy vaatab SNI / marsruuti ja edastab päringu õigele backendile
   (`voting`, `choices`, …) — need on klastris **ClusterIP** nimedega
   (nt `voting.ivxv-aws.svc`).
4. `voting` / `choices` / … suhtlevad `sessionstatus` ja `storage` teenustega.
5. `storage` hoiab andmeid PutGetter abstraktsiooni taga (klassikaliselt etcd;
   AWS-is võib asendada DynamoDB / Postgres’iga — vt koodirepo arutelu).

## 2. Identiteet

`mid`, `smartid`, `webeid` on abiteenused autentimiseks / allkirjastamiseks.
Neid ei eksponeerita internetti otse — ainult proxy kaudu või klastrisiseselt.

## 3. Haldus

`collector-admin` on operaatori liides. **Ärge** pange seda avaliku Ingressi
taha tootmises. Ligipääs: VPN, bastion või `kubectl port-forward`.

## 4. Pärast hääletust (offline)

`processor`, `key`, `auditor` jooksevad turvalisel operaatori masinal või
CI Job’ina — mitte püsivate EKS Deployment’idena.
