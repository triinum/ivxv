# Ansible skeleton (build, push, apply)

Ansible tegeleb **operatsioonidega** pärast seda, kui Terraform on loonud
ECR + EKS (vt `terraform/README.md` ja `k8s/AWS.md`).

```text
ansible/
  ansible.cfg
  inventory/
    hosts.yml
    group_vars/
      all.yml
      aws_dev.yml
      aws_prod.yml
  playbooks/
    site.yml          # build → push → apply
    build-push.yml
    apply.yml
  roles/
    ecr_push/         # docker build + ECR login/push + kustomize image set
    k8s_apply/        # kubectl apply -k overlay
```

```text
terraform apply  →  ECR repos + EKS
ansible-playbook →  docker build/push + kubectl apply -k k8s/overlays/aws
```

## Eeldused

- `docker`, `aws` CLI, `kubectl`, `kustomize` (või `kubectl kustomize`)
- ECR registry ja EKS klaster olemas (Terraform väljundid või käsitsi)
- `kubectl` kontekst osutab õigele klastrile

## Käivitamine

Repo juurest (või `ansible/` kaustast — `ansible.cfg` seab `roles_path`):

```bash
cd ansible

# Väärtused: kopeeri Terraform väljundid group_vars-i
#   ecr_registry: "ACCOUNT.dkr.ecr.REGION.amazonaws.com"
#   aws_region: "eu-north-1"
#   eks_cluster_name: "ivxv-dev"
#   image_tag: "$(git rev-parse --short HEAD)"

ansible-playbook playbooks/site.yml -e @inventory/group_vars/aws_dev.yml

# Ainult build+push
ansible-playbook playbooks/build-push.yml -e @inventory/group_vars/aws_dev.yml

# Ainult kubectl apply
ansible-playbook playbooks/apply.yml -e @inventory/group_vars/aws_dev.yml
```

`hosts.yml` kasutab `localhost` + `connection: local` — playbook’id
jooksuvad operaatori masinas / CI-s, mitte remote SSH peal.

## Mida skelett teeb / ei tee

| Teeb | Ei tee (jäta käsitsi / laienda) |
|------|----------------------------------|
| ECR login | Secret’ite (`ivxv-config`) loomine |
| `docker build` iga `services/*/Dockerfile` jaoks | etcd / DynamoDB sisu |
| `docker push` ECR-i | DNS / Route 53 |
| `kustomize edit set image` aws overlay’s | NLB annotatsioonide peenhäälestus |
| `kubectl apply -k` | Helm chart’id |

## Seotud

- `k8s/AWS.md` — käsitsi samm-sammult sama voog
- `terraform/` — VPC / ECR / EKS skelett
- `k8s/overlays/aws/` — sihtmärk `k8s_apply` rollile
