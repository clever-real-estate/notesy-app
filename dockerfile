# syntax=docker/dockerfile:1

FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY . /app

RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

#RUN npm install \
#    && npm run build

RUN adduser --disabled-password --gecos "" appuser \
    && chown -R appuser:appuser /app

USER appuser

# collectstatic needs Django settings to import successfully.
# This dummy key is only for build-time static collection.
RUN DJANGO_SECRET_KEY="build-time-dummy-key-not-used-at-runtime" \
    DJANGO_DEBUG=False \
    python manage.py collectstatic --noinput

EXPOSE 8000

CMD ["gunicorn", "notesy.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3", "--timeout", "60"]