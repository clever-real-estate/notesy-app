# Submission

> Rename this file to `SUBMISSION.md` and fill it in. Keep it as long as it needs to be — no longer.

## What I changed and why

### App

- Removed the committed .env file from source control and replaced it with environment-specific example files (.env.dev.example and .env.prod.example).
- Moved Django configuration (secret key, debug mode, allowed hosts, database configuration) to environment variables.
- Replaced the hardcoded SQLite configuration with DATABASE_URL-based configuration to support SQLite locally and PostgreSQL in containerized/production environments.
- Removed file-based session storage and reverted to Django's default database-backed session handling. This avoids session persistence issues when running multiple containers or replacing containers during deployments.
- Added basic production-oriented Django security settings (secure cookies, content-type protection, clickjacking protection).
- Replaced print() statements with standard Python logging so application logs can be collected by container platforms and centralized logging systems.
- Updated outdated application dependencies where appropriate.

### Docker

Focused on making the application reproducible and easy to run locally while keeping the solution simple.

- Added a Dockerfile to containerize the Django application.
- Switched application startup from Django's development server to Gunicorn.
- Added a .dockerignore to reduce build context size and avoid including local artifacts and secrets in container builds.
- Added a Docker Compose configuration to orchestrate the application and PostgreSQL together.
- Replaced the local SQLite workflow with PostgreSQL in the containerized environment.
- Added a PostgreSQL health check and configured the application container to wait for database readiness before startup.
- Added WhiteNoise to serve static assets
- Configured application startup to automatically run migrations and seed demo data for local onboarding convenience.

### CI

- Run Python tests and fail if broken.
- Run frontend typecheck/build.
- Build the Docker image.
- On main, push to GHCR with rollback-friendly tags.

## Tradeoffs

- Prioritized configuration management, session handling, logging, and deployment-related concerns with respect to making the app production ready.
- Kept the Docker solution intentionally simple and focused on local reproducibility rather than production-scale container orchestration.
- Included migrations and seeding in container startup to reduce reviewer setup effort, though I would separate those concerns in a production deployment.
- Did not implement a multi-stage Docker build due to the assessment time constraints, though that would be a logical next optimization.

## What I'd do with another day

- Convert the image to a multi-stage build to reduce image size and remove build tooling from the runtime image.
- Run containers as a non-root user.
- Add application health endpoints and container health checks.
- Separate database migrations from application startup.
- Introduce a dedicated static asset strategy for a production deployment.

## How to run

```bash
# the command(s) a reviewer should run
```

## Deployment plan

> How would you take this from `docker compose up` on your laptop to a safe, production-ready deployment? You do not need to actually deploy it — we want your reasoning. Cover at least: where it runs, how secrets reach it, rollout + rollback, migrations, logs/metrics/alerts, and anything you'd want in place before a real user touched it.

-