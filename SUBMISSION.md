# Submission

> Rename this file to `SUBMISSION.md` and fill it in. Keep it as long as it needs to be — no longer.

## What I changed and why

### App
- Converted SECRET_KEY to environment variable to it can be passed once containerized and isn't in GIT.
- Converted DEBUG to environment variable with default False so it can be toggled on for local development of the app.
- Commented out /Admin URL path for now as I didn't see any usage and it is not recommended to be avaialble publiclly
- Setup allowed hosts list for localhost instead of * to lock down hostname allows.  Required when DEBUG isn't True.


### Docker

-

### CI

-

## Tradeoffs

-

## What I'd do with another day

-

## How to run

```bash
# the command(s) a reviewer should run
```

## Deployment plan

> How would you take this from `docker compose up` on your laptop to a safe, production-ready deployment? You do not need to actually deploy it — we want your reasoning. Cover at least: where it runs, how secrets reach it, rollout + rollback, migrations, logs/metrics/alerts, and anything you'd want in place before a real user touched it.

-
