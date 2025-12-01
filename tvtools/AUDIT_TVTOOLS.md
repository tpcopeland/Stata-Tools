# Audit Report: tvtools Stata .ado Files

**Date:** 2025-12-01
**Files Audited:** tvevent.ado, tvmerge.ado, tvexpose.ado
**Auditor:** Claude Code

---

## Executive Summary

A comprehensive audit of the tvtools Stata package identified **3 issues** across the three .ado files:
- **1 Critical Bug** in tvmerge.ado (continuous variable detection)
- **1 Critical Bug** in tvexpose.ado (grace period bridging)
- **1 Minor Issue** in tvevent.ado (unnecessary code)

All issues have been fixed.

---

## Issue 1: tvmerge.ado - Continuous Variable Detection Failure

### Severity: **Critical**

### Location
`tvmerge.ado` lines 594-615

### Description
The continuous variable detection logic failed when `prefix()` or `generate()` options were used. The code compared **renamed** variable names against **original** continuous names, which would never match after renaming.

### Root Cause
When iterating over `exp_k_list` (which contains renamed variable names like `prefix_dose`), the code compared these against `continuous_names` (which contains original names like `dose`). This comparison would always fail when prefix/generate options were applied.

### Before (Buggy Code)
```stata
* Pre-compute which exposures are continuous (optimization to avoid repeated checks)
foreach exp_var in `exp_k_list' {
    local is_cont_`exp_var' = 0
    foreach cont_name in `continuous_names' {
        if "`exp_var'" == "`cont_name'" {  // BUG: compares "prefix_dose" to "dose"
            local is_cont_`exp_var' = 1
        }
    }
}
```

### After (Fixed Code)
```stata
* Pre-compute which exposures are continuous (optimization to avoid repeated checks)
* FIX: Must handle renamed variables - compare original names to continuous_names,
* then apply result to the renamed variable names in exp_k_list
foreach exp_var in `exp_k_list' {
    local is_cont_`exp_var' = 0
}
* Set continuous flag for the primary exposure of this dataset
* is_cont_k was computed earlier using original name (exp_k_raw) vs continuous_names
* exp_k is the renamed version of exp_k_raw
local is_cont_`exp_k' = `is_cont_k'
```

### Impact Before Fix
- Continuous exposures would NOT be interpolated when using `prefix()` or `generate()` options
- Pro-rata adjustment of continuous values would be skipped silently
- Results would be incorrect for time-varying analyses using continuous exposures with renamed variables

### Simulation Example

**Scenario:** Two datasets with continuous exposure, using prefix option

```stata
* Dataset 1: exposure periods for drug dose
clear
input id start1 stop1 dose
1 0 100 50
2 0 150 75
end
save ds1, replace

* Dataset 2: exposure periods for another variable
clear
input id start2 stop2 visits
1 50 120 10
2 0 100 8
end
save ds2, replace

* Merge with continuous() and prefix() options
tvmerge ds1 ds2, id(id) start(start1 start2) stop(stop1 stop2) ///
    exposure(dose visits) continuous(dose) prefix(tv_)
```

**Before Fix:** The `tv_dose` variable would NOT be interpolated because `is_cont_tv_dose` would be 0 (comparing "tv_dose" to "dose" fails).

**After Fix:** The `tv_dose` variable IS correctly interpolated because `is_cont_k` was computed using original name "dose" and is now properly assigned to the renamed variable.

---

## Issue 2: tvexpose.ado - Grace Period Bridging Across Different Exposure Types

### Severity: **Critical**

### Location
`tvexpose.ado` lines 1349-1355

### Description
The grace period bridging logic was intended to only bridge gaps within the **same exposure type** (as stated in the code comment), but the actual implementation bridged gaps between **any** consecutive periods regardless of exposure type. This could incorrectly extend exposure labels across different exposure categories.

### Root Cause
The comment explicitly stated "CRITICAL: Only apply grace within same exposure type to avoid incorrectly extending exposure labels" but the code condition was missing the `exp_value == exp_value[_n+1]` check.

### Before (Buggy Code)
```stata
* NEW: Bridge small gaps within grace by extending previous period's stop
* This ensures gaps <= grace are treated as the same episode (no uncovered days).
* CRITICAL: Only apply grace within same exposure type to avoid incorrectly extending exposure labels
quietly by id : replace exp_stop = exp_start[_n+1] - 1 if _n < _N & id == id[_n+1] & ///
    __gap_days <= __grace_days & !missing(__gap_days) & !missing(exp_start[_n+1]) & ///
    exp_stop < exp_start[_n+1] - 1
    * BUG: Missing exp_value == exp_value[_n+1] condition!
```

### After (Fixed Code)
```stata
* NEW: Bridge small gaps within grace by extending previous period's stop
* This ensures gaps <= grace are treated as the same episode (no uncovered days).
* CRITICAL: Only apply grace within same exposure type to avoid incorrectly extending exposure labels
* FIX: Added exp_value == exp_value[_n+1] condition to enforce same-type bridging
quietly by id : replace exp_stop = exp_start[_n+1] - 1 if _n < _N & id == id[_n+1] & ///
    __gap_days <= __grace_days & !missing(__gap_days) & !missing(exp_start[_n+1]) & ///
    exp_stop < exp_start[_n+1] - 1 & exp_value == exp_value[_n+1]
```

### Impact Before Fix
- Grace periods would incorrectly bridge gaps between different exposure types
- Exposure A's end date could be extended into what should be unexposed time before Exposure B
- Person-time would be misclassified, leading to biased hazard ratio estimates

### Simulation Example

**Scenario:** Patient with two different drug exposures with a 1-day gap, grace(1) specified

```stata
* Master dataset
clear
input id entry exit
1 0 100
end
save master, replace

* Exposure dataset: Drug A ends day 50, Drug B starts day 52 (1-day gap)
clear
input id start stop drug
1 10 50 1   // Drug A
1 52 80 2   // Drug B (different drug)
end
save exposures, replace

* Run tvexpose with grace period
use master, clear
tvexpose using exposures, id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) entry(entry) exit(exit) grace(1)
```

**Before Fix:**
- Day 51 would be incorrectly labeled as Drug A (exp_stop extended from 50 to 51)
- This is wrong because days 51 should be unexposed (gap between different drugs)

**After Fix:**
- Day 51 correctly remains a gap (unexposed period)
- Grace bridging only occurs within same exposure type

---

## Issue 3: tvevent.ado - Unnecessary Code (Minor)

### Severity: **Minor/Cosmetic**

### Location
`tvevent.ado` line 231

### Description
The code contained `capture drop _merge` after a `joinby` command. However, `joinby` does not create a `_merge` variable (only the `merge` command does). This line was unnecessary and potentially confusing.

### Before
```stata
drop _needs_split _copy
capture drop _merge
sort `id' start stop
```

### After
```stata
drop _needs_split _copy
* Note: joinby does not create _merge (unlike merge command)
sort `id' start stop
```

### Impact
- No functional impact (the `capture` prevented any error)
- Code clarity improved by removing misleading line

---

## Testing Recommendations

After applying these fixes, the following test scenarios should be verified:

### Test 1: tvmerge with continuous() and prefix()
```stata
* Verify continuous interpolation works with renamed variables
tvmerge ds1 ds2, id(id) start(s1 s2) stop(e1 e2) ///
    exposure(exp1 exp2) continuous(exp1) prefix(tv_)
* Check that tv_exp1 values are properly interpolated
```

### Test 2: tvexpose with grace() and multiple exposure types
```stata
* Verify grace only bridges same-type exposures
tvexpose using exposures, id(id) start(start) stop(stop) ///
    exposure(drug) reference(0) entry(entry) exit(exit) grace(7)
* Check that gaps between different drug types are NOT bridged
```

### Test 3: tvevent basic functionality
```stata
* Verify event integration still works correctly
tvevent using intervals, id(id) date(event_date) ///
    generate(failure) type(single)
* Check event flags are properly assigned
```

---

## Summary of Changes

| File | Line(s) | Change Type | Description |
|------|---------|-------------|-------------|
| tvmerge.ado | 594-603 | Bug Fix | Fixed continuous variable detection for renamed variables |
| tvexpose.ado | 1352-1355 | Bug Fix | Added same-type check for grace period bridging |
| tvevent.ado | 231 | Code Cleanup | Removed unnecessary `capture drop _merge` |

---

## Version Control

These fixes should be incorporated into the next release of the tvtools package. The changes are backward compatible and do not alter the public API.
