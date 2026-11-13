# `ansible/` — operatsioonid

Pärast Terraform’i: ehita image’id, push ECR-i, rakenda Kustomize.

| Playbook | Tegevus |
|----------|---------|
| `playbooks/build-push.yml` | `ecr_push` roll |
| `playbooks/apply.yml` | `k8s_apply` roll |
| `playbooks/site.yml` | mõlemad järjest |

Inventory on `localhost` (operaatori masin / CI), mitte SSH remote.
