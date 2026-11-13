# `services/` — mikroteenused (selgitus)

Koodirepos on iga alamkausta juures **Dockerfile**. Siin repos on sama puu,
aga ainult rolli kirjeldused.

## Reegel

| Tee koodirepos | Siin |
|----------------|------|
| `services/<nimi>/Dockerfile` | Kirjeldatud vastavas `services/<nimi>/README.md` |
| `services/<nimi>/` lähtekood | Ei kopeerita — ainult selgitus |
| `docker/` | Ainult jagatud build helper’ite selgitus |

Ehita alati **repo juurest** (`docker build -f services/voting/Dockerfile … .`),
sest `COPY` teed eeldavad `common/` ja `core/` olemasolu.
