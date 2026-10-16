# Temperature Conversion API with Automated Docker Publishing

A DevOps mini project that converts Celsius to Fahrenheit and automatically tests, packages, and publishes the application using GitHub Actions and Docker Hub.

## What changed from the original project?

The original application returned a welcome message and a basic health response. This version adds a useful operation: converting a temperature supplied by the caller.

| Area | Original project | This project |
|---|---|---|
| Application purpose | Demonstrate a running web server | Convert Celsius to Fahrenheit |
| Endpoints | `/` and `/health` | `/`, `/health`, and `/convert` |
| Input handling | No user input needed | Validates the supplied temperature |
| Tests | Welcome message and health response | Also checks conversions and invalid input |
| Docker Hub image name | `devops-lab-ca` | `temperature-conversion-api` |
| Delivery process | Test, build, publish | Same process |

The technical foundation stays the same: Node.js, Express, Jest, Supertest, Docker, GitHub Actions, and Docker Hub. No database, frontend framework, or additional service is required.

The workflow publishes an image. It does **not** automatically deploy or update an application on a remote server. Pulling the image and starting a container are separate steps.

## How a conversion works

1. A caller requests `/convert?celsius=25`.
2. Express routes the request to the conversion handler.
3. The handler checks that `celsius` contains exactly one valid number.
4. The handler calculates `fahrenheit = celsius × 1.8 + 32`.
5. The application returns the input and result as JSON.

Example response, with HTTP status `200`:

```json
{
  "celsius": 25,
  "fahrenheit": 77
}
```

Negative temperatures, decimal values, and scientific notation such as `1e2` are supported. Surrounding whitespace is ignored. Missing, blank, repeated, nonnumeric, or excessively large values return HTTP `400` with an `error` message. Hexadecimal input such as `0x19` is rejected.

This is a numerical unit converter; it does not enforce physical temperature limits. Results use JavaScript floating-point numbers, so some decimal results may contain small rounding artifacts.

## Endpoints

| Request | Response |
|---|---|
| `GET /` | Application name, version, and example conversion URL |
| `GET /health` | `{"status":"healthy"}` |
| `GET /convert?celsius=25` | `{"celsius":25,"fahrenheit":77}` |
| `GET /convert?celsius=hello` | HTTP `400` and an error message |

The health endpoint is a basic availability response. It does not inspect external services or provide production monitoring.

## How the automated pipeline works

```text
Developer pushes code to main
              |
              v
GitHub Actions checks out the code
              |
              v
Set up Node.js 24 and install dependencies
              |
              v
Run automated application tests
              |
        Tests pass?
              |
              v
Set up Docker and log in to Docker Hub
              |
              v
Build and publish the application image
              |
              v
A person pulls the image and starts a container
```

Tests and Docker builds run even when Docker Hub credentials have not been configured. Publishing runs only when both `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` are present. Otherwise, the workflow skips login and publishing and explains this in its run summary. A successful build-only run does not mean the image was uploaded.

A failed test stops the job before publishing. The workflow can also be started manually from the GitHub Actions page. It does not currently run automatically for pull requests.

Each published image receives two tags:

- `latest`: a convenient label updated by publishing runs.
- The Git commit identifier: associates a build with its source revision.

The tests check Express directly. The workflow does not start the built container and test it before publishing.

## Repository structure

```text
.github/workflows/docker.yml   Automated test, build, and publishing workflow
src/server.js                  Express endpoints and conversion logic
test/server.test.js            Endpoint, conversion, and validation tests
Dockerfile                     Instructions for packaging the application
.dockerignore                  Files excluded from Docker's build context
package.json                   Project metadata, dependencies, and commands
package-lock.json              Locked dependency versions
```

## Run locally

Use Node.js 24, which is the version configured in the workflow and Dockerfile.

```bash
npm ci
npm test
npm start
```

The server listens on port `3000` by default. Set the `PORT` environment variable to use a different port.

In another terminal, try:

```bash
curl http://localhost:3000/
curl http://localhost:3000/health
curl 'http://localhost:3000/convert?celsius=25'
curl 'http://localhost:3000/convert?celsius=-40'
curl -i 'http://localhost:3000/convert?celsius=hello'
```

The conversion examples return `77` and `-40` Fahrenheit. The invalid example returns HTTP `400`. Stop the server with Ctrl+C.

## Build and run with Docker

A Docker image packages the application, Node.js, and production dependencies. A container is a running instance of that image. Development dependencies used for testing are excluded from the image.

With Docker installed and running:

```bash
docker build -t temperature-conversion-api:local .
docker run --name temperature-api -p 3000:3000 -d temperature-conversion-api:local
curl 'http://localhost:3000/convert?celsius=25'
```

The port mapping connects port `3000` on your computer to port `3000` inside the container. If the local port is busy, use `-p 3001:3000` and visit port `3001` instead.

To inspect and stop the container:

```bash
docker logs temperature-api
docker stop temperature-api
docker rm temperature-api
```

## Demonstrate a push to your own GitHub repository

The workflow runs automatically when a commit reaches `main`. After the project has been pushed to your own repository:

1. Edit the welcome message in `src/server.js` and its expected value in `test/server.test.js`.
2. Run `npm test` to verify the change.
3. Commit and push:

```bash
git add src/server.js test/server.test.js
git commit -m "Update the temperature API welcome message"
git push origin main
```

4. Open your repository's **Actions** tab and select the new **Docker CI/CD** run.
5. Show the passing tests and Docker image build.

This demonstration works without Docker Hub credentials. To also show image publishing, complete the setup below. The workflow can also be run manually, but a manual run does not demonstrate a push trigger.

## Configure GitHub Actions and Docker Hub

1. Put the project in your GitHub repository with a `main` branch.
2. Create a Docker Hub repository named `temperature-conversion-api`.
3. Create a Docker Hub access token with permission to push to that repository.
4. Add these GitHub repository secrets under **Settings → Secrets and variables → Actions**:

| Secret | Value |
|---|---|
| `DOCKERHUB_USERNAME` | Your Docker Hub username |
| `DOCKERHUB_TOKEN` | Your Docker Hub access token |

5. Push a commit to `main`, or manually run **Docker CI/CD** in the Actions tab.
6. Inspect the workflow logs to confirm that tests, image building, and publishing succeeded.

The image destination changed from `devops-lab-ca` to `temperature-conversion-api`. Existing Docker Hub setup must allow pushing to this new repository. Keep credentials in GitHub secrets, not source files.

## Run the published image

After a successful publishing run, replace `YOUR-USERNAME` below with your Docker Hub username:

```bash
docker pull YOUR-USERNAME/temperature-conversion-api:latest
docker run --name temperature-api -p 3000:3000 -d YOUR-USERNAME/temperature-conversion-api:latest
curl 'http://localhost:3000/convert?celsius=25'
```

Remove a previous container with the same name before creating another. To run a particular build, replace `latest` with its Git commit tag. Updating an image does not update an already-running container; pull the intended image and recreate the container.

## Suggested demonstration

1. Explain the conversion formula and show a successful request.
2. Show that invalid input returns HTTP `400`.
3. Run `npm test` and explain the conversion and validation checks.
4. Explain how the Dockerfile packages the application.
5. Push a change to `main` and show the GitHub Actions run.
6. Show the published image and its tags on Docker Hub.
7. Pull and run that image, then demonstrate a conversion from the container.

**Project explanation:** We built a temperature-conversion service. Every push to main automatically tests it, packages it as a Docker image, and publishes the image to Docker Hub. The application adds input validation and real calculation to the original demonstration while retaining the same delivery workflow.

## Original project

Adapted from [Jain2975/DevopsLabCA](https://github.com/Jain2975/DevopsLabCA). This version adds the temperature-conversion API, input validation, expanded tests, and a workflow that can test and build before Docker Hub credentials are configured. The original Git history is retained.
