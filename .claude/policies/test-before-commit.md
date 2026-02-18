# Test Before Commit Policy

**Status:** ENFORCED
**Reference:** CLAUDE.md mandatory workflow

---

## Rule

All .ado modifications require passing tests before commit.

## Two Types of Testing Required

| Type | Purpose | Location | Required |
|------|---------|----------|----------|
| Functional | Does it run without errors? | `_devkit/_testing/test_*.do` | Yes |
| Validation | Does it produce correct results? | `_devkit/_validation/validation_*.do` | Recommended |

## Verification

### Manual (Before Commit)

```bash
# Run functional tests
stata-mp -b do _devkit/_testing/test_COMMAND.do

# Check for errors
grep -E "^r\([0-9]+" _devkit/_testing/test_COMMAND.log

# Run validation tests (recommended)
stata-mp -b do _devkit/_validation/validation_COMMAND.do
```

Or use the `/package` skill to run tests and parse results.

## Minimum Test Coverage

| Package Status | Functional Tests | Validation Tests |
|----------------|------------------|------------------|
| New package | Required | Required |
| Bug fix | Required | Recommended |
| New feature | Required | Required for new logic |
| Refactoring | Required | Run existing tests |
