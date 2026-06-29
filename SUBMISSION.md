# Submission

## What I changed and why

### App

- .gitignore - added .env file to gitignore as you should not have credentials, keys checked in, especially on a public registry.
- .env - added few new keys and updated existing key (DATABASE_URL) making it compatible to use with docker compose and also to maintain coding standards in the app
- .env.sample - sample template that new developers can use to fill the appropriate values

notesy/settings.py:
- Removed hard-coded variables to access the values from the .env file. Variables changed are: SECRET_KEY, DEBUG, ALLOWED_HOSTS, SESSION_ENGINE
- Added urllib.parse for parsing database settings from the DATABASE_URL env variable and for setting the DATABASES variable
- load_dotenv() reads the .env file for local development. In production and Docker, environment variables are injected directly by the platform so load_dotenv() does nothing, but harmless to keep.

notesy/apps/notes/views.py:
- I was not sure if I should have done this change, but I went ahead and removed the print statements and replaced with logging, as print statements would not be available in the logs. This task is usually a developer task but since it was a simple fix, I made the changes here.

Observations:
-   I understood that the session seems to be maintained in file which works fine, but once containerized wont be a good idea as in the containers, the state would not be maintained, so everytime a container restarts, the session state would be lost. So for prod, believe this should be changed to db option which I came acros.
-   The .env file containing creds which is already checked in. This is not a good practice as they could be compromised. 
-   I noticed the summarize function, has a sleep timer for 8 seconds and this is a synchronous function. This is not a good practice as if multiple users click the summarize button, it would make the system unresponsive.
-   Dependencies in requirements.txt does not have version numbers(unpinned), which could make different environments (local, production) running different versions without any indication. So version need to be specified
-   The logout method is a GET method, which opens up a CSRF vulnerability and can log a user out for example. This needs to be fixed
-   The seed command runs on every container start currently. In production this should be removed or guarded with a check so it only runs once on first deployment.

### Docker

- Setup a two stage Dockerfile — Stage 1 compiles the TypeScript frontend, Stage 2 then builds the final app image. Only the compiled JS output is copied from Stage 1, keeping Node.js and npm out of the final image entirely, making it lighter.
- The notesy-db service uses a pg_isready healthcheck which ensures the app never starts before the database is actually ready to accept connections, not just running.
- The compose file wires the two services together, notesy-db(backend) and notesy-web(application). All environment variables are passed in at runtime from .env rather than hardcoding.
- Named volume (postgres_data) is used for the database so data persists across container restarts.
- added .dockerignore to exclude a few folders to reduce bloating

Observations:
-   A couple of things caught me in the middle:
    - We know that docker service names act as internal DNS hostnames within the compose network. I had set up the db service as notesy-db but initially still had localhost in DATABASE_URL in my .env. Once I connected the dots that localhost inside a container refers to itself and not the actual service, it was a quick fix.
    - When adding a non-root user (notesy-appuser) for security hardening, I initially missed setting ownership of the /app folder to that user, coz of which, the app lost write access to the .sessions directory at runtime, and we were using file based sessions. A good reminder to set the correct permissions in Docker.
-

### CI

- CI runs automatically on every push to 'main' via GitHub Actions (`.github/workflows/ci.yml`), with two sequential jobs:
- test: spins up a PostgreSQL service container, installs dependencies, and runs the pytest. Secrets are injected via GitHub Actions secrets.
- build and push: only runs when 'test' passes. Builds the Docker image and pushes it to GHCR tagged with the commit SHA ('ghcr.io/susheilcodes/notesy-app:<sha>'), making every image traceable to the exact commit that produced it.
- cached pip packages and only reinstalls when requirements.txt changes.

## Tradeoffs

- uses the same credentials as local dev for simplicity. In a real setup, CI would have its own isolated database user with limited permissions.
- CI runs only on 'main' with no branch protection rules or PR-required checks. A real team would enforce PRs with required CI passing before merge.
- Code analysis not done before docker build(e.g. SonarQube)
- the docker image is built and pushed without a security scan step (e.g. Trivy). This would be a must before production.


## What I'd do with another day

- Add branch protection rules — require CI to pass before merging
- Add Code Analysis and image scanning to the CI
- Set up manual approval step for the deployments

## How to run

```bash
# the command(s) a reviewer should run
## How to run

# 1. Clone the repo and create your environment file
cp .env.example .env  # fill in your values

# 2. Build and start the app (migrations and seed run automatically)
docker compose up --build

# 3. Access the app at http://localhost:8000
# Login with demo / demo

## Deployment plan (Going to keep Azure as the primary cloud provider here)
> How would you take this from `docker compose up` on your laptop to a safe, production-ready deployment? You do not need to actually deploy it — we want your reasoning. Cover at least: where it runs, how secrets reach it, rollout + rollback, migrations, logs/metrics/alerts, and anything you'd want in place before a real user touched it.

- The app would run on Azure Container Apps or AKS, pulling the tagged image from GHCR. The database would be Azure Database for PostgreSQL Flexible Server.

- Secrets are stored in Azure Key Vault and injected as environment variables at runtime via managed identity. They never appear in the Docker image, the repository, or CI logs.

- Each CI run pushes an image tagged with the commit SHA. Deployments point to a specific SHA tag — never 'latest'. Rolling deploys replace containers one at a time with health checks before proceeding. Rollback is instant: redeploy the previous SHA tag.

- Migrations run as a one-off task before the new container version takes traffic — as an AKS job or pre-deploy hook.

- Logs / metrics / alerts
    - Container logs ship to Azure Monitor/Log Analytics 
    - Key metrics: request latency (p50/p95/p99), error rate (5xx), DB connection pool usage
    - Alerts: PagerDuty or Slack notification if error rate exceeds 1% or p95 latency exceeds 500ms
    - Uptime monitored via an external health check — a /health/ endpoint would need to be added to the app returning HTTP 200

- Before a real user touched it
    - [ ] Image vulnerability scan (Trivy) passes in CI
    - [ ] Staging environment smoke-tested with a production data snapshot
    - [ ] Rate limiting enabled on auth endpoints
    - [ ] HTTPS enforced, 'DEBUG=False', 'ALLOWED_HOSTS' locked down
    - [ ] Database backups enabled with a tested restore procedure

