# Stage 1 — Build the frontend
FROM node:20-slim AS frontend
WORKDIR /app
COPY package.json .
RUN npm install
COPY apps/notes/static_src/ apps/notes/static_src/
COPY tsconfig.json .
RUN npm run build


# Stage 2 — Build the app
FROM python:3.12-slim AS app
WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY --from=frontend /app/static/js/ static/js/
COPY . .

RUN DJANGO_SECRET_KEY=dummy-build-key DATABASE_URL=postgres://x:x@localhost/x \
    python manage.py collectstatic --noinput

RUN adduser --disabled-password --gecos "" notesy-appuser && chown -R notesy-appuser:notesy-appuser /app
USER notesy-appuser


CMD ["gunicorn", "notesy.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3", "--timeout", "120"]