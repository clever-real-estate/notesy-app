FROM python:3.12-slim

# Set environment variables to optimize Python performance inside Docker
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /notesy-app

#Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends gcc libpq-dev curl nodejs npm && rm -rf /var/lib/apt/lists/*

#Upgrade pip and install Python dependencies
COPY requirements.txt package.json package-lock.json ./
RUN pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt && npm ci

COPY . .

RUN npm run typecheck \
    && npm run build \
    && DJANGO_SECRET_KEY=build-only-placeholder python manage.py collectstatic --noinput

EXPOSE 8000

CMD ["gunicorn", "notesy.wsgi:application", "--bind", "0.0.0.0:8000"]

