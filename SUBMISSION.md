# Submission

## What I changed and why

### App

- Moved risky Django runtime settings into environment variables: `DJANGO_SECRET_KEY`, `DJANGO_DEBUG`, `DJANGO_ALLOWED_HOSTS`, `DATABASE_URL`, CSRF trusted origins, and production security toggles. This keeps local development easy while preventing production from silently running with hard-coded development settings.
- Removed the committed `.env` file from the repo and added `.env.example` with safe placeholder values. In a real incident, any exposed secret-shaped values would be rotated rather than reused.
- Replaced ad-hoc `print()` calls with standard Python logging so logs can be controlled by level and routed cleanly from containers.
- Restricted views to their intended HTTP methods. Read-only views accept `GET`; mutating views require `POST` or `DELETE`; logout is now `POST` with CSRF protection.
- Removed file-backed sessions so Django uses database-backed sessions. This avoids container-local state and works if the app later runs more than one web container.
- Added `GET /healthz/` as a simple unauthenticated health endpoint for Docker/platform checks.
- Replaced CDN-loaded HTMX with a declared npm dependency copied into the local static asset build. This removes a production runtime dependency on `unpkg.com` and makes builds more reproducible.
- Updated Python dependencies to bounded supported ranges, added `dj-database-url` and WhiteNoise, and removed the old unused `requests==2.20.0` dependency.

### Docker

- Added a multi-stage `Dockerfile`:
  - a Node stage installs npm dependencies, typechecks TypeScript, and builds static assets;
  - a Python runtime stage installs app dependencies, copies the app and built static files, runs `collectstatic`, and starts Django with Gunicorn.
- The runtime image runs as a non-root `notesy` user.
- Added `.dockerignore` so local virtualenvs, node_modules, generated files, SQLite databases, sessions, git metadata, and real env files stay out of the image build context.
- Added `compose.yaml` with two services: `web` and `db`.
  - `db` uses `postgres:16-alpine`, a named volume, and a healthcheck.
  - `web` builds the app image, waits for healthy Postgres, exposes port `8000`, and has a healthcheck against `/healthz/`.
- Added `docker/entrypoint.sh` to wait for the database socket, run migrations for local Compose convenience, then exec Gunicorn.

### CI

- Replaced the starter workflow that used `pytest || true`; test failures now fail CI.
- CI now runs on pull requests, pushes to `main`, and manual dispatch.
- Added a Postgres service in CI so checks run against the same class of database used by Docker/production instead of only SQLite.
- Added Python 3.12 and Node 20 setup with dependency caching.
- CI runs frontend and backend gates: `npm ci`, `npm run typecheck`, `npm run build`, `python manage.py check`, and `pytest -q`.
- Added a Docker image job that builds the image after tests pass.
- GHCR publishing only happens on push to `main` using GitHub's built-in `GITHUB_TOKEN`.
- Images are tagged with an immutable `sha-...` tag for rollback and a moving `main` tag for the latest main build.
- The CI Django secret is generated at runtime with `openssl rand`; no static application secret is committed.

## Tradeoffs

- I used WhiteNoise for static files because it keeps this challenge self-contained: one app container can serve the built assets without adding nginx, S3, or a CDN. For a larger production system, I would usually put static assets behind object storage and a CDN.
- The local Compose entrypoint runs migrations on web startup. That is convenient for reviewers running `docker compose up`, but I would not rely on that pattern for production. Production migrations should run as a controlled one-off release job before traffic shifts.
- I kept the summarization endpoint synchronous. It currently sleeps to simulate an external call; moving it to a background queue with retries/timeouts would be valuable, but it would be more infrastructure than this time-boxed challenge needs.
- I did not add Kubernetes/Terraform/Helm. The README asks for a local Docker stack and a deployment plan, not actual cloud infrastructure.
- I used GitHub Actions major-version pins like `actions/checkout@v4`. Full SHA pinning is stronger supply-chain hygiene, but major pins are a reasonable balance for this exercise.
- I kept the app behavior largely intact instead of refactoring the Django views/templates. The goal was operational readiness, not rewriting the product.

## What I'd do with another day

- Move summarization to an async worker with request timeouts, retries, dead-letter handling, and a user-visible pending/error state.
- Add login throttling/rate limiting and stronger password/session policies.
- Add structured JSON logs with request IDs and correlation IDs.
- Add application metrics: request latency, error rate, DB latency, summary job latency/failures, and healthcheck status.
- Add image/dependency scanning and Dependabot/Renovate updates.
- Add smoke tests that run against the built Docker image.
- Add backup/restore documentation and test a Postgres restore.
- Add a migration runbook for irreversible or long-running migrations.
- Add stricter production security headers after confirming the final HTTPS/proxy topology.

## How to run

Requirements: Docker and Docker Compose.

```bash
# Build and start the full local stack: Django + Postgres
docker compose up --build
```

In another terminal, optionally seed demo data:

```bash
docker compose exec web python manage.py seed
```

Then open:

```text
http://localhost:8000
```

Demo login:

```text
username: demo
password: demo
```

Useful checks:

```bash
# Confirm services are healthy
docker compose ps

# Health endpoint
curl -fsS http://localhost:8000/healthz/

# Run tests inside the web container
docker compose exec web pytest -q

# Stop the stack
docker compose down
```

To remove the local Postgres data volume as well:

```bash
docker compose down -v
```

## Deployment plan

### Platform and region

I would deploy this as a containerized web service on a managed platform such as AWS ECS Fargate, Google Cloud Run, Fly.io, Render, or another platform that supports container health checks, managed secrets, and rolling deploys. For a small team, I would choose the simplest managed option already familiar to the company rather than introducing Kubernetes immediately.

I would run it in one primary US region close to the expected users, for example `us-east-1` or `us-central1`, with managed Postgres in the same region/VPC to minimize latency. If the app became business-critical, I would add multi-AZ Postgres, automated backups, and a warm standby or documented regional recovery plan.

### Secrets and configuration

Secrets should come from the deployment platform's secret manager, not from files committed to the repo or baked into the image.

Required runtime configuration would include:

- `DJANGO_SECRET_KEY`
- `DATABASE_URL`
- `DJANGO_ALLOWED_HOSTS`
- `DJANGO_CSRF_TRUSTED_ORIGINS`
- any future summarizer API key/URL

For rotation:

- database credentials would be rotated through the managed database/secret manager;
- external API keys would be rotated at the provider and updated in the secret manager;
- `DJANGO_SECRET_KEY` rotation needs care because it can invalidate signed sessions, so I would plan that as a controlled maintenance task or implement key fallback support first.

### Rollout and rollback

CI publishes immutable GHCR images tagged by commit SHA, plus a moving `main` tag.

For rollout:

1. Merge to `main` after tests pass.
2. CI builds and publishes `ghcr.io/<owner>/<repo>:sha-<commit>`.
3. Deploy that immutable SHA tag to staging.
4. Run smoke checks against staging: `/healthz/`, login, create/edit/delete note, summarize note.
5. Promote the same SHA tag to production.
6. Use rolling or blue/green deploys so old tasks stay serving until new tasks pass health checks.

For rollback:

- redeploy the previous known-good `sha-...` image tag;
- avoid rolling back database schema blindly;
- if a release included migrations, follow the migration runbook below before rolling back app code.

### Database migrations

For local Compose, the entrypoint runs migrations automatically for convenience.

For production, I would run migrations as a separate release step/job before shifting traffic to the new web containers. That job should:

- run once, not once per web replica;
- use the same image SHA as the release;
- fail the deployment if migrations fail;
- emit logs to the normal centralized logging system.

For irreversible or risky migrations:

- use expand/contract patterns;
- deploy backward-compatible schema changes first;
- backfill in small batches if needed;
- deploy app code that reads/writes the new shape;
- only remove old columns/tables after the new version is stable;
- take a fresh backup and document the restore point before the migration.

### Logs, metrics, and alerts

Logs should go to stdout/stderr from the container and be collected by the platform into a central log system. I would include request IDs and structured JSON logs before production traffic.

Minimum metrics/alerts before real users:

- app availability and healthcheck failures;
- HTTP 5xx rate;
- request latency p95/p99;
- container restarts and memory/CPU saturation;
- database connection count, CPU, storage, and slow queries;
- migration job failures;
- summarization failures/timeouts once the external service is real.

Alerts should go to the team's normal on-call path, such as PagerDuty/Opsgenie/Slack, with clear runbooks for common failures.

### Before real users touch it

Before production traffic, I would want:

- HTTPS-only access with secure cookies and HSTS enabled;
- production `ALLOWED_HOSTS` and CSRF trusted origins set explicitly;
- managed Postgres backups and restore tested;
- staging environment using the same image and migration flow;
- smoke tests in CI/CD after deploy;
- dependency and image vulnerability scanning;
- documented rollback/migration procedures;
- basic abuse protection for login and expensive summarize calls;
- ownership/runbook docs so a teammate can operate the service without guessing.
