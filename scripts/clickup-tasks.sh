#!/bin/bash
#
# ClickUp Task Viewer - Quick CLI to check tasks
#
# Usage:
#   ./clickup-tasks.sh                  # List all tasks
#   ./clickup-tasks.sh ready            # List tasks in "Ready" status
#   ./clickup-tasks.sh <status>         # List tasks in specific status
#
# Required env vars:
#   CLICKUP_API_TOKEN - Your ClickUp API token
#   CLICKUP_LIST_ID   - The list ID to query
#

# Kynship workspace credentials
CLICKUP_API_TOKEN="${CLICKUP_API_TOKEN:-pk_156100008_9DCFCYYQDKBARR8H1E4QM7PGQ7GTGXQE}"
# Available lists: Project 1 (901316988195), Project 2 (901316988194)
CLICKUP_LIST_ID="${CLICKUP_LIST_ID:-901316988195}"

if [ -z "$CLICKUP_API_TOKEN" ]; then
    echo "ERROR: CLICKUP_API_TOKEN not set"
    exit 1
fi

if [ -z "$CLICKUP_LIST_ID" ]; then
    echo "ERROR: CLICKUP_LIST_ID not set"
    exit 1
fi

STATUS_FILTER="$1"

# Build URL
URL="https://api.clickup.com/api/v2/list/$CLICKUP_LIST_ID/task"
if [ -n "$STATUS_FILTER" ]; then
    URL="${URL}?statuses%5B%5D=${STATUS_FILTER}"
fi

# Fetch and display
response=$(curl -s "$URL" \
    -H "Authorization: $CLICKUP_API_TOKEN" \
    -H "Content-Type: application/json")

if ! command -v jq &> /dev/null; then
    echo "$response"
    exit 0
fi

echo "$response" | jq -r '
    .tasks[] | 
    "[\(.status.status | ascii_upcase)] \(.id) - \(.name)" + 
    (if .assignees[0] then " (@\(.assignees[0].username))" else "" end)
' 2>/dev/null || echo "No tasks found or error in response"
