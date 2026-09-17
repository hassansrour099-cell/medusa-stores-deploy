#!/usr/bin/env bash
# Create the NEXUS database on an already-initialized Postgres volume
# (init-databases.sql only runs on first volume create).
# Safe: CREATE DATABASE only — does not drop or modify UC/PS databases.
set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${DEPLOY_DIR}"

docker compose exec -T postgres \
  psql -U "${POSTGRES_USER:-medusa}" -d postgres \
  -c "SELECT 1 FROM pg_database WHERE datname = 'nexus'" | grep -q 1 \
  && echo "Database nexus already exists" \
  || docker compose exec -T postgres \
       psql -U "${POSTGRES_USER:-medusa}" -d postgres \
       -c "CREATE DATABASE nexus;"

echo "OK — nexus database ready"
