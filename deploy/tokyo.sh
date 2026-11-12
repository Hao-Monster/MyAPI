#!/usr/bin/env bash
set -euo pipefail
image=$1
revision=$2
actor=$3
if ! command -v docker >/dev/null; then
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends docker.io
fi
systemctl enable --now docker
export DOCKER_CONFIG
DOCKER_CONFIG=$(mktemp -d /run/new-api-registry.XXXXXX)
trap 'rm -r -- "$DOCKER_CONFIG"' EXIT
printf '%s' "$GH_TOKEN" | docker login ghcr.io -u "$actor" --password-stdin
unset GH_TOKEN
docker pull "$image"
test "$(docker image inspect --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}' "$image")" = "$revision"

install -d -m 0700 /var/lib/new-api-tokyo
envfile=/var/lib/new-api-tokyo/server.env
if [[ ! -e $envfile ]]; then
  (umask 077; printf 'SESSION_SECRET=%s\nCRYPTO_SECRET=%s\n' "$(openssl rand -hex 32)" "$(openssl rand -hex 32)" > "$envfile")
fi
name=new-api-tokyo
if docker container inspect "$name" >/dev/null 2>&1; then
  test "$(docker inspect --format '{{ index .Config.Labels "io.myapi.deployment" }}' "$name")" = tokyo
  docker stop "$name"
  docker rm "$name"
fi
docker run -d --name "$name" --label io.myapi.deployment=tokyo --restart unless-stopped \
  --publish 127.0.0.1:3000:3000 --volume new-api-tokyo-data:/data \
  --log-opt max-size=10m --log-opt max-file=3 --env-file "$envfile" \
  --env NEW_API_SITE_NAME=Ant-Claude "$image"
for ((i=0; i<30; i++)); do
  if curl -fsS --max-time 3 http://127.0.0.1:3000/api/status | python3 -c 'import json,sys; s=json.load(sys.stdin); sys.exit(not(s["success"] and s["data"]["version"]==sys.argv[1]))' "$revision"; then
    echo "Tokyo is serving $revision"
    break
  fi
  if ((i == 29)); then
    echo "Tokyo health check failed for $revision" >&2
    exit 1
  fi
  sleep 2
done

# Claim the fresh database over loopback before making the site reachable.
python3 - <<'PY'
import json
import os
from pathlib import Path
import secrets
from urllib.request import Request, urlopen

url = "http://127.0.0.1:3000/api/setup"
with urlopen(url, timeout=10) as response:
    setup = json.load(response)
if not setup["success"]:
    raise RuntimeError("Could not read setup state")
if not setup["data"]["status"]:
    if setup["data"]["root_init"]:
        raise RuntimeError("Existing administrator found during first-time initialization")
    path = Path("/var/lib/new-api-tokyo/initial-admin-password")
    if not path.exists():
        with os.fdopen(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "w") as out:
            out.write(secrets.token_urlsafe(32) + "\n")
    password = path.read_text().strip()
    payload = {"username": "admin", "password": password, "confirmPassword": password}
    req = Request(url, data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"})
    with urlopen(req, timeout=15) as response:
        if not json.load(response)["success"]:
            raise RuntimeError("First-time administrator initialization failed")
with urlopen(url, timeout=10) as response:
    state = json.load(response)
    if not (state["success"] and state["data"]["status"]):
        raise RuntimeError("Setup incomplete, refusing to publish")
PY

proxy=new-api-tokyo-https
caddy_image='caddy:2-alpine@sha256:78bd35025c7ba85961dd149ae670315129954e77abe2383ac47c89106b35ade9'
# Keep certificates across releases. Host networking reaches the loopback-only app.
cat > /var/lib/new-api-tokyo/Caddyfile <<'CADDY'
holliday.win {
    reverse_proxy 127.0.0.1:3000
}
CADDY
if ! docker container inspect "$proxy" >/dev/null 2>&1; then
  docker run -d --name "$proxy" --restart unless-stopped --network host \
    --label io.myapi.deployment=tokyo --log-opt max-size=5m --log-opt max-file=2 \
    -v /var/lib/new-api-tokyo/Caddyfile:/etc/caddy/Caddyfile:ro \
    -v new-api-tokyo-certs:/data -v new-api-tokyo-caddy-config:/config "$caddy_image"
else
  test "$(docker inspect --format '{{ index .Config.Labels "io.myapi.deployment" }}' "$proxy")" = tokyo
  docker start "$proxy"
  docker exec "$proxy" caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
fi
