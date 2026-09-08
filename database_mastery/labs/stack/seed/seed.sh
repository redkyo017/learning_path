#!/usr/bin/env bash
set -euo pipefail

# seed.sh
#
# Orchestrates the full deterministic seed: PostgreSQL schema + data
# generation, MySQL subset load + PK variants, MongoDB collections. Run
# from inside the `ws` service (it reaches pg/my/mongo by their compose
# service names), from labs/stack/seed/:
#   SCALE=10 bash seed.sh
#
# Honours SCALE (default 10, meaning millions of ledger_entries) and
# refuses to run against an already-seeded database unless FORCE=1 is
# set, since re-running without dropping first would either fail on
# duplicate primary keys or silently double the data.

SCALE="${SCALE:-10}"
FORCE="${FORCE:-0}"

PGHOST="${PGHOST:-pg}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-dbm}"
PGDATABASE="${PGDATABASE:-payments}"
export PGPASSWORD="${PGPASSWORD:-dbmastery}"

MONGO_HOST="${MONGO_HOST:-mongo}"
MONGO_PORT="${MONGO_PORT:-27017}"
MONGO_URI="${MONGO_URI:-mongodb://${MONGO_HOST}:${MONGO_PORT}/payments?replicaSet=rs0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

stage() {
    local name="$1"
    shift
    local start end elapsed
    start=$(date +%s)
    echo "===> starting ${name}"
    "$@"
    end=$(date +%s)
    elapsed=$((end - start))
    echo "===> finished ${name} in ${elapsed}s"
}

check_empty_or_force() {
    if [[ "$FORCE" == "1" ]]; then
        echo "FORCE=1 set: re-seeding regardless of existing data."
        return 0
    fi
    local existing
    existing=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -tAc \
        "SELECT (to_regclass('public.merchants') IS NOT NULL) AND EXISTS (SELECT 1 FROM merchants LIMIT 1)" \
        2>/dev/null || echo "f")
    if [[ "$existing" == "t" ]]; then
        echo "refusing to seed: merchants already has rows. Set FORCE=1 to re-seed from scratch." >&2
        exit 1
    fi
}

check_empty_or_force

stage "00-schema.sql" \
    psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" \
        -v ON_ERROR_STOP=1 -f "$SCRIPT_DIR/00-schema.sql"

stage "10-generate.sql" \
    psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" \
        -v ON_ERROR_STOP=1 -v scale="$SCALE" -f "$SCRIPT_DIR/10-generate.sql"

stage "20-mysql-load.sh" \
    bash "$SCRIPT_DIR/20-mysql-load.sh"

stage "30-mongo-load.js" \
    env SCALE="$SCALE" mongosh "$MONGO_URI" --quiet --file "$SCRIPT_DIR/30-mongo-load.js"

echo "seed complete at SCALE=${SCALE}"
