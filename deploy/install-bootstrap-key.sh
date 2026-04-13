#!/usr/bin/env bash
# One-shot: install the Mac's passphraseless bootstrap pubkey into
# /root/.ssh/authorized_keys on a fresh Hetzner VPS, so SSH key auth works
# before vps-setup.sh runs. Used once to bootstrap the new server after
# the original key's passphrase was lost.
set -euo pipefail
mkdir -p /root/.ssh
chmod 700 /root/.ssh
KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPybvc786w0y/w+6xoA4RtBuV7x3Wrl5NsxwfYeT18Cs mstysin@mac-hetzner'
touch /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
if ! grep -qxF "$KEY" /root/.ssh/authorized_keys; then
    printf '%s\n' "$KEY" >> /root/.ssh/authorized_keys
    echo "Bootstrap key installed."
else
    echo "Bootstrap key already present."
fi
