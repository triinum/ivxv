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

The collector is split into independently developed microservices. Each service
lives in its own top-level directory with its own module boundary and
``Dockerfile``. See ``SERVICES.md`` for the full service map.

Build a single service image (from the repository root)::

        docker build -f voting/Dockerfile -t ivxv/voting .

Build all service images::

        make docker

Or use Compose for local wiring (configuration must be provided under
``./config``)::

        docker compose build
