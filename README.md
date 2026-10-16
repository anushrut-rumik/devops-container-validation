# Test, Build, and Deploy a Docker Application

A DevOps mini project that automatically checks whether a built Docker image actually runs before allowing it to be published

It also includes an automatic deployment job for a demo laptop and tests for deployment, replacement, and failure recovery.

## Current setup: read this first

The repository remains public. No laptop runner has been registered, and `LAPTOP_DEPLOY_ENABLED` has not been enabled. Therefore **automatic laptop deployment is currently disabled**. The workflow includes the deployment job, but skips it until a suitable runner is connected and the variable is enabled.

The GitHub-hosted job does run real deployment tests on a temporary GitHub machine: it deploys a container, replaces it, checks recovery from a broken startup, and removes the test containers. Those tests verify the deployment script; they are not a persistent deployment to your laptop.

## What the application does

The application is intentionally simple:

- `/` returns a welcome message, version, release label, and deployed commit.
- `/health` returns `{"status":"healthy"}`.

`src/release.json` contains the visible release label. Changing that label lets you demonstrate which version is running without adding unrelated application features.

The main project is the automated delivery process around this application.

## What Docker does

Docker packages Node.js, the application code, and dependencies into an image. Starting that image creates a container that runs the web application.

The pipeline distinguishes two uses of containers:

1. A temporary test container proves that the built image starts and responds correctly. It is removed after the check.
2. A deployed container stays running after the deployment script finishes. On the demo laptop it would be available at `http://localhost:8080`.

## Pipeline

```text
Push code to main
        |
        v
GitHub-hosted ARM64 machine
  Run application tests
  Build the Docker image
  Start and check a temporary container
  Test deployment, replacement, and failed-start recovery
  Save the verified image as a workflow artifact
        |
        v
Optional laptop deployment job (currently disabled)
  Download the same verified image
  Load it into the laptop's Docker
  Replace the project's running container
  Check the new container and laptop port
  Leave it running at http://localhost:8080
```

A workflow artifact is a saved file transferred between jobs. Here it contains the Docker image and deployment script. This deployment route does not require Docker Hub credentials and does not rebuild the image on the laptop.

The build uses an ARM64 GitHub machine to match the Apple Silicon laptop. An Intel deployment machine would need a matching image/build architecture and runner labels.

## What changed from the original repository?

| Original project | This project |
|---|---|
| Test source code | Test source code |
| Build Docker image | Build Docker image |
| Publish the image | First start the image and verify HTTP responses |
| No deployment script | Script that starts a persistent container and replaces the old version |
| No deployed-version evidence | Response includes release label and commit |
| No failed-deployment recovery | Restarts the previous container if the replacement fails |

Docker Hub publication remains optional. It is separate from the artifact-based laptop deployment route.

## How deployment works

`scripts/deploy-local.sh IMAGE COMMIT` performs these steps:

1. Confirms the requested image exists locally.
2. Checks that an existing `devops-lab-app` container belongs to this project before touching it.
3. Keeps the previous container temporarily, then stops it to free port 8080.
4. Starts the new image as `devops-lab-app`, mapped to `127.0.0.1:8080`.
5. Checks the new container's health response and expected commit, then checks the laptop port.
6. On success, removes the old container and leaves the new one running.
7. On failure, removes the failed replacement and restarts the previous container if one existed. The workflow still fails to make the unsuccessful deployment visible.

The container uses `--restart unless-stopped`, so Docker can restart it after Docker itself restarts. It cannot serve requests while the laptop is asleep or Docker is stopped. The switch has a brief interruption; this is not a zero-downtime deployment. The application has no database or persistent user data.

## Demo A: What you can show on GitHub now

1. Edit `README.md`, then commit and push to `main`.
2. Open **Actions → Test, Build, and Deploy**.
3. Show the passing application tests and Docker build.
4. Expand **Start and verify the built container** to show the HTTP response check.
5. Expand **Test deployment, update, and failure recovery**. It demonstrates:
   - a first deployment;
   - an update to a different commit marker;
   - a deliberately broken startup;
   - restoration of the previous container.
6. Show the `deployment-<commit>` artifact produced by the successful build.
7. Explain that **Deploy on the laptop** is skipped because no laptop runner is connected.

The deliberate failure inside the integration test is expected: the test passes only if the deploy script rejects it and the previous container works again.

## Demo B: Run a persistent deployment locally by hand

This is a manual demonstration of the deployment script, not automatic deployment from GitHub. Start Docker Desktop first.

```bash
npm ci
npm test
docker build -t devops-container-validation:demo-1 .
bash scripts/deploy-local.sh devops-container-validation:demo-1 demo-1
```

Open `http://localhost:8080/`. You should see `Demo release 1` and commit `demo-1`.

Now change `src/release.json` to:

```json
{
  "label": "Demo release 2"
}
```

Build and deploy the second version:

```bash
docker build -t devops-container-validation:demo-2 .
bash scripts/deploy-local.sh devops-container-validation:demo-2 demo-2
```

Refresh the same URL. The release label and commit should change. The application remains running after the commands finish.

To inspect or stop the local application:

```bash
docker ps --filter name=devops-lab-app
docker logs devops-lab-app
docker stop devops-lab-app
```

## Demo C: Automatic deployment after runner setup

This path is prepared but not activated. Do not describe it as demonstrated until a laptop deployment has completed and its URL has been checked.

A self-hosted runner is GitHub's agent running on a machine you manage. It receives workflow jobs and executes them there. GitHub recommends using self-hosted runners with private repositories because public-repository contributions can expose the machine to untrusted code. See [GitHub's runner setup guidance](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/add-runners).

For an automatic demo, first arrange a suitable private repository or isolated deployment runner. If the repository name changes, update the repository guard in the workflow. Do not connect an everyday laptop to this public repository merely to bypass that concern.

For an approved setup:

1. Register an Apple Silicon macOS runner with the custom label `devops-lab-laptop`.
2. Keep Docker Desktop and the runner process running. This workflow does not install a startup service.
3. Ensure the runner can execute Docker and curl.
4. Set the repository Actions variable `LAPTOP_DEPLOY_ENABLED` to `true`.
5. Push a change to `main`.
6. Watch the hosted build job pass, then the laptop deployment job run.
7. Open `http://localhost:8080/` on the deployment laptop. The commit must match the workflow commit.
8. Change the release label, commit, and push again. Refresh the same URL after deployment finishes to demonstrate the automatic update.

Only `main` in the named repository can enter the laptop deployment job. Manual runs on other branches only exercise CI. Deployment jobs are serialized so two updates do not replace the container simultaneously. If the runner is offline while deployment is enabled, the job queues until a matching runner is available.

Example commands after changing the release label:

```bash
git add src/release.json
git commit -m "Demo: update deployed release label"
git push origin main
```

To disable future laptop deployment jobs, set `LAPTOP_DEPLOY_ENABLED` to `false`. This does not stop a container that is already running.

## Optional Docker Hub publication

To upload the verified image to Docker Hub, create a `devops-container-validation` repository there and add `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` as GitHub repository secrets. Without them, publishing is explicitly skipped.

Published image tags are `latest` and the source commit identifier. The laptop deployment path uses the saved workflow artifact instead of Docker Hub.

## Main files

| File | Role |
|---|---|
| `.github/workflows/docker.yml` | Hosted checks, artifact upload, optional publication, and guarded laptop deployment |
| `scripts/check-container.sh` | Checks a temporary container |
| `scripts/deploy-local.sh` | Starts or replaces the persistent container |
| `scripts/test-deployment.sh` | Exercises deployment and recovery on a disposable CI machine |
| `src/release.json` | Visible release label for the demo |
| `src/server.js` | Simple application and deployed commit response |
| `Dockerfile` | Packages the application |

Runner files and credentials, if created in a future setup, belong in the ignored `.local/` folder, which is also excluded from Docker builds.

## Original project

Adapted from [Jain2975/DevopsLabCA](https://github.com/Jain2975/DevopsLabCA). The original Git history is retained. The extensions concern container validation and deployment.
