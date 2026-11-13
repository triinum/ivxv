# Teenuste kaart

Kõik juurutatavad üksused elavad koodirepos kaustas `services/<nimi>/`.
Igal teenusel on **oma Dockerfile samas kaustas**, et seda saaks iseseisvalt
arendada ja avaldada.

## Online koguja (collector) mikroteenused

| Teenus | Kaust | Roll | Tüüpiline port |
|--------|-------|------|----------------|
| **proxy** | `services/proxy/` | SNI/TLS dispatcher (HAProxy + Go) — **ainus avalik sissepääs** | 443 |
| **choices** | `services/choices/` | Valikute / ringkondade / nimekirjade teenus | 443 |
| **voting** | `services/voting/` | Hääle vastuvõtt ja kvalifikatsioon | 443 |
| **verification** | `services/verification/` | Hääle kontroll (verification app) | 443 |
| **storage** | `services/storage/` | Valimiste andmete PutGetter-salvesti (etcd jms) | 2379 |
| **sessionstatus** | `services/sessionstatus/` | Sessiooni oleku jälgimine | 443 |
| **mid** | `services/mid/` | Mobiil-ID abiteenus | 443 |
| **smartid** | `services/smartid/` | Smart-ID abiteenus | 443 |
| **webeid** | `services/webeid/` | Web eID abiteenus | 443 |
| **votesorder** | `services/votesorder/` | Häälte järjekorra / order feed | 443 |
| **xroad-service** | `services/xroad-service/` | X-tee sild | 8080 |
| **collector-admin** | `services/collector-admin/` | Haldus-API / admin (Python) | 8080 |

## Offline rakendused (ei ole pikaajalised pod’id)

| Rakendus | Kaust | Roll |
|----------|-------|------|
| **processor** | `services/processor/` | Offline toru: check → squash → revoke → anonymize |
| **key** | `services/key/` | Võtmed (sh nutikaardi jagud), dekrüpteerimine + tõestused |
| **auditor** | `services/auditor/` | Shuffle/decrypt tõestused; processor’i auditirada |

## Jagatud (ei ole teenused)

- `common/` — collector framework ja tööriistad
- `core/` — krüptograafia (`tivi.io/core`)
- `services/sessionstatus/api` — klient-API moodul, mida teised Go teenused kasutavad

## Iseseisev arendus (koodirepos)

1. Tööta `services/<nimi>/` all.
2. Ehita selle kausta `Dockerfile`-iga (kontekst = repo juur).
3. Käivitamisel mounti seadistus `/etc/ivxv` alla.
