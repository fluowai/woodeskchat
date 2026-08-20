#!/bin/sh
# rails.prod.sh — Production entrypoint for the locally-built Chatwoot image.
#
# Runs DB migration/setup idempotently against the configured (Supabase) database
# using `db:chatwoot_prepare` (schema load + seed for a fresh DB, migrate for an
# existing one), then execs the container's main command (provided by the compose
# `command`/`CMD`).
#
# When using the published `chatwoot/chatwoot:latest` image with the separate
# `migrate` init service (see docker-compose.supabase.yaml), this entrypoint is
# not required — prefer that pattern. This script is for local image builds.

set -x

# Remove a stale PID from a previous container lifetime.
rm -f /app/tmp/pids/server.pid
rm -rf /app/tmp/cache/*

# Let DATABASE_URL take precedence; translate it into the individual POSTGRES_*
# vars that config/database.yml reads. `eval` is required so the exports persist
# in this shell (the helper prints `export ...` statements).
if [ -n "$DATABASE_URL" ]; then
  eval "$(ruby /app/docker/entrypoints/helpers/pg_database_url.rb 2>/dev/null)"
fi

echo "==> Running database setup/migrations (db:chatwoot_prepare)..."
bundle exec rails db:chatwoot_prepare

# Hand off to the container's main process (e.g. puma).
exec "$@"
