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
  --log-opt max-size=10m --log-opt max-file=3 --env-file "$envfile" "$image"
for ((i=0; i<30; i++)); do
  if curl -fsS --max-time 3 http://127.0.0.1:3000/api/status | python3 -c 'import json,sys; s=json.load(sys.stdin); sys.exit(not(s["success"] and s["data"]["version"]==sys.argv[1]))' "$revision"; then
    echo "Tokyo is serving $revision"
    exit 0
  fi
  sleep 2
done
echo "Tokyo health check failed for $revision" >&2
exit 1
