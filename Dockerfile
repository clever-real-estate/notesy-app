# ---- Stage 1: compile the TypeScript bundle ----
FROM node:22-slim AS frontend
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY apps/notes/static_src ./apps/notes/static_src
RUN npm run build                      # esbuild -> static/js/

# ---- Stage 2: app base (deps + code + collected static) ----
FROM python:3.14-slim AS appbase
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
COPY --from=frontend /app/static/js ./static/js
# Collect static at build. Dummy key only satisfies settings import.
RUN DJANGO_SECRET_KEY=build-only-not-a-secret DJANGO_DEBUG=False \
    python manage.py collectstatic --noinput

# ---- Stage 3 (target: runtime): gunicorn app, non-root ----
FROM appbase AS runtime
RUN useradd --create-home --uid 1000 appuser && chown -R appuser:appuser /app
RUN chmod +x entrypoint.sh
USER appuser
EXPOSE 8000
ENTRYPOINT ["./entrypoint.sh"]
CMD ["gunicorn", "notesy.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3"]

# ---- Stage 4 (target: nginx): static + config baked in ----
FROM nginx:1.27 AS nginx
COPY --from=appbase /app/staticfiles /usr/share/nginx/static
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80