# Submission

## What I changed and why

### App

First thing I did was read through `settings.py` top to bottom before
touching anything and i noticed the following issues;

The `SECRET_KEY` was hardcoded as `django-insecure-replace-me-eventually`..
If the repo ever goes public that key is gone. Moved it to an environment
variable. Made it a hard crash if the key is missing on startup.

`DEBUG = True` was hardcoded. Easy to overlook, genuinely bad. When debug
mode is on and something breaks, Django shows everyone the full error page
with your source code, your settings, your database queries. All of it.
Changed it to read from the environment and default to `False` if not set.
Safe by default.

`ALLOWED_HOSTS = ["*"]` accepted requests from any domain. Changed it to
read a list from the environment.

Sessions were stored as files on disk. Three problems with that: the files
pile up forever, they vanish if the server restarts, and the whole thing
falls apart if you ever run more than one instance. Switched to database
sessions.

The database was SQLite. Fine locally but it cannot handle concurrent writes
and there is no real backup story. Switched to `dj-database-url` so the
connection string comes from the environment. Local dev still uses SQLite.
Docker uses Postgres.

Added WhiteNoise for static files. Without it CSS and JavaScript return 404
in production. The dev server handles this quietly so it is easy to ship
without noticing.

Added security headers. Secure cookies, SSL redirect, HSTS, clickjacking
protection. All tied to `not DEBUG` so local dev is not affected.

Added logging to stdout. Containers capture stdout automatically. Logs to
a file inside a container disappear on restart.

---

### Docker

Two stage Dockerfile. Stage one uses Node to compile the TypeScript bundle.
Stage two is the Python app. Separating them keeps Node and node_modules
out of the final image.

Ran into something early: I assumed the build output went to
`apps/notes/static/` but `npm run build` actually writes to `static/js/`.
Checked `package.json` after the build step failed and fixed the
`COPY --from` path.

Gunicorn instead of `runserver`. The dev server is single threaded. Not
production.

`docker-compose.yml` runs two services. The database has a health check
using `pg_isready` so the app waits for Postgres to be ready before running
migrations. Without that the app starts, tries to connect immediately, and
crashes.

One thing that got me: Gunicorn needs `--bind 0.0.0.0:8000` not
`127.0.0.1`. The default only accepts connections from inside the container.
Port mapping in compose does nothing if Gunicorn is not listening on the
right interface. Found this because the browser kept returning
`ERR_EMPTY_RESPONSE` with the container showing as healthy.

Startup command chains three things: migrate, seed, start Gunicorn. Fresh
environment sets itself up on first run.

`.dockerignore` excludes `.env`, `.venv`, `node_modules`, `__pycache__`,
the local database. Keeps the image small and keeps secrets out of it.

---

### CI

The original had `pytest || true`. If tests fail the pipeline still passes.
So i changed it to -run: pytest.

No database either. Django tests need one. Added a Postgres service
container to the job.

No JavaScript build step. The app needs a compiled bundle and the original
workflow never built it. Added `npm ci && npm run build`.

Split into two jobs. First job runs tests on every push and pull request.
Second job builds and pushes a Docker image to GitHub Container Registry,
but only on main and only after tests pass.

Images get two tags: `:latest` and the git commit SHA. The SHA is the
useful one. If production breaks you redeploy a previous SHA and you know
exactly what code you are running.

---

## Tradeoffs

`psycopg2-binary` instead of compiling from source. The binary wheel
bundles the Postgres C library so the Docker build does not need headers
installed. Can cause issues on Alpine but we are on Debian slim so it is
not a problem here.

Migrations run at container startup. Works for a single container. If two
containers start simultaneously during a rolling deploy they could both try
to migrate at the same time. Django has partial protection against this but
I would not rely on it at scale. Good enough for now.

Seed also runs every startup. Checked that it handles duplicates without
exploding, but it is still sloppy. In a real production app seeding happens
once during setup, not on every boot.

SQLite locally, Postgres in Docker. Different engines locally and in
production can hide bugs. The payoff is not needing to run Postgres locally
just to work on the app.

---

## What I'd do with another day

Container runs as root. If something in the app gets exploited an attacker
has root inside the container. Adding a dedicated non-root user in the
Dockerfile is a small change.

The login endpoint has no rate limiting. Nothing stops someone from trying
thousands of passwords. Would add `django-ratelimit` or handle it at the
load balancer.

Would run `pip-audit` in CI. Catches known vulnerabilities in dependencies
before they ship.

Requirements file has unpinned packages. `django` with no version pinned
means a breaking release could silently break the build. Would pin
everything.

Would add a `/health` endpoint that checks the database connection. Load
balancers need something real to ping.

---

## How to run

<!-- ```bash
git clone https://github.com/YOUR_USERNAME/notesy-app
cd notesy-app

cp .env.example .env
# Set a real SECRET_KEY in .env
# python -c "import secrets; print(secrets.token_urlsafe(50))"

docker compose up --build
# http://localhost:8000
# demo / demo

docker compose down
docker compose down -v  # wipes database too
``` -->

---

## Deployment plan

### Where it runs

For this stage I would start with Railway or Render. Both run Docker
natively, include managed Postgres, and handle SSL. No need to manage
servers for an app this size.

If it outgrows that, AWS ECS with RDS Postgres. More operational overhead,
more control. Single region to start. Second region only when the uptime
requirement actually justifies it.

### How secrets reach the container

Nothing in the image. Nothing in git. The pattern is straightforward:

Secret goes into the platform secret manager. Platform injects it as an
environment variable at container startup. App reads it from `os.environ`.
It never touches disk and never appears in logs.

Rotation means updating the value in the secret manager and redeploying.
New container picks it up. No code change needed.

### Rollout and rollback

Every merge to main produces two tags:
ghcr.io/username/notesy-app:latest

ghcr.io/username/notesy-app:abc1234def5

Rolling deploy starts new containers, runs health checks, then terminates
old ones. If health checks fail the deploy stops and old containers keep
serving.

Rollback is redeploying an earlier SHA tag. Same speed as a normal deploy.
You always know exactly what code you are rolling back to.

### Migrations

Order matters:

Run migrations
Fail here? Stop. Do not deploy.
Deploy new containers
Health checks pass? Cut over traffic.
Terminate old containers


For a migration that cannot be rolled back, expand and contract. First
deploy: app handles both old and new schema. Run the migration. Second
deploy: drop old schema support. Each step is safe to roll back on its own.

### Logs, metrics, alerts

Logs go to stdout. Platform captures and forwards them. Log lines include
timestamp, level, and module.

Metrics that matter: error rate, p95 response time, database connection
saturation. Alert on error rate above 1% for five minutes. Alert on p95
above two seconds. Both firing together is almost always a database problem.

Health endpoint at `/health` checking database connectivity. Load balancers
ping it. Instance comes out of rotation automatically if it stops returning
200.

### Before a real user touches it

HTTPS enforced. Real SECRET_KEY, not the placeholder. DEBUG off. Database
backups on and tested with an actual restore. Rate limiting on login.
Alerts wired up and verified in staging. At least one other person has
successfully deployed and rolled back. create a Runbook