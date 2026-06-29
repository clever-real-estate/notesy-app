# Submission

> Rename this file to `SUBMISSION.md` and fill it in. Keep it as long as it needs to be — no longer.

## What I changed and why

### App

- .gitignore - added .env file to gitignore as you should not have credentials, keys checked in, especially on a public registry.
- .env - added few new keys and updated existing key (DATABASE_URL) making it compatible to use with docker compose and also to maintain coding standards in the app
- .env.sample - sample template that new developers can use to fill the appropriate values

notesy/settings.py:
- Removed hard-coded variables to access the values from the .env file. Variables changed are: SECRET_KEY, DEBUG, ALLOWED_HOSTS, SESSION_ENGINE
- Added urllib.parse for parsing database settings from the DATABASE_URL env variable and for setting the DATABASES variable
- added load_dotenv when I was trying to first setup locally and made few changes. I believe this is not needed for prod, but can stay there when used for local development

notesy/apps/notes/views.py:
- I was not sure if I should have done this change, but I went ahead and removed the print statements and replaced with logging, as print statements would not be available in the logs. This task is usually a developer task but since it was a simple fix, I made the changes here.

Observations:
-   I understood that the session seems to be maintained in file which works fine, but once containerized wont be a good idea as in the containers, the state would not be maintained, so everytime a container restarts, the session state would be lost. So for prod, believe this should be changed to db option which I came acros.
-   The .env file containing creds which is already checked in. This is not a good practice as they could be compromised. 
-   I noticed the summarize function, has a sleep timer for 8 seconds and this is a synchronous function. This is not a good practice as if multiple users click the summarize button, it would make the system unresponsive.
-   Dependencies in requirements.txt does not have version numbers(unpinned), which could make different environments (local, production) running different versions without any indication. So version need to be specified
-   The logout method is a GET method, which opens up a CSRF vulnerability and can log a user out for example. This needs to be fixed
-   The seed command should not be running every time, if this goes into production, correct ?

### Docker

- Setup a two stage Dockerfile — Stage 1 compiles the TypeScript frontend, Stage 2 then builds the final app image. Only the compiled JS output is copied from Stage 1, keeping Node.js and npm out of the final image entirely, making it lighter.
- The notesy-db service uses a pg_isready healthcheck which ensures the app never starts before the database is actually ready to accept connections, not just running.
- The compose file wires the two services together, notesy-db(backend) and notesy-web(frontend). All environment variables are passed in at runtime from .env rather than hardcoding.
- Named volume (postgres_data) is used for the database so data persists across container restarts.
- added .dockerignore to exclude a few folders to reduce bloating

Observations:
-   A couple of things caught me in the middle:
    - We know that docker service names act as internal DNS hostnames within the compose network. I had set up the db service as notesy-db but initially still had localhost in DATABASE_URL in my .env. Once I connected the dots that localhost inside a container refers to itself and not the actual service, it was a quick fix.
    - When adding a non-root user (notesy-appuser) for security hardening, I initially missed setting ownership of the /app folder to that user, coz of which, the app lost write access to the .sessions directory at runtime, and we were using file based sessions. A good reminder to set the correct permissions in Docker.
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
