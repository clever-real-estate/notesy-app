#!/bin/sh
set -eu

echo "Waiting for database..."
python <<'PY'
import os
import sys
import time

import psycopg2
from urllib.parse import urlparse

url = os.environ.get("DATABASE_URL", "").strip()
if not url:
    sys.exit(0)

parsed = urlparse(url)
deadline = time.time() + 60
while time.time() < deadline:
    try:
        psycopg2.connect(
            dbname=parsed.path.lstrip("/"),
            user=parsed.username,
            password=parsed.password,
            host=parsed.hostname,
            port=parsed.port or 5432,
        ).close()
        break
    except psycopg2.OperationalError:
        time.sleep(1)
else:
    raise SystemExit("Database did not become ready in time")
PY

python manage.py migrate --noinput
python manage.py collectstatic --noinput
python manage.py seed

exec gunicorn notesy.wsgi:application \
    --bind 0.0.0.0:8000 \
    --workers "${GUNICORN_WORKERS:-2}" \
    --access-logfile - \
    --error-logfile -
