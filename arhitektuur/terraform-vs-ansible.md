# Terraform vs Ansible

| | Terraform | Ansible |
|---|-----------|---------|
| **Omab** | Infrastruktuuri olekut (VPC, ECR, EKS, IAM) | Operatsioonide samme |
| **Tüüpiline käsk** | `terraform apply` | `ansible-playbook playbooks/site.yml` |
| **Tulemus** | Pilve ressursid | Tõmmised registris + pod’id klastris |
| **Idempotentsus** | State-fail / plan | Playbook task’id |

```text
terraform apply  →  ECR + EKS valmis
ansible-playbook →  build/push + kubectl apply -k k8s/overlays/aws
```

Ära pane Terraformisse `kubectl apply` ega Ansible’isse VPC loomist —
piir hoiab vastutused selgena.
