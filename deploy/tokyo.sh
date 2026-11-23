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
# Cloudflare edge ranges (https://www.cloudflare.com/ips/), used only by trusted_proxies
# to unwrap real client IPs; origin access on holliday.win is gated by mTLS (aop_ca_der),
# so new Cloudflare edge ranges never block traffic. api.holliday.win is DNS-only.
cloudflare_ranges='173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 141.101.64.0/18 108.162.192.0/18 190.93.240.0/20 188.114.96.0/20 197.234.240.0/22 198.41.128.0/17 162.158.0.0/15 104.16.0.0/13 104.24.0.0/14 172.64.0.0/13 131.0.72.0/22 2400:cb00::/32 2606:4700::/32 2803:f800::/32 2405:b500::/32 2405:8100::/32 2a06:98c0::/29 2c0f:f248::/32'
# Base64 DER of deploy/cloudflare-aop/ca.crt (verified by .github/workflows/cloudflare-origin-guard.yml).
aop_ca_der='MIIFVjCCAz6gAwIBAgIUarr3/ldqxDSXBW2DzooC+rvf1V0wDQYJKoZIhvcNAQELBQAwMTEvMC0GA1UEAwwmQW50LUNsYXVkZSBob2xsaWRheS53aW4gT3JpZ2luIFB1bGwgQ0EwHhcNMjYxMTIzMTIyNDAzWhcNMzYxMTIwMTIyNDAzWjAxMS8wLQYDVQQDDCZBbnQtQ2xhdWRlIGhvbGxpZGF5LndpbiBPcmlnaW4gUHVsbCBDQTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAMChK57ChGT/oab0wi5y8HbRDlfUUf23cWbWPRnftp3VyBRZoQdo5JjRqeOtP9v+A+O8VGDYVwBHaQoTSm86t1ZU8SYmE7ebjhdx8b7VEwHriDkm2AUgv6ddoLn0egukSnPq27LrJC2SbQhD5mKMb5WOGLucW3SzLXiY9uAGPSVY8oAhILSmglZ++8gyYaMR9aG9imFufLCpsBJq6xKd99WiPYvuRGICoib8iZmEntxqOCGamkk4nZJQ8psYxPEPLcgPUrsENpILdncjET7r/0SZ4BAnv5VnJ9kqNxZx97OZ+aoeH2u+d5perbaW/EVQgDYKedIyA+az0g7oB6CaD1EC735hvYYfwMQD0ODNpcrQzCz/UtoYpgM2VmZg1kZApfl7X9xXFCPGvHmR1FcDw6Q53yEFMuj3tBvq/OmjLAGn+X8i+xX9HF2naQzFB34eZAxl7ttUQIOYny43PLWRrOQOkuvaOkWBCud49aPNFNerTU9iKo6bLrVvGEAoAYXKIcg7YzUGo+TYWZxpga33XDZ4FrkS8H2tLs7RsWyuli3w1XK4dOyZ15Na/Kfo2ySRBmhcqyUflJTWtKaGxa9A1BQjdO7JjDdQqs7Cp7hpbZcO1ngq0D1OmBs+K1LXAeAlJn+HhGl3kN/Wxs4ILxLKJHRXCQJWuxwUQ6V0IH46Qqd5AgMBAAGjZjBkMB0GA1UdDgQWBBQ8V0KDqyF1W+Z/Gjtzc3qCpO5cTjAfBgNVHSMEGDAWgBQ8V0KDqyF1W+Z/Gjtzc3qCpO5cTjASBgNVHRMBAf8ECDAGAQH/AgEAMA4GA1UdDwEB/wQEAwIBBjANBgkqhkiG9w0BAQsFAAOCAgEAK2IX/+IxEtrrKA7B+887wfxSlAFUP/RHq3Axi8NKZ2bRv76qsbHCzJgkSn+1tSVWduvpQt7CFJ5hPoa/5undpQ75LfQDiJvBjU9uw9ftGOiPXjcMezGadRlbABK4Jygwy4VoTiF9MFaAoo5jChZHK87dtI6yjAfXdkvGQN8o7O9xgyxJ1bDsAV6zCr9vVtLr2falC0IeIlIYQfNbTe5aeuWHFGQdI9Ohn9X4E/Iwz4LhXFF9bMHju+tqRd4qtPLYyMIl5AHNrMTLlByN2eCaDtqxXoVBMiQb8AXo+L76SytMeYfw9xffFzrphd24lzFhQy8KKSYkMfmWyqJ6JN+BpyK0XkP5zCp4vvXJBTWb6G45q0bwdZ//XcgBBiHZVx6L5iMwlIWrDl7u0xtHfeXermMtsAXwFYhw+yfFHJHwcYMPlvpEt05MIXDmNHBiqG4BweJap66Pdx5AU1eNvRcMFwo9B+kDaeESek6w0BsFLdwsZL9DBITfpPA1OEv/lGhwEB8P+yUERB6fbrocv9EQ9yYzd2ox+tPzVpRtdS6CdTiakRyZjJV+PRPy/bFBI3irLh1sC2dE80oacy0Fc+QfkJGSyzcFUSZ3PHBWay1RZiShQkZdPvK/U8WcbHrKDQZhSk6YJqKurXDQSHluVOh27oDokQO4aiD3dPfdLg4/IAI='
# Keep certificates across releases. Host networking reaches the loopback-only app.
# Write and validate a candidate first so a bad config never replaces the live file,
# which the running proxy reloads and a restarted container would boot from.
# The heredoc is unquoted only to expand $cloudflare_ranges and $aop_ca_der; do not add other $ or backticks.
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
            mode require_and_verify
            trust_pool inline {
                trust_der $aop_ca_der
            }
        }
    }
    @defaultIcons path /logo.png /favicon.ico
    redir @defaultIcons /ant-claude-swords-icon.png 302
    reverse_proxy 127.0.0.1:3000 {
        header_up X-Forwarded-For {client_ip}
        header_up X-Real-IP {client_ip}
        flush_interval -1
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
