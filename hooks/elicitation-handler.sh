#!/usr/bin/env bash
# Claude Octopus — Elicitation Hook (v9.19.0)
# Fires when an MCP server requests structured user input (Elicitation event)
# or when the user responds (ElicitationResult event).
#
# Hook events: Elicitation, ElicitationResult (CC v2.1.76+, SUPPORTS_ELICITATION_HOOKS)
# Purpose: Observability logging for MCP elicitation events
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

MODE="${1:-request}"  # "request" or "result"
LOG_DIR="${HOME}/.claude-octopus/logs"
mkdir -p "$LOG_DIR"

# Log elicitation events for observability (append-only, no rotation needed — small entries)
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) elicitation_${MODE} session=${CLAUDE_SESSION_ID:-unknown}" \
    >> "$LOG_DIR/elicitation.log" 2>/dev/null || true

exit 0
