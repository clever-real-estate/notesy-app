# Submission

> Rename this file to `SUBMISSION.md` and fill it in. Keep it as long as it needs to be — no longer.

## What I changed and why

### App

**Secrets out of version control.**
The repo shipped a `.env` committed in the initial commit, containing the Django `SECRET_KEY`, a `sk-live-`-prefixed summarizer API key, and a Postgres password. I added `.env` to `.gitignore` so it is no longer tracked; ; a valueless `.env.example` documents every variable the app reads.

Note that gitignoring does not remove the secrets already present in git history — they remain readable at the initial commit and must be treated as compromised. The real remediation is rotation of every affected credential.
I did not rewrite history to scrub the file as mentioned in the brief.

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
-

### Docker

### Docker

**Three-container stack.** `nginx` (`:80`, public) reverse-proxies dynamic requests to `web` (gunicorn, internal only) and serves `/static/` directly; `db` is Postgres. `docker compose up --build` brings everything up — one command to a working `demo`/`demo` login at `http://localhost:80`.

**Multi-stage Dockerfile (one file, two built images).** A `node:22-slim` stage compiles the TypeScript bundle; a shared `appbase` stage installs Python deps and runs `collectstatic` once. The `runtime` target adds a non-root user and runs gunicorn; the `nginx` target copies the collected static and config into a stock nginx image. Both images share the first two stages — no duplication, no separate toolchain in the final images.

**Static files baked into the nginx image** at build time (not a shared volume). Immutable images, no volume-ownership gotcha, no collectstatic at runtime. The tradeoff: a static-only change requires rebuilding the nginx image, and collectstatic needs a dummy build-time `SECRET_KEY` to import settings (no real secret is baked in).

**Startup ordering** is health-gated — nginx waits for web healthy, web waits for Postgres healthy (`pg_isready`). No sleep hacks. Entrypoint runs
migrations then seeds demo data idempotently (guarded on the demo user existing, so restarts skip it cleanly).

**Config.** App reads from `env_file: .env`; `DATABASE_URL` is overridden in compose to target the `db` service name (not `localhost` — a separate container on the compose network). Postgres port is not published to the host; nothing reaches the DB except the app. nginx forwards `Host` and `X-Forwarded-Proto`, connecting to Tier 1's `ALLOWED_HOSTS` and (in prod) `SECURE_PROXY_SSL_HEADER`.

**TLS** terminates upstream in production (load balancer / ingress); nginx is HTTP-only locally. Consistent with treating transport security as a platform concern.
-

### CI

**Reworked `ci.yml` from scratch.** The original had one critical flaw and several real gaps:

- **`pytest || true` → `pytest`** — the original always reported green even when tests failed. Removing `|| true` is the single most important fix: a failing test now actually fails the build.
- **Scoped triggers** — was `on: [push]` (every branch, always). Now tests run on `feature/**` branch pushes and `pull_request` to main (catch failures early); build-and-push fires on any push event,  gated by `needs: test` so images only reach GHCR if tests pass.
- **Postgres service with healthcheck** — tests run against `postgres:16`  matching the production database. The healthcheck gates test execution until Postgres is actually accepting connections — the same startup-race fix as `depends_on: service_healthy` in compose. The original had no DB service so tests either errored or silently ran against the wrong engine.
- **Python 3.14** — matches the Dockerfile and local venv. Original used 3.12, meaning CI tested a runtime that wasn't shipped.
- **Nothing hardcoded** — DB credentials and Django secret key come from GitHub repository secrets and variables.
- **Two images pushed to GHCR** — `notesy` (gunicorn/runtime) and `notesy-nginx` (nginx with baked static), both tagged by `github.sha`. SHA-only tagging: every push produces one addressable image per target. Rollback is finding the last good SHA in git log and redeploying that image. `github.repository_owner` used instead of a hardcoded username so the workflow is portable across forks.
-

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

- Add production security headers (SSL redirect, secure cookies, HSTS, `SECURE_PROXY_SSL_HEADER`), gated on `not DEBUG`.
- Split test-only dependencies (`pytest`, `pytest-django`) out of `requirements.txt` so the production image doesn't ship the test framework.
- Add automated dependency updates (Dependabot/Renovate) so exact pins still receive security bumps, gated behind CI.
- **Blocking call in `note_summarize`.** `time.sleep(8)` stands in for a synchronous call to the external summarizer service. With sync gunicorn workers, concurrent summarize requests block the whole worker pool — a few can make the app unresponsive to everyone (worker starvation). I left it in place (deleting it hides the risk rather than fixing it; the real call is slow too). Proper fix is to offload to a background task queue (Celery/RQ); interim mitigation is a timeout on the call so a hung upstream can't pin a worker indefinitely. 

- Add Docker layer caching to CI (`cache-from/cache-to: type=gha`) to speed up repeated builds.
- Add `npm run typecheck` (`tsc --noEmit`) as a CI step so TypeScript errors are caught before the image is built.

-

## How to run

```bash
# the command(s) a reviewer should run
```
Local development requires a `.env` file at the repo root (it is gitignored).
Copy `.env.example` to `.env` and fill in the values:

    cp .env.example .env

At minimum you must set `DJANGO_SECRET_KEY` and `DATABASE_URL` — the app reads its config from the environment and will refuse to start if `DJANGO_SECRET_KEY` is unset (this is intentional: there is no insecure fallback key anywhere in the code). Generate a key with:

    python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"

docker compose up --build

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

**Secrets.** A `.env` file is a local-dev convenience, not a production secrets mechanism. In production, secrets are injected at runtime as environment variables from a managed secret store (e.g. AWS Secrets Manager / SSM,or Kubernetes Secrets) — never written to a file in the image or repo. Because settings.py reads everything from the environment, the *source* of those variables is a deployment concern, not a code concern: the same settings.py runs locally (from `.env`) and in prod (from the secret store) with no change. Rotation is handled by the secret store.

**Database transport security.** I did not hard-code `sslmode` into settings.py. Encryption of app-to-Postgres traffic is enforced at the platform layer: the database runs on a private network unreachable from the public internet, and a managed Postgres endpoint would require TLS server-side. This keeps app config free of environment-specific assumptions. If app-side enforcement were wanted as defense-in-depth, `dj-database-url` supports `ssl_require=True` (ideally with `verify-full` for certificate verification, not bare `require`).

**Host validation (defense in depth).** `ALLOWED_HOSTS` is enforced in the app per environment. At the platform layer I would additionally configure the ingress / load balancer to only route requests matching the expected host(s), dropping malformed-host traffic before it reaches the app. The app-level check remains as the inner layer — it travels with the app and covers internal or
direct traffic that bypasses the ingress.
<!-- > How would you take this from `docker compose up` on your laptop to a safe, production-ready deployment? You do not need to actually deploy it — we want your reasoning. Cover at least: where it runs, how secrets reach it, rollout + rollback, migrations, logs/metrics/alerts, and anything you'd want in place before a real user touched it. -->

-
