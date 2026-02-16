#!/bin/bash
set -e

AGENT_NAME=$1  # oscar, luna, marcus, rex, vigil, quinn

if [ -z "$AGENT_NAME" ]; then
    echo "Usage: ./setup-agent.sh <agent-name>"
    echo "Agent names: oscar, luna, marcus, rex, vigil, quinn"
    exit 1
fi

echo "=== Setting up OpenClaw agent: $AGENT_NAME ==="

# 1. Create service user
echo "[1/8] Creating service user..."
useradd -m -s /bin/bash openclaw 2>/dev/null || echo "User openclaw already exists"
# WARNING: This grants passwordless root access to the openclaw user.
# For production, scope sudo to only the commands each agent needs.
# Example: openclaw ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart openclaw, /usr/bin/pm2 *
echo "openclaw ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/openclaw

# 2. Install system packages
echo "[2/8] Installing system packages..."
apt update && apt upgrade -y
apt install -y git curl wget build-essential python3 python3-pip python3-venv

# 3. Install Node.js 22
echo "[3/8] Installing Node.js..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt install -y nodejs
else
    echo "Node.js already installed: $(node --version)"
fi

# 4. Install PM2
echo "[4/8] Installing PM2..."
npm install -g pm2

# 5. Install OpenClaw
echo "[5/8] Installing OpenClaw..."
npm install -g openclaw

# 6. Install Claude Code (for specialist agents, not PM)
if [ "$AGENT_NAME" != "oscar" ]; then
    echo "[6/8] Installing Claude Code..."
    npm install -g @anthropic-ai/claude-code
else
    echo "[6/8] Skipping Claude Code (PM doesn't need it)..."
fi

# 7. Install GitHub CLI
echo "[7/8] Installing GitHub CLI..."
if ! command -v gh &> /dev/null; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
    apt update && apt install gh -y
else
    echo "GitHub CLI already installed: $(gh --version | head -1)"
fi

# 8. Setup workspace and directories
echo "[8/8] Setting up workspace..."
su - openclaw << 'EOF'
mkdir -p ~/workspace
mkdir -p ~/logs
mkdir -p ~/.openclaw

# Git config
git config --global user.name "OpenClaw Agent"
git config --global user.email "agent@openclaw.local"
git config --global init.defaultBranch main

# Create run script for Claude Code (specialist agents)
cat > ~/workspace/run-agent.sh << 'RUNSCRIPT'
#!/bin/bash
cd ~/workspace

# Pull latest if in a git repo
if [ -d .git ]; then
    git fetch origin
    git checkout main
    git pull
fi

# Run Claude Code headless with full permissions
claude --dangerously-skip-permissions \
       --headless \
       --model claude-sonnet-4-5 \
       "$@"
RUNSCRIPT
chmod +x ~/workspace/run-agent.sh
EOF

# Setup OpenClaw as systemd service
echo "Setting up systemd service..."
cat > /etc/systemd/system/openclaw.service << EOF
[Unit]
Description=OpenClaw Agent ($AGENT_NAME)
After=network.target

[Service]
Type=simple
User=openclaw
WorkingDirectory=/home/openclaw/workspace
ExecStart=/usr/bin/openclaw gateway
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable openclaw

echo ""
echo "=== Setup complete for $AGENT_NAME ==="
echo ""
echo "Next steps:"
echo "1. Copy SOUL.md to /home/openclaw/workspace/"
echo "2. Copy openclaw.json to /home/openclaw/.openclaw/"
echo "3. Set environment variables in /home/openclaw/.openclaw/openclaw.json"
echo "4. Setup GitHub auth: su - openclaw && gh auth login"
echo "5. Clone your repos to /home/openclaw/workspace/"
echo "6. Start service: systemctl start openclaw"
echo "7. Check logs: journalctl -u openclaw -f"
echo ""
