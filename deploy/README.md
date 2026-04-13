# OpenClaw VPS Deployment

Deploy OpenClaw to a VPS (Hetzner, DigitalOcean, etc.) with Docker.

## Quick Start

### 1. Provision a VPS
- Hetzner CX23: 2 vCPU, 4GB RAM (recommended)
- Minimum: 2GB RAM, Debian/Ubuntu
- **REQUIRED: add your SSH public key in the Hetzner Cloud UI at creation time.** Do NOT set a root password and harden later — `vps-setup.sh` will refuse to run if `/root/.ssh/authorized_keys` is empty. (Learned the hard way: a deferred-hardening box was brute-forced within 3 days and Hetzner locked the IP.)

### 2. Run setup on the VPS
```bash
ssh root@YOUR_VPS_IP
curl -fsSL https://raw.githubusercontent.com/mstysin/openclaw/main/deploy/vps-setup.sh | bash
```
The script will immediately disable password SSH, lock the root password, enable fail2ban, and enable UFW before touching anything else.

### 3. Add your API keys
```bash
nano /opt/openclaw/deploy/.env
# Add: ANTHROPIC_API_KEY=sk-ant-... (or OPENAI_API_KEY)
```

### 4. Start OpenClaw
```bash
cd /opt/openclaw/deploy && docker compose up -d
```

### 5. Connect from your Mac
```bash
# One-time setup (creates persistent SSH tunnel + LaunchAgent):
cd deploy && bash setup-ssh-tunnel.sh YOUR_VPS_IP

# Then open: http://127.0.0.1:18789
```

## Files
- `vps-setup.sh` - One-shot VPS provisioning script
- `docker-compose.yml` - Docker Compose config for the gateway
- `.env.template` - Environment variable template
- `setup-ssh-tunnel.sh` - Mac SSH tunnel + LaunchAgent setup

## Updating
```bash
ssh root@YOUR_VPS_IP
cd /opt/openclaw && git pull && cd deploy && docker compose pull && docker compose up -d
```
