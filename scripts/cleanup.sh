#!/usr/bin/env bash
# cleanup.sh — SessionEnd hook to remove state files from /tmp

set -euo pipefail

SESSION_ID=$(cat | jq -r '.session_id')

# Validate SESSION_ID — only allow alphanumeric, dashes, and underscores
if [[ ! "$SESSION_ID" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  exit 1
fi

STATE_FILE="/tmp/claude-plan-audit-${SESSION_ID}"
PRIMARY_MARKER="/tmp/claude-plan-audit-primary-${SESSION_ID}"

# Reject symlinks to prevent symlink attacks
if [[ -L "$STATE_FILE" || -L "$PRIMARY_MARKER" ]]; then
  exit 1
fi

rm -f "$STATE_FILE" "$PRIMARY_MARKER"
