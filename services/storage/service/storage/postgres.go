package main

import (
	"context"
	"time"

	"ivxv.ee/common/collector/command/exit"
	"ivxv.ee/common/collector/conf"
	"ivxv.ee/common/collector/errors"
	"ivxv.ee/common/collector/log"
	"ivxv.ee/common/collector/storage"
	// Register the postgres PutGetter implementation.
	_ "ivxv.ee/common/collector/storage/postgres"
)

// postgresCtrl keeps the storage service process alive when using an external
// PostgreSQL database. It does not manage DB lifecycle (use RDS / operator).
type postgresCtrl struct {
	client *storage.Client
}

func newPostgresCtrl(cfg *conf.Technical, service *conf.Service) (
	c *postgresCtrl, code int, err error) {

	client, err := storage.New(&cfg.Storage, &storage.Services{
		Sensitive: conf.Sensitive(service.ID),
	})
	if err != nil {
		return nil, exit.Config, PostgresClientError{Err: err,
			Description: _STORAGE_PG_CLIENT}
	}
	return &postgresCtrl{client: client}, exit.OK, nil
}

func (c *postgresCtrl) start(ctx context.Context) error {
	log.Log(ctx, PostgresStorageReady{Description: _STORAGE_PG_READY})
	return nil
}

func (c *postgresCtrl) check(ctx context.Context) error {
	// Hit the database with a read that is valid even before election data
	// is loaded. Missing data is OK; connection failures are not.
	_, err := c.client.GetDistrictsVersion(ctx)
	if err == nil {
		return nil
	}
	if errors.CausedBy(err, new(storage.NotExistError)) != nil {
		return nil
	}
	return PostgresCheckError{Err: err, Description: _STORAGE_PG_CHECK}
}

func (c *postgresCtrl) stop(_ context.Context, _ time.Duration) error {
	return nil
}
