/*
Package postgres implements a storage protocol which reads and writes data
from a PostgreSQL database (e.g. Amazon RDS).

It is a drop-in PutGetter backend alternative to etcd for deployments that
prefer managed SQL over an etcd cluster. Keys remain opaque strings and values
opaque byte slices — this is not a relational mapping of IVXV domain objects.
*/
package postgres

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"ivxv.ee/common/collector/log"
	"ivxv.ee/common/collector/storage"
	"ivxv.ee/common/collector/yaml"
)

const (
	defaultBatchSize   = 128
	defaultConnTimeout = 10
	defaultOpTimeout   = 10
)

const schemaSQL = `
CREATE TABLE IF NOT EXISTS ivxv_kv (
	key   TEXT PRIMARY KEY,
	value BYTEA NOT NULL,
	serial BIGSERIAL NOT NULL
);
CREATE INDEX IF NOT EXISTS ivxv_kv_key_prefix ON ivxv_kv (key text_pattern_ops);
`

func init() {
	storage.Register(storage.Postgres, func(n yaml.Node, services *storage.Services) (
		s storage.PutGetter, err error) {

		var cfg Conf
		if err = yaml.Apply(n, &cfg); err != nil {
			return nil, ConfigurationError{Err: err, Description: _PG_CFG}
		}
		if cfg.URI == "" && services != nil && services.Sensitive != "" {
			b, rerr := os.ReadFile(filepath.Join(services.Sensitive, "postgres.uri"))
			if rerr == nil {
				cfg.URI = strings.TrimSpace(string(b))
			}
		}
		if cfg.URI == "" {
			if u := os.Getenv("IVXV_POSTGRES_URI"); u != "" {
				cfg.URI = u
			}
		}
		if cfg.URI == "" {
			return nil, MissingURIError{Description: _PG_URI}
		}
		if cfg.ConnTimeout == 0 {
			cfg.ConnTimeout = defaultConnTimeout
		}
		if cfg.OpTimeout == 0 {
			cfg.OpTimeout = defaultOpTimeout
		}
		if cfg.BatchSize == 0 {
			cfg.BatchSize = defaultBatchSize
		}

		ctx, cancel := context.WithTimeout(context.Background(),
			time.Duration(cfg.ConnTimeout)*time.Second)
		defer cancel()

		pool, err := pgxpool.New(ctx, cfg.URI)
		if err != nil {
			return nil, ConnectError{Err: err, Description: _PG_CONN}
		}
		if err = pool.Ping(ctx); err != nil {
			pool.Close()
			return nil, PingError{Err: err, Description: _PG_PING}
		}
		if _, err = pool.Exec(ctx, schemaSQL); err != nil {
			pool.Close()
			return nil, SchemaError{Err: err, Description: _PG_SCHEMA}
		}

		return &client{
			pool:    pool,
			optime:  time.Duration(cfg.OpTimeout) * time.Second,
			batchSz: cfg.BatchSize,
		}, nil
	})
}

// Conf is the PostgreSQL storage protocol configuration.
type Conf struct {
	// URI is a libpq/pgx connection string, e.g.
	// postgres://ivxv:secret@db.example:5432/ivxv?sslmode=require
	URI string

	// ConnTimeout is the timeout for connecting / pinging in seconds.
	ConnTimeout int64

	// OpTimeout is the timeout for a single operation in seconds.
	OpTimeout int64

	// BatchSize is the maximum number of keys in Batcher methods.
	BatchSize int
}

type client struct {
	pool    *pgxpool.Pool
	optime  time.Duration
	batchSz int
}

func (c *client) BatchSize() int { return c.batchSz }

func (c *client) withTimeout(ctx context.Context) (context.Context, context.CancelFunc) {
	return context.WithTimeout(ctx, c.optime)
}

func (c *client) Put(ctx context.Context, key string, value []byte) error {
	ctx, cancel := c.withTimeout(ctx)
	defer cancel()

	_, err := c.pool.Exec(ctx,
		`INSERT INTO ivxv_kv (key, value) VALUES ($1, $2)`, key, value)
	if err != nil {
		if isUniqueViolation(err) {
			return storage.ExistError{Key: key, Err: PutExistingKeyError{
				Description: _PG_PUT_EXISTING,
			}}
		}
		return log.Alert(PutError{Key: key, Err: err, Description: _PG_PUT})
	}
	return nil
}

func (c *client) PutAll(ctx context.Context, reqs ...storage.PutAllRequest) error {
	if len(reqs) == 0 {
		return nil
	}
	if len(reqs) > c.batchSz {
		return log.Alert(PutAllTooLargeError{
			Have: len(reqs), Want: c.batchSz, Description: _PG_PUT_ALL,
		})
	}

	ctx, cancel := c.withTimeout(ctx)
	defer cancel()

	tx, err := c.pool.Begin(ctx)
	if err != nil {
		return log.Alert(PutAllBeginError{Err: err, Description: _PG_PUT_ALL})
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	for _, req := range reqs {
		_, err = tx.Exec(ctx,
			`INSERT INTO ivxv_kv (key, value) VALUES ($1, $2)`, req.Key, req.Value)
		if err != nil {
			if isUniqueViolation(err) {
				return storage.ExistError{Key: req.Key, Err: PutAllExistingKeyError{
					Description: _PG_PUT_EXISTING,
				}}
			}
			return log.Alert(PutAllExecError{Err: err, Description: _PG_PUT_ALL})
		}
	}
	if err = tx.Commit(ctx); err != nil {
		return log.Alert(PutAllCommitError{Err: err, Description: _PG_PUT_ALL})
	}
	return nil
}

func (c *client) Get(ctx context.Context, key string) ([]byte, error) {
	ctx, cancel := c.withTimeout(ctx)
	defer cancel()

	var value []byte
	err := c.pool.QueryRow(ctx,
		`SELECT value FROM ivxv_kv WHERE key = $1`, key).Scan(&value)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, storage.NotExistError{Key: key, Err: GetMissingKeyError{
			Description: _PG_GET_NONE,
		}}
	}
	if err != nil {
		return nil, log.Alert(GetError{Key: key, Err: err, Description: _PG_GET})
	}
	return value, nil
}

func (c *client) GetAll(ctx context.Context, keys ...string) (map[string][]byte, error) {
	out := make(map[string][]byte, len(keys))
	if len(keys) == 0 {
		return out, nil
	}
	if len(keys) > c.batchSz {
		return nil, log.Alert(GetAllTooLargeError{
			Have: len(keys), Want: c.batchSz, Description: _PG_GET_ALL,
		})
	}

	ctx, cancel := c.withTimeout(ctx)
	defer cancel()

	rows, err := c.pool.Query(ctx,
		`SELECT key, value FROM ivxv_kv WHERE key = ANY($1)`, keys)
	if err != nil {
		return nil, log.Alert(GetAllQueryError{Err: err, Description: _PG_GET_ALL})
	}
	defer rows.Close()

	for rows.Next() {
		var k string
		var v []byte
		if err = rows.Scan(&k, &v); err != nil {
			return nil, log.Alert(GetAllScanError{Err: err, Description: _PG_GET_ALL})
		}
		out[k] = v
	}
	if err = rows.Err(); err != nil {
		return nil, log.Alert(GetAllRowsError{Err: err, Description: _PG_GET_ALL})
	}
	return out, nil
}

func (c *client) GetWithPrefix(ctx context.Context, prefix string) (
	<-chan storage.GetWithPrefixResult, <-chan error) {

	ch := make(chan storage.GetWithPrefixResult)
	errc := make(chan error, 1)

	go func() {
		defer close(errc)
		defer close(ch)

		qctx, cancel := c.withTimeout(ctx)
		defer cancel()

		rows, err := c.pool.Query(qctx,
			`SELECT key, value FROM ivxv_kv WHERE key LIKE $1 ESCAPE '\' ORDER BY key`,
			escapeLike(prefix)+"%")
		if err != nil {
			errc <- log.Alert(GetWithPrefixQueryError{Err: err, Description: _PG_GET_PREFIX})
			return
		}
		defer rows.Close()

		for rows.Next() {
			var r storage.GetWithPrefixResult
			if err = rows.Scan(&r.Key, &r.Value); err != nil {
				errc <- log.Alert(GetWithPrefixScanError{Err: err, Description: _PG_GET_PREFIX})
				return
			}
			select {
			case ch <- r:
			case <-ctx.Done():
				errc <- ctx.Err()
				return
			}
		}
		if err = rows.Err(); err != nil {
			errc <- log.Alert(GetWithPrefixRowsError{Err: err, Description: _PG_GET_PREFIX})
		}
	}()

	return ch, errc
}

func (c *client) GetWithSerial(ctx context.Context, key string) ([]byte, int64, error) {
	ctx, cancel := c.withTimeout(ctx)
	defer cancel()

	var value []byte
	var serial int64
	err := c.pool.QueryRow(ctx,
		`SELECT value, serial FROM ivxv_kv WHERE key = $1`, key).Scan(&value, &serial)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, 0, storage.NotExistError{Key: key, Err: GetWithSerialMissingKeyError{
			Description: _PG_GET_NONE,
		}}
	}
	if err != nil {
		return nil, 0, log.Alert(GetWithSerialError{Key: key, Err: err, Description: _PG_GET})
	}
	return value, serial, nil
}

func (c *client) CAS(ctx context.Context, cas string, old, new []byte) error { //nolint:revive
	ctx, cancel := c.withTimeout(ctx)
	defer cancel()

	tag, err := c.pool.Exec(ctx, `
		UPDATE ivxv_kv
		SET value = $1, serial = serial + 1
		WHERE key = $2 AND value = $3`, new, cas, old)
	if err != nil {
		return log.Alert(CASExecError{CAS: cas, Err: err, Description: _PG_CAS})
	}
	if tag.RowsAffected() == 1 {
		return nil
	}

	var have []byte
	err = c.pool.QueryRow(ctx, `SELECT value FROM ivxv_kv WHERE key = $1`, cas).Scan(&have)
	if errors.Is(err, pgx.ErrNoRows) {
		return storage.NotExistError{Key: cas, Err: CASMissingCASKeyError{
			Description: _PG_GET_NONE,
		}}
	}
	if err != nil {
		return log.Alert(CASReadError{CAS: cas, Err: err, Description: _PG_CAS})
	}
	return storage.UnexpectedValueError{
		Key: cas,
		Err: CASValueMismatchError{
			Have:        string(have),
			Want:        string(old),
			Description: _PG_CAS_CMP,
		},
	}
}

// Close releases the connection pool. Optional; clients usually live for the
// process lifetime.
func (c *client) Close() { c.pool.Close() }

func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}

func escapeLike(s string) string {
	r := strings.NewReplacer(`\`, `\\`, `%`, `\%`, `_`, `\_`)
	return r.Replace(s)
}
