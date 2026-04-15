---
name: skill-scope-drift
version: 1.0.0
description: "Scope drift detection — compares actual diff against stated intent to catch scope creep and missing requirements. Informational only, never blocks."
---

# Scope Drift Detection

Compares the actual code diff against stated intent (TODOS.md, PR description, commit messages) to surface scope creep and missing requirements **before** the full code review runs.

**This is informational only — it never blocks a review or merge.** Some scope drift is intentional ("I saw a bug while working on the feature"). The goal is awareness, not enforcement.

## When to Run

- Automatically as part of `/octo:deliver` and `/octo:review` (Dev context only)
- Manually via: "check scope drift", "scope check", "did I drift?"
- Skipped for Knowledge context reviews (no diff to compare)

## How It Works

### Step 1: Gather Stated Intent

Collect intent signals from multiple sources (any that exist):

```bash
# 1. TODOS.md / TODO.md in project root or .octo/
TODOS_FILE=""
for candidate in TODOS.md TODO.md .octo/TODOS.md; do
  [[ -f "$candidate" ]] && TODOS_FILE="$candidate" && break
done

# 2. PR description (if on a branch with an open PR)
PR_BODY=""
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [[ -n "$CURRENT_BRANCH" && "$CURRENT_BRANCH" != "main" && "$CURRENT_BRANCH" != "master" ]]; then
  if command -v gh &>/dev/null; then
    PR_BODY=$(gh pr view "$CURRENT_BRANCH" --json body --jq '.body' 2>/dev/null || echo "")
  fi
fi

# 3. Commit messages on this branch (since divergence from main/master)
BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
COMMIT_MESSAGES=$(git log --oneline "${BASE_BRANCH}..HEAD" 2>/dev/null || echo "")

# 4. .octo/STATE.md context (if using Double Diamond workflow)
STATE_CONTEXT=""
if [[ -f ".octo/STATE.md" ]]; then
  STATE_CONTEXT=$(cat .octo/STATE.md 2>/dev/null || echo "")
fi
```

### Step 2: Gather Actual Diff

```bash
# Files changed on this branch vs base
DIFF_STAT=$(git diff --stat "${BASE_BRANCH}..HEAD" 2>/dev/null || git diff --stat HEAD~1 2>/dev/null || echo "")
DIFF_FILES=$(git diff --name-only "${BASE_BRANCH}..HEAD" 2>/dev/null || git diff --name-only HEAD~1 2>/dev/null || echo "")
DIFF_SUMMARY=$(git diff --shortstat "${BASE_BRANCH}..HEAD" 2>/dev/null || git diff --shortstat HEAD~1 2>/dev/null || echo "")
```

### Step 3: Analyse for Drift

Compare intent signals against the actual diff. Look for two categories:

#### Scope Creep Detection

Files or changes that don't align with any stated intent:

- **Unrelated directories**: Changes in modules/directories not mentioned in TODOS or commit messages
- **Feature additions**: New capabilities, APIs, or UI elements not described in intent
- **"While I was in there" changes**: Formatting, refactoring, or dependency updates mixed with feature work
- **Config/infra changes**: Build config, CI, or dependency changes bundled with feature code

#### Missing Requirements Detection

Items from stated intent not reflected in the diff:

- **Unchecked TODOS**: Items in TODOS.md not addressed by any changed file
- **Mentioned but missing**: Features described in PR body or commit messages with no corresponding code changes
- **Test gaps**: Features implemented but no corresponding test files changed
- **Doc gaps**: API or behaviour changes with no documentation updates

### Step 4: Output Structured Report

```markdown
## Scope Drift Check

**Status:** `CLEAN` | `DRIFT DETECTED` | `REQUIREMENTS MISSING` | `DRIFT + MISSING`

### Intent Summary
Sources checked: TODOS.md ✓ | PR description ✗ | Commit messages (N commits) ✓ | STATE.md ✗
- [Summarise the stated intent in 2-3 bullet points]

### Delivered Summary
- N files changed across M directories
- [Summarise what the diff actually does in 2-3 bullet points]

### Scope Creep (if any)
| File/Directory | Why it looks unrelated | Severity |
|---------------|----------------------|----------|
| `path/to/file` | Not mentioned in any intent source | Low/Medium/High |

### Missing Requirements (if any)
| Requirement | Source | Evidence |
|------------|--------|----------|
| [Requirement text] | TODOS.md line N | No matching file changes found |

### Recommendation
- [One-line recommendation: "Clean — proceed to review" or "N items drifted, M requirements missing — review with awareness"]
```

## MANDATORY COMPLIANCE — DO NOT SKIP

**When this skill is invoked, you MUST execute the scope drift analysis pipeline. You are PROHIBITED from:**
- Skipping the diff comparison and guessing whether drift occurred
- Reporting "no drift" without actually checking available intent sources
- Blocking or gating reviews based on drift results (this is informational only)

## Integration Points

### In `/octo:deliver` (flow-deliver)

Run scope drift check between Step 1 (context detection) and Step 4 (orchestrate.sh execution). Insert as **Step 1c: Scope Drift Check** (Dev context only):

```
After detecting Dev context and subtype:
1. Run scope drift analysis
2. Display the structured report
3. Proceed to Step 2 (visual indicators) regardless of result
```

The scope drift report becomes part of the validation context passed to the review providers.

### In `/octo:review` (skill-code-review)

Run scope drift check as a pre-review step. Display results before the multi-LLM review pipeline begins.

### In `/octo:staged-review`

Run scope drift check during Stage 1 (spec compliance). The drift report supplements the spec compliance check — drift detection catches lightweight intent signals that formal specs may not capture.

## Configuration

No configuration needed. The skill auto-detects available intent sources and adapts:

- No TODOS.md? Skip that source.
- No PR? Skip PR body.
- No git history? Skip commit messages.
- All sources missing? Report "No intent sources found — scope drift check skipped."

If zero intent sources are found, the skill exits silently rather than producing a vacuous report.

## Examples

### Clean Result
```
## Scope Drift Check
**Status:** CLEAN

### Intent Summary
Sources: TODOS.md ✓ | Commit messages (4 commits) ✓
- Add retry logic to provider dispatch
- Handle 429 rate limit responses

### Delivered Summary
- 3 files changed: provider-router.sh, lib/resilience.sh, tests/unit/test-resilience.sh
- Added error classification and exponential backoff

### Recommendation
Clean — proceed to review.
```

### Drift Detected
```
## Scope Drift Check
**Status:** DRIFT DETECTED

### Intent Summary
Sources: TODOS.md ✓ | PR description ✓ | Commit messages (7 commits) ✓
- Fix login page CSS alignment
- Add loading spinner to submit button

### Delivered Summary
- 8 files changed across 4 directories
- Fixed CSS alignment, added spinner, AND refactored auth module, updated 3 unrelated test fixtures

### Scope Creep
| File/Directory | Why it looks unrelated | Severity |
|---------------|----------------------|----------|
| `src/auth/oauth.ts` | Auth refactor not in any intent source | Medium |
| `tests/fixtures/users.json` | Test fixture updates unrelated to CSS/spinner | Low |
| `package.json` | Dependency bump not mentioned | Low |

### Recommendation
3 items drifted — review with awareness. Consider splitting auth refactor into a separate PR.
```
