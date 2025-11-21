# tvmerge Batch Processing Optimization Plan

## Problem Statement

The current `tvmerge.ado` implementation processes **one person ID at a time** during the cartesian merge operation. For datasets with thousands of unique IDs, this creates a massive performance bottleneck due to:

1. **Excessive disk I/O**: Loading the entire merged dataset for each individual person
2. **Repeated file operations**: Creating and reading temporary files in a loop
3. **Memory inefficiency**: Constantly clearing and reloading data

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

### AFTER: Process multiple IDs in batches

```stata
* Get all unique IDs
levelsof id, local(ids)
local n_ids: word count `ids'

* Pre-compute which exposures are continuous
foreach exp_var in `exp_k_list' {
    local is_cont_`exp_var' = 0
    foreach cont_name in `continuous_names' {
        if "`exp_var'" == "`cont_name'" {
            local is_cont_`exp_var' = 1
        }
    }
}

* Calculate batch size based on batch() option (default 20%)
if "`batch'" == "" {
    local batch_pct = 20
}
else {
    local batch_pct = `batch'
}

* Validate batch percentage
if `batch_pct' < 1 | `batch_pct' > 100 {
    di as error "batch() must be between 1 and 100"
    exit 198
}

* Calculate number of IDs per batch
local batch_size = max(1, ceil(`n_ids' * `batch_pct' / 100))
local n_batches = ceil(`n_ids' / `batch_size')

di as txt "Processing `n_ids' IDs in `n_batches' batches (batch size: `batch_size' IDs = `batch_pct'%)"

* Initialize empty dataset for results
clear

* Process IDs in batches
local id_counter = 0
forvalues batch = 1/`n_batches' {

    * Build list of IDs for this batch
    local batch_ids ""
    local batch_start = (`batch' - 1) * `batch_size' + 1
    local batch_end = min(`batch' * `batch_size', `n_ids')

    forvalues i = `batch_start'/`batch_end' {
        local current_id: word `i' of `ids'
        local batch_ids "`batch_ids' `current_id'"
    }

    * Display progress
    local batch_count: word count `batch_ids'
    di as txt "  Batch `batch'/`n_batches': Processing `batch_count' IDs..."

    * Get batch's records from merged data (dataset 1 through k-1)
    use `merged_data', clear
    * Use inlist() for efficient filtering of multiple IDs
    * For very large batches, split into chunks of 250 (Stata's inlist limit)
    local batch_count: word count `batch_ids'
    if `batch_count' <= 250 {
        keep if inlist(id, `batch_ids')
    }
    else {
        * For batches > 250 IDs, use multiple inlist() calls combined with OR
        tempvar keepflag
        generate byte `keepflag' = 0
        local chunk_size = 250
        local n_chunks = ceil(`batch_count' / `chunk_size')

        forvalues chunk = 1/`n_chunks' {
            local chunk_start = (`chunk' - 1) * `chunk_size' + 1
            local chunk_end = min(`chunk' * `chunk_size', `batch_count')

            local chunk_ids ""
            forvalues i = `chunk_start'/`chunk_end' {
                local current_id: word `i' of `batch_ids'
                local chunk_ids "`chunk_ids' `current_id'"
            }
            replace `keepflag' = 1 if inlist(id, `chunk_ids')
        }
        keep if `keepflag' == 1
        drop `keepflag'
    }

    tempfile batch_merged
    save `batch_merged', replace

    * Get batch's records from dataset k
    use `ds_k_clean', clear
    * Same filtering approach for dataset k
    if `batch_count' <= 250 {
        keep if inlist(id, `batch_ids')
    }
    else {
        tempvar keepflag
        generate byte `keepflag' = 0
        local chunk_size = 250
        local n_chunks = ceil(`batch_count' / `chunk_size')

        forvalues chunk = 1/`n_chunks' {
            local chunk_start = (`chunk' - 1) * `chunk_size' + 1
            local chunk_end = min(`chunk' * `chunk_size', `batch_count')

            local chunk_ids ""
            forvalues i = `chunk_start'/`chunk_end' {
                local current_id: word `i' of `batch_ids'
                local chunk_ids "`chunk_ids' `current_id'"
            }
            replace `keepflag' = 1 if inlist(id, `chunk_ids')
        }
        keep if `keepflag' == 1
        drop `keepflag'
    }

    tempfile batch_k
    save `batch_k', replace

    * Create cartesian product for entire batch
    use `batch_merged', clear
    joinby id using `batch_k'

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

    * Append batch results to overall results
    if _N > 0 {
        tempfile batch_result
        save `batch_result', replace

        capture confirm file `cartesian'
        if _rc == 0 {
            append using `cartesian'
        }
        save `cartesian', replace
    }
}
```

**Key Changes**:
1. **Batch IDs together**: Process 20% of IDs at once (configurable)
2. **Use `inlist()` for filtering**: Much faster than individual `keep if id == `pid'` operations
3. **Use `joinby` instead of `cross`**: More efficient for multi-ID cartesian products
4. **Reduced I/O**: Load datasets once per batch instead of once per ID

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

### Critical Changes

1. **Replace `cross` with `joinby`**:
   - `cross` creates cartesian product of entire datasets (ignoring ID)
   - `joinby id` creates cartesian product **within each ID**, which is what we want
   - This is crucial for correctness when processing multiple IDs at once

2. **Handle Stata's `inlist()` limit**:
   - `inlist()` supports maximum 250 arguments
   - For batches > 250 IDs, split into multiple `inlist()` calls

3. **Progress reporting**:
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
