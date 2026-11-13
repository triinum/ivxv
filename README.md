IVXV online voting system
=========================

The intention behind this repository is to make source code of the Estonian
online voting system available for public review.

The repository is not used for active development, but will be kept up to date,
so the code that can be found here is the code that is used for election. As the
voting system used for legally binding elections must strictly follow the
legislation, the actual development of Estonian I-voting system and I-vote
verification application is supervised by State Electoral Office of Estonia.
Please refer to www.valimised.ee for further information.

Microservices
-------------

Deployable units live under ``services/<name>/``. Each service directory
contains its own source **and** ``Dockerfile``. See ``SERVICES.md`` and
``services/README.md`` (Dockerfile structure).

Build a single service image (from the repository root)::

        docker build -f services/voting/Dockerfile -t ivxv/voting .

Build all service images::

        make docker

Or use Compose for local wiring (configuration under ``./config``)::

        docker compose build

Kubernetes (Kustomize base + overlays)::

        kubectl apply -k k8s/overlays/dev
        kubectl apply -k k8s/overlays/aws

AWS (ECR + EKS, public LB only in front of proxy): see ``k8s/AWS.md``.
Also ``k8s/README.md``.
