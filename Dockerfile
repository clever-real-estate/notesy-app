# syntax=docker/dockerfile:1

# --- Stage 1: build the front-end TS bundle -------------------------------
FROM node:20-slim AS frontend
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY apps/notes/static_src ./apps/notes/static_src
RUN npm run build   # outputs minified JS to static/js/

# --- Stage 2: Python runtime ----------------------------------------------
FROM python:3.12-slim AS runtime

# - no .pyc files, unbuffered stdout so logs stream to the platform
# - DJANGO_SETTINGS_MODULE so manage.py works without extra flags
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DJANGO_SETTINGS_MODULE=notesy.settings

WORKDIR /app

# psycopg2-binary ships wheels, so no compiler needed. curl is for healthchecks.
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# App source + the built front-end bundle from stage 1.
COPY . .
COPY --from=frontend /app/static/js ./static/js

# Collect static into STATIC_ROOT at build time (WhiteNoise serves from there).
# A throwaway key is fine here — collectstatic doesn't need the real one.
RUN DJANGO_SECRET_KEY=build-only DJANGO_DEBUG=False \
    python manage.py collectstatic --noinput

# Run as an unprivileged user.
RUN useradd --create-home --uid 1000 appuser \
    && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["gunicorn", "notesy.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3", "--access-logfile", "-", "--error-logfile", "-"]
