#!/bin/bash
#
# ClickUp Task Monitor with Auto-Deploy
# Polls ClickUp for tasks in "Done" status and auto-deploys them
#
# Usage: ./clickup-monitor.sh [--once]
# --once: run once and exit (for cron), otherwise polls every 60s
#
# Required env vars:
#   CLICKUP_API_TOKEN - Your ClickUp API token
#   CLICKUP_LIST_ID   - The list ID to monitor
#
# Optional:
#   DEPLOY_REPO       - Git repo path (default: /root/clawd/robertogalan/virtual-eng-dept)
#   POLL_INTERVAL     - Seconds between polls (default: 60)
#   SLACK_WEBHOOK     - Slack webhook for notifications
#

set -e

# Config - Kynship workspace credentials
CLICKUP_API_TOKEN="${CLICKUP_API_TOKEN:-pk_156100008_9DCFCYYQDKBARR8H1E4QM7PGQ7GTGXQE}"
# Available lists: Project 1 (901316988195), Project 2 (901316988194)
CLICKUP_LIST_ID="${CLICKUP_LIST_ID:-901316988195}"
DEPLOY_REPO="${DEPLOY_REPO:-/root/clawd/robertogalan/virtual-eng-dept}"
POLL_INTERVAL="${POLL_INTERVAL:-60}"
STATE_FILE="/tmp/clickup-deployed-tasks.txt"
LOG_FILE="/root/clawd/logs/clickup-monitor.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Validate config
if [ -z "$CLICKUP_API_TOKEN" ]; then
    echo "ERROR: CLICKUP_API_TOKEN not set"
    echo "Get your token from: https://app.clickup.com/settings/apps"
    exit 1
fi

if [ -z "$CLICKUP_LIST_ID" ]; then
    echo "ERROR: CLICKUP_LIST_ID not set"
    echo "Find it in ClickUp URL: https://app.clickup.com/[team]/[space]/list/[LIST_ID]"
    exit 1
fi

mkdir -p "$(dirname "$LOG_FILE")"
touch "$STATE_FILE"

# Get tasks from ClickUp
get_tasks() {
    local status="$1"
    curl -s "https://api.clickup.com/api/v2/list/$CLICKUP_LIST_ID/task?statuses%5B%5D=$status" \
        -H "Authorization: $CLICKUP_API_TOKEN" \
        -H "Content-Type: application/json"
}

# Update task status in ClickUp
update_task_status() {
    local task_id="$1"
    local new_status="$2"
    curl -s -X PUT "https://api.clickup.com/api/v2/task/$task_id" \
        -H "Authorization: $CLICKUP_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"status\": \"$new_status\"}"
}

# Add comment to task
add_task_comment() {
    local task_id="$1"
    local comment="$2"
    curl -s -X POST "https://api.clickup.com/api/v2/task/$task_id/comment" \
        -H "Authorization: $CLICKUP_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"comment_text\": \"$comment\"}"
}

# Check if task was already deployed
is_deployed() {
    local task_id="$1"
    grep -q "^$task_id$" "$STATE_FILE" 2>/dev/null
}

# Mark task as deployed
mark_deployed() {
    local task_id="$1"
    echo "$task_id" >> "$STATE_FILE"
}

# Deploy a task (commit, push, deploy)
deploy_task() {
    local task_id="$1"
    local task_name="$2"
    local branch="${3:-main}"
    
    log "${GREEN}Deploying task: [$task_id] $task_name${NC}"
    
    cd "$DEPLOY_REPO" || {
        log "${RED}ERROR: Cannot cd to $DEPLOY_REPO${NC}"
        return 1
    }
    
    # Pull latest
    log "  Pulling latest from origin..."
    git fetch origin
    git checkout "$branch" 2>/dev/null || git checkout main
    git pull origin "$branch" 2>/dev/null || git pull origin main
    
    # Check for uncommitted changes
    if ! git diff --quiet || ! git diff --cached --quiet; then
        log "  Committing changes..."
        git add -A
        git commit -m "[$task_id] $task_name - Auto-deployed by ClickUp monitor" || true
    fi
    
    # Push
    log "  Pushing to origin..."
    git push origin HEAD || {
        log "${RED}ERROR: Push failed${NC}"
        return 1
    }
    
    # Deploy (customize this for your setup)
    log "  Running deploy..."
    if [ -f "deploy.sh" ]; then
        ./deploy.sh
    elif [ -f "Makefile" ] && grep -q "deploy:" Makefile; then
        make deploy
    else
        # Default: PM2 restart if it exists
        if command -v pm2 &> /dev/null; then
            pm2 restart all 2>/dev/null || true
        fi
    fi
    
    # Add comment to ClickUp
    add_task_comment "$task_id" "✅ Auto-deployed at $(date '+%Y-%m-%d %H:%M:%S')\n\nCommit: $(git rev-parse --short HEAD)\nBranch: $branch"
    
    log "${GREEN}  ✅ Deploy complete${NC}"
    return 0
}

# Notify via Slack (if configured)
notify_slack() {
    local message="$1"
    if [ -n "$SLACK_WEBHOOK" ]; then
        curl -s -X POST "$SLACK_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"text\": \"$message\"}" >/dev/null
    fi
}

# Main poll loop
poll_and_deploy() {
    log "Checking ClickUp for completed tasks..."
    
    # Get tasks in "Done" or "complete" status
    local response
    response=$(get_tasks "done")
    
    # Also check "complete" status (ClickUp varies)
    local response2
    response2=$(get_tasks "complete")
    
    # Parse tasks (requires jq)
    if ! command -v jq &> /dev/null; then
        log "${RED}ERROR: jq not installed. Run: apt install jq${NC}"
        exit 1
    fi
    
    # Combine and process
    local tasks
    tasks=$(echo "$response" | jq -r '.tasks[]? | "\(.id)|\(.name)|\(.status.status)"' 2>/dev/null || echo "")
    tasks+=$'\n'
    tasks+=$(echo "$response2" | jq -r '.tasks[]? | "\(.id)|\(.name)|\(.status.status)"' 2>/dev/null || echo "")
    
    local count=0
    while IFS='|' read -r task_id task_name task_status; do
        [ -z "$task_id" ] && continue
        
        if is_deployed "$task_id"; then
            continue
        fi
        
        log "${YELLOW}Found completed task: [$task_id] $task_name${NC}"
        
        if deploy_task "$task_id" "$task_name"; then
            mark_deployed "$task_id"
            notify_slack "✅ Deployed: [$task_id] $task_name"
            ((count++))
        else
            log "${RED}Failed to deploy: $task_id${NC}"
            notify_slack "❌ Deploy failed: [$task_id] $task_name"
        fi
    done <<< "$tasks"
    
    if [ "$count" -eq 0 ]; then
        log "No new tasks to deploy"
    else
        log "${GREEN}Deployed $count task(s)${NC}"
    fi
}

# Main
log "=========================================="
log "ClickUp Monitor started"
log "List ID: $CLICKUP_LIST_ID"
log "Repo: $DEPLOY_REPO"
log "=========================================="

if [ "$1" = "--once" ]; then
    poll_and_deploy
else
    while true; do
        poll_and_deploy
        log "Sleeping ${POLL_INTERVAL}s..."
        sleep "$POLL_INTERVAL"
    done
fi
