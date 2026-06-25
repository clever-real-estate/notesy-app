# Submission

> Rename this file to `SUBMISSION.md` and fill it in. Keep it as long as it needs to be — no longer.

## What I changed and why

### App
- Converted SECRET_KEY to environment variable to it can be passed once containerized and isn't in GIT.
- Converted DEBUG to environment variable with default False so it can be toggled on for local development of the app.
- Commented out /Admin URL path for now as I didn't see any usage and it is not recommended to be available publicly
- Setup allowed hosts list for localhost instead of * to lock down hostname allows.  Required when DEBUG isn't True.
- Added DJANGO_OLD_SECRET_KEY environment variable that can be used for key rotation as-needed, defaults to empty
- Added cookie security flag for HTTPONLY.  This prevents JavaScript from reading the cookie data and is considered more secure.
- Added cookie security flag for SECURE but set to false.  This prevents the cookie from being sent over HTTP where it can be intercepted unencrypted.  I however set this to false for now because I do not have HTTPS setup yet.
- Added comment to change session engine to Redis later if time allows.  File-based caches are not generally shared between containers and will not support load balancing the site across servers.
- Added stub for creating a content security policy.  If I have time I'll come back and build this.  This is a good security setting to add and would be something required for PCI or compliance heavy environments.
- Added comment to come back and change session handling later.
- Added session cookie age to settings.  Default of 2 weeks may be high for some apps.  This would require on app security requirements but should be explicitly set as best practice in my mind.
- Increase password validation requirements to set length to 12 and add common and numeric password checks.  Strong passwords are important to securing an app.

#### TODO
- Implement session handling, in prod we can't have sessions in local files
- Implement CSP
- http -> https redirect, might be better at load balancer level
- Looks like Django needs to deal with static objects, might be something for docker and later though
- Verify no vulnerable packages, I saw a warning in my build of the ts stuff
- Understand asgi vs wsgi and which to use.  wsgi works but asgi seems to be the intent.

### Docker
-

#### TODO
- Build Docker file
- Change to use postgres and add container for it
- Setup docker compose file
- Setup container reg and push first version

### CI
-

#### TODO
- Setup GitHub actions
-- Run tests
-- Build container
-- Push built container to reg

## Tradeoffs

-

## What I'd do with another day
- I choose not to investigate how to research django sessions or if the app is using them due to my lack of knowledge of django.  If this app uses a session then the default appears to store in memory which will not work in production when load balanced.  Therefore you would need to implement a remote state backend such as Redis.
- I choose not to add HTTPS to the application because my assumption is that the load balancer in front of this app in production will terminate HTTPS/TLS.  This means I also did not include security headers such as HSTS and did not set the secure flag on the cookies.

## How to run

```bash
# the command(s) a reviewer should run
```

## Deployment plan

> How would you take this from `docker compose up` on your laptop to a safe, production-ready deployment? You do not need to actually deploy it — we want your reasoning. Cover at least: where it runs, how secrets reach it, rollout + rollback, migrations, logs/metrics/alerts, and anything you'd want in place before a real user touched it.

-
