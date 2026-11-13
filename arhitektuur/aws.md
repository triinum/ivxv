# AWS: ECR → EKS → NLB → proxy

## Kas Ingress on vaja?

**Ei** — mitte AWS overlay’s. Avalik sissepääs on:

`Internet → NLB (TCP 443) → Service/proxy (LoadBalancer) → pod`

Ingress (nginx/ALB) lõpetaks või segaks TLS-i; IVXV proxy peab SNI-d nägema.
Staging/prod overlay’des on Ingress **alternatiiv** keskkondadele ilma pilve-NLB-ta.

## Sammud

1. **ECR** — iga teenuse tõmmis `ivxv/<teenus>`
2. **EKS** — kõik pod’id; worker’id eelistatult privaatses alamvõrgus
3. **Kustomize** `k8s/overlays/aws` — image’id ECR-ist; ainult proxy on `LoadBalancer`
4. **DNS** → NLB hostname

## Terraform vs Ansible

- Terraform loob VPC / ECR / EKS (infra).
- Ansible teeb `docker build` / push / `kubectl apply -k`.

Vt `terraform/README.md`, `ansible/README.md`, `arhitektuur/terraform-vs-ansible.md`.
