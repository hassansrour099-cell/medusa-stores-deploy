#!/usr/bin/env bash
# One-liner friendly: curl | bash  OR  paste into Contabo VNC as root
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends ca-certificates curl git
mkdir -p /opt/medusa-stores
cd /opt/medusa-stores
if [[ ! -d deploy/.git ]]; then
  git clone --depth 1 https://github.com/hassansrour099-cell/medusa-stores-deploy.git deploy
fi
bash /opt/medusa-stores/deploy/scripts/bootstrap.sh
