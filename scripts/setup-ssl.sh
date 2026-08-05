#!/usr/bin/env bash
set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${DEPLOY_DIR}"

# shellcheck disable=SC1091
set -a
source .env
set +a

EMAIL="${CERTBOT_EMAIL:-hassansrour099@gmail.com}"
DOMAINS=(
  urban.hassansrour.me
  api-urban.hassansrour.me
  street.hassansrour.me
  api-street.hassansrour.me
)

echo "==> Checking DNS points at this host"
MY_IP="$(curl -4 -fsS https://ifconfig.me || curl -4 -fsS https://api.ipify.org)"
for d in "${DOMAINS[@]}"; do
  RESOLVED="$(getent ahostsv4 "$d" | awk '{print $1; exit}' || true)"
  echo "  $d -> ${RESOLVED:-unresolved} (server ${MY_IP})"
  if [[ -z "${RESOLVED}" || "${RESOLVED}" != "${MY_IP}" ]]; then
    echo "DNS for $d is not ready. Fix GoDaddy A records, then re-run." >&2
    exit 1
  fi
done

echo "==> Issuing Let's Encrypt certificates"
for d in "${DOMAINS[@]}"; do
  docker compose run --rm --entrypoint certbot certbot certonly \
    --webroot -w /var/www/certbot \
    --email "${EMAIL}" \
    --agree-tos \
    --no-eff-email \
    -d "${d}"
done

# Ensure nginx TLS options exist (certbot image may not ship companion files)
if [[ ! -f certbot/conf/options-ssl-nginx.conf ]]; then
  curl -fsSL https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf \
    -o certbot/conf/options-ssl-nginx.conf
fi
if [[ ! -f certbot/conf/ssl-dhparams.pem ]]; then
  curl -fsSL https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem \
    -o certbot/conf/ssl-dhparams.pem
fi

echo "==> Enabling HTTPS server blocks"
cp -f nginx/conf.d/urban.conf.ssl nginx/conf.d/urban.conf
cp -f nginx/conf.d/street.conf.ssl nginx/conf.d/street.conf
# Avoid duplicate listen 80 server_name with bootstrap
mv -f nginx/conf.d/http-bootstrap.conf nginx/conf.d/http-bootstrap.conf.off

docker compose exec nginx nginx -t
docker compose exec nginx nginx -s reload

echo "==> SSL ready"
echo "  https://urban.hassansrour.me"
echo "  https://street.hassansrour.me"
echo "  https://api-urban.hassansrour.me/app"
echo "  https://api-street.hassansrour.me/app"
