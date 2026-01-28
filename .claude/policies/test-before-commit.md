# Test Before Commit Policy

**Status:** ENFORCED
**Reference:** Pre-commit hook, CLAUDE.md

---

## Rule

All .ado modifications require passing tests before commit.

## Two Types of Testing Required

| Type | Purpose | Location | Required |
|------|---------|----------|----------|
| Functional | Does it run without errors? | `_devkit/_testing/test_*.do` | Yes |
| Validation | Does it produce correct results? | `_devkit/_validation/validation_*.do` | Recommended |

## Verification

### Automatic (Pre-commit Hook)

The pre-commit hook runs:
1. `validate-ado.sh` on all staged .ado files
2. `check-versions.sh` on modified packages

### Manual (Before Commit)

Run tests manually:

```bash
# Run functional tests
stata-mp -b do _devkit/_testing/test_COMMAND.do

# Check for errors
grep -E "^r\([0-9]+" _devkit/_testing/test_COMMAND.log

# Run validation tests (recommended)
stata-mp -b do _devkit/_validation/validation_COMMAND.do
```

Or use the package-tester skill:

```
/package-tester
Run tests for [package_name]
```

## Minimum Test Coverage

| Package Status | Functional Tests | Validation Tests |
|----------------|------------------|------------------|
| New package | Required | Required |
| Bug fix | Required | Recommended |
| New feature | Required | Required for new logic |
| Refactoring | Required | Run existing tests |

## Skip (Emergency Only)

```bash
git commit --no-verify -m "Emergency: [description]

Skipping tests due to: [reason]
TODO: Add tests in follow-up commit"
```

Or set environment variable:

```bash
SKIP_ADO_VALIDATION=1 git commit -m "message"
```

## What Tests Should Cover

### Functional Tests (test_*.do)

- [ ] Basic usage with valid inputs
- [ ] All documented options
- [ ] Expected error cases (capture + assert _rc)
- [ ] Edge cases (empty data, single obs)
- [ ] if/in conditions

### Validation Tests (validation_*.do)

- [ ] Known-answer tests with hand-calculated values
- [ ] Boundary conditions
- [ ] Multi-observation per person data
- [ ] Row-level validation (not just aggregates)

---

## Rationale

Testing before commit:
- Prevents broken code from entering the repository
- Catches regression bugs early
- Documents expected behavior
- Makes debugging easier (known-good baseline)

Validation testing specifically:
- Catches logic errors that functional tests miss
- Verifies mathematical correctness
- Prevents "runs but wrong" bugs
