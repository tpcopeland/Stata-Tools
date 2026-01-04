# Learning Functionality for Stata Package Development

> **Purpose:** This directory contains a complete AI-assisted learning and validation system for Stata package development. It's designed to help Claude Code (or other AI assistants) create, test, and validate Stata packages while accumulating knowledge from each iteration.

---

## Overview

This system provides:

1. **Hook Scripts** - Automatic context and skill routing at session start and during work
2. **Skills** - Specialized "expertise hats" for code review, testing, and generation
3. **Learning Logs** - Structured documentation of errors and fixes that persists across sessions
4. **Accumulated Knowledge** - Distilled patterns from logs that prevent repeated mistakes
5. **Synthetic Testing** - Framework for validating code before deployment

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                    LEARNING CYCLE FOR STATA PACKAGES                          │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                                │
│  ┌────────┐   ┌────────┐   ┌────────┐   ┌────────┐   ┌────────┐              │
│  │ WRITE  │──▶│ REVIEW │──▶│  TEST  │──▶│  LOG   │──▶│ LEARN  │──▶ IMPROVE   │
│  │  CODE  │   │  CODE  │   │  CODE  │   │ ERRORS │   │PATTERNS│              │
│  └────────┘   └────────┘   └────────┘   └────────┘   └────────┘              │
│      │            │            │            │            │                    │
│      ▼            ▼            ▼            ▼            ▼                    │
│   Skills      Skills       Synthetic     Log Files   Common Errors           │
│              (review)       Data         Templates   Reference               │
│                                                                                │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Quick Start

### 1. Copy to Your Repo

```bash
# Copy the entire directory to your Stata package repo
cp -r LEARNING_FUNCTIONALITY/* /path/to/your/stata-package-repo/

# Or selectively copy what you need
cp -r LEARNING_FUNCTIONALITY/.claude /path/to/your/repo/
cp LEARNING_FUNCTIONALITY/CLAUDE.md /path/to/your/repo/
```

### 2. Customize

1. Edit `CLAUDE.md` to reflect your package structure
2. Adjust hook scripts for your file patterns
3. Customize skills for your package types

### 3. Use

Claude Code will automatically:
- Detect when to use skills based on your prompts
- Suggest relevant skills when reading code files
- Validate operations before execution
- Track uncommitted changes at session end

---

## Directory Structure

```
LEARNING_FUNCTIONALITY/
├── README.md                    # This file
├── CLAUDE.md                    # Main AI instructions (COPY TO REPO ROOT)
├── RECOMMENDATIONS.md           # Commentary and additional suggestions
│
├── .claude/                     # Claude Code configuration
│   ├── settings.json           # Hook configuration
│   ├── scripts/                # Hook scripts
│   │   ├── session-context.sh         # Session start context
│   │   ├── user-prompt-skill-router.sh # Skill detection
│   │   ├── validate-operation.sh       # Pre-operation validation
│   │   ├── suggest-skill-on-read.sh    # File-based skill suggestions
│   │   ├── stop-hook-validation.sh     # End-of-session checks
│   │   └── format-markdown.sh          # Markdown cleanup
│   │
│   └── skills/                 # Specialized expertise modules
│       ├── README.md           # Skill system overview
│       ├── code-reviewer/      # Package code review
│       │   └── SKILL.md
│       ├── stata-code-generator/ # Code generation
│       │   └── SKILL.md
│       └── package-tester/     # Testing and validation
│           └── SKILL.md
│
├── _resources/                  # Supporting resources
│   ├── context/                # Reference documents
│   │   └── stata-common-errors.md  # Accumulated error patterns
│   ├── templates/              # Document templates
│   │   └── logs/
│   │       └── development-log.md  # Error logging template
│   └── logs/                   # Development logs
│       └── README.md           # Learning system documentation
│
└── examples/                    # Example configurations
    └── README.md               # Example descriptions
```

---

## How It Works

### Session Lifecycle

```
SESSION START
    │
    ▼
┌─────────────────────────────────────┐
│  session-context.sh runs            │
│  → Shows repo status, recent files  │
│  → Sets context for the session     │
└─────────────────────────────────────┘
    │
    ▼
USER PROMPT
    │
    ▼
┌─────────────────────────────────────┐
│  user-prompt-skill-router.sh        │
│  → Detects keywords in prompt       │
│  → Suggests relevant skills         │
└─────────────────────────────────────┘
    │
    ▼
CLAUDE READS FILE
    │
    ▼
┌─────────────────────────────────────┐
│  suggest-skill-on-read.sh           │
│  → Detects file type (.do, .ado)    │
│  → Suggests code-reviewer skill     │
└─────────────────────────────────────┘
    │
    ▼
CLAUDE EDITS/WRITES
    │
    ▼
┌─────────────────────────────────────┐
│  validate-operation.sh (PRE)        │
│  → Checks for protected files       │
│  → Blocks dangerous operations      │
│  format-markdown.sh (POST)          │
│  → Ensures consistent formatting    │
└─────────────────────────────────────┘
    │
    ▼
SESSION END
    │
    ▼
┌─────────────────────────────────────┐
│  stop-hook-validation.sh            │
│  → Shows uncommitted changes        │
│  → Suggests DOCX conversion         │
│  → Next session reminder            │
└─────────────────────────────────────┘
```

### Learning Cycle

```
1. DURING DEVELOPMENT
   ├── Errors occur during testing
   ├── Fixes are applied
   └── Session continues

2. AFTER COMPLETION
   ├── Create log file from template
   ├── Document each error with:
   │   ├── Symptom (exact error message)
   │   ├── Context (what was being done)
   │   ├── Before code (what failed)
   │   ├── After code (what worked)
   │   ├── Root cause (why it failed)
   │   └── Prevention (how to avoid)
   └── Mark novel patterns

3. PERIODIC DISTILLATION (every 3-5 packages)
   ├── Review recent logs
   ├── Extract repeating patterns
   └── Update stata-common-errors.md

4. SKILLS REFERENCE LESSONS
   ├── Skills load common errors at start
   ├── Code reviewer catches known patterns
   └── Mistakes are prevented
```

---

## Key Components

### 1. CLAUDE.md (Main Instructions)

This is the primary instruction file for Claude Code. It should be placed at the root of your repository and contains:

- Repository purpose and structure
- Workflow modes (one-shot vs multi-part)
- Skill routing instructions
- Custom Stata tools reference
- File naming conventions
- Protected file patterns

**Action:** Copy to your repo root and customize for your package structure.

### 2. Hook Scripts

| Script | Trigger | Purpose |
|--------|---------|---------|
| `session-context.sh` | SessionStart | Shows repo status, recent files |
| `user-prompt-skill-router.sh` | UserPromptSubmit | Detects skills from keywords |
| `validate-operation.sh` | PreToolUse (Bash/Write/Edit) | Protects key files |
| `suggest-skill-on-read.sh` | PostToolUse (Read) | Suggests skills by file type |
| `stop-hook-validation.sh` | Stop | Shows uncommitted changes |
| `format-markdown.sh` | PostToolUse (Edit/Write) | Cleans markdown files |

### 3. Skills

Skills are "expertise hats" that provide domain-specific workflows and quality gates.

| Skill | Purpose | When Used |
|-------|---------|-----------|
| `code-reviewer` | Review Stata package code for bugs, style | Editing .ado/.do files |
| `stata-code-generator` | Generate code following templates | Creating new commands |
| `package-tester` | Run tests, validate package structure | Testing packages |

### 4. Learning System

The learning system has three tiers:

| Tier | Location | Purpose | Token Cost |
|------|----------|---------|------------|
| 1 | Skills (inline) | 5-10 critical checks | ~50 lines |
| 2 | `_resources/context/` | Accumulated lessons | ~100-200 lines |
| 3 | `_resources/logs/` | Individual logs | On-demand only |

---

## Customization Guide

### Adapting for Your Package

1. **Edit skill routing patterns** in `user-prompt-skill-router.sh`:
   ```bash
   ["code-reviewer"]="review.*code|check.*ado|validate.*package|test.*syntax"
   ["package-tester"]="test.*package|run.*tests|validate|certify"
   ```

2. **Edit file type detection** in `suggest-skill-on-read.sh`:
   ```bash
   *.ado|*.do)
       SUGGESTION="code-reviewer"
       ;;
   *.sthlp)
       SUGGESTION="help-file-reviewer"
       ;;
   ```

3. **Add protected files** in `validate-operation.sh`:
   ```bash
   PROTECTED_PATTERNS=(
       "stata.toc"
       "*.pkg"
       "README.md"
   )
   ```

### Adding New Skills

1. Create directory: `.claude/skills/<skill-name>/`
2. Create `SKILL.md` with YAML frontmatter:
   ```yaml
   ---
   name: skill-name
   description: Brief description
   allowed-tools:
     - Read
     - Write
     - Bash
   ---
   ```
3. Add skill content (workflow, checklists, output format)
4. Update `.claude/skills/README.md`
5. Add routing patterns to `user-prompt-skill-router.sh`

---

## Usage Examples

### Example 1: Reviewing Package Code

```
User: "Review the tvexpose.ado file for bugs"

Claude sees skill routing suggestion:
╔════════════════════════════════════════════════════════════╗
║ 🎯 SKILL ROUTING DETECTED                                   ║
╠════════════════════════════════════════════════════════════╣
║ Recommended skill(s) for this task:                        ║
║   → code-reviewer                                           ║
╚════════════════════════════════════════════════════════════╝

Claude invokes skill, reads file, provides structured review.
```

### Example 2: Testing Package

```
User: "Run tests for the new tvtools package"

Claude:
1. Loads package-tester skill
2. Identifies test files
3. Runs tests with stata-mp
4. Documents results
5. Creates log if errors found
```

### Example 3: After Finding Errors

```
Error encountered during testing:
  "variable rxdate not found r(111)"

Claude:
1. Fixes the error (rxdate → dispdt)
2. Re-runs test
3. At session end, creates development log
4. Marks pattern as novel
5. Pattern is added to stata-common-errors.md
6. Future sessions catch this pattern proactively
```

---

## Integration with tpcopeland/Stata-Tools

This system was developed alongside the [Stata-Tools](https://github.com/tpcopeland/Stata-Tools) package collection. Key integrations:

- **Code templates** reference the custom tools
- **Common errors** document tool-specific patterns
- **Testing** validates tool installation and usage

---

## Maintenance

### Weekly
- Review recent development logs
- Check for uncommitted changes in repos

### Monthly
- Distill new patterns from logs into common errors
- Update skill checklists with new patterns
- Archive old logs if needed

### Quarterly
- Review skill effectiveness
- Update hook scripts for new file types
- Clean up obsolete patterns

---

## License

This learning infrastructure is provided as-is for use with Stata package development. Adapt freely for your needs.

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-04 | Initial extraction from Plans-and-Proposals |
