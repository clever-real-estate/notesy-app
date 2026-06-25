#!/usr/bin/env bash
set -e

echo "Applying migrations..."
python manage.py migrate --noinput

# Seed demo data only if not already present, so restarts stay idempotent.
SEEDED=$(python manage.py shell -c \
  "from django.contrib.auth import get_user_model; print(get_user_model().objects.filter(username='demo').exists())")
if echo "$SEEDED" | grep -q True; then
  echo "Demo data already present; skipping seed."
else
  echo "Seeding demo data..."
  python manage.py seed
fi

exec "$@"