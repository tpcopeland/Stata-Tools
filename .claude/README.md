# Using Claude Code with Stata-Tools

This guide explains how to use Claude Code effectively with the Stata-Tools repository.

## Quick Start

When working with Claude Code in this repository:

1. **Claude reads `CLAUDE.md`** automatically - it contains coding standards and critical rules
2. **Hooks fire automatically** - Session context, skill suggestions, and validation happen via hooks
3. **Use slash commands** for specialized guidance (all skills can be invoked with `/skill-name`):
   - `/stata-develop` - Creating or modifying Stata commands
   - `/stata-test` - Writing functional tests
   - `/stata-validate` - Writing validation tests
   - `/stata-audit` - Auditing .ado files for errors
   - `/code-reviewer` - Code review with bug detection
   - `/package-tester` - Running tests and validating packages
4. **Ask Claude to run validators** after writing code:
   - `.claude/validators/validate-ado.sh mycommand.ado`

## How It Works

### CLAUDE.md (Repository Instructions)

The `CLAUDE.md` file in the repository root is automatically loaded by Claude Code. It contains:

- Critical Stata coding rules (version statements, varabbrev, marksample, etc.)
- Package structure requirements
- Code templates and syntax patterns
- Common pitfalls to avoid

**You don't need to do anything** - Claude reads this automatically.

### Skills (Slash Commands)

Skills provide task-specific guidance and expertise. All skills can be invoked with `/skill-name`:

| Skill | When to Use |
|-------|-------------|
| `/stata-develop` | Creating a new .ado command or fixing bugs |
| `/stata-test` | Writing `test_*.do` functional test files |
| `/stata-validate` | Writing `validation_*.do` correctness tests |
| `/stata-audit` | Reviewing code for common errors |
| `/code-reviewer` | Detailed code review with scoring |
| `/stata-code-generator` | Generating code from requirements |
| `/package-tester` | Running tests and parsing results |

**Example workflow:**
```
You: /stata-develop
Claude: [Loads development guidance]
You: Create a new command called "mystat" that calculates summary statistics
Claude: [Uses the loaded guidance to create properly structured files]
```

### Automation Scripts

Ask Claude to run these scripts:

| Task | Command |
|------|---------|
| Create new package | `.claude/scripts/scaffold-command.sh mycommand "Description"` |
| Check version consistency | `.claude/scripts/check-versions.sh mypackage` |
| Check test coverage | `.claude/scripts/check-test-coverage.sh` |
| Validate .ado syntax | `.claude/validators/validate-ado.sh mypackage/mypackage.ado` |
| Check with Stata runtime | `.claude/validators/run-stata-check.sh mypackage/mypackage.ado` |

## Directory Structure

```
.claude/
├── README.md              # This file
├── settings.json          # Hook configuration
├── skills/                # All skills (invoke with /skill-name)
│   ├── README.md             # Skills documentation
│   ├── stata-develop/        # Command development guidance
│   ├── stata-test/           # Functional testing guidance
│   ├── stata-validate/       # Validation testing (with lazy sections)
│   ├── stata-audit/          # Code audit guidance
│   ├── code-reviewer/        # Code review expertise
│   ├── stata-code-generator/ # Code generation (with lazy sections)
│   └── package-tester/       # Testing expertise (with lazy sections)
├── policies/              # Quality enforcement policies
│   ├── mandatory-code-review.md  # Code review requirements
│   ├── test-before-commit.md     # Testing requirements
│   └── version-consistency.md    # Version sync requirements
├── validators/            # Validation scripts
│   ├── validate-ado.sh       # Static analysis (no Stata required)
│   └── run-stata-check.sh    # Syntax check (requires Stata)
├── scripts/               # Automation and hook scripts
│   ├── scaffold-command.sh       # Create new package from templates
│   ├── check-versions.sh         # Check version consistency
│   ├── check-test-coverage.sh    # Report test coverage
│   ├── pre-tool-dispatcher.sh    # PreToolUse dispatcher
│   ├── post-tool-dispatcher.sh   # PostToolUse dispatcher
│   ├── session-context.sh        # SessionStart hook
│   ├── user-prompt-skill-router.sh  # UserPromptSubmit hook
│   ├── validate-operation.sh     # Validation logic
│   ├── suggest-skill-on-read.sh  # Skill suggestion logic
│   ├── format-markdown.sh        # Markdown formatting logic
│   └── stop-hook-validation.sh   # Stop hook
├── lib/                   # Shared libraries for scripts
│   ├── common.sh             # Common functions
│   └── config.sh             # Configuration
└── tests/                 # Integration tests for automation
    └── run-tests.sh

_resources/                # Learning system resources
├── context/
│   └── stata-common-errors.md   # Accumulated error patterns
├── templates/
│   └── logs/
│       └── development-log.md   # Log template
└── logs/
    └── README.md                # Learning system documentation
```

## Common Workflows

### Creating a New Stata Command

1. Tell Claude: "Create a new command called X that does Y"
2. Or use: `/stata-develop` then describe what you need
3. Claude will:
   - Run `scaffold-command.sh` to create the package structure
   - Customize the .ado, .sthlp, .pkg, and other files
   - Run `validate-ado.sh` to check for errors
   - Run `check-versions.sh` to verify consistency

### Writing Tests

1. Use `/stata-test` for functional tests (does it run?)
2. Use `/stata-validate` for validation tests (is output correct?)
3. Claude will create properly structured test files

### Fixing Bugs

1. Use `/stata-audit` to review the code systematically
2. Claude will check for common Stata error patterns
3. After fixes, Claude runs validators to verify

### Before Committing

The pre-commit hook automatically runs:
- `validate-ado.sh` on staged .ado files
- `check-versions.sh` on modified packages

Skip with: `git commit --no-verify`

## Validators Reference

### validate-ado.sh

Static analysis that runs **without Stata**. Checks for:

- Version line format (`*! name Version X.Y.Z  YYYY/MM/DD`)
- Program class declaration (rclass, eclass, etc.)
- `version 16.0`/`17.0`/`18.0` statement
- `set varabbrev off` setting
- `marksample` usage with if/in
- Macro name length (>31 chars = silent truncation bug)
- Tempvar backtick usage
- `capture` with `_rc` check
- Return statement consistency

**Usage:**
```bash
.claude/validators/validate-ado.sh mypackage/mypackage.ado
```

### run-stata-check.sh

Runtime syntax check that **requires Stata**.

**Usage:**
```bash
.claude/validators/run-stata-check.sh mypackage/mypackage.ado
```

**Environment variables:**
- `STATA_EXEC` - Path to Stata (default: `stata-mp`)
- `STATA_TIMEOUT` - Timeout in seconds (default: 60)

## Scripts Reference

### scaffold-command.sh

Creates a complete package structure from templates.

```bash
.claude/scripts/scaffold-command.sh mycommand "Brief description"
.claude/scripts/scaffold-command.sh mycommand "Brief description" "Author Name"
```

**Creates:**
- `mycommand/mycommand.ado`
- `mycommand/mycommand.sthlp`
- `mycommand/mycommand.pkg`
- `mycommand/mycommand.dlg`
- `mycommand/stata.toc`
- `mycommand/README.md`
- `_devkit/_testing/test_mycommand.do`
- `_devkit/_validation/validation_mycommand.do`

### check-versions.sh

Verifies version consistency across package files.

```bash
.claude/scripts/check-versions.sh              # Check all packages
.claude/scripts/check-versions.sh mypackage    # Check specific package
```

### check-test-coverage.sh

Reports test and validation coverage.

```bash
.claude/scripts/check-test-coverage.sh
.claude/scripts/check-test-coverage.sh --threshold 80  # Fail if <80% coverage
```

## Exit Codes

All scripts use standardized exit codes:

| Code | Meaning |
|------|---------|
| 0 | Success / All checks passed |
| 1 | Errors found / Operation failed |
| 2 | Warnings found (no errors) |
| 3 | Configuration error / Missing requirements |

## Environment Variables

| Variable | Used By | Description |
|----------|---------|-------------|
| `STATA_EXEC` | run-stata-check.sh | Path to Stata executable |
| `STATA_TIMEOUT` | run-stata-check.sh | Timeout in seconds |
| `DEBUG` | All scripts | Enable debug output (1=on) |
| `SKIP_ADO_VALIDATION` | pre-commit | Skip .ado validation |
| `SKIP_VERSION_CHECK` | pre-commit | Skip version check |

## Hooks System

Hooks are scripts that run automatically at specific points in the Claude Code session lifecycle. They are configured in `.claude/settings.json`.

### Hook Architecture (Dispatcher Pattern)

All hooks use a unified dispatcher pattern for cleaner configuration and centralized logic:

| Hook | Dispatcher | Purpose |
|------|------------|---------|
| SessionStart | `session-context.sh` | Shows repo status, recent files |
| UserPromptSubmit | `user-prompt-skill-router.sh` | Suggests relevant skills |
| PreToolUse | `pre-tool-dispatcher.sh` | Routes to validation scripts |
| PostToolUse | `post-tool-dispatcher.sh` | Routes to post-processing scripts |
| Stop | `stop-hook-validation.sh` | Shows uncommitted changes |

### What Happens Automatically

1. **Session Start**: Shows git status, recent .ado files, failed tests
2. **On Prompt**: Detects if task matches a skill and suggests using it
3. **On File Read**: Suggests relevant skills based on file extension
4. **On File Write**: Auto-validates .ado files, warns about protected files
5. **On Stata Run**: Reminds to check logs for errors
6. **Session End**: Lists uncommitted changes, reminds about dev logs

## Policies

Quality enforcement policies are documented in `.claude/policies/`:

| Policy | Purpose |
|--------|---------|
| `mandatory-code-review.md` | Requires `/code-reviewer` after code generation |
| `test-before-commit.md` | Requires tests to pass before committing |
| `version-consistency.md` | Ensures version synchronization across files |

These policies are enforced through hooks and skill workflows.

## Skills System

Skills are "expertise hats" that provide domain-specific workflows, quality gates, and output formats. All skills can be invoked with `/skill-name`.

### Available Skills

| Skill | Purpose | Suggested When |
|-------|---------|----------------|
| `stata-develop` | Command development guidance | Creating/modifying .ado files |
| `stata-test` | Functional testing workflow | Writing test_*.do files |
| `stata-validate` | Validation testing workflow | Writing validation_*.do files |
| `stata-audit` | Code audit and review | Reviewing .ado files |
| `code-reviewer` | Review code for bugs and style | Reading .ado/.do files |
| `stata-code-generator` | Generate new commands | Creating new .ado files |
| `package-tester` | Run tests and validate packages | Testing packages |

See `.claude/skills/README.md` for full documentation.

## Learning System

The learning system captures errors during development and accumulates patterns to prevent future mistakes.

### Three-Tier Knowledge System

| Tier | Location | Purpose | When Loaded |
|------|----------|---------|-------------|
| 1 | Skills (inline) | Critical checks | With skill |
| 2 | `_resources/context/stata-common-errors.md` | Accumulated patterns | On request |
| 3 | `_resources/logs/*.md` | Individual logs | On-demand |

### Workflow

1. **During Development**: Errors occur, fixes applied
2. **After Testing**: Create development log from template
3. **Periodic Review**: Distill novel patterns into common errors
4. **Future Sessions**: Skills reference accumulated knowledge

### Creating Development Logs

```bash
# Template location
_resources/templates/logs/development-log.md

# Save logs as
_resources/logs/[package]_[YYYY_MM_DD].md
```

See `_resources/logs/README.md` for full documentation.

## Troubleshooting

### "common.sh not found"

Run scripts from repository root:
```bash
cd /path/to/Stata-Tools
.claude/scripts/check-versions.sh
```

### "Bash 4.0 or higher required"

On macOS:
```bash
brew install bash
export PATH="/opt/homebrew/bin:$PATH"
```

### "Stata not found"

Set the Stata path:
```bash
export STATA_EXEC=/path/to/stata-mp
```

Or use static analysis only (no Stata needed):
```bash
.claude/validators/validate-ado.sh file.ado
```

## Requirements

- **Bash 4.0+** - Required for all scripts
- **Git** - For repository operations
- **Stata** - Only for `run-stata-check.sh` (optional for static analysis)

On macOS, install newer bash: `brew install bash`

## Version History

- **3.1.0** - Added dispatcher pattern for hooks, policies directory, lazy loading for skills
- **3.0.0** - Merged commands and skills into unified skills system
- **2.0.0** - Added hooks system, skills, and learning system (_resources/)
- **1.2.0** - Reorganized as Claude Code usage guide, renamed skills to commands, hooks to validators
- **1.1.0** - Added config.sh, bash version check, standardized exit codes
- **1.0.0** - Initial automation infrastructure
