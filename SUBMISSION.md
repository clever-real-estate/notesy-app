# Submission

## What I changed and why

### App

**Secrets out of version control.**


The repo shipped a `.env` committed in the initial commit, containing the Django `SECRET_KEY`, a `sk-live-`-prefixed summarizer API key, and a Postgres password. I added `.env` to `.gitignore` so it is no longer tracked; ; a valueless `.env.example` documents every variable the app reads.

Note that gitignoring does not remove the secrets already present in git history — they remain readable at the initial commit and must be treated as compromised. The real remediation is rotation of every affected credential. I did not rewrite history to scrub the file as mentioned in the brief.

**Secrets in production.** 

A `.env` file is a local-development convenience, not a production secrets mechanism. In a deployed environment, secrets should not sit in a plaintext file at all — they should be injected at runtime as environment variables from a managed secret store (e.g. AWS Secrets Manager / SSM Parameter Store, or Kubernetes Secrets). Because`settings.py` reads config from the environment, the *source* of those variables becomes a deployment concern, not a code concern: locally they come from `.env`, in production from the secret manager, with the same env-var interface either way. Rotation is then handled by the secret store rather than by editing files.

**Environment-driven configuration**

`settings.py` previously hardcoded `SECRET_KEY`, `DEBUG=True`, `ALLOWED_HOSTS=["*"]`, and a sqlite database, ignoring the `.env` the repo shipped. I wired the environment-specific config to `os.environ` (loaded from `.env` locally via the `python-dotenv` already in requirements), with safe-by-default behavior:

- `DEBUG` defaults to `False`; a missing var yields the safe state.
- `SECRET_KEY` is read from the environment with no hardcoded fallback of any kind. If unset it resolves to `None`, and Django refuses to operate (raises `ImproperlyConfigured` when the key is used), so a known or guessable signing key can never ship by accident. Setup is documented in "How to run."
- `ALLOWED_HOSTS` was `["*"]`, which disables Django's Host-header validation and enables host-header injection since the Host header is client-controlled. Now read from `DJANGO_ALLOWED_HOSTS` per environment, with a `localhost 127.0.0.1` default so local dev needs no setup.
- The database is parsed from `DATABASE_URL` (Postgres) via `dj-database-url`, replacing sqlite (also required for the Tier 2 Postgres setup).

**Dependency pinning and the `requests` bump.**

`requirements.txt` had a single pinned package — `requests==2.20.0` (2018), which carries known CVEs (e.g. CVE-2023-32681, a Proxy-Authorization header leak on redirect) — while every other dependency floated unpinned. Both are problems: the old pin is a security risk, and the unpinned packages make builds non-reproducible. I bumped `requests` to current and pinned every dependency exactly (`==`), including `dj-database-url` (newly added for settings.py). Django is pinned to the **5.2 LTS** line rather than the newer 6.0 standard release, for the longer security-support window.

**Replaced `print()` debugging with structured logging.**

Views used `print()` for operational output — no levels, no timestamps, no way to route or silence it; unusable in production. Added a minimal `LOGGING` config emitting to stdout (the container runtime captures it; files inside a container are lost) with timestamps and levels, and swapped all prints for `logging` calls — failed login at `warning` , routine events at `info`. Usernames logged for audit, never passwords. (The config is an operational concern; the print→logger swap edits view code, so I kept it to a minimal mechanical fix and would flag it in review, as what-to-log is partly an app-domain call.)



### Docker

**Three-container stack.** 

`nginx` (`:80`, public) reverse-proxies dynamic requests to `web` (gunicorn, internal only) and serves `/static/` directly; `db` is Postgres. `docker compose up --build` brings everything up — one command to a working `demo`/`demo` login at `http://localhost:80`.

**Multi-stage Dockerfile (one file, two built images).** 

A `node:22-slim` stage compiles the TypeScript bundle; a shared `appbase` stage installs Python deps and runs `collectstatic` once. The `runtime` target adds a non-root user and runs gunicorn; the `nginx` target copies the collected static and config into a stock nginx image. Both images share the first two stages — no duplication, no separate toolchain in the final images.

**Static files baked into the nginx image** 

At build time (not a shared volume). Immutable images, no volume-ownership gotcha, no collectstatic at runtime. The tradeoff: a static-only change requires rebuilding the nginx image, and collectstatic needs a dummy build-time `SECRET_KEY` to import settings (no real secret is baked in).

**Startup ordering** 

Is health-gated — nginx waits for web healthy, web waits for Postgres healthy (`pg_isready`). No sleep hacks. Entrypoint runs
migrations then seeds demo data idempotently (guarded on the demo user existing, so restarts skip it cleanly).

**Config.** 

App reads from `env_file: .env`; `DATABASE_URL` is overridden in compose to target the `db` service name (not `localhost` — a separate container on the compose network). Postgres port is not published to the host; nothing reaches the DB except the app. nginx forwards `Host` and `X-Forwarded-Proto`, connecting to Tier 1's `ALLOWED_HOSTS` and (in prod) `SECURE_PROXY_SSL_HEADER`.

**TLS** terminates upstream in production (load balancer / ingress); nginx is HTTP-only locally. Consistent with treating transport security as a platform concern.


### CI

**Reworked `ci.yml` from scratch.** 

The original had one critical flaw and several real gaps:

- **`pytest || true` → `pytest`** — the original always reported green even when tests failed. Removing `|| true` is the single most important fix: a failing test now actually fails the build.
- **Scoped triggers** — was `on: [push]` (every branch, always). Now tests run on `feature/**` branch pushes and `pull_request` to main (catch failures early); build-and-push fires on any push event,  gated by `needs: test` so images only reach GHCR if tests pass.
- **Postgres service with healthcheck** — tests run against `postgres:16`  matching the production database. The healthcheck gates test execution until Postgres is actually accepting connections — the same startup-race fix as `depends_on: service_healthy` in compose. The original had no DB service so tests either errored or silently ran against the wrong engine.
- **Python 3.14** — matches the Dockerfile and local venv. Original used 3.12, meaning CI tested a runtime that wasn't shipped.
- **Nothing hardcoded** — DB credentials and Django secret key come from GitHub repository secrets and variables.
- **Two images pushed to GHCR** — `notesy` (gunicorn/runtime) and `notesy-nginx` (nginx with baked static), both tagged by `github.sha`. SHA-only tagging: every push produces one addressable image per target. Rollback is finding the last good SHA in git log and redeploying that image. `github.repository_owner` used instead of a hardcoded username so the workflow is portable across forks.

## Tradeoffs

- **`dj-database-url` vs. hand-parsing `DATABASE_URL`:** added the small library rather than parsing the URL with `urllib.parse` — one dependency for fewer edge cases and a one-line DATABASES block.
**No DB `sslmode` in app config:** left transport security to the platform layer rather than asserting a production assumption in settings.py.

- **Exact pins (`==`) vs. compatible ranges (`~=`):** chose exact pins for reproducible container builds. The cost is no automatic patch updates — which only stays safe if paired with an automated dependency-update tool(Dependabot/Renovate) raising pins behind CI.
- **Django 5.2 LTS vs. 6.0:** picked the LTS line (3-yr support) over the newest feature release (16-mo support) for a production deployment target.

- **nginx sidecar vs. WhiteNoise:** nginx for the production-representative topology — a real reverse proxy with a natural TLS termination point and
  future caching/rate-limiting layer. WhiteNoise would be simpler for this static footprint.

- **Baked static (nginx image) vs. shared volume:** baked for immutability and no runtime ownership complexity; cost is a rebuild on static changes and a
  dummy build-time key.
- **One Dockerfile, two targets vs. separate Dockerfiles:** two images from one build because they share the frontend and appbase stages — no duplication.
  Postgres uses a stock image with no Dockerfile.
- **`npm ci` over `npm install`:** reproducible front-end builds from the lockfile, matching the exact-pin approach for Python deps.

## What I'd do with another day

- Add production security headers (SSL redirect, secure cookies, HSTS, SECURE_PROXY_SSL_HEADER), gated on `not DEBUG`.
- Split test-only dependencies (`pytest`, `pytest-django`) out of `requirements.txt` so the production image doesn't ship the test framework.
- Add automated dependency updates (Dependabot/Renovate) so exact pins still receive security bumps, gated behind CI.
- **Blocking call in `note_summarize`.** `time.sleep(8)` stands in for a synchronous call to the external summarizer service. With sync gunicorn workers, concurrent summarize requests block the whole worker pool — a few can make the app unresponsive to everyone (worker starvation). I left it in place (deleting it hides the risk rather than fixing it; the real call is slow too). Proper fix is to offload to a background task queue (Celery/RQ); interim mitigation is a timeout on the call so a hung upstream can't pin a worker indefinitely. 

- Add Docker layer caching to CI (`cache-from/cache-to: type=gha`) to speed up repeated builds.
- Add `npm run typecheck` (`tsc --noEmit`) as a CI step so TypeScript errors are caught before the image is built.


## How to run


Local development requires a `.env` file at the repo root (it is gitignored).
Copy `.env.example` to `.env` and fill in the values:

    cp .env.example .env

At minimum you must set `DJANGO_SECRET_KEY` and `DATABASE_URL` — the app reads its config from the environment and will refuse to start if `DJANGO_SECRET_KEY` is unset (this is intentional: there is no insecure fallback key anywhere in the code). Generate a key with:

    python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"

`docker compose up --build`

Visit `http://localhost:80` and log in as `demo` / `demo`. The stack is `db` → `web` (migrations + seed) → `nginx`, health-gated so it comes up in the right order automatically. Restart is safe — seeding is idempotent.

For local development outside Docker, ensure `.env` is populated (especially `DJANGO_SECRET_KEY` and `DATABASE_URL`) and run:


```bash
pip install -r requirements.txt
npm install && npm run build
python manage.py migrate
python manage.py seed
python manage.py runserver
```

## Deployment plan


This describes how I'd take Notesy from `docker compose up` on a laptop to a safe, production-ready deployment on AWS. Written for a teammate joining next week.

**Platform and region.**

Start on **ECS with Fargate** — managed container runtime, no EC2 instances to patch, scales to zero when idle, and the operational overhead matches where a small service should be. The three containers from compose map cleanly: an ECS service for the app (gunicorn), a task for nginx (or an ALB in front, making a separate nginx container unnecessary), and Amazon RDS for Postgres (managed, automated backups, multi-AZ for HA). If the service grows in traffic or complexity — more services, more teams, need for fine-grained resource control — migrate to **EKS**. That's not a rewrite; the same Docker images run on Kubernetes with a Helm chart wrapping the compose topology.
Single region to start (`us-east-1` — lowest latency for most US users, widest AWS service availability). Add a second region behind Route 53 latency routing if the user base grows globally or if SLA requirements demand geographic redundancy.

**Secrets.**

No secrets in the image, no secrets in source — established in Tier 1. In production, secrets are stored in **AWS Secrets Manager** and injected as environment variables at task startup by ECS. The app reads them from `os.environ`, so the same code runs locally (from `.env`) and in prod (from Secrets Manager) with no change. Rotation is handled by Secrets Manager: it rotates on a schedule, pushes the new value, and ECS picks it up on the next task restart. No manual secret management, no credential drift. IAM roles (not access keys) grant the ECS task permission to read its own secrets — no long-lived credentials anywhere.

**Rollout strategy.**

**Rolling update** — ECS replaces tasks one at a time, with the old version serving traffic until the new one passes its health check. At least one healthy task is always running, so there's no downtime window. The ALB health check (hitting `/login/`) gates traffic away from tasks that haven't fully started yet.

**Rollback** 

Is redeploying the previous commit's image. Every image is tagged by `github.sha`, so the sequence is: identify the last good commit in git log, trigger a deploy of that SHA's image. No rebuild
needed — the image is already in GHCR. With ECS this is a task definition update pointing at the previous SHA; it's a two-minute operation.

**Database migrations.**

Migrations run as a one-off ECS task before the new app version receives traffic — the same `python manage.py migrate --noinput` from the entrypoint, but as a standalone task rather than inline with the web
process. This separates "migrate the schema" from "start serving traffic" so a failed migration stops the deploy before users see it.

The hard case is a migration that can't be rolled back — a destructive change like dropping a column or renaming a table. The strategy:

1. **Expand/contract pattern.** Never drop in the same deploy you stop using something. First deploy: add the new column, keep the old one, app writes to both. Second deploy: migrate data, switch reads to new column. Third deploy: drop the old column once confident. Each step is independently rollback-safe.
2. **Backup before any destructive migration.** RDS automated backups + a manual snapshot immediately before the migration runs. If something goes wrong, restore point is minutes away.
3. **If a migration has already run and rollback is impossible:** roll forward with a fix rather than back. The app code is the rollback lever, not the schema.

**Logs, metrics, alerts.**


The app already logs structured output to stdout. In ECS, stdout is automatically shipped to **CloudWatch Logs** — no agent, no config. Log groups per service, retention set to 30 days.

Metrics via **CloudWatch Container Insights** (CPU, memory, request count per task) and application-level metrics from gunicorn (request duration,error rate). Key alerts:

- **5xx error rate > 1%** — page on-call immediately.
- **p99 response time > 2s** — warning; investigate before it becomes an outage. (Also the signal that the `note_summarize` blocking call is causing worker starvation under load)
- **Task restarts** — a restarting task is almost always a crash loop; alert before it takes down the service.
- **RDS CPU / connection count** — headroom indicator; act before it becomes a bottleneck.

Alerts route to **SNS → PagerDuty/Slack** depending on severity. Critical (5xx spike, task crash) → PagerDuty. Warning (latency, DB headroom) → Slack.

**Before a real user touches it.**
In rough priority order:

- **HTTPS end to end.** ALB terminates TLS with an ACM certificate; HTTP redirects to HTTPS. `SESSION_COOKIE_SECURE` and `CSRF_COOKIE_SECURE` enabled (currently deferred — safe to add now that the platform layer is defined).
- **Secrets in Secrets Manager**, not a `.env` file on a server.
- **RDS in a private subnet** — not reachable from the public internet, only from the app's security group.
- **At least two tasks running** so a single task failure doesn't cause downtime.
- **Backup verified** — automated RDS snapshots enabled and a restore tested, not just assumed to work.
- **Alerts wired** — at minimum the 5xx and task-restart alerts above, so the first sign of trouble reaches a human.
- **The `note_summarize` blocking call** handled — either a timeout on the real API call so a hung upstream can't pin a worker indefinitely, or summarize traffic isolated to a separate task definition so it can't starve the main service. The background queue (Celery/RQ) is the full fix but takes time; the timeout is the immediate must-have.
