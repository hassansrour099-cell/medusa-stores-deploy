#!/usr/bin/env bash
# Issue Let's Encrypt certs for NEXUS only (UC/PS certs remain untouched).
# Prerequisites:
#   1. DNS A records for nexus + api-nexus → this VPS
#   2. nx-backend / nx-storefront running (Compose profile nexus)
#   3. ACME HTTP challenge reachable on port 80 for those hosts
set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${DEPLOY_DIR}"

# shellcheck disable=SC1091
set -a
source .env
set +a

EMAIL="${CERTBOT_EMAIL:-hassansrour099@gmail.com}"
DOMAINS=(
  nexus.hassansrour.me
  api-nexus.hassansrour.me
)

echo "==> Checking DNS points at this host"
MY_IP="$(curl -4 -fsS https://ifconfig.me || curl -4 -fsS https://api.ipify.org)"
for d in "${DOMAINS[@]}"; do
  RESOLVED="$(getent ahostsv4 "$d" | awk '{print $1; exit}' || true)"
  echo "  $d -> ${RESOLVED:-unresolved} (server ${MY_IP})"
  if [[ -z "${RESOLVED}" || "${RESOLVED}" != "${MY_IP}" ]]; then
    echo "DNS for $d is not ready. Fix A records, then re-run." >&2
    exit 1
  fi
done

# When UC/PS HTTPS is already live, http-bootstrap.conf is usually disabled.
# Add a short-lived ACME-only server block for NEXUS hosts.
if [[ -f nginx/conf.d/http-bootstrap.conf.off ]] && [[ ! -f nginx/conf.d/nexus.conf ]] && [[ ! -f nginx/conf.d/nexus-acme.conf ]]; then
  cat > nginx/conf.d/nexus-acme.conf <<'EOF'
server {
  listen 80;
  server_name nexus.hassansrour.me api-nexus.hassansrour.me;
  location /.well-known/acme-challenge/ { root /var/www/certbot; }
  location / { return 301 https://$host$request_uri; }
}
EOF
  docker compose exec nginx nginx -t
  docker compose exec nginx nginx -s reload
fi

echo "==> Issuing Let's Encrypt certificates for NEXUS"
for d in "${DOMAINS[@]}"; do
  docker compose run --rm --entrypoint certbot certbot certonly \
    --webroot -w /var/www/certbot \
    --email "${EMAIL}" \
    --agree-tos \
    --no-eff-email \
    -d "${d}"
done

echo "==> Enabling NEXUS HTTPS server blocks"
cp -f nginx/conf.d/nexus.conf.ssl nginx/conf.d/nexus.conf
rm -f nginx/conf.d/nexus-acme.conf

docker compose exec nginx nginx -t
docker compose exec nginx nginx -s reload

echo "==> NEXUS SSL ready"
echo "  https://nexus.hassansrour.me"
echo "  https://api-nexus.hassansrour.me/app"
