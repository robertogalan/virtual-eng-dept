# Deployment Guide

Complete infrastructure setup for the Virtual Engineering Department.

## Infrastructure Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        HETZNER CLOUD                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐         ┌─────────────┐                   │
│  │   CLAWDBOT PM   │◄───────►│   ClickUp   │                   │
│  │   "Oscar"       │         │   (Kanban)  │                   │
│  │   Orchestrator  │         └─────────────┘                   │
│  └────────┬────────┘                                           │
│           │ Dispatches via ClickUp comments                    │
│           │                                                    │
│  ┌────────┴────────┬───────────┬───────────┬───────────┐      │
│  ▼                 ▼           ▼           ▼           ▼      │
│ ┌─────┐        ┌─────┐     ┌─────┐     ┌─────┐     ┌─────┐   │
│ │Luna │        │Marcus│    │ Rex │     │Vigil│     │Quinn│   │
│ │ FE  │        │ BE   │    │DevOps│    │Sec+ │     │ QA  │   │
│ │     │        │      │    │      │    │Backup│    │     │   │
│ └─────┘        └─────┘     └─────┘     └─────┘     └─────┘   │
│                                                                 │
└───────────────────────────────────────────────────────────────┘
                            │
                            ▼
              ┌──────────────────────────┐
              │         GitHub           │
              │    PR → Staging (auto)   │
              │  Merge → Production (auto)│
              └──────────────────────────┘
```

## VPS Specifications

| Instance | Hostname | Hetzner Plan | Specs | Monthly |
|----------|----------|--------------|-------|---------|
| PM Orchestrator | `openclaw-pm` | CX32 | 4 vCPU, 8GB RAM, 80GB SSD | €7.59 |
| Frontend Agent | `openclaw-fe` | CX32 | 4 vCPU, 8GB RAM, 80GB SSD | €7.59 |
| Backend Agent | `openclaw-be` | CX32 | 4 vCPU, 8GB RAM, 80GB SSD | €7.59 |
| DevOps Agent | `openclaw-devops` | CX32 | 4 vCPU, 8GB RAM, 80GB SSD | €7.59 |
| Security Agent | `openclaw-sec` | CX32 | 4 vCPU, 8GB RAM, 80GB SSD | €7.59 |
| QA Agent | `openclaw-qa` | CX32 | 4 vCPU, 8GB RAM, 80GB SSD | €7.59 |
| **Total** | | | | **~€45.50/mo (~$49)** |

**Recommended Region:** Ashburn, VA (closest to GitHub's primary infrastructure)

---

## Phase 1: Hetzner Setup

### Create Project and Network

1. Create project: "OpenClaw" (or your preferred name)
2. Create private network: `10.0.0.0/16`
3. Provision 6x CX32 VPS instances
4. Attach all instances to the private network
5. Configure firewall:
   - Allow SSH (22) from your IP
   - Allow internal traffic on private network
   - Block all other inbound

### Private Network IPs

Add to `/etc/hosts` on each VPS:

```
10.0.0.1  openclaw-pm
10.0.0.2  openclaw-fe
10.0.0.3  openclaw-be
10.0.0.4  openclaw-devops
10.0.0.5  openclaw-sec
10.0.0.6  openclaw-qa
```

---

## Phase 2: GitHub Setup

### Create a GitHub App

1. Go to: `https://github.com/organizations/YOUR_ORG/settings/apps/new`
2. Name: `OpenClaw Engineering`
3. Permissions:
   - Repository: Contents (Read & Write)
   - Repository: Pull requests (Read & Write)
   - Repository: Issues (Read & Write)
   - Repository: Workflows (Read & Write)
   - Repository: Checks (Read & Write)
4. Generate private key, save securely
5. Note the App ID and Installation ID

### Branch Protection

Configure branch protection on `main`:
- Require pull request before merging
- Require status checks to pass
- Require review from code owners (optional)

---

## Phase 3: VPS Setup

Run the setup script on each VPS:

```bash
# SSH as root
ssh root@<vps-ip>

# Download and run setup script
curl -O https://raw.githubusercontent.com/YOUR_ORG/virtual-eng-dept/main/scripts/setup-agent.sh
chmod +x setup-agent.sh
./setup-agent.sh <agent-name>  # oscar, luna, marcus, rex, vigil, quinn
```

### Manual Steps After Script

1. Copy the agent's SOUL.md to `/home/openclaw/workspace/`
2. Copy clawdbot.json to `/home/openclaw/.clawdbot/`
3. Setup GitHub CLI auth:
   ```bash
   su - openclaw
   gh auth login
   ```
4. Start the service:
   ```bash
   systemctl start clawdbot
   ```

---

## Phase 4: Clawdbot Configuration

### PM Orchestrator (Oscar)

**`/home/openclaw/.clawdbot/clawdbot.json`:**

```json5
{
  agents: {
    defaults: {
      workspace: "/home/openclaw/workspace",
      model: { primary: "anthropic/claude-sonnet-4-5" },
      compaction: {
        mode: "safeguard",
        memoryFlush: { enabled: true, softThresholdTokens: 4000 }
      }
    }
  },
  channels: {
    slack: {
      enabled: true,
      botToken: "${SLACK_BOT_TOKEN}",
      appToken: "${SLACK_APP_TOKEN}",
      defaultChannel: "engineering"
    }
  },
  gateway: {
    port: 18789,
    mode: "local",
    bind: "0.0.0.0",
    auth: { mode: "password", password: "${GATEWAY_PASSWORD}" }
  }
}
```

### Specialist Agents

Each specialist agent uses a simpler config focused on Claude Code execution:

```json5
{
  agents: {
    defaults: {
      workspace: "/home/openclaw/workspace",
      model: { primary: "anthropic/claude-sonnet-4-5" },
      compaction: {
        mode: "safeguard",
        memoryFlush: { enabled: true, softThresholdTokens: 4000 }
      }
    }
  },
  gateway: {
    port: 18789,
    mode: "local",
    bind: "0.0.0.0",
    auth: { mode: "password", password: "${GATEWAY_PASSWORD}" }
  }
}
```

---

## Phase 5: Integration Setup

### ClickUp

1. Create API token: Settings → Apps → Generate API Token
2. Configure webhook to Oscar's endpoint for task status changes
3. Setup custom fields:
   - `agent` (dropdown): oscar, luna, marcus, rex, vigil, quinn
   - `pr_link` (url): GitHub PR link
   - `staging_url` (url): Staging environment link

### Slack

1. Create Slack App: api.slack.com/apps
2. Enable Socket Mode
3. Add bot to channels: `#engineering`, `#engineering-alerts`
4. Scopes needed:
   - `chat:write`
   - `channels:read`
   - `users:read`

### ClickUp Task Statuses

Configure your board with these statuses:

```
Backlog → Ready → In Progress → In Review → Staging → QA → Done
```

---

## Phase 6: Claude Code Setup

Each specialist agent runs Claude Code in headless mode.

**`/home/openclaw/workspace/run-agent.sh`:**

```bash
#!/bin/bash
cd ~/workspace

# Pull latest
git fetch origin
git checkout main
git pull

# Run Claude Code headless with full permissions
claude --dangerously-skip-permissions \
       --headless \
       --model claude-sonnet-4-5 \
       "$@"
```

Make executable:
```bash
chmod +x ~/workspace/run-agent.sh
```

---

## Phase 7: Backup Setup (Vigil)

### Nightly Backup Script

See `scripts/nightly-backup.sh`

### Cron Configuration

```bash
# On Vigil's VPS, add to crontab:
crontab -e

# Add this line (runs at 02:00 UTC daily):
0 2 * * * /home/openclaw/workspace/scripts/nightly-backup.sh >> /home/openclaw/logs/backup.log 2>&1
```

---

## Deployment Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                        DEPLOYMENT FLOW                           │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. DEVELOP                                                      │
│     Agent works on feature branch                                │
│     └─► Commits with [CLICKUP-ID] in message                    │
│                                                                  │
│  2. PR CREATED                                                   │
│     Agent opens PR → triggers:                                   │
│     ├─► Vigil: Security scan                                    │
│     ├─► Quinn: Code review                                      │
│     └─► Rex: Auto-deploy to STAGING                             │
│                                                                  │
│  3. STAGING READY                                                │
│     Oscar posts staging URL to ClickUp + Slack                  │
│     Oscar: "@human ready for testing: [staging-url]"            │
│     Status → "QA"                                                │
│                                                                  │
│  4. HUMAN APPROVAL                                               │
│     Human tests on staging                                       │
│     Human: "merge and deploy" (via Clawdbot PM)                 │
│                                                                  │
│  5. PRODUCTION                                                   │
│     Oscar triggers merge                                         │
│     Rex auto-deploys to PRODUCTION                              │
│     Status → "Done"                                              │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Human Commands

Issue natural language commands to Oscar via Slack or Clawdbot:

| Command | Action |
|---------|--------|
| `merge and deploy [task]` | Merges PR, triggers production deploy |
| `hold [task]` | Pauses work, moves to backlog |
| `prioritize [task]` | Bumps to top of queue |
| `assign [task] to [agent]` | Manual dispatch override |
| `status` | Reports all active tasks |
| `deploy staging [task]` | Forces staging redeploy |
| `rollback [task]` | Reverts last production deploy |
| `what's blocking?` | Lists blocked tasks |

---

## Deployment Checklist

```
[ ] Hetzner Setup
    [ ] Create project
    [ ] Create private network: 10.0.0.0/16
    [ ] Provision 6x CX32 VPS
    [ ] Attach all to private network
    [ ] Configure firewall

[ ] GitHub Setup
    [ ] Create org repos
    [ ] Create GitHub App
    [ ] Setup branch protection
    [ ] Setup deploy keys

[ ] ClickUp Setup
    [ ] API token for Oscar
    [ ] Webhook configuration
    [ ] Custom fields setup

[ ] Slack Setup
    [ ] Create Slack App
    [ ] Add bot to channels
    [ ] Get bot + app tokens

[ ] Per-Agent Setup (repeat 6x)
    [ ] Run setup-agent.sh
    [ ] Copy SOUL.md
    [ ] Configure clawdbot.json
    [ ] GitHub CLI auth
    [ ] Test Claude Code headless
    [ ] Start Clawdbot service

[ ] Vigil-Specific
    [ ] Setup backup script
    [ ] Configure cron
    [ ] Setup backup storage
    [ ] Test backup + restore

[ ] Rex-Specific
    [ ] Setup GitHub Actions
    [ ] Configure staging environment
    [ ] Configure production environment
    [ ] Test deploy pipeline

[ ] Integration Test
    [ ] Create test task in ClickUp
    [ ] Full lifecycle test
    [ ] Verify all notifications

[ ] Go Live
    [ ] Monitor for 1 week
    [ ] Iterate on prompts
```

---

## Cost Summary

| Item | Monthly |
|------|---------|
| 6x Hetzner CX32 | ~$49 |
| Anthropic API (Sonnet) | ~$100-300 |
| Backup storage (S3) | ~$5 |
| **Total** | **~$150-350/mo** |
