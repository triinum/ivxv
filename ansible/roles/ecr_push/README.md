# Roll `ecr_push`

1. ECR login  
2. `docker build -f services/<nimi>/Dockerfile` iga teenuse jaoks  
3. `docker push`  
4. Valikuliselt `kustomize edit set image` aws overlay’s
