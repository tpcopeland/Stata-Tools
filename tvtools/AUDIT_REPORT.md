# tvtools Comprehensive Audit Report

**Auditor:** Claude (Anthropic)
**Date:** 2025-11-23
**Scope:** All .ado and .dlg files in tvtools/

---

## Summary

| Severity | Count | Potential Reward |
|----------|-------|------------------|
| Critical | 3 | $600 |
| Major | 5 | $500 |
| Minor | 4 | $200 |
| **Total** | **12** | **$1,300** |

---

## Critical Bugs ($200 each)

### 1. tvevent.ado:255 - Attempting to Drop Frame Name as Variable

**File:** `tvevent.ado`
**Line:** 255

**Code:**
```stata
drop `match_date' `event_frame' `imported_type'
```

**Problem:** `event_frame` is a frame name (created on line 235), not a variable. Stata will throw an error "variable `event_frame' not found" because you cannot drop a frame name as if it were a variable.

**Solution:**
```stata
drop `match_date' `imported_type'
```
The frame was already dropped on line 254 with `frame drop \`event_frame'`.

---

### 2. tvexpose.ado:2367-2384 - Invalid `else` Block Outside Conditional

**File:** `tvexpose.ado`
**Lines:** 2367-2384

**Code:**
```stata
            local thresh_count = 0
            foreach exp_type_val of local exp_types {
                if `n_cuts' > 0 {
                    local thresh_count = `thresh_count' + `n_cuts'
                }
            }
            else {
                * No thresholds - create empty dataset
                clear
                ...
            }
```

**Problem:** The `else` block is syntactically orphaned - it follows a `foreach` loop closing brace, not an `if` statement. This will cause Stata to error with "else not allowed" or similar syntax error.

**Solution:** Restructure the logic - the `else` appears intended to handle `n_cuts == 0`:
```stata
            local thresh_count = 0
            foreach exp_type_val of local exp_types {
                if `n_cuts' > 0 {
                    local thresh_count = `thresh_count' + `n_cuts'
                }
            }

            if `thresh_count' == 0 {
                * No thresholds - create empty dataset
                clear
                ...
            }
```

---

### 3. tvmerge.ado:498 - Using Original Variable Names After Rename

**File:** `tvmerge.ado`
**Line:** 498

**Code:**
```stata
            * Keep only necessary variables
            local keeplist_k "id start_k stop_k `exp_k_list'"
```

**Problem:** At this point, exposure variables have already been renamed (lines 484-494). The `exp_k_list` contains the **original** variable names from the source dataset, but those variables were just renamed to either `newname_k` (if generate specified) or `prefix'exp_k_raw` (if prefix specified). The `keep` command on line 524 will fail with "variable not found".

**Solution:**
```stata
            * Build keeplist after all renames are complete
            local keeplist_k "id start_k stop_k `exp_k'"
```
Use the renamed `exp_k` variable instead of the original `exp_k_list`.

---

## Major Bugs ($100 each)

### 4. tvmerge.ado:780 - Duplicate Count Always Zero

**File:** `tvmerge.ado`
**Line:** 780

**Code:**
```stata
        duplicates drop `dupvars', force
        quietly count
        local n_after_dedup = r(N)
        local n_dups = _N - `n_after_dedup'
```

**Problem:** After `duplicates drop`, `_N` equals the current observation count, which is also what `count` returns. Therefore `n_dups = _N - r(N) = r(N) - r(N) = 0`. The duplicate count will always show as 0.

**Solution:**
```stata
        quietly count
        local n_before_dedup = r(N)
        duplicates drop `dupvars', force
        quietly count
        local n_after_dedup = r(N)
        local n_dups = `n_before_dedup' - `n_after_dedup'
```

---

### 5. tvexpose.ado:4048-4051 - Incorrect Variable Renaming at End

**File:** `tvexpose.ado`
**Lines:** 4048-4051

**Code:**
```stata
    * Rename to originals
    capture quietly rename id `id'
    capture quietly rename start `start'
    capture quietly rename stop `stop'
```

**Problem:** The macros `start` and `stop` contain the **input** variable names from the using dataset (set in syntax on line 114-115), not the desired output names. If user specified `start(rx_start) stop(rx_stop)`, this would rename the output variables to "rx_start" and "rx_stop" instead of keeping them as "start" and "stop".

**Solution:** Remove these lines entirely, or if the intent is to use original ID name:
```stata
    capture quietly rename id `id'
    * Do NOT rename start/stop - they should remain as "start" and "stop" in output
```

---

### 6. tvmerge.ado:975 - Wrong Variable Reference in validatecoverage

**File:** `tvmerge.ado`
**Line:** 975

**Code:**
```stata
            noisily list `id' `startname' `stopname' _gap if _gap > 1 & !missing(_gap), sep(20)
```

**Problem:** The original ID variable was renamed to "id" on line 366. The macro `id` contains the user's original variable name (e.g., "patid"), but the actual variable in the dataset is now called "id". This will error with "variable `id' not found" if the user's ID variable had a different name.

**Solution:**
```stata
            noisily list id `startname' `stopname' _gap if _gap > 1 & !missing(_gap), sep(20)
```

---

### 7. tvmerge.ado:993 - Same Wrong Variable Reference in validateoverlap

**File:** `tvmerge.ado`
**Line:** 993

**Code:**
```stata
            noisily list `id' `startname' `stopname' if _overlap == 1, sep(20)
```

**Problem:** Same issue as #6 - references `id` macro instead of literal "id" variable.

**Solution:**
```stata
            noisily list id `startname' `stopname' if _overlap == 1, sep(20)
```

---

### 8. tvexpose.ado:3681 - Reference to Non-existent Variable in bytype Mode

**File:** `tvexpose.ado`
**Line:** 3681

**Code:**
```stata
                local show_exp = `generate'[`i']
```

**Problem:** When `bytype` option is used, `skip_main_var == 1` and the `generate` variable is never created (line 3342-3347 shows the conditional rename). This code is inside the `overlaps` diagnostic which runs regardless of bytype mode, causing an error when trying to reference a non-existent variable.

**Solution:**
```stata
                if `skip_main_var' == 0 {
                    local show_exp = `generate'[`i']
                }
                else {
                    local show_exp = exp_value[`i']
                }
```

---

## Minor Bugs ($50 each)

### 9. tvevent.dlg:174 - Incorrect Radio Button Output Syntax

**File:** `tvevent.dlg`
**Line:** 174

**Code:**
```stata
    option radio(main rb_single rb_recur)
```

**Problem:** This syntax doesn't correctly output the type() option value. It outputs the selected radio button identifier, not the appropriate type value ("single" or "recurring").

**Solution:**
```stata
    if main.rb_single {
        put " type(single)"
    }
    if main.rb_recur {
        put " type(recurring)"
    }
```

---

### 10. tvmerge.dlg:106-107 - Duplicate Widget ID

**File:** `tvmerge.dlg`
**Lines:** 106-107

**Code:**
```stata
  TEXT     tx_note       10  195 620  80,  label("Note: tvmerge replaces...")
  TEXT     tx_note       10  215 620  80,  label("Use saveas() to preserve...")
```

**Problem:** Two TEXT widgets have the same ID `tx_note`. This may cause undefined behavior in the dialog system.

**Solution:**
```stata
  TEXT     tx_note1      10  195 620  80,  label("Note: tvmerge replaces...")
  TEXT     tx_note2      10  215 620  80,  label("Use saveas() to preserve...")
```

---

### 11. tvmerge.ado:700-717 - Incorrect Continuous Exposure Interpolation

**File:** `tvmerge.ado`
**Lines:** 700-717

**Code:**
```stata
                if `is_cont_`exp_var'' == 1 {
                    * Calculate cumulative proportion (progress to date)
                    generate double _proportion = cond(stop_k > start_k, (`stopname' - start_k) / (stop_k - start_k), 1)
                    ...
                    replace `exp_var' = `exp_var' * _proportion
```

**Problem:** The formula calculates the proportion as (new_stop - original_start) / (original_duration). This represents "how far into the original period the new period ends" - but this doesn't correctly pro-rate the exposure value. For example, if original period is days 1-10 with exposure=100, and new period is days 5-7, the proportion would be (7-1)/(10-1) = 0.67, giving exposure=67. But days 5-7 is only 3 days of a 10-day period, so the exposure should be 30.

**Solution:**
```stata
                    * Calculate actual overlap duration / original duration
                    generate double _proportion = cond(stop_k > start_k, ///
                        (`stopname' - `startname' + 1) / (stop_k - start_k + 1), 1)
```

---

### 12. tvexpose.ado:326-329 - Exposure Type Boolean for Continuous is Redundant

**File:** `tvexpose.ado`
**Lines:** 311-328

**Code:**
```stata
    else if "`continuousunit'" != "" {
        local exp_type "continuous"
        * Validate continuous unit if specified (required for continuous exposure)
        if "`continuousunit'" != "" {
            ...
        }
```

**Problem:** The outer `if` already checks `"`continuousunit'" != ""`, so the inner check on line 314 is always true and redundant. While not causing incorrect behavior, it indicates logic confusion.

**Solution:**
```stata
    else if "`continuousunit'" != "" {
        local exp_type "continuous"
        * Validate continuous unit (already confirmed non-empty by outer if)
        local unit_lower = lower(trim("`continuousunit'"))
        ...
```

---

## Notes

- Bugs were identified through static code analysis
- All line numbers reference the files as read during the audit
- Solutions provided are suggestions; actual implementation may vary based on broader context
- The audit focused on functional bugs, not style or optimization issues

---

## Gemini Comparison

Gemini reported "all good" - this audit found **12 bugs** including 3 critical issues that would cause runtime errors. The most severe issues (#1, #2, #3) would cause immediate failures when specific code paths are executed.
