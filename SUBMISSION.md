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
git clone <repo-url>
cd notesy-app

cp .env.dev.example .env

docker compose up --build
```

The application will:

* Start PostgreSQL
* Wait for database readiness
* Run database migrations
* Seed demo data
* Start the Django application via Gunicorn

Once startup completes, visit:

```text
http://localhost:8000
```

Login credentials:

```text
Username: demo
Password: demo
```

## Deployment plan

### Platform

I would deploy this application to AWS ECS in a single region initially. ECS provides managed container orchestration with minimal operational overhead for an application of this size.

### Database

I would replace the Docker Compose PostgreSQL instance with Amazon RDS PostgreSQL. Automated backups, Multi-AZ support, and maintenance windows would be enabled.

### Secrets Management

Application secrets would be stored in AWS Secrets Manager and injected into the container at runtime through ECS task definitions.

Secret rotation would be handled through Secrets Manager where supported.

### Rollout Strategy

Container images would be built by GitHub Actions and published to GitHub Container Registry using immutable commit SHA tags.

Deployments would use rolling updates with health checks.

Rollback would be performed by redeploying the previous image tag.

### Database Migrations

Migrations would run as a dedicated deployment step prior to application rollout.

For migrations that cannot be rolled back safely, I would favor additive migration patterns and staged deployments to reduce risk.

### Logging, Metrics, and Alerting

Application logs would be written to stdout/stderr and forwarded to CloudWatch Logs.

Infrastructure and application metrics would be collected through CloudWatch.

Alerts would be routed to the team's notification platform (Slack, PagerDuty, etc.) for:

* Application health check failures
* Elevated error rates
* Container restart loops
* Database availability issues

### Additional Production Readiness Items

Before serving real users I would want:

* Automated backups and restore testing
* HTTPS termination
* Security scanning in CI
* Dependency vulnerability monitoring
* Infrastructure as Code for all deployed resources
* Basic application and infrastructure monitoring dashboards

```
```
