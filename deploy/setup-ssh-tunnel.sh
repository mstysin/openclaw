#!/usr/bin/env bash
# Sets up persistent SSH tunnel from your Mac to the OpenClaw VPS gateway.
# Usage: bash setup-ssh-tunnel.sh <VPS_IP> [SSH_USER]

set -euo pipefail

VPS_IP="${1:-}"
SSH_USER="${2:-root}"
SSH_KEY="$HOME/.ssh/id_ed25519"
PLIST_PATH="$HOME/Library/LaunchAgents/ai.openclaw.ssh-tunnel.plist"

if [ -z "$VPS_IP" ]; then
    echo "Usage: $0 <VPS_IP> [SSH_USER]"
    echo "Example: $0 123.45.67.89 root"
    exit 1
fi

echo "=== OpenClaw SSH Tunnel Setup ==="
echo ""

# 1. Generate SSH key if needed
if [ ! -f "$SSH_KEY" ]; then
    echo "[1/4] Generating SSH key..."
    ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "openclaw-tunnel"
else
    echo "[1/4] SSH key exists at $SSH_KEY"
fi

# 2. Copy key to VPS
echo "[2/4] Copying SSH key to VPS (you'll need to enter password once)..."
ssh-copy-id -i "$SSH_KEY" "$SSH_USER@$VPS_IP" 2>/dev/null || true

# 3. Add SSH config entry
echo "[3/4] Adding SSH config..."
SSH_CONFIG="$HOME/.ssh/config"
if ! grep -q "Host openclaw-gateway" "$SSH_CONFIG" 2>/dev/null; then
    cat >> "$SSH_CONFIG" <<EOF

Host openclaw-gateway
    HostName $VPS_IP
    User $SSH_USER
    LocalForward 18789 127.0.0.1:18789
    IdentityFile $SSH_KEY
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
    echo "  Added 'openclaw-gateway' to ~/.ssh/config"
else
    echo "  'openclaw-gateway' already in ~/.ssh/config"
fi

# 4. Create LaunchAgent for auto-start
echo "[4/4] Creating LaunchAgent for persistent tunnel..."
cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>ai.openclaw.ssh-tunnel</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/ssh</string>
        <string>-N</string>
        <string>openclaw-gateway</string>
    </array>
    <key>KeepAlive</key>
    <true/>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/tmp/openclaw-tunnel.err</string>
    <key>StandardOutPath</key>
    <string>/tmp/openclaw-tunnel.out</string>
</dict>
</plist>
PLIST

launchctl bootstrap gui/$UID "$PLIST_PATH" 2>/dev/null || true
launchctl kickstart -k gui/$UID/ai.openclaw.ssh-tunnel 2>/dev/null || true

echo ""
echo "=== Done! ==="
echo ""
echo "The SSH tunnel is now running and will auto-start on login."
echo "OpenClaw dashboard: http://127.0.0.1:18789"
echo ""
echo "Useful commands:"
echo "  Check tunnel:   lsof -i :18789"
echo "  Restart tunnel: launchctl kickstart -k gui/\$UID/ai.openclaw.ssh-tunnel"
echo "  Stop tunnel:    launchctl bootout gui/\$UID/ai.openclaw.ssh-tunnel"
echo "  Manual connect: ssh -N openclaw-gateway"
