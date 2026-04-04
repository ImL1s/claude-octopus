# Claude Octopus — Developer Reference

> Moved from CLAUDE.md to save ~1,000 tokens per user session. These sections are for plugin developers and maintainers, not end users.

---

## Enforcement Best Practices (Mandatory for Workflow Skills)

Skills that invoke orchestrate.sh MUST use the **Validation Gate Pattern** to ensure proper execution.

### Required Pattern

1. **Add to frontmatter:**
   ```yaml
   execution_mode: enforced
   pre_execution_contract:
     - interactive_questions_answered
     - visual_indicators_displayed
   validation_gates:
     - orchestrate_sh_executed
     - synthesis_file_exists
   ```

2. **Add EXECUTION CONTRACT section** with:
   - Blocking steps (numbered, mandatory)
   - Explicit Bash tool calls (not just markdown examples)
   - Validation gates that verify execution
   - Clear prohibition statements (what NOT to do)

3. **Use imperative language:**
   - "You MUST execute..." / "PROHIBITED from..." / "CANNOT SKIP..."
   - NOT "You should..." / "It's recommended..." / "Consider..."

4. **Validate artifacts:**
   - Check synthesis files exist and are recent
   - Verify via filesystem checks, not assumptions
   - Fail explicitly if validation doesn't pass

See `.claude/skills/skill-deep-research.md` for reference implementation.

---

## Modular Configuration (Claude Code v2.1.20+)

### Directory Structure

```
claude-octopus/
├── CLAUDE.md                    # Main instructions
├── config/
│   ├── providers/
│   │   ├── codex/CLAUDE.md     # Codex-specific
│   │   ├── gemini/CLAUDE.md    # Gemini-specific
│   │   ├── claude/CLAUDE.md    # Claude orchestrator
│   │   ├── ollama/CLAUDE.md    # Ollama local LLM
│   │   └── copilot/CLAUDE.md   # GitHub Copilot CLI
│   └── workflows/CLAUDE.md      # Double Diamond methodology
```

### Loading Modules

```bash
claude --add-dir=config/providers/codex    # Codex context
claude --add-dir=config/providers/gemini   # Gemini context
claude --add-dir=config/workflows          # Double Diamond
```

| Module | When to Load |
|--------|--------------|
| `providers/codex` | Working with Codex CLI integration |
| `providers/gemini` | Working with Gemini CLI integration |
| `providers/claude` | Understanding Claude's orchestrator role |
| `providers/ollama` | Working with Ollama local LLM |
| `providers/copilot` | Working with GitHub Copilot CLI |
| `workflows` | Learning about Double Diamond methodology |

---

## E2E Testing Infrastructure

Automated smoke testing on Oracle Cloud VPS (`ssh amy`), checking every 2 hours.

- **Phase A (Docker):** Install → structure verify → unit tests → uninstall
- **Phase B (Native):** Live command tests with authed Claude Code, Codex, Gemini

### Maintenance

```bash
scp docs/e2e/*.sh amy:/home/openclaw/.octopus-e2e/       # Deploy
ssh amy 'rm -f ~/.octopus-e2e/last-tested-version && ~/.octopus-e2e/e2e-runner.sh'  # Force re-run
ssh amy 'cat ~/.octopus-e2e/last-tested-version && tail -20 ~/.octopus-e2e/logs/cron.log'  # Status
```

### Dynamic Fleet Dispatch

`scripts/helpers/build-fleet.sh` is the single source of truth for provider-to-perspective assignment. Enforces model family diversity (OpenAI, Google, Microsoft, Alibaba, Anthropic). Never hardcode provider names in skills.
