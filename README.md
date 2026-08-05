# Medusa stores — Contabo deploy

Deploys **Urban Compact** and **Performance Street** on one Contabo VPS with shared Postgres/Redis, Nginx, and Let's Encrypt.

## Hostnames

| Service | URL |
|---|---|
| UC storefront | https://urban.hassansrour.me |
| UC API / admin | https://api-urban.hassansrour.me |
| PS storefront | https://street.hassansrour.me |
| PS API / admin | https://api-street.hassansrour.me |

## Server layout

```
/opt/medusa-stores/
  deploy/                 # this pack
  urban-compact/          # github.com/hassansrour099-cell/urban-compact-store
  performance-street/     # github.com/hassansrour099-cell/performance-street-store
```

## DNS (GoDaddy)

`hassansrour.me` uses GoDaddy nameservers (`ns37/ns38.domaincontrol.com`). Add **A** records:

| Type | Name | Value | TTL |
|---|---|---|---|
| A | urban | 169.58.124.240 | 600 |
| A | api-urban | 169.58.124.240 | 600 |
| A | street | 169.58.124.240 | 600 |
| A | api-street | 169.58.124.240 | 600 |

## Quick start (on the VPS as root)

```bash
mkdir -p /opt/medusa-stores
# copy this deploy/ folder to /opt/medusa-stores/deploy
bash /opt/medusa-stores/deploy/scripts/bootstrap.sh
bash /opt/medusa-stores/deploy/scripts/setup-ssl.sh
```

After first boot, create publishable API keys in each admin (`/app`), set them in `deploy/.env`, then:

```bash
cd /opt/medusa-stores/deploy
docker compose up -d --build uc-storefront ps-storefront
```
