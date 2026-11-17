#!/usr/bin/env bash
# Starts sam-prusa-connect from its own docker-compose.yml the way umbrelOS
# does (data folders owned by uid 1000, APP_PASSWORD set, no app_proxy), then
# checks that it becomes healthy, that umbrelOS's password is accepted as the
# setup code, and that it requires a sign-in after a restart.
#
# Usage: smoke.sh <image@digest> <expected version>
set -euo pipefail

image="${1:?image}"
version="${2:?version}"
app_dir="sam-prusa-connect"
work="$(mktemp -d)"
port=18580
base="http://127.0.0.1:${port}"

export APP_DATA_DIR="${work}/app"
APP_PASSWORD="$(openssl rand -hex 32)" # same shape as umbrelOS's: 64 hex characters
export APP_PASSWORD

mkdir -p "${APP_DATA_DIR}/data/config" "${APP_DATA_DIR}/data/storage"
sudo chown -R 1000:1000 "${APP_DATA_DIR}/data"

python3 - "${app_dir}/docker-compose.yml" "${work}/compose.yml" "${image}" "${port}" <<'PY'
import sys, yaml
source, target, image, port = sys.argv[1:]
compose = yaml.safe_load(open(source))
compose.pop("version", None)
services = compose["services"]
services.pop("app_proxy")  # umbrelOS's own service, not runnable here
services["server"]["image"] = image
services["server"]["ports"] = [port + ":8080"]
yaml.safe_dump(compose, open(target, "w"), sort_keys=False)
PY

dc() { docker compose -p smoke -f "${work}/compose.yml" "$@"; }

fail() {
  echo "::error::$*"
  dc ps || true
  dc logs --no-color --tail=200 || true
  exit 1
}

if ! docker pull "${image}"; then
  fail "anonymous pull of ${image} failed. If this is the first build, make the package public: github.com/users/sam-apostel/packages/container/prusa-connect/settings > Change visibility > Public, then re-run this workflow."
fi

wait_healthy() {
  local id status
  id="$(dc ps -q server)"
  for _ in $(seq 1 40); do
    status="$(docker inspect --format '{{.State.Health.Status}}' "${id}" 2>/dev/null || echo missing)"
    echo "health: ${status}"
    [[ "${status}" == "healthy" ]] && return 0
    [[ "$(docker inspect --format '{{.State.Running}}' "${id}")" == "true" ]] || fail "the server exited"
    sleep 5
  done
  fail "the server did not become healthy"
}

dc up -d
wait_healthy

health="$(curl -fsS "${base}/api/v1/health")"
echo "health: ${health}"
grep -q "\"version\":\"${version}\"" <<<"${health}" || fail "health does not report version ${version}"

[[ "$(sudo stat -c %u "${APP_DATA_DIR}/data/config/config.yaml")" == "1000" ]] || fail "config.yaml is not owned by uid 1000"

setup="$(curl -sS -X POST "${base}/api/v1/setup" -H 'content-type: application/json' \
  -d "{\"code\":\"${APP_PASSWORD}\",\"mode\":\"required\",\"account\":{\"username\":\"smoke\",\"password\":\"smoke-test-password-1\"},\"admission\":\"ask\"}")"
echo "setup: ${setup}"
grep -q '"state":"done"' <<<"${setup}" || fail "the setup code from APP_PASSWORD was not accepted"

dc restart server
wait_healthy

code="$(curl -s -o /dev/null -w '%{http_code}' "${base}/api/v1/devices")"
echo "unauthenticated /api/v1/devices: ${code}"
[[ "${code}" == "401" || "${code}" == "403" ]] || fail "expected a sign-in to be required, got HTTP ${code}"

dc down -v
sudo rm -rf "${work}"
echo "Smoke test passed for ${image}"
