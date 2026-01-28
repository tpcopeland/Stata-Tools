# Version Consistency Policy

**Status:** ENFORCED
**Reference:** CLAUDE.md Package Updates section

---

## Rule

Version numbers must match across all package files when making any modification.

## Files That Must Stay Synchronized

| File | Version Location | Format |
|------|------------------|--------|
| `.ado` | Header line | `*! command Version X.Y.Z  YYYY/MM/DD` |
| `.sthlp` | Version comment | `{* *! version X.Y.Z  DDmonYYYY}` |
| `.pkg` | Distribution-Date | `Distribution-Date: YYYYMMDD` |
| Package `README.md` | Version section | `Version X.Y.Z, YYYY-MM-DD` |
| Root `README.md` | If command listed | Match .ado version |

## Version Format Rules

| Element | Correct | Incorrect |
|---------|---------|-----------|
| Semantic version | `1.0.0`, `2.1.3` | `1.0`, `v1.0.0` |
| .pkg file format | `v 3` (NEVER change) | `v 1.0.0` |
| .toc file format | `v 3` (NEVER change) | `v 1.0.0` |
| Distribution-Date | `20260128` | `2026-01-28` |

## When to Increment Versions

| Change Type | Increment | Example |
|-------------|-----------|---------|
| Bug fix | PATCH (Z) | 1.0.0 → 1.0.1 |
| New feature | MINOR (Y) | 1.0.1 → 1.1.0 |
| Breaking change | MAJOR (X) | 1.1.0 → 2.0.0 |
| Documentation only | No change | - |

## Checking Consistency

Run the version checker:

```bash
# Check all packages
.claude/scripts/check-versions.sh

# Check specific package
.claude/scripts/check-versions.sh mypackage
```

## Common Mistakes

1. **Forgetting .pkg Distribution-Date**
   - This is how Stata detects updates
   - MUST be updated with every change

2. **Using X.Y instead of X.Y.Z**
   - Always use three-part semantic versioning
   - Wrong: `1.0`, Right: `1.0.0`

3. **Updating .ado but not .sthlp**
   - Both must have matching versions
   - Help file version should match command version

4. **Changing `v 3` in .pkg or .toc**
   - `v 3` is the FILE FORMAT version
   - NEVER change this value

5. **Inconsistent date formats**
   - .ado: `YYYY/MM/DD`
   - .sthlp: `DDmonYYYY` (e.g., `28jan2026`)
   - .pkg: `YYYYMMDD`
   - README: `YYYY-MM-DD`

## Example: Updating a Package

After modifying `regtab.ado`:

```bash
# 1. Update version in regtab.ado
*! regtab Version 1.2.0  2026/01/28

# 2. Update version in regtab.sthlp
{* *! version 1.2.0  28jan2026}

# 3. Update Distribution-Date in regtab.pkg
Distribution-Date: 20260128

# 4. Update regtab/README.md
Version 1.2.0, 2026-01-28

# 5. Verify consistency
.claude/scripts/check-versions.sh tabtools/regtab
```

---

## Enforcement

The pre-commit hook runs `check-versions.sh` on modified packages and will warn (but not block) on inconsistencies.

The stop-hook-validation.sh script will remind you to check versions before ending a session with package modifications.

---

## Rationale

Version consistency:
- Ensures users get updates when running `net install`
- Makes debugging easier (know exact version)
- Maintains professional package standards
- Prevents "which version is this?" confusion
