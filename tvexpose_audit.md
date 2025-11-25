# tvexpose.ado Code Audit

## Summary
**File:** tvexpose.ado v1.0.0  
**Purpose:** Create time-varying exposure variables for survival analysis  
**Issues Found:** 12

---

## Issue 1: Unreachable Code Due to Early Default Assignment

**Severity:** High  
**Location:** Lines ~220-230

**Current Code:**
```stata
* Set default continuousunit for duration if not specified
if "`duration'" != "" & "`continuousunit'" == "" {
    local continuousunit "years"
    local unit_lower "years"
}
```

Then later (lines ~280-300):
```stata
else if "`continuousunit'" != "" {
    local exp_type "continuous"
    * Validate continuous unit (already confirmed non-empty by outer if)
    * Normalize to lowercase for comparison
    local unit_lower = lower(trim("`continuousunit'"))
```

**Problem:** When `duration` is specified without `continuousunit`, the default sets `continuousunit` to "years". Then later, the `else if "`continuousunit'" != ""` branch becomes true (since continuousunit is now set), incorrectly setting `exp_type` to "continuous" instead of "duration".

**Corrected Code:**
```stata
* Determine primary exposure type for processing BEFORE setting defaults
if "`evertreated'" != "" {
    local exp_type "evertreated"
}
else if "`currentformer'" != "" {
    local exp_type "currentformer"
}
else if "`duration'" != "" {
    local exp_type "duration"
    * Set default continuousunit for duration if not specified
    if "`continuousunit'" == "" {
        local continuousunit "years"
    }
    local unit_lower = lower(trim("`continuousunit'"))
}
else if "`continuousunit'" != "" {
    local exp_type "continuous"
    local unit_lower = lower(trim("`continuousunit'"))
}
...
```

---

## Issue 2: Missing Error Handler for Empty `exp_types` in bytype

**Severity:** Medium  
**Location:** Lines ~1700-1750 (evertreated bytype section)

**Current Code:**
```stata
* Get complete list of exposure types from saved pre-overlap data
preserve
quietly use `all_person_exp_types', clear
quietly levelsof __all_exp_types, local(exp_types)
restore

* Initialize all bytype variables to 0 (never exposed)
foreach exp_type_val of local exp_types {
```

**Problem:** If `all_person_exp_types` is empty (no one was ever exposed), `exp_types` will be empty and the loop will silently do nothing, potentially leaving the dataset in an inconsistent state.

**Corrected Code:**
```stata
* Get complete list of exposure types from saved pre-overlap data
preserve
quietly use `all_person_exp_types', clear
quietly count
if r(N) == 0 {
    restore
    noisily di as text "Warning: No exposure periods found for bytype processing"
    * Create dummy variable to indicate no exposure types found
    quietly gen double `stub_name'_none = 0
    label var `stub_name'_none "No exposures found"
}
else {
    quietly levelsof __all_exp_types, local(exp_types)
    restore
    
    * Initialize all bytype variables to 0 (never exposed)
    foreach exp_type_val of local exp_types {
```

---

## Issue 3: Inefficient Iteration Limit for Period Merging

**Severity:** Low (Performance)  
**Location:** Lines ~700-750

**Current Code:**
```stata
local max_merge_iter = 10000
while `changes' > 0 & `iter' < `max_merge_iter' {
```

**Problem:** 10,000 iterations is excessive for most datasets. The algorithm converges quickly in practice. This wastes time checking the condition and could mask infinite loops.

**Corrected Code:**
```stata
local max_merge_iter = 100  // Reduced from 10000 - should converge much faster
local warn_iter = 20  // Warn if taking unusually long
while `changes' > 0 & `iter' < `max_merge_iter' {
    ...
    local iter = `iter' + 1
    if `iter' == `warn_iter' {
        noisily di as text "Note: Period merging taking longer than expected (iteration `iter')"
    }
}
```

---

## Issue 4: Variable Collision Risk with Double Underscores

**Severity:** Medium  
**Location:** Throughout (e.g., `__orig_exp_binary`, `__first_exp`)

**Current Code:**
```stata
quietly gen double __orig_exp_binary = (exp_value != `reference')
```

**Problem:** Variables starting with `__` could conflict with user data that uses the same naming convention. While unlikely, the program should either check for conflicts or use `tempvar`.

**Corrected Code:**
```stata
tempvar orig_exp_binary first_exp
quietly gen double `orig_exp_binary' = (exp_value != `reference')
```

Or at minimum, add collision check:
```stata
foreach tvar in __orig_exp_binary __first_exp __exp_now_cont {
    capture confirm variable `tvar'
    if _rc == 0 {
        di as error "Variable `tvar' already exists in data - conflicts with internal variable"
        exit 110
    }
}
```

---

## Issue 5: Memory Leak - Tempfiles Not Cleaned in Error Paths

**Severity:** Low  
**Location:** Lines ~500-600 (early validation)

**Current Code:**
```stata
preserve
quietly {
    capture use "`using'", clear
    if _rc {
        noisily display as error "Cannot open using dataset: `using'"
        restore
        exit 601
    }
    ...
}
restore
```

**Problem:** If an error occurs after `preserve` but before `restore`, tempfiles created earlier remain allocated. Stata will clean these up eventually, but explicit cleanup is better practice.

**Corrected Code:**
```stata
* Create cleanup routine at top of program
capture program drop _tvexpose_cleanup
program define _tvexpose_cleanup
    capture restore
    capture frame drop `event_frame'
end

* Then use throughout:
preserve
quietly {
    capture use "`using'", clear
    if _rc {
        noisily display as error "Cannot open using dataset: `using'"
        _tvexpose_cleanup
        exit 601
    }
```

---

## Issue 6: Floating Point Comparison Without Tolerance

**Severity:** Medium  
**Location:** Lines ~2200-2250 (duration category assignment)

**Current Code:**
```stata
local epsilon = 0.001
quietly replace exp_duration = 1 if __exp_now_dur & cumul_units_start < (`first_cut' - `epsilon') & cumul_units_start >= 0
```

**Problem:** Using a fixed epsilon of 0.001 may not be appropriate for all units. For days, 0.001 is fine, but for years, it's overly precise. The epsilon should scale with the unit.

**Corrected Code:**
```stata
* Scale epsilon based on unit size
if "`unit_lower'" == "days" {
    local epsilon = 0.5  // Half a day
}
else if "`unit_lower'" == "weeks" {
    local epsilon = 0.07  // ~Half a day in weeks
}
else if "`unit_lower'" == "months" {
    local epsilon = 0.016  // ~Half a day in months
}
else if "`unit_lower'" == "quarters" {
    local epsilon = 0.005  // ~Half a day in quarters
}
else if "`unit_lower'" == "years" {
    local epsilon = 0.00137  // ~Half a day in years
}
```

---

## Issue 7: Incorrect Handling of `_N` in forvalues Loop

**Severity:** High  
**Location:** Lines ~900-950 (priority overlap handling)

**Current Code:**
```stata
local n_rows = _N
forvalues i = 1/`n_rows' {
    local curr_id = id[`i']
    local curr_start = exp_start[`i']  
    ...
    forvalues j = 1/`=`i'-1' {
        if id[`j'] == `curr_id' & priority_rank[`j'] < `curr_rank' {
```

**Problem:** This nested loop has O(n²) complexity and accesses observations by index, which is extremely slow in Stata. For datasets with >10,000 rows, this will be prohibitively slow.

**Corrected Code:**
```stata
* Use by-group processing instead of nested loops
sort id priority_rank exp_start exp_stop

* Mark lower-priority periods that overlap with higher-priority
by id: gen double __high_stop = exp_stop[1]  // First row has highest priority
by id: replace __high_stop = max(__high_stop[_n-1], exp_stop) if priority_rank == priority_rank[_n-1]

* Flag overlaps where current period starts before cumulative high-priority stop
by id: gen double __overlaps_higher = (exp_start <= __high_stop[_n-1]) if _n > 1

* Process overlaps
...
```

---

## Issue 8: Potential Infinite Loop in Carry-Forward Logic

**Severity:** Medium  
**Location:** Lines ~2300-2350 (duration bytype section)

**Current Code:**
```stata
local changes = 1
while `changes' > 0 {
    quietly bysort id (exp_start exp_stop): replace `stub_name'`suffix' = `stub_name'`suffix'[_n-1] if _n > 1 & ///
        `stub_name'`suffix' == `reference' & `stub_name'`suffix'[_n-1] != `reference' & ///
        _n > __first_exp_any
    quietly count if `stub_name'`suffix' == `reference' & _n > 1 & _n > __first_exp_any
    local remaining = r(N)
    if `remaining' > 0 {
        quietly bysort id (exp_start exp_stop): gen double __can_carry = (...)
        quietly count if __can_carry == 1
        local changes = r(N)
        quietly drop __can_carry
    }
    else {
        local changes = 0
    }
}
```

**Problem:** If the data has a structure where carry-forward can never complete (e.g., circular references or data corruption), this loop will run forever. No iteration limit is set.

**Corrected Code:**
```stata
local changes = 1
local carry_iter = 0
local max_carry_iter = 1000
while `changes' > 0 & `carry_iter' < `max_carry_iter' {
    ...
    local carry_iter = `carry_iter' + 1
}
if `carry_iter' >= `max_carry_iter' {
    noisily di as error "Warning: Carry-forward iteration limit reached - results may be incomplete"
}
```

---

## Issue 9: Undocumented Behavior When `reference` Value Doesn't Exist

**Severity:** Medium  
**Location:** Lines ~150-160

**Current Code:**
```stata
syntax using/ , ///
    ...
    reference(numlist max=1) ///
```

**Problem:** The program accepts any numeric value as `reference`, but doesn't validate that this value actually exists in the exposure data or makes sense. If user specifies `reference(999)` but 999 never appears, the program silently creates unexpected output.

**Corrected Code:**
```stata
* After loading exposure data, validate reference value
quietly levelsof exp_value, local(all_exp_values)
local ref_found = 0
foreach v of local all_exp_values {
    if `v' == `reference' {
        local ref_found = 1
    }
}
if `ref_found' == 0 {
    noisily di as text "Note: Reference value `reference' not found in exposure data."
    noisily di as text "      Unexposed periods will be created with this value."
}
```

---

## Issue 10: Race Condition in Tempfile Label Saving

**Severity:** Low  
**Location:** Lines ~580-600

**Current Code:**
```stata
if "`vallab_`var''" != "" {
    quietly label save `vallab_`var'' using `c(tmpdir)'/label_`var'.do, replace
}
```

**Problem:** Using fixed filenames in tmpdir could cause conflicts if multiple Stata instances run tvexpose simultaneously.

**Corrected Code:**
```stata
if "`vallab_`var''" != "" {
    tempfile labfile_`var'
    quietly label save `vallab_`var'' using `labfile_`var'', replace
}
```

---

## Issue 11: Missing `noisily` Causing Silent Failures

**Severity:** Low  
**Location:** Lines ~2600-2650 (label application)

**Current Code:**
```stata
* B. Apply User Overrides
if `"`eventlabel'"' != "" {
    * Use 'modify' to overwrite specific values or add new ones
    capture label define `generate'_lbl `eventlabel', modify
    if _rc {
         di as error "Error applying eventlabel(). Ensure syntax follows 'value \"Label\"' pairs."
         exit 198
    }
}
```

**Problem:** The `di as error` is inside a `quietly` block (from line ~110), so the error message won't display.

**Corrected Code:**
```stata
if `"`eventlabel'"' != "" {
    capture label define `generate'_lbl `eventlabel', modify
    if _rc {
         noisily di as error "Error applying eventlabel(). Ensure syntax follows 'value \"Label\"' pairs."
         exit 198
    }
}
```

---

## Issue 12: Inconsistent Variable Type Declarations

**Severity:** Low  
**Location:** Throughout

**Current Code (various locations):**
```stata
quietly gen double __gap_days = 0
quietly generate double period_days = exp_stop - exp_start + 1
quietly gen exp_value_et = cond(...)
```

**Problem:** Some generated variables specify `double` type, others don't. For consistency and to prevent precision issues, all numeric variables should explicitly declare type.

**Corrected Code:**
```stata
* Establish consistent pattern: always use "gen double" for calculated values
quietly gen double exp_value_et = cond(...)
```

---
