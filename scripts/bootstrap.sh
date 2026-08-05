#!/usr/bin/env bash
set -euo pipefail

# First-boot Contabo VPS setup for Urban Compact + Performance Street
# Run as root: bash /opt/medusa-stores/deploy/scripts/bootstrap.sh

DEPLOY_ROOT="${DEPLOY_ROOT:-/opt/medusa-stores}"
DEPLOY_DIR="${DEPLOY_ROOT}/deploy"
UC_DIR="${DEPLOY_ROOT}/urban-compact"
PS_DIR="${DEPLOY_ROOT}/performance-street"
UC_REPO="${UC_REPO:-https://github.com/hassansrour099-cell/urban-compact-store.git}"
PS_REPO="${PS_REPO:-https://github.com/hassansrour099-cell/performance-street-store.git}"
DEPLOY_REPO="${DEPLOY_REPO:-https://github.com/hassansrour099-cell/medusa-stores-deploy.git}"

echo "==> Bootstrap medusa-stores on $(hostname) at ${DEPLOY_ROOT}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends \
  ca-certificates curl git ufw fail2ban \
  apt-transport-https gnupg lsb-release

# Swap (2G)
if ! swapon --show | grep -q '/swapfile'; then
  echo "==> Creating 2G swap"
  fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# Docker Engine
if ! command -v docker >/dev/null 2>&1; then
  echo "==> Installing Docker"
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker
fi

# Firewall
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable || true

mkdir -p "${DEPLOY_ROOT}"
cd "${DEPLOY_ROOT}"

if [[ ! -d "${UC_DIR}/.git" ]]; then
  echo "==> Cloning Urban Compact"
  git clone --depth 1 "${UC_REPO}" "${UC_DIR}"
else
  git -C "${UC_DIR}" pull --ff-only || true
fi

if [[ ! -d "${PS_DIR}/.git" ]]; then
  echo "==> Cloning Performance Street"
  git clone --depth 1 "${PS_REPO}" "${PS_DIR}"
else
  git -C "${PS_DIR}" pull --ff-only || true
fi

if [[ ! -f "${DEPLOY_DIR}/docker-compose.yml" ]]; then
  echo "==> Cloning deploy pack"
  git clone --depth 1 "${DEPLOY_REPO}" "${DEPLOY_DIR}"
else
  git -C "${DEPLOY_DIR}" pull --ff-only || true
fi

if [[ ! -f "${DEPLOY_DIR}/docker-compose.yml" ]]; then
  echo "Missing ${DEPLOY_DIR}/docker-compose.yml — copy deploy pack first" >&2
  exit 1
fi

# Copy dockerignore into build contexts
cp -f "${DEPLOY_DIR}/docker/.dockerignore" "${UC_DIR}/.dockerignore"
cp -f "${DEPLOY_DIR}/docker/.dockerignore" "${PS_DIR}/.dockerignore"

cd "${DEPLOY_DIR}"

if [[ ! -f .env ]]; then
  echo "==> Generating .env"
  cp .env.example .env
  PW="$(openssl rand -base64 24 | tr -d '/+=' | head -c 32)"
  sed -i "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${PW}|" .env
  sed -i "s|UC_JWT_SECRET=.*|UC_JWT_SECRET=$(openssl rand -hex 32)|" .env
  sed -i "s|UC_COOKIE_SECRET=.*|UC_COOKIE_SECRET=$(openssl rand -hex 32)|" .env
  sed -i "s|PS_JWT_SECRET=.*|PS_JWT_SECRET=$(openssl rand -hex 32)|" .env
  sed -i "s|PS_COOKIE_SECRET=.*|PS_COOKIE_SECRET=$(openssl rand -hex 32)|" .env
fi

mkdir -p certbot/www certbot/conf

echo "==> Building and starting stack (HTTP bootstrap)"
docker compose up -d --build postgres redis
sleep 5
docker compose up -d --build uc-backend ps-backend
echo "==> Waiting for backends..."
sleep 40
docker compose exec -T uc-backend npx medusa db:migrate || true
docker compose exec -T ps-backend npx medusa db:migrate || true
docker compose exec -T uc-backend npx medusa exec ./src/scripts/seed-urban-compact-v1.ts || true
docker compose exec -T ps-backend npx medusa exec ./src/scripts/seed-performance-street-v1.ts || true

docker compose up -d --build uc-storefront ps-storefront nginx

echo "==> Bootstrap complete (HTTP). Next:"
echo "  1) Point DNS A records to this server"
echo "  2) Create publishable API keys in each admin, set UC_PUBLISHABLE_KEY / PS_PUBLISHABLE_KEY"
echo "  3) Rebuild storefronts: docker compose up -d --build uc-storefront ps-storefront"
echo "  4) Run: bash scripts/setup-ssl.sh"
docker compose ps
