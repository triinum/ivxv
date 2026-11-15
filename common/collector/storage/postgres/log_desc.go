package postgres

const (
	_PG_CFG          = "Invalid 'postgres:' section in a YAML configuration file"
	_PG_URI          = "PostgreSQL connection URI is missing (conf.URI, sensitive/postgres.uri, or IVXV_POSTGRES_URI)"
	_PG_CONN         = "Failed to create PostgreSQL connection pool"
	_PG_PING         = "Failed to ping PostgreSQL"
	_PG_SCHEMA       = "Failed to ensure ivxv_kv schema"
	_PG_PUT          = "Failed to put key into PostgreSQL"
	_PG_PUT_EXISTING = "Key already exists in PostgreSQL"
	_PG_PUT_ALL      = "Failed to put multiple keys into PostgreSQL"
	_PG_GET          = "Failed to get key from PostgreSQL"
	_PG_GET_NONE     = "Key not found in PostgreSQL"
	_PG_GET_ALL      = "Failed to get multiple keys from PostgreSQL"
	_PG_GET_PREFIX   = "Failed to get keys by prefix from PostgreSQL"
	_PG_CAS          = "Failed to compare-and-swap key in PostgreSQL"
	_PG_CAS_CMP      = "Compare-and-swap expected value mismatch"
)
