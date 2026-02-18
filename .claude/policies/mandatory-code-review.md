# Mandatory Code Review Policy

**Status:** ENFORCED
**Reference:** Quality gates in skills

---

## Rule

All generated or modified .ado code MUST be reviewed before commit.

## Workflow

1. Generate/modify code using `/develop`
2. Run `/review` skill to review the code
3. Address all HIGH severity issues
4. Only then proceed to commit

## What Code Review Checks

| Category | Checks |
|----------|--------|
| Syntax | Version statement, varabbrev off, marksample |
| Safety | Macro name length (<32 chars), tempvar usage |
| Style | Header format, documentation, error messages |
| Logic | Error handling, edge cases, return values |

## Required for

- New .ado files
- Bug fixes in existing .ado files
- Feature additions to .ado files
- Any modification that changes program logic

## NOT Required for

- .sthlp documentation updates only
- .pkg metadata updates only
- README.md updates only
- Test file modifications

## Enforcement

The Stop hook prompt will check if .ado files were modified without code review during the session.

## Bypass

In emergencies, document the reason in the commit message and review in follow-up.
