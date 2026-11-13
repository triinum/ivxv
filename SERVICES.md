# IVXV microservices

IVXV is split into independently developed and deployable microservices.
Each service has its own module/package boundary, build, and `Dockerfile`.

Build any service image from the repository root:

```bash
docker build -f <service>/Dockerfile -t ivxv/<service> .
```

Or build everything:

```bash
make docker
```

## Online collector microservices

| Service | Directory | Role |
|---------|-----------|------|
| **proxy** | `proxy/` | SNI/TLS dispatcher in front of other services (HAProxy) |
| **choices** | `choices/` | Voter/choices/district list service |
| **voting** | `voting/` | Vote acceptance, eligibility, qualification |
| **verification** | `verification/` | Vote verification for the control app |
| **storage** | `storage/` | Election data storage (etcd-backed) |
| **sessionstatus** | `sessionstatus/` | Session status tracking |
| **mid** | `mid/` | Mobile-ID authentication helper |
| **smartid** | `smartid/` | Smart-ID authentication helper |
| **webeid** | `webeid/` | Web eID authentication helper |
| **votesorder** | `votesorder/` | Vote order / running list feed |
| **xroad-service** | `xroad-service/` | X-Road ↔ votesorder bridge |
| **collector-admin** | `collector-admin/` | Collector management API / UI backend |

Shared Go libraries used by collector services (not deployable services themselves):

- `common/collector` — shared collector framework
- `sessionstatus/api` — session-status client API module
- `core` (`tivi.io/core`) — crypto primitives

## Offline processing applications

These are not request-serving microservices, but they are developed and
containerized separately for the post-voting workflow:

| Application | Directory | Role |
|-------------|-----------|------|
| **processor** | `processor/` | Ballot-box validation and anonymization |
| **key** | `key/` | Key generation and decryption |
| **auditor** | `auditor/` | Audit / proof verification |

## Independent development

Each service directory is the unit of development:

1. Change code under that service (and shared libs only when needed).
2. Build and test the service image with its own `Dockerfile`.
3. Run with election/technical/trust configuration mounted at `/etc/ivxv`.

Go services keep local `replace` directives to `common/collector` and
`sessionstatus/api` so they can be built from the monorepo without publishing
those modules first. Docker builds additionally point `tivi.io/core` at the
in-repo `core/` module.

## Compose stack

`docker-compose.yml` builds the online services for local integration work.
Configuration and TLS material must be supplied via `./config` (see comments
in the compose file). Storage depends on etcd.
