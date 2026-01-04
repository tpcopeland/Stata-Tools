# Development Learning System

This directory contains development logs from each package, organized for learning and pattern accumulation. Logs persist permanently and are periodically distilled into accumulated lessons files.

## Purpose

Every error or iteration during development is a learning opportunity. This system:

1. **Captures** issues as they occur (individual logs)
2. **Accumulates** patterns across packages (common errors file)
3. **Prevents** repeating mistakes (skills reference lessons)
4. **Preserves** history without bloating context

## Directory Structure

```
_resources/
├── context/
│   └── stata-common-errors.md   # Accumulated error patterns
├── templates/
│   └── logs/
│       └── development-log.md   # Log template
└── logs/
    ├── README.md                # This file
    └── [package]_[date].md      # Individual development logs
```

## Workflow

### During Development

Note issues informally as work proceeds. Focus on completing the task.

### After Test Completion

1. Create log using template from `_resources/templates/logs/development-log.md`
2. Save to this directory with naming: `[package]_[YYYY_MM_DD].md`
3. Document all iterations, corrections, and verification steps
4. Mark novel patterns not already in common errors file

### Periodic Distillation (every 3-5 packages)

1. Review recent logs
2. Extract novel, repeating patterns
3. Update `_resources/context/stata-common-errors.md`
4. Logs remain for historical reference

## Token Efficiency Design

### Tier 1: Critical Patterns (in skills)

- 5-10 most important checks per skill
- Things that cause fatal errors or major rework
- ~50 lines maximum

### Tier 2: Common Errors File (loaded at skill start)

- `_resources/context/stata-common-errors.md`
- Tables and checklists, easily scannable
- ~100-200 lines

### Tier 3: Individual Logs (on-demand)

- This directory
- Only read when debugging specific issues
- Never auto-loaded into context

## Log Naming Convention

```
[package_name]_[YYYY_MM_DD].md

Examples:
- tvtools_2026_01_04.md
- table1_tc_2026_01_03.md
- regtab_2026_01_03.md
```

## What to Log

### Always Document

- **Syntax errors** with exact error message (r(XXX))
- **Variable name corrections** (wrong -> correct)
- **Batch mode issues** (commands that fail in stata-mp -b)
- **Template deviations** and why

### Include Details

- **Before code** - What caused the error
- **After code** - What fixed it
- **Root cause** - Why it failed
- **Prevention** - How to avoid in future

### Mark Novel Patterns

Flag any pattern that:
- Isn't in `stata-common-errors.md`
- Caused >30 minutes of debugging
- Could affect other packages

## Promotion Criteria

Patterns should be promoted from logs to common errors file when:

- Pattern caused >30 minutes of rework
- Pattern appeared in 3+ packages
- Pattern is easily checkable/preventable

## Maintenance

### Weekly

- Review recent development logs
- Check for uncommitted changes

### Monthly

- Distill new patterns into common errors
- Update skill checklists with new patterns
- Archive old logs if needed

### Quarterly

- Review skill effectiveness
- Update hook scripts for new patterns
- Clean up obsolete patterns

## Example Log Entry

```markdown
### Error 2: Wrong variable name for prescription date

**Symptom:**
```
variable rxdate not found r(111)
```

**Context:**
Loading prescription data from rx_YYYY.dta files

**Before:**
```stata
bysort id (rxdate): gen first_rx = rxdate if _n == 1
```

**After:**
```stata
bysort id (dispdt): gen first_rx = dispdt if _n == 1
```

**Root Cause:**
Swedish Prescribed Drug Register uses `dispdt` not `rxdate`

**Prevention:**
Always verify variable names against data dictionary

**Novel Pattern?** Yes - Added to stata-common-errors.md
```
