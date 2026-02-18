# No Subagents Policy

**Status:** ENFORCED
**Reference:** CLAUDE.md, pre-block-task.sh hook

---

## Rule

**NEVER use the Task tool to spawn subagents.** All work must be done directly in the main Claude session.

## Rationale

- Subagents hallucinate and produce inconsistent results
- They waste tokens without context of the current session
- They slow down development and lose important state
- Skills provide domain expertise without subagent overhead

## Enforcement

The `pre-block-task.sh` hook blocks all Task tool calls with a JSON deny response. This cannot be bypassed.

## Alternatives

| Instead of | Use |
|------------|-----|
| Task tool for web search | `WebSearch` / `WebFetch` directly |
| Task tool for code search | `Glob` / `Grep` / `Read` directly |
| Task tool for expertise | `Skill` tool with appropriate skill |
| Task tool for parallel work | Sequential tool calls in main session |

## Skills Available

- `/develop` - Create/modify .ado commands
- `/review` - Code review and audit
- `/test` - Write functional and validation tests
- `/package` - Run tests and validate structure
