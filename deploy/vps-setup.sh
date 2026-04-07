#!/usr/bin/env bash
# OpenClaw VPS Setup Script
# Run this on a fresh Debian/Ubuntu VPS as root:
#   curl -fsSL https://raw.githubusercontent.com/mstysin/openclaw/main/deploy/vps-setup.sh | bash
#
# Or clone and run:
#   git clone https://github.com/mstysin/openclaw.git && cd openclaw/deploy && bash vps-setup.sh

set -euo pipefail

DEPLOY_DIR="/opt/openclaw"
CONFIG_DIR="/root/.openclaw"

echo "=== OpenClaw VPS Setup ==="
echo ""

# 1. System updates + Docker
echo "[1/5] Installing Docker..."
apt-get update -qq
apt-get install -y -qq git curl ca-certificates ufw > /dev/null

if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
fi

docker --version
docker compose version

# 2. Firewall - allow SSH only, Docker handles its own port binding to 127.0.0.1
echo "[2/5] Configuring firewall..."
ufw allow OpenSSH
ufw --force enable
echo "Firewall: SSH allowed, all other inbound blocked"

# 3. Clone repo or use existing
echo "[3/5] Setting up OpenClaw..."
if [ -d "$DEPLOY_DIR" ]; then
    echo "Updating existing installation..."
    cd "$DEPLOY_DIR/deploy"
    git -C "$DEPLOY_DIR" pull --ff-only
else
    git clone https://github.com/mstysin/openclaw.git "$DEPLOY_DIR"
    cd "$DEPLOY_DIR/deploy"
fi

# 4. Create config directories
echo "[4/5] Creating config directories..."
mkdir -p "$CONFIG_DIR/workspace"
chown -R 1000:1000 "$CONFIG_DIR"

# 5. Generate .env if not present
if [ ! -f "$DEPLOY_DIR/deploy/.env" ]; then
    echo "[5/5] Generating .env from template..."
    GATEWAY_TOKEN=$(openssl rand -hex 32)
    KEYRING_PASSWORD=$(openssl rand -hex 32)

    cp .env.template .env
    sed -i "s/OPENCLAW_GATEWAY_TOKEN=CHANGE_ME/OPENCLAW_GATEWAY_TOKEN=$GATEWAY_TOKEN/" .env
    sed -i "s/GOG_KEYRING_PASSWORD=CHANGE_ME/GOG_KEYRING_PASSWORD=$KEYRING_PASSWORD/" .env

    echo ""
    echo "========================================="
    echo "  SAVE THIS - YOUR GATEWAY TOKEN:"
    echo "  $GATEWAY_TOKEN"
    echo "========================================="
    echo ""
    echo "Now edit $DEPLOY_DIR/deploy/.env to add your API keys:"
    echo "  nano $DEPLOY_DIR/deploy/.env"
    echo ""
    echo "Then start OpenClaw:"
    echo "  cd $DEPLOY_DIR/deploy && docker compose up -d"
    echo ""
    echo "Connect from your Mac:"
    echo "  ssh -N -L 18789:127.0.0.1:18789 root@YOUR_VPS_IP"
    echo "  Then open http://127.0.0.1:18789"
else
    echo "[5/5] .env already exists, skipping..."
    echo ""
    echo "Starting OpenClaw..."
    docker compose pull
    docker compose up -d
    echo ""
    echo "OpenClaw is running! Check status:"
    echo "  docker compose logs -f"
fi
