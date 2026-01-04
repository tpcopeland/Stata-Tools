# Audit Recommendation: _templates/TEMPLATE.ado

## Audit Summary
This file is the core component. **It contains a critical logic error** regarding the `preserve`/`restore` workflow when generating new variables.

## Findings

### 1. `preserve`/`restore` Erases Output `[Critical]`
- **Location:** Lines 80-104.
- **Issue:**
    ```stata
    preserve
    quietly {
        keep if `touse'
        // ...
        gen double `generate' = . // Variable created here
        // ...
    }
    restore // Variable DELETED here because it didn't exist before preserve
    ```
    This pattern ensures the command *runs* but returns **nothing** to the user in the dataset.
- **Recommendation:**
    - **Option A (Safe):** Do not `preserve`. Use `marksample` and `if \`touse'` carefully for all operations.
    - **Option B (Merge):** Calculate results, `keep \`id' \`generate'`, save to `tempfile`, `restore`, then `merge 1:1 \`id' using ...`
    - **Option C (Restore Not):** Only works if the dataset structure changes (e.g. `collapse`), but `restore, not` discards the original data, which is usually not desired for a `generate` command.
    - **Suggested Fix:** Removing `preserve`/`restore` is usually best for "variable creation" commands. Only use `preserve` for "estimation" or "report" commands that mess up the data temporarily.

### 2. `markout` Placement `[Medium]`
- **Location:** Line 39.
- **Issue:** `markout \`touse' \`required_option'`.
- **Observation:** This is correct. Just ensuring it handles string vs numeric vars correctly (Stata's `markout` handles both if used right, but often `markout` is for numeric).

### 3. `varabbrev` Setting `[Good]`
- **Location:** Line 23.
- **Observation:** `set varabbrev off` is excellent practice.

## Recommendations

1.  **FIX THE PRESERVE BUG IMMEDIATELY.**
    - Change template to:
      ```stata
      // PRESERVE is usually NOT needed for generating new variables.
      // Only use preserve if you must destroy data structure to calculate results.
      // preserve
      // ...
      // restore
      ```
    - Or provide the `tempfile` merge pattern.

2.  **Use `double` by default:**
    - Change `gen double` to be the standard in the example (it already is, which is good).

3.  **Add `sortpreserve`:**
    - Update line 21 to: `program define TEMPLATE, rclass sortpreserve`
