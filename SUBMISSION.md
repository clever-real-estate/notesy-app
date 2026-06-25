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
- Add WhiteNoiseMiddleware to support delivery of static files.  From what I saw the better way to do this in prod is to use a CDN or NGINX but for the sake of this small project WhiteNoise seems good enough for now.  This would be something to revisit depending on the expected traffic and complexity of the app.
- Changed app to use postgres database engine to allow for a remote database that is not a file on your system to be used when deployed.

### Docker

- Build Docker file to allow building the app container.
- Setup docker compose file to allow running the local dev environment quickly.

### CI

- Adjusted ci.yml file to try to build the docker image, test it using a empty database, then publish it to GHCR.

## Tradeoffs

- For now I decided that the app itself would be HTTP and terminate HTTPS at an external load balancer.
- The requirement for postgres means you can't manually run commands at the command prompt unless you specificlly start up the container for postgres on your machine.

## What I'd do with another day

### App

- Implement session handling using Redis.  Production sessions should not be stored on local files within the docker container as that does not allow traffic to be load balanced between containers.
- Implement CSP to improve security of the site.
- Setup HTTPS for the site.  This would likely involve using a reverse proxy like NGINX.  After this was setup I could then enable http to https redirection and would be able to also start using various security related settings I left stubbed.
- An evaluation could be done if the static objects should be migrated off WhiteNoise and hosted with NGINX or whatever is used to terminate HTTPS.  This would allow for better scaling of the site.
- I noticed when running the npm command there was a warning.  An evaluation should be made to ensure there are no vulnerable packages.
- I myself do not at this time understand asgi vs wsgi and which to use.  I used wsgi because ChatGPT suggested it and it seems to work.  I see a file though named asgi so I suspect that is the intended server to be using.  From my breif read asgi might be better for higher load situations and is considered more modern.
- The packages in the requirements.txt installed by PIP should have version numbers added to each of them.  This prevents unexpected package updates that could introduce unexpected bugs.  It can also help protect against supply chain attacks if a new version posted to PIP ends up being compromised by delaying the update until it can be reviewed.
- I did not get time to do a good review of what is being logged.  I see some level of logging spit out for the app as it runs that but that logging seemed pretty weak.  I determined this was lower priority than getting the app running in a container itself.  This would need to be done though before anything went to production.
- If adding IP logging for requests make sure to take into account x-forwarded-for header which should be passed by NGINX or whatever terminates HTTPS.
- The allowed hosts setting should be passed via an environment variable.  This allows production use easier.  I didn't take the time to do this as it was lower priority at this time.

### Docker

- Right now the docker file copies a lot of the local files into the container.  I was trying to use a .dockerignore to keep the container size small.  I need more time to evaluate a better way to handle this, perhaps only copying specific files instead of copying the whole directly and relying on .dockerignore.  Either way this would require more time.
- Investigate if there's a better way to build the docker container, or update it, that doesn't take so long.  I suspect there is using a more modular dockerfile.  I have heard of using multi-stage docker files but have not myself used one before.  I decided doing that research would take too long.
Setup container reg and push first version
- Right now there is not a run for the tests when building the container.  This means errors in the tests are not discovered until the CI is run.  The docker file should run the tests then cleanup after itself.  That validates the docker container passes all tests but ideally is still small.

### CI

- The existing file is not fully tested in all situations, in fact this version isn't tested because I need to commit to test.
- I feel this process could use additional checks added.  There's no kind of security check that might look for things like packages with known vulnerabilities or static code scanning.  Those are well beyond the scope of this initial exercise.

## How to run

This command will start the initial version which sets up the database and seeds it.
```bash
docker compose --profile seed-database up
```

Once you've seeded the database though you would not want your app to continue to reseed the database each run so just use this instead.
```bash
docker compose up
```


## Deployment plan

> How would you take this from `docker compose up` on your laptop to a safe, production-ready deployment? You do not need to actually deploy it — we want your reasoning. Cover at least: where it runs, how secrets reach it, rollout + rollback, migrations, logs/metrics/alerts, and anything you'd want in place before a real user touched it.

-
## Bugs found

- Deleting a note does not reflect on page until refresh.