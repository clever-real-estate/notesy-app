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

-

### CI

-

## Tradeoffs

- Prioritized configuration management, session handling, logging, and deployment-related concerns. 

## What I'd do with another day

-

## How to run

```bash
# the command(s) a reviewer should run
```

## Deployment plan

> How would you take this from `docker compose up` on your laptop to a safe, production-ready deployment? You do not need to actually deploy it — we want your reasoning. Cover at least: where it runs, how secrets reach it, rollout + rollback, migrations, logs/metrics/alerts, and anything you'd want in place before a real user touched it.

-
