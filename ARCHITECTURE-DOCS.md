# Arhitektuuri selgitused (meeskonnale)

Koodirepo kõrval on **eraldi selgituste puu** — sama kaustastruktuur
(`services/`, `k8s/`, `terraform/`, `ansible/`, …), aga **ainult Markdown**.

## Kus see elab

| | |
|--|--|
| **GitHub haru (ainult docs)** | [`cursor/ivxv-architecture-docs-625e`](https://github.com/triinum/ivxv/tree/cursor/ivxv-architecture-docs-625e) |
| **ZIP allalaadimine (haru)** | [ivxv-architecture-docs-625e.zip](https://github.com/triinum/ivxv/archive/refs/heads/cursor/ivxv-architecture-docs-625e.zip) |
| **Alusta lugemist** | `README.md` → `arhitektuur/ylevaade.md` |

Haru ajalugu on **orphan** (ei sisalda IVXV lähtekoodi). Seda võib kopeerida
enda `ivxv-architecture` repoks:

```bash
git clone --branch cursor/ivxv-architecture-docs-625e --single-branch \
  https://github.com/triinum/ivxv.git ivxv-architecture
cd ivxv-architecture
# Loo GitHubis tühi repo triinum/ivxv-architecture, siis:
# git remote set-url origin https://github.com/triinum/ivxv-architecture.git
# git push -u origin HEAD:main
```

## Mida sealt leiad

- Teenuste rollid (`services/<nimi>/README.md`)
- Andmevoog ja AWS (NLB → proxy; **Ingressit AWS-is ei ole vaja**)
- Terraform vs Ansible
- Kustomize overlay’de erinevused
