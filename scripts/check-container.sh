#!/usr/bin/env bash
set -euo pipefail

image="${1:?Usage: bash scripts/check-container.sh IMAGE}"
container_name="devops-check-$$"
response_dir="$(mktemp -d)"

cleanup() {
  result=$?
  trap - EXIT
  if [ "$result" -ne 0 ]; then
    echo "Container verification failed. Container logs:"
    docker logs "$container_name" 2>&1 || true
  fi
  docker rm -f "$container_name" >/dev/null 2>&1 || true
  rm -rf "$response_dir"
  exit "$result"
}
trap cleanup EXIT

# Docker selects an available local port, avoiding conflicts with other apps.
docker run --detach --name "$container_name" --publish 127.0.0.1::3000 "$image"
address="$(docker port "$container_name" 3000/tcp)"
base_url="http://$address"

ready=false
for attempt in {1..15}; do
  if curl --fail --silent --show-error --max-time 2 "$base_url/health" > "$response_dir/health.json"; then
    ready=true
    break
  fi
  sleep 1
done

if [ "$ready" != true ]; then
  echo "The container did not become ready within 15 attempts."
  exit 1
fi

curl --fail --silent --show-error --max-time 2 "$base_url/" > "$response_dir/home.json"

# Check the response content, not just whether a port is open.
node --input-type=module - "$response_dir" <<'NODE'
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const directory = process.argv[2];
const health = JSON.parse(readFileSync(`${directory}/health.json`, 'utf8'));
const home = JSON.parse(readFileSync(`${directory}/home.json`, 'utf8'));
assert.equal(health.status, 'healthy');
assert.equal(home.message, 'DevOps Lab CA application is running!');
assert.equal(home.version, '1.0.0');
console.log('PASS: the built Docker container serves the expected home and health responses.');
NODE
