# Submission

## What I changed and why

### App

- Added .env* to .gitignore
- Removed .env and added sanitized .env.example so reader knows what to set for local deployment (when no docker)
- Default 'DEBUG' to False
- Replaced wildcard 'ALLOWED_HOSTS' with localhost, 127.0.0.1
- Read 'SECRET_KEY' from environment 
- Database now parses 'DATABASE_URL'
- Real logging instead of `print()`
- 'requirement.txt' all pinned with tested version
- Production security hardenings, individually env-tunable so local container on plain HTTP works:

### Docker

One command to run stack using `docker compose up --build`, and serves on http://localhost:8000. No host setup beyond Docker.
- Added Dockerfile for image build
- Added Docker Compose defines 'db' and 'web'
- Added Dcoker Entrypoint script so the container is self-bootstrapping
- Added Whitenoise middleware to handle static files
- Added .dockerignore so build output never enter the image

### CI

- Updated CI to trigger on 'main' and my branch test 'alex-assessment'
- 'test' job to psin up Postgre 16 and smoke-check
- 'frontend' job to npm build
- 'publish' job to build and push image to repo with commit tag

## Tradeoffs

- dj-database-url dependency, added the small, standard library rather than writing a URL parser
- WhiteNoise keeps the stack to two containers and is plenty for this traffic level; a CDN/nginx in front would be the move at scale. The static-serving change is config-only (no app rewrite).


## What I'd do with another day

- Remove DB migration from docker-entrypoint.sh, add as a dedicated CICD step
- Add security/vulnerability scanning in CICD
- Add container status checking mechanism to CI (If using applicable service)
- Build dev/qa/stg/prod branch and set up github organization merge policy (prevent drift between envs, branch protection)
- Build infra branch for Terraform, keep it separate from application branch/pipeline

## How to run

**Containerized — one command:**

```bash
docker compose up --build
# open http://localhost:8000  and log in as demo / demo
```

**Local (no Docker):** the app defaults to SQLite when `DATABASE_URL` is unset.

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
npm install && npm run build
cp .env.example .env          # set DJANGO_SECRET_KEY; DJANGO_DEBUG=True for dev
python manage.py migrate
python manage.py seed
python manage.py runserver
```

## Deployment plan

> How would you take this from `docker compose up` on your laptop to a safe, production-ready deployment? You do not need to actually deploy it — we want your reasoning. Cover at least: where it runs, how secrets reach it, rollout + rollback, migrations, logs/metrics/alerts, and anything you'd want in place before a real user touched it.


Architecture (AWS service to consolidated mamangement)

### Github & AWS management
I would own github repository for each AWS account for main terraform code.
Github repo per application, I would use branch to control dedicated code/resources
- dev/qa/stg/prod branch - appplication code and workflow file
- infra branch - Terraform code for dedicated resource management

### CI/CD & rollback

1. Deploy to `dev` → run smoke checks.
2. Promote to `qa` → `stg` (same image) with validation gates.
3. Promote to `prod` behind required approval.

If deployment fails, ECS will automatically roll back to previous image. If manual intervension is needed,
1. Identify the last known-good `sha-<prev>`.
2. Update the ECS service to that task definition / image.

We can use image tag with "dev-latest, prod-latest" to separate image versions between envs.


### AWS resources to build
- AWS codebuild runner for Github Action instead of using github's runner
- AWS ECR repo for image build/pull
- Route53, CloudFront, EC2 (Load Balancer, Target Group) for network
- ECS fargate container (task definition, cluster)
- RDS postgreSQL
- AWS secret manager & SSM parameter store for secret management

### Network layout

```text
Internet
  -> Route 53 (DNS)
  -> CloudFront (CDN)  + AWS WAF (rate limiting, managed rule sets)
       [optional Lambda@Edge / CloudFront Function: security headers,
        CORS handling, allowed-origin enforcement]
  -> Internal ALB  (CloudFront as the only origin)
  -> Target group
  -> ECS Fargate task  (private subnet)
  -> RDS PostgreSQL    (private subnet)
```

ALB is **internal** and only accepts traffic from CloudFront (locked down via the CloudFront managed prefix list / a shared secret header verified at the edge). Fargate tasks and RDS sit in **private subnets** with no public IPs.

### Monitoring & Alerting
- CloudWatch for log monitoring and alerts (email, sns, slack, or whichever company prefers)
- Use external log ingest & analysis (datadog, checkly, etc) for log collection

### Idea: AWS DevOpsAgent for failure triage
I ran a small POC with AWS's DevopsAgent service: you connect the org's GitHub (read-only) and it can inspect branches, commits, and GitHub Actions run status, and correlate that with AWS-side signals. If budget allows, this could shorten incident triage — engineers investigate a deploy failure in one place instead of switching back and forth between the GitHub Actions UI and the AWS console.