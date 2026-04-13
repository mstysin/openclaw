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
- `vps-setup.sh` - One-shot VPS provisioning script (hardened SSH + Docker + repo clone + .env scaffold)
- `install-bootstrap-key.sh` - One-shot helper to install a passphraseless SSH key on a fresh VPS when you lose the primary key's passphrase. Not needed for normal provisioning.
- `docker-compose.yml` - Docker Compose config for the gateway
- `.env.template` - Environment variable template (pins `OPENCLAW_IMAGE`)
- `setup-ssh-tunnel.sh` - Mac SSH tunnel + LaunchAgent setup

## Image pinning (important)

`OPENCLAW_IMAGE` in `.env.template` is pinned to a specific tag rather than `:latest`. OpenClaw ships frequently and we hit a regression where the native `deepseek` provider disappeared from the runtime catalog starting in `2026.4.10`. The bot would start successfully, accept Telegram messages, then fail inference with `FailoverError: Unknown model: deepseek/deepseek-chat`. `2026.4.8` is the last verified-working tag for this deployment.

Before bumping the pin, verify on the new version:
```bash
ssh root@YOUR_VPS_IP 'docker exec deploy-openclaw-gateway-1 openclaw infer model providers | grep "\"provider\":\"deepseek\""'
```
If the native `deepseek` provider is listed, it's safe to bump. If not, stay pinned.

## Updating
```bash
ssh root@YOUR_VPS_IP
cd /opt/openclaw && git pull && cd deploy && docker compose pull && docker compose up -d
```

## Lessons learned (keep these)

1. **Never run with a weak/temporary root password on a public IP, even briefly.** The previous CX23 was brute-forced within 3 days (root password `abc12345` + PasswordAuth yes + deferred hardening) and Hetzner locked the IP. Full rebuild + secrets rotation was required.
2. **Always inject SSH keys at provision time** (Hetzner Cloud UI, cloud-init, etc.). `vps-setup.sh` now refuses to run if `/root/.ssh/authorized_keys` is empty.
3. **Pin `OPENCLAW_IMAGE`.** `:latest` is a moving target and upstream can ship regressions at any time.
4. **Assume full compromise after an abuse lock.** Rotate every credential that was on the box: Telegram bot token (BotFather `/revoke`), DeepSeek/provider API keys, generated gateway token, keyring password. The public SSH key on the server is harmless; the private key on your Mac is unaffected.
5. **Keep a passphrase-cached SSH key** (`ssh-add --apple-use-keychain`) or a dedicated passphraseless server key, so bootstrap flows don't get stuck when the primary key can't be unlocked non-interactively.
