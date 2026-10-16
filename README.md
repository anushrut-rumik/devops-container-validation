# Simple Docker CI/CD with GitHub 

This project demonstrates a small automated workflow for a Node.js application.

## What happens when you push to main?

1. GitHub installs the application dependencies.
2. It runs two application tests.
3. Docker builds a fresh image containing the application, with build caching disabled and a unique tag for each workflow run and retry.
4. The workflow briefly starts that image and checks that the application responds.
5. It removes the temporary container.
6. If Docker Hub credentials are configured, it publishes the checked image.

Everything runs on GitHub's temporary machine. No laptop runner, cloud server, or persistent deployment is needed.

```text
Push to main → Test code → Build Docker image → Check container → Optionally publish
```

The small DevOps difference from the original project is the running-container check: an image must start and respond correctly before it can be published.

## What does the application do?

It is deliberately simple:

- `GET /` returns a welcome message and version.
- `GET /health` returns `{"status":"healthy"}`.

The purpose is to demonstrate the pipeline, not a complex application.

## How to demo it

1. Make a small change to this README, such as adding your group members.
2. Commit and push:

```bash
git add README.md
git commit -m "Demo the Docker workflow"
git push origin main
```

3. Open [GitHub Actions](https://github.com/anushrut-rumik/devops-container-validation/actions).
4. Select the new **Docker Build and Container Validation** run.
5. Open **build-test-push**.
6. Show **Run tests**, **Build Docker image locally**, and **Start and verify the built container** passing.

Say: "Whenever we push a change, GitHub checks our code, builds its Docker image, and verifies that the container works."

Without Docker Hub secrets, publishing is skipped. That does not prevent the tests, build, or container check from running.

## Optional Docker Hub publishing

Create a Docker Hub repository named `devops-container-validation`. Add these GitHub repository secrets under **Settings → Secrets and variables → Actions**:

- `DOCKERHUB_USERNAME`: your Docker Hub username.
- `DOCKERHUB_TOKEN`: an access token with permission to push to that repository.

The workflow publishes `latest` and source-commit tags after successful checks. It does not deploy a permanent application.

## Optional local run

Use Node.js 24:

```bash
npm ci
npm test
npm start
```

Open `http://localhost:3000/` or `http://localhost:3000/health`. Stop with Ctrl+C.

To try the Docker check locally, with Docker running:

```bash
docker build -t devops-container-validation:local .
bash scripts/check-container.sh devops-container-validation:local
```

The script removes its temporary container when finished. Local Docker is not required to demonstrate the GitHub workflow.

## Main files

| File | Purpose |
|---|---|
| `src/server.js` | Simple web application |
| `test/server.test.js` | Application tests |
| `Dockerfile` | Packages the application |
| `scripts/check-container.sh` | Checks the running Docker image |
| `.github/workflows/docker.yml` | Automates the steps |

## Original project

Adapted from [Jain2975/DevopsLabCA](https://github.com/Jain2975/DevopsLabCA). The original history is retained; this version adds the container check before publishing.
