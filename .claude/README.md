# Claude Code Automation Infrastructure

This directory contains automation scripts, hooks, and skills for Claude Code integration with Stata-Tools development.

## Directory Structure

```
.claude/
├── README.md           # This file
├── settings.json       # Claude Code settings
├── lib/                # Shared libraries
│   ├── common.sh       # Common functions (colors, output, validation)
│   └── config.sh       # Centralized configuration
├── hooks/              # Git and Claude hooks
│   ├── validate-ado.sh # Static .ado file validation
│   └── run-stata-check.sh # Stata runtime syntax check
├── scripts/            # Automation scripts
│   ├── scaffold-command.sh    # Create new package from templates
│   ├── check-versions.sh      # Check version consistency
│   └── check-test-coverage.sh # Report test coverage
└── skills/             # Claude Code skills
    ├── stata-test.md   # Test execution skill
    └── stata-validate.md # Validation execution skill
```

## Requirements

- **Bash 4.0+** - Required for all scripts (associative arrays, better regex)
- **Git** - For repository operations
- **Stata** - For `run-stata-check.sh` and skills (optional for static analysis)

On macOS, install newer bash:
```bash
brew install bash
```

## Libraries

### common.sh

Shared functions for all scripts. **Required dependency** for all automation scripts.

**Features:**
- Color-coded output (`error`, `warn`, `pass`, `info`, `debug`)
- Path resolution (`get_repo_root`, `resolve_path`)
- Validation helpers (`require_command`, `require_file`, `require_dir`)
- Temp file management with automatic cleanup
- Semantic version utilities
- Platform detection (macOS vs Linux)

**Usage:**
```bash
source "$SCRIPT_DIR/../lib/common.sh"

info "Processing..."
error "Something failed"  # Increments ERRORS counter
pass "Check passed"
```

### config.sh

Centralized configuration with environment variable overrides.

**Variables:**
| Variable | Default | Description |
|----------|---------|-------------|
| `REPO_ROOT` | (auto) | Repository root path |
| `STATA_EXEC` | `stata-mp` | Stata executable |
| `STATA_TIMEOUT` | `60` | Command timeout (seconds) |
| `DEFAULT_AUTHOR` | `Timothy P Copeland` | Default author name |
| `DEBUG` | `0` | Debug output (1=enabled) |

**Override via environment:**
```bash
STATA_EXEC=/usr/local/stata17/stata-mp ./script.sh
```

## Hooks

### validate-ado.sh

Static analysis for `.ado` files. Runs without Stata.

**Checks performed:**
- Version line format (`*! name Version X.Y.Z  YYYY/MM/DD`)
- Program class declaration (`rclass`, `eclass`, etc.)
- Version statement (`version 16.0`/`17.0`/`18.0`)
- `set varabbrev off` setting
- `marksample` usage with `if/in`
- Macro name length (>31 chars causes silent truncation)
- Tempvar backtick usage
- `capture` with `_rc` check
- Return statement consistency
- Global macro usage
- Hardcoded paths

**Usage:**
```bash
.claude/hooks/validate-ado.sh mypackage/mypackage.ado
.claude/hooks/validate-ado.sh --help
```

**Exit codes:**
- `0` - All checks passed
- `1` - Errors found
- `2` - Warnings found (no errors)
- `3` - Configuration error

### run-stata-check.sh

Runtime syntax check using Stata. Requires Stata installation.

**Usage:**
```bash
.claude/hooks/run-stata-check.sh mypackage/mypackage.ado
STATA_EXEC=/path/to/stata DEBUG=1 .claude/hooks/run-stata-check.sh file.ado
```

**Exit codes:**
- `0` - Syntax valid
- `1` - Syntax errors found
- `2` - Stata not available or timeout
- `3` - Configuration error

## Scripts

### scaffold-command.sh

Create a new Stata package from templates.

**Usage:**
```bash
.claude/scripts/scaffold-command.sh mycommand "Brief description"
.claude/scripts/scaffold-command.sh mycommand "Brief description" "Author Name"
```

**Creates:**
- `mycommand/mycommand.ado` - Main command file
- `mycommand/mycommand.sthlp` - Help file
- `mycommand/mycommand.pkg` - Package metadata
- `mycommand/mycommand.dlg` - Dialog file
- `mycommand/stata.toc` - Table of contents
- `mycommand/README.md` - Documentation
- `_testing/test_mycommand.do` - Test file
- `_validation/validation_mycommand.do` - Validation file

### check-versions.sh

Check version consistency across package files.

**Usage:**
```bash
.claude/scripts/check-versions.sh              # Check all packages
.claude/scripts/check-versions.sh mypackage    # Check specific package
```

**Checks:**
- Version matches in `.ado`, `.sthlp`, `README.md`
- Date matches in `.ado`, `.pkg`
- Proper semantic version format (X.Y.Z)
- Valid SMCL header format in `.sthlp`

### check-test-coverage.sh

Report test and validation coverage.

**Usage:**
```bash
.claude/scripts/check-test-coverage.sh
.claude/scripts/check-test-coverage.sh --threshold 80  # Fail if <80% coverage
```

## Skills

Skills are natural language triggers for Claude Code. Located in `.claude/skills/`.

### stata-test.md

Execute functional tests for Stata packages.

**Triggers:** "run tests", "test [package]", "execute test file"

### stata-validate.md

Execute validation tests for correctness verification.

**Triggers:** "validate", "run validation", "check correctness"

## Git Integration

### Pre-commit Hook

The pre-commit hook (`.git/hooks/pre-commit`) automatically runs:
1. `validate-ado.sh` on staged `.ado` files
2. `check-versions.sh` on modified packages

**Skip validation:**
```bash
git commit --no-verify
SKIP_ADO_VALIDATION=1 git commit
SKIP_VERSION_CHECK=1 git commit
```

### Installing the Hook

The pre-commit hook is already installed. To reinstall:
```bash
cp .claude/hooks/pre-commit.example .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

## Exit Code Standards

All scripts use standardized exit codes:

| Code | Meaning |
|------|---------|
| `0` | Success / All checks passed |
| `1` | Errors found / Operation failed |
| `2` | Warnings found (no errors) |
| `3` | Configuration error / Missing requirements |

## Environment Variables

| Variable | Scripts | Description |
|----------|---------|-------------|
| `STATA_EXEC` | run-stata-check.sh | Path to Stata executable |
| `STATA_TIMEOUT` | run-stata-check.sh | Timeout in seconds |
| `DEBUG` | All | Enable debug output (1=on) |
| `SKIP_ADO_VALIDATION` | pre-commit | Skip .ado validation |
| `SKIP_VERSION_CHECK` | pre-commit | Skip version check |

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
/opt/homebrew/bin/bash .claude/scripts/script.sh
```

Or add to PATH:
```bash
export PATH="/opt/homebrew/bin:$PATH"
```

### "Stata not found"

Set the Stata path:
```bash
export STATA_EXEC=/path/to/stata-mp
```

Or skip runtime checks:
```bash
.claude/hooks/validate-ado.sh file.ado  # Static only, no Stata needed
```

## Development

### Adding a New Script

1. Create script in appropriate directory
2. Add header with version, usage, exit codes
3. Source common.sh (required)
4. Use `set -o pipefail`
5. Add `show_help()` function
6. Use standardized exit codes
7. Update this README

### Script Template

```bash
#!/bin/bash
#
# myscript.sh - Brief description
# Version: 1.0.0
#
# Usage: myscript.sh [-h|--help] ARGS
#
# Exit codes:
#   0 - Success
#   1 - Error
#   3 - Configuration error
#

set -o pipefail

# Source common library (required)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "$SCRIPT_DIR/../lib/common.sh" ]]; then
    echo "[ERROR] common.sh not found. Run from repository root." >&2
    exit 3
fi
source "$SCRIPT_DIR/../lib/common.sh"

# Help function
show_help() {
    echo "Usage: $0 [-h|--help] ARGS"
    echo ""
    echo "Description of what this script does."
}

# Check for help flag
case "${1:-}" in
    -h|--help) show_help; exit 0 ;;
esac

# Initialize counters if needed
init_counters

# Script logic here...
```

## Version History

- **1.1.0** - Added config.sh, bash version check, standardized exit codes, help flags
- **1.0.0** - Initial automation infrastructure
