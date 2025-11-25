# tvevent.ado Code Audit

## Summary
**File:** tvevent.ado v1.0.0  
**Purpose:** Add event/failure flags to time-varying datasets  
**Issues Found:** 6

---

## Issue 1: Incorrect `restore` Placement Causes Data Loss

**Severity:** High  
**Location:** Lines ~145-180 (competing risk logic section)

**Current Code:**
```stata
* -- COMPETING RISK LOGIC START --

* 1. Capture labels for reporting later
local lab_1 : variable label `date'
if "`lab_1'" == "" local lab_1 "Event: `date'"

...

* 3. Clean up event file
keep if !missing(_eff_date)

drop `date'
rename _eff_date `date'
rename _eff_type _event_type

keep `id' `date' _event_type `keepvars'
duplicates drop `id' `date', force

tempfile events
save `events'
restore
```

**Problem:** The `restore` command is issued after saving `events` tempfile, but the corresponding `preserve` is missing. This code operates on the `using` dataset loaded earlier. The `restore` here will restore to the master dataset saved in `tempfile master`, but the structure suggests the author intended to preserve before modifying the using data.

**Corrected Code:**
```stata
* Load and process Event data from using file
use "`using'", clear

capture confirm variable `id'
if _rc {
     di as error "ID variable `id' not found in using dataset `using'"
     exit 111
}

preserve  // ADD: Preserve before modifying using data

* -- COMPETING RISK LOGIC START --
...

tempfile events
save `events'
restore  // Now this restore makes sense
```

---

## Issue 2: Missing Variable Check Before Drop

**Severity:** Medium  
**Location:** Line ~195

**Current Code:**
```stata
drop `date'
rename _eff_date `date'
```

**Problem:** If `date` variable was already dropped or renamed earlier in the code path, this will error. No `capture` protection.

**Corrected Code:**
```stata
capture drop `date'
rename _eff_date `date'
```

---

## Issue 3: Duplicate Variable Creation in MERGE MASTER VARIABLES Section

**Severity:** Medium  
**Location:** Lines ~270-290

**Current Code:**
```stata
**# 9. MERGE MASTER VARIABLES BACK
* By default, keep all variables from the original master dataset
if "`master_vars'" != "" {
    tempfile current
    save `current'

    use `master', clear
    keep `id' start stop `master_vars'
    tempfile master_to_merge
    save `master_to_merge'

    use `current', clear
    merge m:1 `id' start stop using `master_to_merge', keep(master match) nogen
}
```

**Problem:** The variables `start` and `stop` may not exist in `master` tempfile because they were created during processing. This merge could fail or produce unexpected results.

**Corrected Code:**
```stata
**# 9. MERGE MASTER VARIABLES BACK
* By default, keep all variables from the original master dataset
if "`master_vars'" != "" {
    tempfile current
    save `current'

    use `master', clear
    * Only keep master_vars that actually exist
    local vars_to_keep "`id'"
    foreach v of local master_vars {
        capture confirm variable `v'
        if _rc == 0 {
            local vars_to_keep "`vars_to_keep' `v'"
        }
    }
    keep `vars_to_keep'
    tempfile master_to_merge
    save `master_to_merge'

    use `current', clear
    merge m:1 `id' using `master_to_merge', keep(master match) nogen update
}
```

---

## Issue 4: Frame Operations May Fail on Older Stata Versions

**Severity:** Low  
**Location:** Lines ~230-250

**Current Code:**
```stata
tempname event_frame
frame create `event_frame'
frame `event_frame' {
    use `events'
    rename `date' `match_date'
}

frlink 1:1 `id' `match_date', frame(`event_frame')
```

**Problem:** Frame operations require Stata 16+, but there's no version check at the top of the file to ensure compatibility. While `version 16.0` is declared, an informative error would be better.

**Corrected Code:**
```stata
* At program start, add explicit check:
if c(stata_version) < 16 {
    di as error "tvevent requires Stata 16.0 or higher for frame operations"
    exit 199
}
```

---

## Issue 5: Potential Division by Zero in Continuous Variable Adjustment

**Severity:** Medium  
**Location:** Lines ~215-225

**Current Code:**
```stata
* Adjust Continuous Variables
if "`continuous'" != "" {
    gen double `new_dur' = stop - start
    gen double `ratio' = `new_dur' / `orig_dur'
    replace `ratio' = 1 if `orig_dur' == 0
    foreach v of local continuous {
        replace `v' = `v' * `ratio'
    }
    drop `new_dur' `ratio'
}
drop `orig_dur'
```

**Problem:** The `ratio` calculation happens before the zero-duration check, which means Stata will generate missing values for zero-duration periods, then they get replaced. While this works, it generates unnecessary warnings. Also, `new_dur` could also be zero.

**Corrected Code:**
```stata
* Adjust Continuous Variables
if "`continuous'" != "" {
    gen double `new_dur' = stop - start
    gen double `ratio' = cond(`orig_dur' == 0 | `new_dur' == 0, 1, `new_dur' / `orig_dur')
    foreach v of local continuous {
        replace `v' = `v' * `ratio'
    }
    drop `new_dur' `ratio'
}
drop `orig_dur'
```

---

## Issue 6: Inconsistent Interval Definition (Inclusive vs Exclusive)

**Severity:** Low (Documentation)  
**Location:** Line ~17 and throughout

**Current Code (Comment):**
```stata
*  1. Identifies events occurring within intervals (start < date < stop).
```

**Problem:** The comment says `start < date < stop` (exclusive bounds), but elsewhere in the code the comparison is `date > start & date < stop` which is consistent. However, the actual event matching logic uses `stop` as the match date:
```stata
gen double `match_date' = stop
```

This means events are matched to intervals where `event_date == stop`, not where `start < event_date < stop`. This is a logic discrepancy between documentation and implementation.

**Corrected Code (update comment to match implementation):**
```stata
*  1. Identifies events occurring within intervals where event date equals interval stop date.
*     (Events that fall strictly within intervals cause splits, then match on the new stop date)
```

---