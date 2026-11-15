# Optional in-cluster PostgreSQL (dev)

For local/dev overlays that do not use Amazon RDS. Production AWS should
prefer managed RDS and omit this Deployment — see `k8s/overlays/aws`.

Technical config example:

```yaml
storage:
  protocol: postgres
  conf:
    URI: "postgres://ivxv:ivxv@postgres:5432/ivxv?sslmode=disable"
    ConnTimeout: 10
    OpTimeout: 10
```
