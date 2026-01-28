# Mandatory Code Review Policy

**Status:** ENFORCED
**Reference:** Quality gates in skills

---

## Rule

All generated or modified .ado code MUST be reviewed before commit.

## Workflow

1. Generate/modify code using `/stata-develop` or `/stata-code-generator`
2. Run `/code-reviewer` skill to review the code
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

The stop-hook-validation.sh script will remind you if .ado files were modified but the code-reviewer skill was not invoked during the session.

## Bypass

In emergencies, you may skip code review by documenting the reason:

```bash
git commit -m "Emergency fix: [description]

Skipped code review due to: [reason]
Will review in follow-up commit.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Rationale

Code review catches:
- 31-character macro name truncation bugs
- Missing error handling
- Batch mode incompatible commands (cls, pause, browse)
- Undocumented options
- Version synchronization issues

These bugs are difficult to detect in testing but easy to catch in review.
