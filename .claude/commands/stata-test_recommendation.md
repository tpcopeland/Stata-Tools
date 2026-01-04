# Audit Recommendation: stata-test.md

## Audit Summary
This file correctly distinguishes between functional testing ("does it run?") and validation ("is it correct?"). The structure for `test_*.do` files is sound.

## Findings

### 1. Global Macro Pollution `[Medium]`
- **Location:** Test scripts use globals like `RUN_TEST_QUIET`.
- **Issue:** While useful, globals can persist if the test crashes.
- **Recommendation:** Ensure typical cleanup involves `macro drop` or using `c(os)` environment variables passed from the runner solely. (The current implementation is acceptable but could be cleaner).

### 2. Path Handling Logic `[Low]`
- **Location:** Lines 70-83.
- **Issue:** Hardcoded fallback paths in examples (e.g., `~/Documents/GitHub/Stata-Tools`) can confuse users copying the template.
- **Recommendation:** Emphasize using `c(pwd)` relative paths or a robust project root detector.

### 3. Missing `rcof` Check `[Low]`
- **Location:** Error handling examples.
- **Issue:** Checks `_rc != 0`. Sometimes we want to verify the *specific* error code (e.g., `assert _rc == 198` for syntax error vs `_rc == 2000` for no obs).
- **Recommendation:** Encourage asserting specific error codes in negative tests.

## Recommendations

1.  **Promote `assert` over manual `if` blocks:**
    - Much of the testing boilerplate (`if _rc == 0 ... else ...`) makes tests verbose.
    - Recommend a helper program `assert_error` or similar to reduce boilerplate line count.

2.  **Add `set seed`:**
    - Functional tests often involve `sysuse auto` or random sampling. Always recommend `set seed` at the top of test files for reproducibility.

3.  **Output Log Comparison:**
    - Mention `log using` and `diff` (or `git diff`) as a way to track changes in verbose output over time.
