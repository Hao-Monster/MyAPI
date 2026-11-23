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
  --env NEW_API_SITE_NAME=Ant-Claude --env NEW_API_SITE_LOGO=/ant-claude-swords-icon.png "$image"
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

if command -v ufw >/dev/null && LC_ALL=C ufw status | grep -Fxq 'Status: active'; then
  ufw allow 80/tcp
  ufw allow 443/tcp
fi

proxy=new-api-tokyo-https
caddy_image='caddy:2-alpine@sha256:78bd35025c7ba85961dd149ae670315129954e77abe2383ac47c89106b35ade9'
# Cloudflare edge ranges (https://www.cloudflare.com/ips/). holliday.win only accepts
# connections from these addresses; api.holliday.win is DNS-only and accepts clients directly.
cloudflare_ranges='173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 141.101.64.0/18 108.162.192.0/18 190.93.240.0/20 188.114.96.0/20 197.234.240.0/22 198.41.128.0/17 162.158.0.0/15 104.16.0.0/13 104.24.0.0/14 172.64.0.0/13 131.0.72.0/22 2400:cb00::/32 2606:4700::/32 2803:f800::/32 2405:b500::/32 2405:8100::/32 2a06:98c0::/29 2c0f:f248::/32'
# Keep certificates across releases. Host networking reaches the loopback-only app.
# Write and validate a candidate first so a bad config never replaces the live file,
# which the running proxy reloads and a restarted container would boot from.
# The heredoc is unquoted only to expand $cloudflare_ranges; do not add other $ or backticks.
caddyfile=/var/lib/new-api-tokyo/Caddyfile
cat > "$caddyfile.new" <<CADDY
{
    servers {
        protocols h1 h2
        strict_sni_host on
        trusted_proxies static $cloudflare_ranges
        client_ip_headers CF-Connecting-IP X-Forwarded-For
    }
}
holliday.win {
    tls {
        client_auth {
            mode request
        }
    }
    @notCloudflare not remote_ip $cloudflare_ranges
    handle @notCloudflare {
        abort
    }
    handle {
        header X-Origin-Pull-Fingerprint {http.request.tls.client.fingerprint}
        @defaultIcons path /logo.png /favicon.ico
        redir @defaultIcons /ant-claude-swords-icon.png 302
        reverse_proxy 127.0.0.1:3000 {
            header_up X-Forwarded-For {client_ip}
            header_up X-Real-IP {client_ip}
            flush_interval -1
        }
    }
}
api.holliday.win {
    tls {
        issuer acme {
            disable_http_challenge
        }
    }
    @relay {
        path /v1 /v1/* /v1beta /v1beta/* /dashboard/billing/* /mj/* /*/mj/*/* /*/mj/*/*/* /suno/* /kling/* /jimeng /jimeng/* /api/status /api/uptime/status /api/usage/token /api/usage/token/ /api/log/token /api/pricing /api/ratio_config
        not path /api/mj /api/mj/*
    }
    handle @relay {
        reverse_proxy 127.0.0.1:3000 {
            header_up X-Forwarded-For {remote_host}
            header_up X-Real-IP {remote_host}
            header_up -CF-Connecting-IP
            flush_interval -1
        }
    }
    @browserRoot {
        method GET HEAD
        path /
    }
    handle @browserRoot {
        redir https://holliday.win/ 302
    }
    handle {
        respond 404
    }
}
CADDY
docker run --rm --network none -v "$caddyfile.new:/etc/caddy/Caddyfile:ro" "$caddy_image" \
  caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
# Overwrite in place: the single-file bind mount follows the inode, so mv would hide the update.
cat "$caddyfile.new" > "$caddyfile"
rm -f -- "$caddyfile.new"
if ! docker container inspect "$proxy" >/dev/null 2>&1; then
  docker run -d --name "$proxy" --restart unless-stopped --network host \
    --label io.myapi.deployment=tokyo --log-opt max-size=5m --log-opt max-file=2 \
    -v "$caddyfile:/etc/caddy/Caddyfile:ro" \
    -v new-api-tokyo-certs:/data -v new-api-tokyo-caddy-config:/config "$caddy_image"
else
  test "$(docker inspect --format '{{ index .Config.Labels "io.myapi.deployment" }}' "$proxy")" = tokyo
  docker start "$proxy"
  docker exec "$proxy" caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
fi
