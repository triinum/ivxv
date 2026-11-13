# PostgreSQL storage protocol

`PutGetter` backend for IVXV collector services. Use instead of etcd when you
want managed SQL (Amazon RDS, Cloud SQL, in-cluster Postgres).

## Config

```yaml
storage:
  protocol: postgres
  conf:
    URI: "postgres://ivxv:secret@host:5432/ivxv?sslmode=require"
    ConnTimeout: 10
    OpTimeout: 10
    BatchSize: 128
```

URI may also come from:

- `sensitive/postgres.uri` (service sensitive directory), or
- environment variable `IVXV_POSTGRES_URI`

## Schema

On connect the client ensures:

```sql
CREATE TABLE IF NOT EXISTS ivxv_kv (
  key   TEXT PRIMARY KEY,
  value BYTEA NOT NULL,
  serial BIGSERIAL NOT NULL
);
```

## Semantics

Same as etcd: `Put` is create-only, `CAS` updates counters, `GetWithPrefix`
lists by key prefix. This is still a key–value store, not a relational model.
