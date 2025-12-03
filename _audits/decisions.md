# Pending Decisions from Audit Reports

**Date:** 2025-12-03

This document lists all issues identified in the audit reports that were **NOT** implemented and require your decision.

---

## Critical/High Priority Decisions

### 1. datefix: rclass Declaration Without Returns
**Package:** datefix
**Severity:** Critical (audit report) → **DESIGN DECISION**
**Current State:** Program declared as `rclass` but has no return statements

**Options:**
- **A) Remove rclass declaration** - Program becomes a simple utility with no returns
- **B) Add meaningful returns** - Add return values like:
  ```stata
  return scalar n_converted = <count>
  return local detected_format "`format'"
  return scalar miss_before = <count>
  return scalar miss_after = <count>
  ```

**Recommendation:** Option B would make the command more useful for scripting.

---

### 2. datefix: Add if/in Support
**Package:** datefix
**Severity:** Medium (design decision)
**Current State:** Command operates on all observations, no subset support

**Options:**
- **A) Leave as-is** - Users must subset data beforehand
- **B) Add if/in support** - Would require adding `marksample touse` and using `if \`touse'` throughout

**Recommendation:** Consider adding for better user experience, but not critical.

---

## Optional Enhancements (Lower Priority)

### 3. tvtools: Explicit Observation Checks After Merges
**Package:** tvtools (tvmerge.ado, tvevent.ado)
**Severity:** Low (optional)
**Current State:** Merges work correctly but lack explicit "no observations after merge" error messages

**Decision:** Add explicit checks after critical merges for clearer error messages?

**Example fix for tvmerge.ado:**
```stata
merge m:1 id using `master_dates', nogen keep(3)
quietly count
if r(N) == 0 {
    noisily di as error "No observations after merge - check id variables match"
    exit 2000
}
```

---

### 4. datamap/datadict: Add varabbrev off to Helper Programs
**Package:** datamap
**Severity:** Medium (defensive programming)
**Current State:** Helper programs inherit `varabbrev` setting from main program but don't set it explicitly

**Decision:** Add `set varabbrev off` to 20+ helper programs that work with variables?

**Pro:** Defensive programming, ensures consistent behavior
**Con:** Adds code to many functions, current behavior is correct

---

### 5. table1_tc: Range Validation for pdp/highpdp
**Package:** table1_tc
**Severity:** Medium (input validation)
**Current State:** Accepts any integer for decimal places options

**Decision:** Add validation to restrict values to 0-10 range?

**Proposed fix:**
```stata
if `pdp' < 0 | `pdp' > 10 {
    display as error "pdp() must be between 0 and 10"
    error 198
}
```

---

### 6. check: Clickable Error Messages
**Package:** check
**Severity:** Low (UX enhancement)
**Current State:** Error messages for missing dependencies are plain text

**Decision:** Make installation instructions clickable?

**Proposed fix:**
```stata
display as error "check requires the mdesc command"
display as text "Install with: {stata ssc install mdesc:ssc install mdesc}"
```

---

### 7. check: Document All-Missing Variable Behavior
**Package:** check
**Severity:** Low (documentation)
**Current State:** Variables with all missing values display "." for statistics (acceptable behavior but undocumented)

**Decision:** Add note in help file documenting this behavior?

---

### 8. compress_tc: Return Actual Processed Variable List
**Package:** compress_tc
**Severity:** Low (feature enhancement)
**Current State:** Returns input varlist in `r(varlist)` even when empty (operates on all variables)

**Decision:** Return actual list of processed variables instead?

---

### 9. compress_tc: Per-Variable Savings Report
**Package:** compress_tc
**Severity:** Low (feature enhancement)
**Current State:** Only reports aggregate memory savings

**Decision:** Add option to report per-variable savings?

---

### 10. cstat_surv: Future Enhancements
**Package:** cstat_surv
**Severity:** Low (feature request)
**Current State:** Code is excellent, no fixes needed

**Potential future features:**
- Add `version` option to display package version
- Add `notable` option to suppress display output
- Add more detailed inline comments for Mata code (educational)

---

### 11. massdesas: Observation Count Check After Import
**Package:** massdesas
**Severity:** Medium (robustness)
**Current State:** No explicit check that import produced observations before saving

**Decision:** Add check after import?

```stata
if `import_rc' == 0 {
    quietly count
    if r(N) == 0 {
        display as error "Warning: `file' imported but contains 0 observations"
        local ++n_failed
    }
    else {
        save "`dtaname'.dta", replace
        // ...
    }
}
```

---

### 12. massdesas: File Path Sanitization
**Package:** massdesas
**Severity:** Medium (security)
**Current State:** directory() option not validated for dangerous characters

**Decision:** Add validation?

**Note:** Lower risk for this command since it operates on local directories, but inconsistent with other packages that have file path sanitization.

---

### 13. pkgtransfer: Simplify Date Expression
**Package:** pkgtransfer
**Severity:** Low (code clarity)
**Current State:** Complex nested date expression on line 547

**Decision:** Simplify for readability?

**Current:**
```stata
local date "`=string(year(date("`c(current_date)'", "DMY")), "%4.0f")'" "_" "`=string(month(date("`c(current_date)'", "DMY")), "%02.0f")'" "_" "`=string(day(date("`c(current_date)'", "DMY")), "%02.0f")'"
```

**Proposed:**
```stata
local today_date = date("`c(current_date)'", "DMY")
local date "`=string(year(`today_date'), "%4.0f")'_`=string(month(`today_date'), "%02.0f")'_`=string(day(`today_date'), "%02.0f")'"
```

---

### 14. regtab: Validate Collect Table Structure
**Package:** regtab
**Severity:** High (audit report) → **Optional**
**Current State:** Assumes collect table has required dimensions (_r_b, _r_ci, _r_p)

**Decision:** Add explicit validation before processing?

**Pro:** Better error messages when table structure is wrong
**Con:** Adds complexity; current code fails safely with Stata error

---

### 15. regtab: Remove Redundant Option Checks
**Package:** regtab
**Severity:** Low (code cleanup)
**Current State:** Explicitly checks if xlsx() and sheet() are provided, but syntax already enforces this

**Decision:** Remove redundant validation code (lines 52-62)?

---

## Summary Table

| # | Package | Issue | Priority | Recommended Action |
|---|---------|-------|----------|-------------------|
| 1 | datefix | rclass without returns | High | Add returns (Option B) |
| 2 | datefix | No if/in support | Medium | Consider adding |
| 3 | tvtools | Merge observation checks | Low | Optional |
| 4 | datamap | varabbrev in helpers | Medium | Optional |
| 5 | table1_tc | pdp/highpdp validation | Medium | Recommend adding |
| 6 | check | Clickable errors | Low | Nice to have |
| 7 | check | Document all-missing | Low | Should document |
| 8 | compress_tc | Return actual varlist | Low | Optional |
| 9 | compress_tc | Per-var savings | Low | Optional |
| 10 | cstat_surv | Future features | Low | Future consideration |
| 11 | massdesas | Import obs check | Medium | Recommend adding |
| 12 | massdesas | Path sanitization | Medium | For consistency |
| 13 | pkgtransfer | Simplify date | Low | Optional |
| 14 | regtab | Validate collect | Medium | Optional |
| 15 | regtab | Remove redundant checks | Low | Optional cleanup |

---

## Quick Decision Guide

**Recommend Implementing:**
1. datefix returns (makes command more useful)
5. table1_tc pdp/highpdp validation (prevents user errors)
7. check help file documentation (low effort, high value)
11. massdesas observation check (robustness)
12. massdesas path sanitization (consistency)

**Consider for Future:**
2. datefix if/in support
3. tvtools merge checks
4. datamap varabbrev in helpers

**Optional/Low Priority:**
Everything else - implement at your discretion.

---

**End of Decisions Document**
