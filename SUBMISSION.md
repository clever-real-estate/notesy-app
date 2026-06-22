# Submission

## What I changed and why

### App

- Moved `SECRET_KEY`, `DEBUG`, `ALLOWED_HOSTS` to env vars. Fail loudly in prod if missing.
- Added `.env.example`, stopped tracking `.env`.
- Replaced `print()` in views with logging.
- Bumped `requests` to 2.32.3.
- Turned on HTTPS cookie / HSTS settings when `DEBUG=False`.
- Added `DATABASE_URL` support (Postgres in Docker, SQLite locally / in tests).

### Docker

- `Dockerfile` + `docker compose up --build` — web + Postgres, no host Python/Node needed.
- `entrypoint.sh`: wait for DB → migrate → collectstatic → seed → gunicorn.
- WhiteNoise for static files in the container.
- Exposed Postgres on `5432` for DBeaver (dev only).

### CI

- Fixed CI: removed `pytest || true`, added npm build + typecheck.
- PR: test + docker build only.
- `main` merge: push to `ghcr.io/<repo>:latest` and `ghcr.io/<repo>:<commit-sha>` for rollback.

## Tradeoffs

- Compose still has dev passwords hardcoded for DB; only some vars use `${}` from `.env`.
- `latest` tag is convenient but mutable — rollback should use the SHA tag.
- Did not add health checks on the web container or split prod compose from dev.

## What I'd do with another day

- Wire DB password / `DATABASE_URL` through `${}` in compose for prod.
- Run migrations as a separate deploy step instead of every container start.
- Add web healthcheck and basic monitoring/alerting.

## How to run

```bash
docker compose up --build
# http://localhost:8000  login: demo / demo
```

## Deployment plan

- Run on a small managed platform (e.g. ECS/Fly/Railway) behind HTTPS — single region is fine for this app.
- Secrets via platform env / secret store, not in git. Rotate by updating secrets and redeploying.
- Deploy the GHCR image by SHA tag, not `latest`. Roll back = redeploy previous SHA.
- Run `migrate` once per release (job or init container), not on every replica start.
- Logs to stdout (already there) → ship to CloudWatch/Datadog. Alert on 5xx rate and DB down.
- Before real users: turn off `DEBUG`, strong secrets, backups on Postgres, rate limit login.
