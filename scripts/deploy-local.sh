#!/usr/bin/env bash
set -euo pipefail

image="${1:?Usage: bash scripts/deploy-local.sh IMAGE COMMIT}"
commit="${2:?Pass the source commit identifier}"
container_name="devops-lab-app"
previous_name="devops-lab-app-previous"

docker image inspect "$image" >/dev/null
if docker container inspect "$previous_name" >/dev/null 2>&1; then
  echo "A previous deployment needs attention: $previous_name already exists."
  exit 1
fi

has_previous=false
replace_existing=false
if docker container inspect "$container_name" >/dev/null 2>&1; then
  owner="$(docker inspect --format '{{index .Config.Labels "devops-lab.managed"}}' "$container_name")"
  if [ "$owner" != "true" ]; then
    echo "Refusing to replace a container not managed by this project."
    exit 1
  fi
  replace_existing=true
fi

finished=false
cleanup() {
  result=$?
  trap - EXIT
  if [ "$finished" != true ]; then
    echo "Deployment failed; cleaning up the new container."
    docker logs "$container_name" 2>&1 || true
    docker rm -f "$container_name" >/dev/null 2>&1 || true
    if [ "$has_previous" = true ]; then
      docker rename "$previous_name" "$container_name"
      docker start "$container_name"
      echo "Restarted the previous container."
    fi
  fi
  exit "$result"
}
trap cleanup EXIT

if [ "$replace_existing" = true ]; then
  docker rename "$container_name" "$previous_name"
  has_previous=true
  docker stop --time 10 "$previous_name"
fi

docker run --detach \
  --name "$container_name" \
  --label devops-lab.managed=true \
  --restart unless-stopped \
  --publish 127.0.0.1:8080:3000 \
  --env "APP_COMMIT=$commit" \
  "$image"

# Readiness must come from the new container, with the expected commit marker.
ready=false
for attempt in {1..20}; do
  if docker exec "$container_name" node --input-type=module -e '
    const health = await fetch("http://127.0.0.1:3000/health", { signal: AbortSignal.timeout(2000) });
    const home = await fetch("http://127.0.0.1:3000/", { signal: AbortSignal.timeout(2000) });
    if (!health.ok || !home.ok || (await health.json()).status !== "healthy" || (await home.json()).commit !== process.env.APP_COMMIT) process.exit(1);
  '; then
    ready=true
    break
  fi
  sleep 1
done

if [ "$ready" != true ]; then
  echo "The new container did not become healthy."
  exit 1
fi

# Also confirm that the published laptop port is reachable.
curl --fail --silent --show-error --max-time 5 http://127.0.0.1:8080/health
finished=true
if [ "$has_previous" = true ]; then
  docker rm "$previous_name"
fi
echo "Deployed $commit at http://localhost:8080. The container remains running."
