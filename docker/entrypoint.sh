#!/bin/sh
set -e

if [ -n "$DATABASE_URL" ]; then
  python - <<'PY'
import os
import socket
import sys
import time
from urllib.parse import urlparse

url = urlparse(os.environ["DATABASE_URL"])
host = url.hostname
port = url.port or 5432
if not host:
    sys.exit(0)

for attempt in range(30):
    try:
        with socket.create_connection((host, port), timeout=2):
            print(f"Database is reachable at {host}:{port}")
            break
    except OSError:
        if attempt == 29:
            raise
        print(f"Waiting for database at {host}:{port}...")
        time.sleep(1)
PY
fi

python manage.py migrate --noinput

exec "$@"
