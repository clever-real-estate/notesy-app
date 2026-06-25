# Submission

This was a hard project for me because I have never used Django to run a Python webapp.  I thought it was an interesting choice given that Django was only listed in the nice to have section of the job description.  In my case I do have Python experience with small AWS Lambdas and automation helped.  I also have 8+ years of web-based software development experience with other languages helping me understand how the app worked.

I started out by watching a video on YouTube and asking ChatGPT to explain Django's layout compared to .NET where I have the most programing experience.  To be transparent that took me around 40 minutes which I did not include in the project time.

Once I got started on the project I believe I spent around 4 hours actually working on the content of the project itself.  That does not include the time I'm taking now to write out the submission summary and deployment plan.  While I'm not satisfied with my final result being "production ready" I stopped because I was at 4 hours.  I suspect the reason this took me so long is that I have not had any of exposure to AI driven development yet given my previous company had not yet given us access to use AI for it.  I am interested in getting more AI exposure though at a company that does allow the usage of AI development tools.

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
- Changed app to use PostgreSQL database engine to allow for a remote database that is not a file on your system to be used when deployed.

### Docker

- Build Docker file to allow building the app container.
- Setup docker compose file to allow running the local dev environment quickly.

### CI

- Adjusted ci.yml file to try to build the docker image, test it using a empty database, then publish it to GHCR.

## Tradeoffs

- For now I decided that the app itself would be HTTP and terminate HTTPS at an external load balancer.
- The requirement for PostgreSQL means you can't manually run commands at the command prompt unless you specifically start up the container for PostgreSQL on your machine.

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

- My CI doesn't actually work.  I'd want some extra time to make it work but I'm at 4h now so stopping.
- The existing file is not fully tested in all situations, in fact this version isn't tested because I need to commit to test.
- I feel this process could use additional checks added.  There's no kind of security check that might look for things like packages with known vulnerabilities or static code scanning.  Those are well beyond the scope of this initial exercise.
- I feel like the overall workflow could be split out better in GitHub Actions but my experience with it has been light.  I would probably look into splitting the build and test out a bit better.  Right now though it does have the advantage that it will not push the container unless the tests pass.  It is not as reusable though given it does everything as 1 task.

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

For a production application I would run this on AWS with the following services.
- Elastic Container Registry would be used for the application containers.  The CI would be updated to push to this registry.
- ECS Fargate would be used to run the application container itself.  ECS supports automatic scaling the number of containers up and down based on load.
- Aurora PostgreSQL would probably be the easiest place to host the database.  RDS PostgreSQL is also an option and would be closer to the container in dev.  If desired you can also run the database on ECS using a PostgreSQL container with an EFS backend but that would be a lot more management overhead.
- ElastiCache Redis could be utilized for the session storage to move it off a file.  This was noted above as something needed to be done before you can run more than 1 container load balanced.
- For secrets I would setup the ECS task definition to read passwords out of Secret Manager secrets.  You an even build a automation within AWS that rotation of the database password and Django secret key and replaces the app containers with the new settings.
- Various logs, including those from the web container and database, should report their logs to CloudWatch Logs.
- The application will need to terminate HTTPS on a load balancer.  Ideally we would use an Application Load Balancer but a Network Load Balancer is also possible.  Either way the load balancer should terminate traffic with an AWS managed certificate from ACM and then pass traffic along to the ECS container service.
- The AWS account should be using Security Hub, Config, CloudWatch, CloudTrail, and if required Inspector.  I'm sure there are other services but this is those I can think of right now off the top of my head that are for security, logging, and alerting in an AWS account that may have some place in this environment.

Other considerations that need to be taken care of before this application is production ready.
- I mentioned a number of items in the "if I had more time" section related to hardening up the app more, investigating the logging further, and what to enable once HTTPS is setup.  Those would probably be good to set via environment variables so local development environments don't need HTTPS.
- If this is expected to be a larger deployment then the static files should probably be placed into S3 with a CloudFront caching layer instead of serving them from within the container itself.  The ALB should be able to route traffic by route so that the static folder can be in a different service.  I haven't tried this before but I suspect it is possible.
- Deployments could be triggered via GitHub Actions or something else.  The deployment process would need involve updating the ECS task definition for the new container image and the replacing the deployment in ECS.  There needs to be something in the ECS task definition itself that runs the database migration step.  This would likely be via an init container, though AWS doesn't use that term, that is part of the task definition.
- Rollback would simply be reverting the ECS task definition deployed to the prior version.
- Some thought needs to be put into how we want to alert on the application and its metrics.  Metrics such as the number of containers, the container or database CPU/memory usage, or even request volumes might all be useful metrics.  You can use CloudWatch for most of this alerting.  APM would be nice but I don't think it is required right away given how small this app is.
- If compliance requirements for this app are high enough you could look at deploying the containers and database into a VPC.  That would give a higher level of security for the network traffic between them.  Right now my sample I do not believe uses TLS for the database connection so that either needs to get added or we need VPC isolation of the traffic.

## Bugs found

- Deleting a note does not reflect on page until refresh.
