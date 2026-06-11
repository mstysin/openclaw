# OpenClaw VPS Setup - Progress

## Status: ✅ COMPLETE — Telegram + DeepSeek live on 2026.6.1 (upgraded 2026-06-07)

## History

- **2026-04-10** — Initial deploy on CX23 (Helsinki). Working Telegram + DeepSeek end-to-end.
- **2026-04-13** — Hetzner abuse lockout. Root cause: SSH hardening (step 2) had been deferred, server was running with `PasswordAuthentication yes` + `PermitRootLogin yes` + temporary root password `abc12345`. Brute-forced within ~3 days, used to attack other servers, IP `46.62.200.167` locked by Hetzner (abuse ticket #126085999).
- **2026-04-13** — Server destroyed. All exposed secrets rotated (Telegram token, DeepSeek key). New CX22 provisioned with SSH key at creation time. `vps-setup.sh` hardened to refuse running without a pre-installed SSH key, to disable password auth and lock the root password on the first run, and to install fail2ban.
- **2026-04-13** — Hit an OpenClaw regression: the `:latest` image (2026.4.10+) dropped the native `deepseek` provider from the runtime catalog, causing `FailoverError: Unknown model: deepseek/deepseek-chat` on every Telegram message. Pinned image to `2026.4.8` which is the last verified working version.
- **2026-06-07** — Outage after an in-app self-update. Root cause: the agent ran the `update.run` gateway tool, which mutated `/app` inside the container and pruned dependencies that the `2026.4.8` image did not bundle (`kysely`, `typebox`/`@sinclair/typebox`, `grammy` + grammyjs stack), crashing the gateway in a `Cannot find module` restart loop.
- **2026-06-07** — Recovery + upgrade. Confirmed `2026.6.1` both re-ships the native `deepseek` provider **and** bundles the previously-missing deps, so the 4.8 limitations are fixed upstream. Upgraded the image pin from `2026.4.8` to `2026.6.1` and recreated the container. Also fixed a separate `EACCES: mkdir '/root/.openclaw/workspace'` failure ("Something went wrong while processing your request") caused by `OPENCLAW_CONFIG_DIR`/`OPENCLAW_WORKSPACE_DIR` host paths leaking from `.env` into the container via `env_file`; removed those two lines from `deploy/.env`. Telegram + DeepSeek dispatch verified end-to-end on 6.1.

## Updating (Docker)

The correct way to update this deployment is to change the image tag and recreate the container — **not** the in-app self-update:

```bash
# 1. set the new tag in deploy/.env  (OPENCLAW_IMAGE=ghcr.io/openclaw/openclaw:<version>)
# 2. pull + recreate
ssh openclaw-vps 'cd /opt/openclaw/deploy && docker compose pull && docker compose up -d --force-recreate'
```

In-app self-update (the `update.run` tool / asking the bot to "update itself") is left **enabled** but should not be used: it mutates `/app` inside the container, does not survive a recreate, and broke the deployment on 2026-06-07. Update via the image tag instead.

## Server details (current)

- Provider: Hetzner Cloud
- Plan: CX22 (Cost-Optimized, 2 vCPU, 4GB RAM)
- OS: Ubuntu 24.04
- IP: **46.62.195.231**
- Hostname: ubuntu-4gb-my
- Location: Helsinki, Finland (hel1-dc2)
- SSH config: `Host openclaw-vps` in `~/.ssh/config` → `ssh openclaw-vps`
- SSH key on Mac: `~/.ssh/id_ed25519_hetzner` (passphraseless, server-only)
- Root password: **locked** (`passwd -l root`). Password auth disabled. Key auth only.
- fail2ban: active
- UFW: SSH inbound only; gateway port bound to `127.0.0.1:18789` (not externally reachable)
- Docker 29.4.0 + Compose v5.1.2
- Repo: `/opt/openclaw` (github.com/mstysin/openclaw)
- OpenClaw image: `ghcr.io/openclaw/openclaw:2026.6.1` (pinned in `deploy/.env`; re-ships native deepseek + bundles kysely/typebox/grammy)
- Container name: `deploy-openclaw-gateway-1`
- Telegram bot: **@my_taoc_assistant_bot**
- Telegram allowlist: `[55478222]` (Michael only)
- Default model: `deepseek/deepseek-chat`

## Useful commands (from Mac, with `openclaw-vps` SSH alias)

```bash
# Status
ssh openclaw-vps 'docker ps'
ssh openclaw-vps 'cd /opt/openclaw/deploy && docker compose ps'

# Logs
ssh openclaw-vps 'docker logs deploy-openclaw-gateway-1 --tail 50'
ssh openclaw-vps 'cd /opt/openclaw/deploy && docker compose logs -f'

# Restart
ssh openclaw-vps 'cd /opt/openclaw/deploy && docker compose restart'

# Edit .env (secrets stay off the chat log)
ssh -t openclaw-vps 'nano /opt/openclaw/deploy/.env'

# Verify deepseek provider is still in catalog (before bumping image pin)
ssh openclaw-vps 'docker exec deploy-openclaw-gateway-1 openclaw infer model providers | grep "\"provider\":\"deepseek\""'

# CLI inside container
ssh openclaw-vps 'docker exec deploy-openclaw-gateway-1 openclaw doctor'
ssh openclaw-vps 'docker exec deploy-openclaw-gateway-1 openclaw models status'

# Pairing approvals (if a new Telegram user hits the bot and you want to allow them)
ssh openclaw-vps 'docker exec deploy-openclaw-gateway-1 openclaw pairing approve telegram <CODE>'
```

## Security invariants (do not regress)

- SSH: key-only, root password locked. Enforced by `/etc/ssh/sshd_config.d/00-openclaw-hardening.conf` (written by `vps-setup.sh`).
- `vps-setup.sh` refuses to run unless `/root/.ssh/authorized_keys` is non-empty. Do not work around this by setting a temporary root password.
- UFW: SSH only. Gateway binds to loopback; external access is via SSH tunnel, not public port.
- Secrets in `/opt/openclaw/deploy/.env` are not committed. If the server is ever compromised, rotate every value in that file plus the Telegram bot token before redeploying.
- Image pin: `deploy/.env.template` pins `OPENCLAW_IMAGE` to a verified tag. Do not move to `:latest` casually; verify `openclaw infer model providers | grep deepseek` first.

## Bootstrap-key escape hatch

If the Mac's primary SSH key's passphrase is lost and `ssh-add --apple-use-keychain` can't help, a passphraseless key lives at `~/.ssh/id_ed25519_hetzner`. The matching pubkey is hardcoded in `deploy/install-bootstrap-key.sh` for one-shot installation on a fresh VPS via the Hetzner web console. Use only for initial bootstrap; do not rely on this for day-to-day access.
