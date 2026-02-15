# Virtual Engineering Department

An AI-powered engineering team orchestrated by [Clawdbot](https://github.com/clawdbot/clawdbot). Deploy a fleet of specialized Claude Code agents managed by a PM orchestrator that handles task decomposition, dispatch, quality gates, and deployment automation.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        INFRASTRUCTURE                           │
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
```

## The Team

| Agent | Name | Role | Accountability |
|-------|------|------|----------------|
| PM | **Oscar** | Orchestrator | Task decomposition, dispatch, status tracking, human liaison |
| Frontend | **Luna** | UI/UX Specialist | Dashboards, landing pages, client-facing polish |
| Backend | **Marcus** | API Specialist | APIs, data pipelines, business logic, integrations |
| DevOps | **Rex** | Infrastructure | CI/CD, deployments, nginx, PM2, automation |
| Security | **Vigil** | Security + Backup | Security scans, dependency audits, nightly backups |
| QA | **Quinn** | Quality Assurance | Code review, testing, acceptance validation |

## Features

- **Autonomous Development**: Agents pick up tasks, create branches, open PRs
- **Quality Gates**: Mandatory security scans and code reviews on every PR
- **Auto-Deploy**: Staging deploys on PR, production deploys on merge
- **Human-in-the-Loop**: All merges require human approval
- **Natural Language Control**: Issue commands like "merge and deploy" via chat
- **ClickUp Integration**: Full task lifecycle management
- **Slack Notifications**: Team updates and alerts

## Tech Stack

| Layer | Technology |
|-------|------------|
| Backend | Python / Flask |
| Process Manager | PM2 |
| Database | SQLite (isolated per service) |
| Frontend | Tailwind CSS, Vanilla JS |
| Version Control | GitHub |
| Task Management | ClickUp |
| Communication | Slack |
| AI | Claude (Anthropic) via Clawdbot |

## Documentation

- [Deployment Plan](docs/DEPLOYMENT.md) — Full infrastructure setup guide
- [PM System Prompt](docs/PM-SYSTEM-PROMPT.md) — Complete orchestration instructions for Oscar
- [Agent Personalities](agents/) — Individual agent SOUL.md files
- [Config Templates](config/) — Clawdbot configuration templates
- [Scripts](scripts/) — Setup and automation scripts

## Quick Start

1. **Provision Infrastructure**
   ```bash
   # 6x VPS instances (Hetzner CX32 recommended)
   # See docs/DEPLOYMENT.md for details
   ```

2. **Setup Each Agent**
   ```bash
   ./scripts/setup-agent.sh <agent-name>
   ```

3. **Configure Integrations**
   - ClickUp API token
   - GitHub App credentials
   - Slack bot tokens
   - Anthropic API key

4. **Deploy**
   ```bash
   systemctl start clawdbot
   ```

## Deployment Flow

```
Develop → PR → Security Scan → Code Review → Staging → Human QA → Merge → Production
```

1. Agent works on feature branch
2. Opens PR → triggers Vigil (security) + Quinn (QA) + Rex (staging deploy)
3. Oscar notifies human: "Ready for testing: [staging-url]"
4. Human approves: "merge and deploy"
5. Oscar merges, Rex deploys to production

## Cost Estimate

| Item | Monthly |
|------|---------|
| 6x Hetzner CX32 | ~$49 |
| Anthropic API | ~$100-300 |
| Backup storage | ~$5 |
| **Total** | **~$150-350** |

## License

MIT

## Contributing

This is an experimental project. Issues and PRs welcome.
