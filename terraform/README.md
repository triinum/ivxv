# Terraform skeleton (AWS foundation)

Terraform omab **infrastruktuuri**: VPC, EKS, ECR, IAM.  
Teenuste pod’id jäävad `k8s/` (Kustomize) kätte; tõmmiste build/push ja
`kubectl apply` on **Ansible** (`ansible/`) roll.

```text
terraform/
  modules/
    network/     # VPC + subnetid (skelett)
    ecr/         # ivxv/<teenus> repositooriumid
    eks/         # EKS klaster + sõlmede IAM (skelett)
  envs/
    aws-dev/
    aws-prod/
```

Voog koos Ansible’iga: vt ka `k8s/AWS.md` ja `ansible/README.md`.

```text
terraform apply  →  ECR + EKS
ansible-playbook →  docker build/push + kubectl apply -k k8s/overlays/aws
```

## Kiirstart (skelett)

```bash
cd terraform/envs/aws-dev
cp terraform.tfvars.example terraform.tfvars   # täida ACCOUNT/REGION
terraform init
terraform plan
# terraform apply   # kui moodulid on keskkonna jaoks lõpuni viidud
```

`modules/eks` ja `modules/network` on **skeletid**: asenda need tootmises
ametliku mooduliga (nt `terraform-aws-modules/eks/aws`) või oma VPC/EKS
koodiga. `modules/ecr` on kasutatav peaaegu sellisena.

## Väljundid, mida Ansible ootab

- `ecr_registry` — nt `123456789012.dkr.ecr.eu-north-1.amazonaws.com`
- `cluster_name` — EKS nimi `aws eks update-kubeconfig` jaoks
- `region`
