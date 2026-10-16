# Docker Container Validation Before Publishing

A DevOps mini project that automatically checks whether a built Docker image actually runs before allowing it to be published

## What does this project do?

Whenever code is pushed to `main`, GitHub Actions:

1. Runs the application tests.
2. Builds a Docker image.
3. Starts a container from that exact image.
4. Sends HTTP requests to the running container.
5. Checks that the home page and health endpoint return the expected data.
6. Removes the temporary container.
7. Publishes the verified image to Docker Hub, if credentials are configured.

If the application tests, Docker build, or container checks fail, publishing does not run. Failed container checks print the container logs to help diagnose the problem.

## The DevOps difference from the original project

The application remains the original simple Express server. It returns a welcome message at `/` and a health response at `/health`. It has no temperature converter.

| Original pipeline | This pipeline |
|---|---|
| Test application code | Test application code |
| Build Docker image | Build Docker image |
| Publish image | Start the built container and check its HTTP responses |
| No running-container check | Publish only after the container check passes |

Why does this matter? Application tests can pass even if the Dockerfile starts the wrong file or uses the wrong port. Building an image can also succeed in those situations. Running the actual container catches these packaging and startup problems before publication.

The pipeline publishes the same locally built image that it checked. It does not rebuild a different image for publication.

## Pipeline

```text
Push to main
     |
     v
Run application tests
     |
     v
Build Docker image
     |
     v
Start a container from that image
     |
     v
Check /health and / over HTTP
     |
     +-- Failure --> Print logs, remove container, stop
     |
     v
Remove the temporary container
     |
     v
Publish the verified image, if Docker Hub credentials exist
```

The running-container check is commonly called a smoke test: a short check that the packaged application can start and perform its basic function. It does not replace the application's tests or prove production readiness.

## Main files

| File | Responsibility |
|---|---|
| `src/server.js` | Original simple web application |
| `test/server.test.js` | Two application endpoint tests |
| `Dockerfile` | Packages Node.js and the application |
| `scripts/check-container.sh` | Starts the image, checks responses, prints logs on failure, and cleans up |
| `.github/workflows/docker.yml` | Runs the steps automatically after a push to main |

The container check chooses an available local port, waits up to 15 attempts for a response, and validates the JSON data. Each HTTP attempt has a two-second timeout. It requires Bash, Docker, curl, and Node.js; these are available in the configured GitHub runner.

## Demo 1: Show a successful push

1. Open this project's GitHub repository.
2. Make a small README change locally, such as adding your group members.
3. Commit and push it:

```bash
git add README.md
git commit -m "Add project group details"
git push origin main
```

4. Open **Actions** and select **Docker Build and Container Validation**.
5. Open the run triggered by your push.
6. Show **Run tests**, **Build Docker image locally**, and **Start and verify the built container** passing.
7. Expand the container-check step to show the `PASS` message.

Explain: "The original project built and published an image. Our pipeline also starts that image and verifies the running application before it can be published."

## Demo 2: Show why the extra check matters

An optional failure demonstration can use a temporary branch and the manual workflow trigger, so main remains working:

1. Create a temporary branch from main.
2. Change only the final Dockerfile command from `src/server.js` to `src/missing.js`.
3. Commit and push the temporary branch.
4. In GitHub Actions, manually run the workflow on that branch.
5. Show that application tests pass and the Docker build succeeds, but the running-container check fails because the startup file does not exist.
6. Show the container logs and the skipped publishing step. Do not merge this deliberately broken branch into main.

This demonstrates a failure that testing the application source and building an image alone would not catch.

## Run locally

Use Node.js 24, matching the Dockerfile and GitHub workflow.

```bash
npm ci
npm test
npm start
```

Visit `http://localhost:3000/` and `http://localhost:3000/health`. Stop the app with Ctrl+C.

With Docker running, build and verify the packaged application:

```bash
docker build -t devops-container-validation:local .
bash scripts/check-container.sh devops-container-validation:local
```

The script removes its temporary container after either success or failure.

## Optional Docker Hub publishing

Tests, builds, and container validation run without Docker Hub credentials. In that case, the workflow explicitly skips publishing and explains this in its summary. A green run alone does not mean an image was uploaded.

To enable publishing:

1. Create a Docker Hub repository named `devops-container-validation`.
2. Create a Docker Hub access token with push permission.
3. In the GitHub repository, open **Settings → Secrets and variables → Actions**.
4. Add `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` as repository secrets.
5. Push a change to main or manually start the workflow.

The verified image is published with `latest` and Git commit identifier tags. Starting it on a remote server remains a separate step; this project does not automatically deploy to a remote server.

## Original project

Adapted from [Jain2975/DevopsLabCA](https://github.com/Jain2975/DevopsLabCA). The original application and Git history are retained. The main extension is running-container validation before image publication.
