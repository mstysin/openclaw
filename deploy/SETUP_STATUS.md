# OpenClaw VPS Setup - Progress

## Status: Paused - SSH access pending

## What's done
- [x] Hetzner CX23 provisioned (Ubuntu 24.04, Helsinki)
- [x] Server IP: 46.62.200.167
- [x] Server is running
- [x] Password auth enabled in sshd_config (via web console)
- [x] KbdInteractiveAuthentication set to yes
- [x] Local repo wiped and fresh OpenClaw v2026.4.5 cloned
- [x] GitHub repo created: github.com/mstysin/openclaw
- [x] Deploy scripts created (deploy/ directory)

## What's left
- [ ] Fix SSH access (reset root password via web console - `passwd` command, set something simple)
- [ ] Install Docker on VPS
- [ ] Clone repo and configure .env
- [ ] Start OpenClaw gateway
- [ ] Set up SSH tunnel from Mac
- [ ] Configure channels (Telegram, etc.)

## To resume
1. Open Hetzner web console (terminal icon on server page)
2. Log in as root (current password may be `openclaw123` or the original `tfcsqxsvXu3K`)
3. Run `passwd` and set a new simple password (e.g. `abc12345`)
4. Tell Claude the new password
5. Claude will SSH in and finish the setup automatically

## Server details
- Provider: Hetzner
- Plan: CX23 (2 vCPU, 4GB RAM)
- OS: Ubuntu 24.04
- IP: 46.62.200.167
- Location: Helsinki, Finland (hel1-dc2)
- SSH key on Mac: ~/.ssh/id_ed25519 (not yet working on server)
