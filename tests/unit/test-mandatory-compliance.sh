#!/usr/bin/env bash
# Tests that all commands/skills calling orchestrate.sh have MANDATORY COMPLIANCE enforcement
# Prevents Claude from rationalizing workflow bypass
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TEST_COUNT=0; PASS_COUNT=0; FAIL_COUNT=0
pass() { TEST_COUNT=$((TEST_COUNT+1)); PASS_COUNT=$((PASS_COUNT+1)); echo "PASS: $1"; }
fail() { TEST_COUNT=$((TEST_COUNT+1)); FAIL_COUNT=$((FAIL_COUNT+1)); echo "FAIL: $1 — $2"; }

# ── Commands that call orchestrate.sh MUST have MANDATORY COMPLIANCE ─────────
# Exceptions: utility commands that don't run multi-LLM workflows

EXEMPT_COMMANDS="octo-auto octo-careful octo-claw octo-costs octo-dev octo-doctor octo-freeze octo-guard octo-history octo-km octo-model-config octo-setup octo-unfreeze"

for f in "$PROJECT_ROOT"/commands/octo-*.md; do
    name=$(basename "$f" .md)

    # Skip exempt utility commands
    if echo " $EXEMPT_COMMANDS " | grep -q " $name "; then
        continue
    fi

    uses_orchestrate=$(grep -c 'orchestrate\.sh' "$f" 2>/dev/null || true)

    if [[ "$uses_orchestrate" -gt 0 ]]; then
        if grep -q 'MANDATORY COMPLIANCE' "$f" 2>/dev/null; then
            pass "$name has MANDATORY COMPLIANCE (uses orchestrate.sh)"
        else
            fail "$name missing MANDATORY COMPLIANCE" "calls orchestrate.sh but has no enforcement block"
        fi
    fi
done

# ── Skills that call orchestrate.sh MUST have enforcement ────────────────────
# Exceptions: utility skills, template-only skills

EXEMPT_SKILLS="skill-doctor sys-configure skill-finish-branch skill-verify"

for f in "$PROJECT_ROOT"/skills/*/SKILL.md; do
    name=$(basename "$(dirname "$f")")

    if echo " $EXEMPT_SKILLS " | grep -q " $name "; then
        continue
    fi

    uses_orchestrate=$(grep -c 'orchestrate\.sh' "$f" 2>/dev/null || true)

    if [[ "$uses_orchestrate" -gt 0 ]]; then
        if grep -q 'MANDATORY COMPLIANCE\|EXECUTION CONTRACT.*MANDATORY\|CANNOT SKIP' "$f" 2>/dev/null; then
            pass "$name has enforcement (uses orchestrate.sh)"
        else
            fail "$name missing enforcement" "calls orchestrate.sh but has no MANDATORY COMPLIANCE or EXECUTION CONTRACT"
        fi
    fi
done

# ── Enforcement blocks must include PROHIBITED ───────────────────────────────

for f in "$PROJECT_ROOT"/commands/octo-*.md "$PROJECT_ROOT"/skills/*/SKILL.md; do
    if grep -q 'MANDATORY COMPLIANCE' "$f" 2>/dev/null; then
        name=$(basename "$f" .md)
        [[ "$name" == "SKILL" ]] && name=$(basename "$(dirname "$f")")
        if grep -q 'PROHIBITED' "$f" 2>/dev/null; then
            pass "$name enforcement includes PROHIBITED list"
        else
            fail "$name enforcement weak" "has MANDATORY COMPLIANCE but no PROHIBITED list"
        fi
    fi
done

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════"
echo "mandatory-compliance: $PASS_COUNT/$TEST_COUNT passed"
[[ $FAIL_COUNT -gt 0 ]] && echo "FAILURES: $FAIL_COUNT" && exit 1
echo "All tests passed."
