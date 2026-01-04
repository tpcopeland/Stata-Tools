# CLAUDE.md - Stata Package Development Repository

> **Purpose:** This repository contains Stata packages (.ado files), help files, tests, and supporting materials for the [tpcopeland/Stata-Tools](https://github.com/tpcopeland/Stata-Tools) collection.

---

## Stata Executable

**Always use `stata-mp`** when running Stata commands, do-files, or tests. This is the multiprocessor version installed on this machine.

---

## Workflow Modes

Claude supports two interaction styles based on user preference:

### One-Shot Mode (Default)
Autonomous execution without interruption. Claude completes all steps and reports results.

**Triggers:** "one-shot", "just do it", "go ahead", or no explicit mode specified

**Behavior:**
1. Understand the full request
2. Execute all steps autonomously
3. Report results at the end
4. Only ask questions if truly blocked

### Multi-Part Mode
Checkpoints with clarification questions at key decision points.

**Triggers:** "multi-part", "step-by-step", "ask me along the way", "let's discuss"

**Behavior:**
1. Pause at decision points
2. Present options with trade-offs
3. Wait for user input before proceeding
4. Summarize progress at each checkpoint

---

## Skill System

Skills are specialized expertise modules that provide workflows, quality gates, and templates for development tasks. See `.claude/skills/README.md` for the full skill index.

### Automatic Skill Routing

Hooks automatically detect when skills should be invoked. When you see:

```
╔════════════════════════════════════════════════════════════╗
║ 🎯 SKILL ROUTING DETECTED                                   ║
╠════════════════════════════════════════════════════════════╣
║ Recommended skill(s) for this task:                        ║
║   → skill-name                                              ║
╚════════════════════════════════════════════════════════════╝
```

**You MUST invoke the Skill tool immediately** before doing any other work.

### Quick Reference

| Task | Skill | Trigger Phrases |
|------|-------|-----------------|
| Review code | `code-reviewer` | "review code", "check ado", "validate" |
| Generate code | `stata-code-generator` | "create command", "new ado", "generate" |
| Test package | `package-tester` | "test", "run tests", "validate package" |

---

## Repository Structure

```
stata-package-repo/
├── CLAUDE.md                    # This file - AI collaboration guidelines
├── README.md                    # Package documentation
├── stata.toc                    # Stata package index
│
├── [package_name]/              # Each package has its own folder
│   ├── [package_name].pkg      # Package definition
│   ├── [command].ado           # Command implementation
│   ├── [command].sthlp         # Help file
│   └── tests/                  # Test files
│       └── test_[command].do   # Test do-file
│
├── .claude/                     # Claude Code configuration
│   ├── settings.json           # Hook configuration
│   ├── scripts/                # Hook scripts
│   └── skills/                 # Specialized skills
│
└── _resources/                  # Shared resources
    ├── context/                # Reference documents
    │   └── stata-common-errors.md
    ├── templates/              # Templates
    └── logs/                   # Development logs
```

---

## Package Development Workflow

### 1. Creating a New Command

```
1. Create package folder if new package
2. Write .ado file following conventions
3. Write .sthlp help file
4. Write test do-file
5. Run tests with stata-mp
6. Update stata.toc and .pkg if needed
```

### 2. Testing Commands

```bash
# Run a specific test
stata-mp -b do tests/test_command.do

# Check the log for errors
cat tests/test_command.log | grep -E "^r\([0-9]+"
```

### 3. Documenting Errors

After testing, if errors were encountered:
1. Create log file from template: `_resources/templates/logs/development-log.md`
2. Save to: `_resources/logs/[package]_[date].md`
3. Document each error with BEFORE/AFTER code
4. Mark novel patterns for common errors file

---

## Stata Syntax Patterns

### Common Errors (Always Check)

| Error Pattern | Problem | Correct Pattern |
|---------------|---------|-----------------|
| `use "$path/*.dta"` | Wildcards not supported | Loop with `append` |
| `merge ..., nogen` then `_merge` | `nogen` prevents `_merge` creation | Remove `nogen` if needed |
| `cls` in do-file | Not valid in batch mode | Comment out |
| `bysort id (abs(var))` | Functions not in sort spec | Create temp variable |
| `di "-" * 60` | Invalid string repetition | `di _dup(60) "-"` |

### Batch Mode Incompatible

These commands fail in `stata-mp -b do`:
- `cls` - Clear screen
- `pause` - Interactive pause
- `browse` / `edit` - Data editor/browser
- `window manage` - GUI commands

### Safe Patterns

```stata
* Load multiple yearly files
clear
local first = 1
forvalues yr = 2005/2024 {
    capture confirm file "$source/data_`yr'.dta"
    if _rc == 0 {
        if `first' == 1 {
            use "$source/data_`yr'.dta", clear
            local first = 0
        }
        else {
            append using "$source/data_`yr'.dta"
        }
    }
}

* Function-based sorting
gen temp_abs = abs(var)
bysort id (temp_abs): keep if _n == 1
drop temp_abs

* Character repetition
di _dup(60) "-"
di _dup(60) "="
```

---

## File Naming Conventions

### Package Files
```
[command].ado       # Command implementation
[command].sthlp     # Help file
[command].pkg       # Package definition
```

### Test Files
```
test_[command].do   # Test do-file
test_[command].log  # Test log (generated)
```

### Development Logs
```
[package]_[YYYY_MM_DD].md   # Development log
```

---

## Protected Files

The following files should not be overwritten without warning:

- `stata.toc` - Package index
- `*.pkg` - Package definitions
- `README.md` - Main documentation
- `.claude/settings.json` - Hook configuration

---

## How to Help

1. **Review package code** - Check .ado files for bugs, style issues
2. **Generate new commands** - Create .ado files following conventions
3. **Write tests** - Create comprehensive test do-files
4. **Update help files** - Ensure .sthlp files are accurate
5. **Debug errors** - Fix issues found during testing
6. **Document patterns** - Update common errors reference

---

## Supplementary Context (Read On-Demand)

| Context File | When to Read |
|--------------|--------------|
| `_resources/context/stata-common-errors.md` | Before writing/reviewing code |
| `_resources/logs/` | When debugging similar issues |

---

## Learning System

Every error during development is a learning opportunity:

1. **Capture** - Log issues as they occur
2. **Accumulate** - Distill patterns across packages
3. **Prevent** - Skills reference lessons to catch issues early
4. **Preserve** - Logs remain for historical reference

See `_resources/logs/README.md` for the full learning system documentation.

---

## Task Completion Requirements

When working on multiple tasks:

1. **Continue until ALL todos are complete** - Don't stop after one task
2. **Never wait for user input mid-task** - In one-shot mode, only stop if truly blocked
3. **Mark todos complete as you go** - Update status immediately
4. **Test all changes** - Run tests before marking complete

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-04 | Initial version for Stata package development |
