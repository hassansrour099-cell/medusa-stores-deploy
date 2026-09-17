# Medusa stores — Contabo deploy

Shared production infrastructure for **Urban Compact**, **Performance Street**, and **NEXUS** on one Contabo VPS (Postgres, Redis, Nginx, Let's Encrypt).

Application source lives in separate GitHub repositories. This pack only orchestrates deployment.

## Repositories

| Role | Repository |
|---|---|
| Urban Compact app | https://github.com/hassansrour099-cell/urban-compact-store |
| Performance Street app | https://github.com/hassansrour099-cell/performance-street-store |
| NEXUS app | https://github.com/hassansrour099-cell/nexus-store |
| Shared deploy (this repo) | https://github.com/hassansrour099-cell/medusa-stores-deploy |

## Hostnames

| Service | URL |
|---|---|
| UC storefront | https://urban.hassansrour.me |
| UC API / admin | https://api-urban.hassansrour.me |
| PS storefront | https://street.hassansrour.me |
| PS API / admin | https://api-street.hassansrour.me |
| NEXUS storefront | https://nexus.hassansrour.me |
| NEXUS API / admin | https://api-nexus.hassansrour.me |

## Server layout

```
/opt/medusa-stores/
  deploy/                 # this pack (medusa-stores-deploy)
  urban-compact/          # github.com/hassansrour099-cell/urban-compact-store
  performance-street/     # github.com/hassansrour099-cell/performance-street-store
  nexus/                  # github.com/hassansrour099-cell/nexus-store
```

Clone/pull from GitHub on the VPS so the deployed commit is identifiable via `git -C /opt/medusa-stores/nexus rev-parse HEAD`.

## DNS (GoDaddy)

Keep existing GoDaddy nameservers. A records for all three stores:

| Type | Name | Value | TTL |
|---|---|---|---|
| A | urban | 169.58.124.240 | 600 |
| A | api-urban | 169.58.124.240 | 600 |
| A | street | 169.58.124.240 | 600 |
| A | api-street | 169.58.124.240 | 600 |
| A | nexus | 169.58.124.240 | 600 |
| A | api-nexus | 169.58.124.240 | 600 |

## Isolation

| Store | Compose services | Postgres DB | Redis index | Profile |
|---|---|---|---|---|
| Urban Compact | `uc-backend`, `uc-storefront` | `urban_compact` | `/0` | default |
| Performance Street | `ps-backend`, `ps-storefront` | `performance_street` | `/1` | default |
| NEXUS | `nx-backend`, `nx-storefront` | `nexus` | `/2` | `nexus` (opt-in) |

`docker compose up -d` starts UC/PS (and shared infra) only. NEXUS requires `--profile nexus`.

## Quick start (UC + PS)

```bash
mkdir -p /opt/medusa-stores
# clone this pack to /opt/medusa-stores/deploy from medusa-stores-deploy
bash /opt/medusa-stores/deploy/scripts/bootstrap.sh
bash /opt/medusa-stores/deploy/scripts/setup-ssl.sh
```

After first boot, create publishable API keys in each admin (`/app`), set them in `deploy/.env`, then:

```bash
cd /opt/medusa-stores/deploy
docker compose up -d --build uc-storefront ps-storefront
```

## Adding NEXUS (GitHub → VPS)

On an existing Contabo stack (UC/PS already live):

```bash
# 1. Pull latest deploy pack
git -C /opt/medusa-stores/deploy pull --ff-only

# 2. Clone or update NEXUS application from GitHub
if [[ ! -d /opt/medusa-stores/nexus/.git ]]; then
  git clone https://github.com/hassansrour099-cell/nexus-store.git /opt/medusa-stores/nexus
else
  git -C /opt/medusa-stores/nexus pull --ff-only
fi
git -C /opt/medusa-stores/nexus rev-parse --short HEAD   # record deployed commit

cp -f /opt/medusa-stores/deploy/docker/.dockerignore /opt/medusa-stores/nexus/.dockerignore

# 3. Add NX_* placeholders from .env.example into deploy/.env, then set real secrets
#    (JWT/cookie secrets unique to NEXUS — do not reuse UC/PS values)

# 4. Create isolated database (safe; does not touch UC/PS)
cd /opt/medusa-stores/deploy
bash scripts/ensure-nexus-db.sh

# 5. Build and start NEXUS only
docker compose --profile nexus up -d --build nx-backend nx-storefront

# 6. Create admin user + seed + publishable key in NEXUS admin, set NX_PUBLISHABLE_KEY
docker compose --profile nexus up -d --build nx-storefront

# 7. SSL for NEXUS hosts only (UC/PS certs unchanged)
bash scripts/setup-nexus-ssl.sh
```

Never copy a local working tree to production as the primary deploy path — use the GitHub `nexus-store` commit.

## Environment

Copy `.env.example` → `.env` on the VPS. The real `.env` is gitignored. Placeholders only in git.
