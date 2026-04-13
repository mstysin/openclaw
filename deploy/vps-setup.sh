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

# Precondition: refuse to run unless an SSH key is already installed for root.
# This prevents the "temporary root password + deferred hardening" mistake that
# got the previous server brute-forced and locked by Hetzner (2026-04-13).
if [ ! -s /root/.ssh/authorized_keys ]; then
    echo "ERROR: /root/.ssh/authorized_keys is missing or empty." >&2
    echo "Provision the VPS with an SSH key in the Hetzner Cloud UI before running this script." >&2
    echo "Do NOT set a root password and run this later — that is how the last box got owned." >&2
    exit 1
fi

# 1. System updates + Docker
echo "[1/6] Installing Docker..."
apt-get update -qq
apt-get install -y -qq git curl ca-certificates ufw fail2ban > /dev/null

if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
fi

docker --version
docker compose version

# 2. Harden SSH: key-only, no password, no root password login.
# This runs BEFORE anything else that could expose the box, and is not deferred.
echo "[2/6] Hardening SSH (key-only, no passwords)..."
SSHD_DROPIN=/etc/ssh/sshd_config.d/00-openclaw-hardening.conf
cat > "$SSHD_DROPIN" <<'EOF'
# Managed by deploy/vps-setup.sh - do not edit by hand
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PermitRootLogin prohibit-password
PubkeyAuthentication yes
PermitEmptyPasswords no
EOF
chmod 644 "$SSHD_DROPIN"
# Lock the root password so password login is impossible even if sshd config drifts.
passwd -l root >/dev/null
systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || true
systemctl enable --now fail2ban >/dev/null 2>&1 || true
echo "SSH: key-only, root password locked, fail2ban enabled"

# 3. Firewall - allow SSH only, Docker handles its own port binding to 127.0.0.1
echo "[3/6] Configuring firewall..."
ufw allow OpenSSH
ufw --force enable
echo "Firewall: SSH allowed, all other inbound blocked"

# 4. Clone repo or use existing
echo "[4/6] Setting up OpenClaw..."
if [ -d "$DEPLOY_DIR" ]; then
    echo "Updating existing installation..."
    cd "$DEPLOY_DIR/deploy"
    git -C "$DEPLOY_DIR" pull --ff-only
else
    git clone https://github.com/mstysin/openclaw.git "$DEPLOY_DIR"
    cd "$DEPLOY_DIR/deploy"
fi

# 5. Create config directories
echo "[5/6] Creating config directories..."
mkdir -p "$CONFIG_DIR/workspace"
chown -R 1000:1000 "$CONFIG_DIR"

# 6. Generate .env if not present
if [ ! -f "$DEPLOY_DIR/deploy/.env" ]; then
    echo "[6/6] Generating .env from template..."
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
    echo "[6/6] .env already exists, skipping..."
    echo ""
    echo "Starting OpenClaw..."
    docker compose pull
    docker compose up -d
    echo ""
    echo "OpenClaw is running! Check status:"
    echo "  docker compose logs -f"
fi
