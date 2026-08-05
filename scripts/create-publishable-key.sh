#!/usr/bin/env bash
set -euo pipefail

# Create a publishable API key via Medusa admin REST after first boot.
# Usage:
#   ADMIN_EMAIL=... ADMIN_PASSWORD=... BACKEND=http://uc-backend:9000 \
#     bash scripts/create-publishable-key.sh
#
# Or run inside the backend container once an admin user exists.

BACKEND="${BACKEND:?set BACKEND e.g. http://127.0.0.1:9000}"
ADMIN_EMAIL="${ADMIN_EMAIL:?}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:?}"
TITLE="${TITLE:-Storefront}"

TOKEN="$(curl -fsS -X POST "${BACKEND}/auth/user/emailpass" \
  -H 'content-type: application/json' \
  -d "{\"email\":\"${ADMIN_EMAIL}\",\"password\":\"${ADMIN_PASSWORD}\"}" \
  | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')"

if [[ -z "${TOKEN}" ]]; then
  echo "Failed to auth admin" >&2
  exit 1
fi

curl -fsS -X POST "${BACKEND}/admin/api-keys" \
  -H "authorization: Bearer ${TOKEN}" \
  -H 'content-type: application/json' \
  -d "{\"title\":\"${TITLE}\",\"type\":\"publishable\"}"
echo
