# tvmerge.ado Code Audit

## Summary
**File:** tvmerge.ado v1.0.0  
**Purpose:** Merge multiple time-varying exposure datasets  
**Issues Found:** 8

---

## Issue 1: Logic Error in Duplicate Exposure Variable Detection

**Severity:** High  
**Location:** Lines ~85-100

**Current Code:**
```stata
* Get unique exposure variable names (handles duplicates across datasets)
local exposures_raw "`exposure'"
local exposures: list uniq exposures_raw
local numexp: word count `exposures'

* Check for duplicate exposure variable names
local numexp_raw: word count `exposures_raw'
if `numexp' < `numexp_raw' {
    di as error "Duplicate exposure variable names detected across datasets."
    di as error "Each dataset must have a unique exposure variable name."
    di as error "Use the generate() option to specify unique names for each exposure variable."
    exit 198
}
```

**Problem:** The `list uniq` macro function removes duplicates, so if user specifies `exposure(drug drug dose)`, it becomes `exposure(drug dose)`. The count comparison then correctly catches this. However, the error message is misleading - the issue is that the user specified the same variable name twice, not that different datasets have the same name. Also, this doesn't catch the case where two different datasets legitimately have variables with the same name.

**Corrected Code:**
```stata
* Check for duplicate exposure variable names in the specification
local exposures_raw "`exposure'"
local numexp_raw: word count `exposures_raw'

* Check if user specified same variable name multiple times
local seen_names ""
local has_dup = 0
foreach exp_name in `exposures_raw' {
    local already_seen: list exp_name in seen_names
    if `already_seen' {
        local has_dup = 1
        local dup_name "`exp_name'"
    }
    local seen_names "`seen_names' `exp_name'"
}

if `has_dup' {
    di as error "Duplicate exposure variable name '`dup_name'' specified multiple times."
    di as error "Each position in exposure() must have a unique name."
    di as error "Use the generate() option to rename exposures if datasets have same variable names."
    exit 198
}

local exposures "`exposures_raw'"
local numexp: word count `exposures'
```

---

## Issue 2: Tempfile Reference After Restore

**Severity:** High  
**Location:** Lines ~65-80

**Current Code:**
```stata
* Verify all dataset files exist and are valid Stata datasets
preserve
foreach ds in `datasets' {
    capture confirm file "`ds'.dta"
    if _rc != 0 {
        di as error "Dataset file not found: `ds'.dta"
        exit 601
    }
    * Also verify it's a valid Stata dataset
    capture use "`ds'.dta" in 1, clear
    if _rc != 0 {
        di as error "`ds'.dta is not a valid Stata dataset or cannot be read"
        exit 610
    }
}
restore
```

**Problem:** If the file doesn't exist or can't be read, the program calls `exit` without calling `restore` first. This leaves the dataset state in an inconsistent condition.

**Corrected Code:**
```stata
preserve
local validation_error = 0
local error_msg ""
local error_code = 0

foreach ds in `datasets' {
    capture confirm file "`ds'.dta"
    if _rc != 0 {
        local validation_error = 1
        local error_msg "Dataset file not found: `ds'.dta"
        local error_code = 601
        continue, break
    }
    capture use "`ds'.dta" in 1, clear
    if _rc != 0 {
        local validation_error = 1
        local error_msg "`ds'.dta is not a valid Stata dataset or cannot be read"
        local error_code = 610
        continue, break
    }
}
restore

if `validation_error' {
    di as error "`error_msg'"
    exit `error_code'
}
```

---

## Issue 3: Inefficient Batch Size Calculation

**Severity:** Low (Performance)  
**Location:** Lines ~300-320

**Current Code:**
```stata
* Calculate batch size based on batch() option
local batch_size = ceil(`n_unique_ids' * (`batch' / 100))
local n_batches = ceil(`n_unique_ids' / `batch_size')
```

**Problem:** For small datasets (e.g., 50 IDs with batch=20), this creates tiny batches that add I/O overhead. There should be a minimum batch size.

**Corrected Code:**
```stata
* Calculate batch size with minimum threshold
local batch_size = ceil(`n_unique_ids' * (`batch' / 100))
local min_batch_size = 100  // Minimum IDs per batch to avoid excessive I/O
if `batch_size' < `min_batch_size' & `n_unique_ids' >= `min_batch_size' {
    local batch_size = `min_batch_size'
}
local n_batches = ceil(`n_unique_ids' / `batch_size')
```

---

## Issue 4: Missing Variable Type Specification in Generated Variables

**Severity:** Medium  
**Location:** Lines ~350-400

**Current Code:**
```stata
generate double new_start = max(`startname', start_k)
generate double new_stop = min(`stopname', stop_k)
```

**Problem:** While `double` is correctly specified here, other generated variables throughout the code don't specify type:

```stata
generate double _valid = (`startname' <= `stopname') ...  // Line ~250 - correct
gen _proportion = ...  // Line ~380 - missing type
```

**Corrected Code:**
```stata
generate double _proportion = cond(stop_k > start_k, (`stopname' - `startname' + 1) / (stop_k - start_k + 1), 1)
```

---

## Issue 5: Unhandled Edge Case - All Batches Produce Zero Rows

**Severity:** Medium  
**Location:** Lines ~400-450

**Current Code:**
```stata
* Fallback: If all batches produced zero rows (no valid intersections exist),
* create empty dataset with proper structure
capture confirm file `cartesian'
if _rc != 0 {
    use `merged_data', clear
    keep if 1 == 0  // Keep structure but no observations
    generate double `exp_k' = .
    save `cartesian', replace
}
```

**Problem:** When creating the empty fallback dataset, only `exp_k` is added. If there were multiple exposures from dataset k (`exp_k_list`), only one gets added. Also, the `keep if 1 == 0` idiom is less clear than `drop _all` or `clear`.

**Corrected Code:**
```stata
capture confirm file `cartesian'
if _rc != 0 {
    * No valid intersections - create empty dataset with proper structure
    use `merged_data', clear
    drop _all  // More explicit than keep if 1 == 0
    
    * Add all exposure variables from dataset k
    foreach exp_var in `exp_k_list' {
        generate double `exp_var' = .
    }
    save `cartesian', replace
    
    noisily di as text "Warning: No overlapping time periods found with dataset `k' (`ds_k')"
}
```

---

## Issue 6: Inconsistent Return Value Storage

**Severity:** Low  
**Location:** Lines ~550-600

**Current Code:**
```stata
* Store scalar results
return scalar N = _N

* Count and store unique persons
egen double _tag = tag(id)
quietly count if _tag == 1
return scalar N_persons = r(N)
drop _tag
```

**Problem:** `return scalar N = _N` is set, then later operations modify `_N` (egen creates a variable, potentially changing observation count if there were issues). The return should be captured in a local first.

**Corrected Code:**
```stata
* Capture final counts before any modifications
local final_N = _N

* Count unique persons
egen double _tag = tag(id)
quietly count if _tag == 1
local final_persons = r(N)
drop _tag

* Store return values
return scalar N = `final_N'
return scalar N_persons = `final_persons'
```

---

## Issue 7: Missing Validation for `keep()` Variables Across Datasets

**Severity:** Medium  
**Location:** Lines ~200-250 and ~300

**Current Code:**
```stata
* Process keep() variables for dataset 1
if "`keep'" != "" {
    foreach var in `keep' {
        capture confirm variable `var'
        if _rc == 0 {
            * Track that this variable was found
            local keep_vars_found: list keep_vars_found | var
            ...
        }
    }
}
```

**Problem:** The code silently ignores `keep()` variables that don't exist in a dataset, only tracking which were found. At the end, it validates all were found in at least one dataset. However, if a variable exists in dataset 1 but not dataset 2, there's no warning that dataset 2's rows won't have this variable populated.

**Corrected Code:**
```stata
* Process keep() variables for dataset 1
if "`keep'" != "" {
    local keep_in_ds1 ""
    foreach var in `keep' {
        capture confirm variable `var'
        if _rc == 0 {
            local keep_vars_found: list keep_vars_found | var
            local keep_in_ds1 "`keep_in_ds1' `var'"
            ...
        }
    }
}

...

* At end of dataset loop, report which keep vars were missing
if "`keep'" != "" {
    foreach var in `keep' {
        local in_ds1: list var in keep_in_ds1
        local in_ds2: list var in keep_in_ds2
        * etc for all datasets
        
        if !`in_ds1' | !`in_ds2' {
            noisily di as text "Note: Variable '`var'' not present in all datasets"
        }
    }
}
```

---

## Issue 8: Potential Memory Issue with Large Cartesian Products

**Severity:** Medium (Performance/Stability)  
**Location:** Lines ~350-380

**Current Code:**
```stata
* Create cartesian product for entire batch
joinby id using `batch_k'
```

**Problem:** `joinby` creates a cartesian product, which can explode memory usage. If person A has 100 periods in merged_data and 50 periods in batch_k, the result is 5,000 rows for that person alone. With 1,000 persons in a batch, this could be 5 million rows. No warning is given.

**Corrected Code:**
```stata
* Create cartesian product for entire batch
* First estimate result size
quietly count
local pre_join = r(N)
preserve
quietly use `batch_k', clear
quietly count
local batch_k_n = r(N)
restore

* Estimate cartesian product size (rough upper bound)
local est_result = `pre_join' * `batch_k_n' / `batch_size'
if `est_result' > 10000000 {  // 10 million rows
    noisily di as text "Warning: Batch `b' may produce ~" %12.0fc `est_result' " rows"
    noisily di as text "         Consider using smaller batch size or simplifying data"
}

joinby id using `batch_k'
```

---