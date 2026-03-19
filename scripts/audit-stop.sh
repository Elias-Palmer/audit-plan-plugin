#!/usr/bin/env bash
# audit-stop.sh — Stop hook (fallback if PreToolUse on ExitPlanMode isn't hookable)
# Only activates when the primary hook didn't fire.

set -euo pipefail

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')

# Validate SESSION_ID — only allow alphanumeric, dashes, and underscores
if [[ ! "$SESSION_ID" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  exit 1
fi

PRIMARY_MARKER="/tmp/claude-plan-audit-primary-${SESSION_ID}"

# Reject symlinks to prevent symlink attacks
if [[ -L "$PRIMARY_MARKER" ]]; then
  exit 1
fi

# Skip if primary hook already handled this session
if [[ -f "$PRIMARY_MARKER" ]]; then
  exit 0
fi

# Skip if stop_hook_active (built-in loop prevention — this is the second Stop after a block)
if [[ "$STOP_HOOK_ACTIVE" == "true" ]]; then
  exit 0
fi

# Skip if no transcript path available
if [[ -z "$TRANSCRIPT_PATH" || ! -f "$TRANSCRIPT_PATH" ]]; then
  exit 0
fi

# Validate transcript path is under expected Claude data directory
if [[ "$TRANSCRIPT_PATH" != /home/*/.claude/* ]]; then
  exit 0
fi

# Check transcript for a recent ExitPlanMode tool call
# This prevents false triggers on AskUserQuestion or other turn-ending events
if ! tail -c 10000 "$TRANSCRIPT_PATH" | grep -q '"ExitPlanMode"'; then
  exit 0
fi

# Check if Claude actually edited a plan file this session
# If no plan was written, don't trigger the audit
if ! grep -q '\.claude/plans/' "$TRANSCRIPT_PATH" 2>/dev/null; then
  exit 0
fi

# All checks passed — this is a legitimate plan exit that the primary hook missed
echo "Checking plan audit status (fallback)..." >&2

cat <<'RESPONSE'
{
  "decision": "block",
  "reason": "AUTOMATIC PLAN AUDIT — Your exit was blocked for a one-time audit.\n\nReview the plan that is ALREADY in your conversation context above. Do NOT re-read plan files from disk.\n\nCheck for:\n- Missing requirements or edge cases\n- Incorrect file paths or function references\n- Logical gaps or ordering issues\n- Simpler alternatives overlooked\n- Missing verification/testing steps\n\nIf you find issues, make targeted edits to the plan file using Edit (change only the specific lines that need fixing — do NOT rewrite the whole file). If the plan looks good, just call ExitPlanMode again with no changes.\n\nThis is your ONE audit pass. Focus on real issues, not cosmetic changes."
}
RESPONSE
