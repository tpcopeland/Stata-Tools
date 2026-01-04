# Audit Recommendation: _templates/testing_TEMPLATE.do

## Audit Summary
Functional testing template.

## Findings

### 1. `set seed` `[Medium]`
- **Location:** Missing.
- **Recommendation:** Always set a seed when generating random data for tests (`rnormal` is used in Test 10).
- **Fix:** Add `set seed 12345` at top.

## Recommendations

1.  **Use `assert` more aggressively.**
2.  **Clean up `global` usage.** Be careful with global scope pollution.
