# AWS juhendi peegel

Täielik eestikeelne juhend elab **koodirepos** failis `k8s/AWS.md`.

Siin repos loe lühikokkuvõtet: [`arhitektuur/aws.md`](../arhitektuur/aws.md).

Põhipunktid:
1. Ehita `services/*/Dockerfile` → push ECR
2. EKS + `kubectl apply -k k8s/overlays/aws`
3. Avalik liiklus **ainult** proxy NLB-le
4. Ingressit AWS teel **ei** ole vaja
