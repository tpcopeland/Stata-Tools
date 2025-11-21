# tvmerge Batch Processing Optimization Plan

## Problem Statement

The current `tvmerge.ado` implementation processes **one person ID at a time** during the cartesian merge operation. For datasets with thousands of unique IDs, this creates a massive performance bottleneck due to:

1. **Excessive disk I/O**: Loading the entire merged dataset for each individual person
2. **Repeated file operations**: Creating and reading temporary files in a loop
3. **Memory inefficiency**: Constantly clearing and reloading data

---

## Code Review Acknowledgment

**Version 2.0 - Updated after peer review**

Initial approach had **3 critical bugs**:
1. ❌ `inlist()` syntax error (space vs comma separation)
2. ❌ String ID incompatibility (quote handling)
3. ❌ Macro length limits with `levelsof` (truncation with 50k+ IDs)

**Solution**: Replace `levelsof` + `inlist()` with `egen group()` + numeric range filtering + `merge`

*Thanks to code review for catching these issues before implementation!*

---

## Current Implementation (Lines 539-599)

### BEFORE: One-at-a-time processing

```stata
* Get all unique IDs
levelsof id, local(ids)

* Pre-compute which exposures are continuous
foreach exp_var in `exp_k_list' {
    local is_cont_`exp_var' = 0
    foreach cont_name in `continuous_names' {
        if "`exp_var'" == "`cont_name'" {
            local is_cont_`exp_var' = 1
        }
    }
}

* Initialize empty dataset for results
clear

* Process each person ONE AT A TIME
foreach pid in `ids' {
    * Get person's records from merged data (dataset 1 through k-1)
    use `merged_data', clear
    keep if id == `pid'
    tempfile person_merged
    save `person_merged', replace

    * Get person's records from dataset k
    use `ds_k_clean', clear
    keep if id == `pid'
    tempfile person_k
    save `person_k', replace

    * Create cartesian product for this person
    use `person_merged', clear
    cross using `person_k'

    * Calculate interval intersection
    generate double new_start = max(`startname', start_k)
    generate double new_stop = min(`stopname', stop_k)

    * Keep only valid intersections
    keep if new_start <= new_stop & !missing(new_start, new_stop)

    * Replace old interval with intersection
    replace `startname' = new_start
    replace `stopname' = new_stop
    drop new_start new_stop

    * For continuous exposures, interpolate values
    foreach exp_var in `exp_k_list' {
        if `is_cont_`exp_var'' == 1 {
            generate double _proportion = cond(stop_k > start_k, (`stopname' - start_k) / (stop_k - start_k), 1)
            replace _proportion = 1 if _proportion > 1 & !missing(_proportion)
            replace `exp_var' = `exp_var' * _proportion
            drop _proportion
        }
    }

    drop start_k stop_k

    * Save this person's results
    tempfile person_result
    save `person_result', replace

    * Append to overall results
    if _N > 0 {
        capture confirm file `cartesian'
        if _rc == 0 {
            append using `cartesian'
        }
        save `cartesian', replace
    }
}
```

**Problem**: If you have 10,000 unique IDs, this loop runs 10,000 times, loading the entire dataset each time!

---

## Proposed Solution: Batch Processing

### AFTER: Process multiple IDs in batches (CORRECTED VERSION)

**CRITICAL FIXES (identified by code review)**:
1. ❌ **Removed `levelsof`** - Avoids macro length limits with large ID counts
2. ❌ **Removed `inlist()`** - Avoids syntax errors (comma separation) and string ID issues
3. ✅ **Added `egen group()`** - Creates numeric sequence that works with any ID type
4. ✅ **Use `merge` for filtering** - Robust for both string and numeric IDs, no argument limits

```stata
* Pre-compute which exposures are continuous
foreach exp_var in `exp_k_list' {
    local is_cont_`exp_var' = 0
    foreach cont_name in `continuous_names' {
        if "`exp_var'" == "`cont_name'" {
            local is_cont_`exp_var' = 1
        }
    }
}

* CRITICAL FIX: Create numeric sequence for batching
* This handles String IDs and avoids macro length limits
use `merged_data', clear

tempvar batch_seq
egen long `batch_seq' = group(id)

* Calculate batch parameters
quietly summarize `batch_seq', meanonly
local n_unique_ids = r(max)

* Handle batch() option (default 20%)
if "`batch'" == "" {
    local batch = 20
}

* Validate batch percentage
if `batch' < 1 | `batch' > 100 {
    di as error "batch() must be between 1 and 100"
    exit 198
}

* Calculate batch size
local batch_size = ceil(`n_unique_ids' * (`batch' / 100))
local n_batches = ceil(`n_unique_ids' / `batch_size')

di as txt "Processing `n_unique_ids' unique IDs in `n_batches' batches (batch size: `batch_size' IDs = `batch'%)..."

* Save dataset with the sequence variable for the loop
save `merged_data', replace

* Initialize empty result
clear

* BATCH LOOP
forvalues b = 1/`n_batches' {
    local start_seq = ((`b' - 1) * `batch_size') + 1
    local end_seq = `b' * `batch_size'

    di as txt "  Batch `b'/`n_batches'..."

    * 1. LOAD BATCH OF MERGED DATA
    use `merged_data', clear
    quietly keep if `batch_seq' >= `start_seq' & `batch_seq' <= `end_seq'
    tempfile batch_merged
    save `batch_merged'

    * 2. CREATE ID FILTER LIST
    * Extract unique IDs for this batch to filter dataset K
    keep id
    by id: keep if _n == 1
    tempfile batch_filter
    save `batch_filter'

    * 3. LOAD AND FILTER DATASET K
    use `ds_k_clean', clear

    * CRITICAL FIX: Use MERGE to filter instead of INLIST
    * This works for strings and numbers and has no item limit
    quietly merge m:1 id using `batch_filter', keep(match) keepusing(id) nogenerate

    tempfile batch_k
    save `batch_k'

    * 4. PERFORM JOINBY (Cartesian within ID)
    use `batch_merged', clear

    * Drop the sequence var so it doesn't interfere
    drop `batch_seq'

    * Create cartesian product for entire batch
    joinby id using `batch_k'

    * 5. INTERSECTION LOGIC
    * Calculate interval intersection
    generate double new_start = max(`startname', start_k)
    generate double new_stop = min(`stopname', stop_k)

    * Keep only valid intersections
    keep if new_start <= new_stop & !missing(new_start, new_stop)

    * Replace old interval with intersection
    replace `startname' = new_start
    replace `stopname' = new_stop
    drop new_start new_stop

    * 6. CONTINUOUS EXPOSURE INTERPOLATION
    * For continuous exposures, interpolate values based on time elapsed
    foreach exp_var in `exp_k_list' {
        if `is_cont_`exp_var'' == 1 {
            generate double _proportion = cond(stop_k > start_k, (`stopname' - start_k) / (stop_k - start_k), 1)
            replace _proportion = 1 if _proportion > 1 & !missing(_proportion)
            replace `exp_var' = `exp_var' * _proportion
            drop _proportion
        }
    }

    drop start_k stop_k

    * 7. APPEND TO RESULTS
    if _N > 0 {
        tempfile batch_result
        save `batch_result'

        capture confirm file `cartesian'
        if _rc == 0 {
            append using `cartesian'
        }
        save `cartesian', replace
    }
}
```

**Key Changes**:
1. **`egen group()` for indexing**: Creates numeric sequence 1..N that works with any ID type
2. **Numeric range filtering**: Use `>= start & <= end` instead of `inlist()`
3. **`merge` for dataset K filtering**: Robust alternative to `inlist()` with no limits
4. **Use `joinby` instead of `cross`**: More efficient for multi-ID cartesian products
5. **Reduced I/O**: Load datasets once per batch instead of once per ID

---

## Syntax Addition

### New Option

Add to the syntax declaration (around line 53):

```stata
syntax anything(name=datasets), ///
    id(name) ///
    STart(namelist) STOP(namelist) EXPosure(namelist) ///
    [GENerate(namelist) ///
     PREfix(string) ///
     STARTname(string) ///
     STOPname(string) ///
     DATEformat(string) ///
     SAVeas(string) ///
     REPlace ///
     KEEP(namelist) ///
     CONtinuous(namelist) ///
     Batch(integer 20) ///        /* NEW OPTION */
     CHECK VALIDATEcoverage VALIDATEoverlap SUMmarize]
```

### Option Documentation

Add to help text (around line 32):

```
Performance options:
  batch(#)           - Process IDs in batches (default: 20 = 20% of IDs per batch)
                       Higher values = larger batches = potentially faster but more memory
                       Lower values = smaller batches = less memory but more I/O
                       Range: 1-100 (percentage of total IDs)
```

---

## Expected Performance Improvements

### Scenario: 10,000 unique IDs

**Current (one-at-a-time)**:
- 10,000 disk reads of merged data
- 10,000 disk reads of dataset k
- 10,000 cross operations
- 10,000 append operations

**Optimized (20% batches = 2,000 IDs per batch)**:
- 5 disk reads of merged data
- 5 disk reads of dataset k
- 5 joinby operations
- 5 append operations

**Speedup**: Roughly **2,000x fewer I/O operations** = 10-50x faster overall (depending on dataset size)

### Memory Considerations

- **Larger batches** (e.g., `batch(50)` = 50%): Faster but uses more memory
- **Smaller batches** (e.g., `batch(10)` = 10%): Safer for memory but more I/O
- **Default 20%**: Good balance for most use cases

---

## Implementation Notes

### Critical Bugs Fixed in Code Review

**🐛 Bug #1: `inlist()` Syntax Error**
- **Problem**: Space-separated list `inlist(id, 1 2 3)` causes syntax error
- **Required**: Comma-separated `inlist(id, 1, 2, 3)`
- **Solution**: Replaced with `egen group()` + numeric range filtering

**🐛 Bug #2: String ID Incompatibility**
- **Problem**: `inlist(id, A001)` fails with string IDs (needs quotes: `"A001"`)
- **Impact**: Made program incompatible with string identifiers
- **Solution**: `egen group()` creates numeric sequence that works with any ID type

**🐛 Bug #3: Macro Length Limits**
- **Problem**: `levelsof id, local(ids)` truncates at ~64k-4M characters
- **Impact**: Datasets with 50,000+ IDs silently drop thousands of people
- **Solution**: Use `egen group()` instead of storing all IDs in macro

### Critical Changes

1. **Replace `cross` with `joinby`**:
   - `cross` creates cartesian product of entire datasets (ignoring ID)
   - `joinby id` creates cartesian product **within each ID**, which is what we want
   - This is crucial for correctness when processing multiple IDs at once

2. **Use `egen group()` for batch indexing**:
   - Creates numeric sequence 1..N for any ID type (string or numeric)
   - Avoids macro length limits completely
   - Enables simple range filtering: `keep if seq >= start & seq <= end`

3. **Use `merge` instead of `inlist()` for filtering dataset K**:
   - Works with any ID type (string or numeric)
   - No argument limits (unlike `inlist()`'s 250 limit)
   - More efficient for large batches

4. **Progress reporting**:
   - Display batch progress to give users feedback during long operations

### Testing Needed

1. Verify identical results between old and new implementations
2. Test with various batch sizes (1%, 20%, 50%, 100%)
3. Test with small datasets (< 250 IDs) and large datasets (> 10,000 IDs)
4. Memory profiling with very large datasets

---

## Backward Compatibility

The optimization is **fully backward compatible**:
- Default behavior uses `batch(20)` = 20% batches
- Old behavior can be approximated with `batch(1)` (though still uses new code path)
- All other options and outputs remain unchanged
- Results should be **numerically identical** to the old implementation

---

## Alternative Approaches Considered

### 1. Use Mata for in-memory processing
**Pros**: Potentially even faster
**Cons**: Complex rewrite, may not fit in memory for large datasets

### 2. Use `batch(100)` to process all at once
**Pros**: Maximum speed
**Cons**: May run out of memory on large datasets

### 3. Adaptive batch sizing based on dataset size
**Pros**: Automatic optimization
**Cons**: Complex to implement, hard to predict behavior

**Decision**: Stick with user-configurable `batch()` option for simplicity and control.
