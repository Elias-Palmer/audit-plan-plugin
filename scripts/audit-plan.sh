#!/usr/bin/env bash
# audit-plan.sh — PreToolUse hook on ExitPlanMode
# Denies the first ExitPlanMode call (triggers audit), allows the second.
# Only triggers if Claude actually edited a plan file during this session.

set -euo pipefail

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')

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

# If we already denied once, this is the second call — allow through
if [[ -f "$STATE_FILE" ]]; then
  rm -f "$STATE_FILE" "$PRIMARY_MARKER"
  exit 0
fi

# Check if Claude actually edited a plan file this session
# Look for Edit tool calls targeting ~/.claude/plans/ in the transcript
PLAN_WAS_EDITED=false
if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
  # Validate transcript path is under expected Claude data directory
  if [[ "$TRANSCRIPT_PATH" == /home/*/.claude/* ]]; then
    # Search for Edit tool uses on plan files in the transcript
    if grep -q '\.claude/plans/' "$TRANSCRIPT_PATH" 2>/dev/null; then
      PLAN_WAS_EDITED=true
    fi
  fi
fi

# No plan was edited this session — let ExitPlanMode through without audit
if [[ "$PLAN_WAS_EDITED" != "true" ]]; then
  exit 0
fi

# Plan was edited — deny and request audit
touch "$STATE_FILE" && chmod 600 "$STATE_FILE"
touch "$PRIMARY_MARKER" && chmod 600 "$PRIMARY_MARKER"

echo "Checking plan audit status..." >&2

cat <<'RESPONSE'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Plan audit required before exit",
    "additionalContext": "Plan Audit — ExitPlanMode paused for a one-time quality review.\n\nReview the plan that is ALREADY in your conversation context above. Do NOT re-read plan files from disk.\n\nCheck for:\n- Missing requirements or edge cases\n- Incorrect file paths or function references\n- Logical gaps or ordering issues\n- Simpler alternatives overlooked\n- Missing verification or testing steps\n- Assumptions that should be verified — check every assumption against the actual code (e.g., assumed file locations, API behavior, library capabilities, or data formats — grep or read files to confirm rather than trusting memory)\n\nIf you find issues, make targeted edits to the plan file using Edit (change only the specific lines that need fixing — do NOT rewrite the whole file). If the plan looks good, just call ExitPlanMode again with no changes.\n\nThis is your ONE audit pass. Focus on real issues, not cosmetic changes."
  }
}
RESPONSE
