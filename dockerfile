# STAGE 1: BUILD THE JAVASCRIPT BUNDLE

FROM node:20-slim AS frontend


WORKDIR /app


COPY package.json package-lock.json ./

RUN npm ci

COPY . .

RUN npm run build



# STAGE 2: BUILD THE PRODUCTION APP CONTAINER

FROM python:3.12-slim

WORKDIR /app


RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    gcc \
    && rm -rf /var/lib/apt/lists/*


COPY requirements.txt .


RUN pip install --no-cache-dir -r requirements.txt

COPY . .


COPY --from=frontend /app/static ./static


RUN SECRET_KEY=build-time-placeholder \
    DATABASE_URL=sqlite:///tmp/build.db \
    python manage.py collectstatic --noinput

EXPOSE 8000


CMD ["gunicorn", "notesy.wsgi:application", \
     "--bind", "0.0.0.0:8000", \
     "--workers", "2", \
     "--timeout", "120", \
     "--access-logfile", "-", \
     "--error-logfile", "-"] 