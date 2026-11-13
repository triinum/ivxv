# `terraform/` — AWS infra skelett

Terraform omab **infrastruktuuri**: VPC, ECR, EKS.

```text
modules/network|ecr|eks
envs/aws-dev|aws-prod
```

- `modules/ecr` — kasutatav peaaegu kohe (repositooriumid `ivxv/<teenus>`)
- `modules/network`, `modules/eks` — **skeletid**; asenda tootmise moodulitega enne päris `apply`-d

Väljundid Ansible’ile: `ecr_registry`, `cluster_name`, `region`.
