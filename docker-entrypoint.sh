#!/usr/bin/env bash
# Entrypoint: apply DB migrations (and optionally seed) before starting the
# web process. Postgres readiness is gated by the compose healthcheck, so by
# the time this runs the DB should be accepting connections.
set -euo pipefail

echo "[entrypoint] running migrations..."
python manage.py migrate --noinput

if [ "${SEED_DEMO_DATA:-false}" = "true" ]; then
  echo "[entrypoint] seeding demo data..."
  python manage.py seed
fi

echo "[entrypoint] starting: $*"
exec "$@"
