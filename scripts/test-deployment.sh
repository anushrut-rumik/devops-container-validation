#!/usr/bin/env bash
set -euo pipefail

# Run only on a disposable CI machine: these fixed names belong to this test.
image="${1:?Pass the built image}"
commit="${2:?Pass the source commit}"
if [ "${CI:-}" != "true" ]; then
  echo "This integration test is restricted to disposable CI machines."
  exit 1
fi
for name in devops-lab-app devops-lab-app-previous; do
  if docker container inspect "$name" >/dev/null 2>&1; then
    echo "Refusing to interfere with existing container $name."
    exit 1
  fi
done

cleanup() {
  docker rm -f devops-lab-app devops-lab-app-previous >/dev/null 2>&1 || true
  docker image rm devops-broken-deployment:test >/dev/null 2>&1 || true
}
trap cleanup EXIT

assert_commit() {
  expected="$1" node --input-type=module -e '
    import assert from "node:assert/strict";
    const response = await fetch("http://127.0.0.1:8080/", { signal: AbortSignal.timeout(5000) });
    assert.equal(response.status, 200);
    assert.equal((await response.json()).commit, process.env.expected);
  '
}

echo "TEST: First deployment remains running after the deploy script exits."
bash scripts/deploy-local.sh "$image" "$commit"
assert_commit "$commit"

echo "TEST: A second deployment replaces the running container."
bash scripts/deploy-local.sh "$image" "${commit}-update-test"
assert_commit "${commit}-update-test"
previous_id="$(docker inspect --format '{{.Id}}' devops-lab-app)"

echo "TEST: A broken startup restores the previous running container."
docker build -t devops-broken-deployment:test - <<DOCKERFILE
FROM $image
CMD ["node", "src/missing.js"]
DOCKERFILE
if bash scripts/deploy-local.sh devops-broken-deployment:test broken-startup; then
  echo "FAIL: The broken image was unexpectedly accepted."
  exit 1
fi

for attempt in {1..15}; do
  if curl --fail --silent --max-time 2 http://127.0.0.1:8080/health >/dev/null; then
    break
  fi
  sleep 1
done
assert_commit "${commit}-update-test"
test "$(docker inspect --format '{{.Id}}' devops-lab-app)" = "$previous_id"
echo "PASS: First deployment, replacement, and recovery from failed startup all work."
