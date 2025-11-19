# COMPREHENSIVE AUDIT REPORT: tvtools-r Package
**Date:** 2025-11-19  
**Status:** Production Audit - Critical Issues Identified  
**Audit Scope:** R/tvexpose.R and R/tvmerge.R

---

## EXECUTIVE SUMMARY

This audit identified **15 critical and high-priority issues** across two main functions (tvexpose and tvmerge) that pose significant risks to data integrity, user experience, and system stability. These issues fall into four categories:

1. **Type-Safe Date Conversions (CRITICAL):** 4 locations with unsafe date handling
2. **Input Validation (CRITICAL):** 8 missing validation checks
3. **Edge Case Handling (HIGH):** 8 unhandled edge cases
4. **Performance Issues (CRITICAL):** Cartesian product memory explosion risk

**Estimated Impact:** Medium to High risk of silent data corruption or cryptic runtime errors

---

## ISSUE INVENTORY

### CATEGORY 1: UNSAFE DATE CONVERSIONS (4 Issues - CRITICAL)

#### ISSUE #1: Unsafe Date Conversion in tvexpose.R - Master Dataset Entry/Exit
**Location:** R/tvexpose.R, Lines 527-528  
**Function:** tvexpose()  
**Risk Level:** CRITICAL  

**Current Code:**
```r
master_dates <- master %>%
  select(all_of(master_cols)) %>%
  rename(
    id = !!sym(id),
    study_entry = !!sym(entry),
    study_exit = !!sym(exit)
  ) %>%
  mutate(
    study_entry = floor(as.numeric(study_entry)),     # LINE 527
    study_exit = ceiling(as.numeric(study_exit))      # LINE 528
  )
```

**Problem:**
- `as.numeric()` on dates is unsafe because it depends on input type
- If input is character (e.g., "2020-01-01"), `as.numeric()` returns `NA` with a warning (not an error!)
- This silent NA conversion can corrupt all downstream calculations
- If input is already a Date object, conversion works but asymmetric floor/ceiling creates bias
- No validation that the conversion succeeded

**Why It's Critical:**
- Silent failure mode: No error thrown, NAs silently propagated through entire analysis
- Data integrity: Results would be completely wrong but difficult to detect
- Reproducibility: Same code might work with Date objects but fail with character strings
- User impact: Users have no way to know if their analysis used corrupted data

**Impact Example:**
```r
# Scenario 1: Character input
study_entry <- "2020-01-01"
as.numeric(study_entry)  # Returns NA with warning!

# Scenario 2: Date input - asymmetric handling
study_entry <- as.Date("2020-01-01")
floor(as.numeric(study_entry))    # 18262
study_exit <- as.Date("2020-12-31")
ceiling(as.numeric(study_exit))   # 18627

# The floor/ceiling on entry/exit creates boundary asymmetry
# that could bias analyses
```

**What Needs To Be Fixed:**
1. Create `convert_to_numeric_date()` helper function to handle all input types safely
2. Detect and error on character input explicitly (with helpful message)
3. Replace unsafe `as.numeric()` with safe conversion
4. Add validation that conversion succeeded (no NAs created)
5. Document why floor/ceiling are needed and potential bias implications

---

#### ISSUE #2: Unsafe Date Conversion in tvexpose.R - Exposure Dataset Start/Stop
**Location:** R/tvexpose.R, Lines 558-559  
**Function:** tvexpose()  
**Risk Level:** CRITICAL  

**Current Code:**
```r
exp_data <- exposure_data %>%
  select(all_of(exp_cols)) %>%
  rename(
    id = !!sym(id),
    exp_start = !!sym(start),
    exp_value = !!sym(exposure)
  )

if (!is.null(stop)) {
  exp_data <- exp_data %>%
    rename(exp_stop = !!sym(stop)) %>%
    mutate(
      exp_start = floor(as.numeric(exp_start)),      # LINE 558
      exp_stop = ceiling(as.numeric(exp_stop))       # LINE 559
    )
```

**Problem:**
- Same issues as Issue #1: unsafe `as.numeric()` conversion
- Affects exposure period boundaries which directly impact all exposure calculations
- Silent failure if input is character dates
- Could result in all exposures being marked as NA or incorrect dates

**Why It's Critical:**
- Exposure data is core to the entire analysis
- Faulty conversion would corrupt all output periods
- Users wouldn't realize their analysis is invalid

**What Needs To Be Fixed:**
- Same solution as Issue #1: implement type-safe conversion helper
- Add validation after conversion

---

#### ISSUE #3: Unsafe Date Conversion in tvmerge.R - Dataset 1 Dates
**Location:** R/tvmerge.R, Lines 618-619  
**Function:** tvmerge()  
**Risk Level:** CRITICAL  

**Current Code:**
```r
merged_data <- df1 %>%
  select(
    id_var = !!sym(id),
    start_var = !!sym(start[1]),
    stop_var = !!sym(stop[1]),
    exp_var = !!sym(exposure[1]),
    if (!is.null(keep)) {
      any_of(keep)
    }
  ) %>%
  mutate(
    start_var = floor(as.numeric(start_var)),        # LINE 618
    stop_var = ceiling(as.numeric(stop_var))         # LINE 619
  )
```

**Problem:**
- Same unsafe date conversion as Issues #1-2
- Input comes from tvexpose output, which should be numeric/Date
- However, if user manually constructs dataset or loads from CSV, dates might be character
- Silent conversion to NA would invalidate merge

**Why It's Critical:**
- tvmerge is the final step in analysis pipeline
- Date corruption here affects the final results users will publish
- Merges already become complex due to Cartesian product; date issues hard to debug

**What Needs To Be Fixed:**
- Implement same safe conversion helper function
- Add validation

---

#### ISSUE #4: Unsafe Date Conversion Back to Date Objects in tvmerge.R - Output
**Location:** R/tvmerge.R, Lines 796-797  
**Function:** tvmerge()  
**Risk Level:** CRITICAL  

**Current Code:**
```r
# Rename id_var, start_var, stop_var to final names
merged_data <- merged_data %>%
  rename(
    !!sym(id) := id_var,
    !!sym(startname) := start_var,
    !!sym(stopname) := stop_var
  )

# Apply date format if specified and convert back to Date objects
merged_data <- merged_data %>%
  mutate(
    !!sym(startname) := as.Date(!!sym(startname), origin = "1970-01-01"),  # LINE 796
    !!sym(stopname) := as.Date(!!sym(stopname), origin = "1970-01-01")     # LINE 797
  )
```

**Problem:**
- Line 796-797 assumes numeric values have origin "1970-01-01"
- But the date conversion could have failed silently in earlier steps
- If values are already Date objects, `as.Date()` might fail or behave unexpectedly
- `as.Date()` on already-Date objects can return NA in some R versions
- No error handling if conversion fails

**Why It's Critical:**
- Output data is what users will use for analysis
- Failed date conversion here means output has NA dates
- Users depend on these dates being correct for survival analysis
- Silent failure makes it difficult to detect problems

**What Needs To Be Fixed:**
- Check what type values are before converting
- Use safe conversion with validation
- Error clearly if conversion fails

---

### CATEGORY 2: MISSING INPUT VALIDATION (8 Issues - CRITICAL/HIGH)

#### ISSUE #5: No Validation for Empty Master Dataset
**Location:** R/tvexpose.R, Parameter validation section (after line 420)  
**Function:** tvexpose()  
**Risk Level:** CRITICAL  

**Current Code:**
```r
# Check that master and exposure_data are data frames
if (!is.data.frame(master)) {
  stop("master must be a data frame")
}
# ... column existence checks ...
# ... NA checks ...

# BUT NO CHECK FOR EMPTY MASTER!
```

**Problem:**
- Empty master dataset (0 rows) will be accepted
- All downstream operations will proceed but produce 0-row output
- User has no warning that this is invalid input
- Could indicate data loading error that goes unnoticed

**Why It's Critical:**
- Empty master is likely a data loading error
- Should fail fast with clear error, not silently produce empty output
- User might not notice and report empty results as valid analysis

**What Needs To Be Fixed:**
```r
# Add after line 420:
if (nrow(master) == 0) {
  stop("master dataset is empty (0 rows). Please provide a dataset with at least one person.")
}
```

---

#### ISSUE #6: No Validation for Duplicate IDs in Master Dataset
**Location:** R/tvexpose.R, Parameter validation section (after line 420)  
**Function:** tvexpose()  
**Risk Level:** CRITICAL  

**Current Code:**
No validation exists for duplicate IDs

**Problem:**
- Master dataset can contain duplicate IDs (same person twice)
- This violates the fundamental assumption that each person appears once
- If person A appears twice with different entry/exit dates, merge behavior is undefined
- Silent duplicate rows in output would corrupt analysis

**Why It's Critical:**
- Duplicates fundamentally break the design assumption
- Will create mysterious bugs when same person matched to both rows
- Could lead to double-counting of person-time
- No warning to user that data is invalid

**What Needs To Be Fixed:**
```r
# Add validation function
validate_master_dataset <- function(master, id) {
  if (anyDuplicated(master[[id]])) {
    dup_ids <- master[[id]][duplicated(master[[id]])]
    dup_count <- length(unique(dup_ids))
    example_dups <- paste(head(unique(dup_ids), 5), collapse = ", ")
    
    stop(sprintf(
      "master dataset has %d duplicate ID(s). Each person should appear once.\nDuplicate IDs: %s%s",
      dup_count,
      example_dups,
      if (dup_count > 5) paste0(" ... and ", dup_count - 5, " more") else ""
    ))
  }
  invisible(TRUE)
}
```

---

#### ISSUE #7: No Validation for ID Type Mismatch Between Datasets
**Location:** R/tvexpose.R, Parameter validation section (after line 420)  
**Function:** tvexpose()  
**Risk Level:** CRITICAL  

**Current Code:**
No type validation exists for ID matching

**Problem:**
- Master ID might be numeric (1, 2, 3, ...)
- Exposure ID might be character ("1", "2", "3")
- `inner_join` by ID will produce 0 rows (no matches!)
- Output will be empty with no warning about why

**Why It's Critical:**
- Type mismatch causes join to fail silently (no error, just 0 rows)
- User gets empty output and no indication of the problem
- This is a hard bug to diagnose and fix
- Could happen easily if data loaded from CSV (IDs become character)

**What Needs To Be Fixed:**
```r
# Add validation
validate_id_type_match <- function(master_id, exposure_id, id_varname) {
  master_class <- class(master_id)[1]
  exposure_class <- class(exposure_id)[1]
  
  if (master_class != exposure_class) {
    stop(sprintf(
      "ID variable '%s' has different types:\n  master: %s\n  exposure_data: %s\nBoth must be numeric or both character.",
      id_varname,
      master_class,
      exposure_class
    ))
  }
  invisible(TRUE)
}
```

---

#### ISSUE #8: No Validation for Infinite Date Values
**Location:** R/tvexpose.R, Parameter validation section (after line 420)  
**Function:** tvexpose()  
**Risk Level:** HIGH  

**Current Code:**
```r
# Check for NA values in critical columns
if (any(is.na(master[[entry]]))) {
  stop("entry variable in master contains NA values")
}

# BUT NO CHECK FOR INFINITE VALUES!
```

**Problem:**
- Infinite dates (Inf, -Inf) can be created in R but are invalid for date analysis
- If dates are Inf, all downstream date calculations produce Inf or NaN
- `floor()` and `ceiling()` operations on Inf produce Inf
- Analysis proceeds but all results are invalid (all infinities)

**Why It's Critical:**
- Infinite values silently propagate through analysis
- Could result from data entry errors or calculation mistakes
- User might not notice that all periods have infinite dates
- Could occur from operations like "max date ever" with no data

**What Needs To Be Fixed:**
```r
# Add validation after conversion
validate_date_values <- function(date_var, var_name) {
  if (any(is.infinite(date_var))) {
    stop(sprintf("%s contains infinite (Inf or -Inf) values. Please provide finite dates.",
                 var_name))
  }
  invisible(TRUE)
}
```

---

#### ISSUE #9: No Validation for NA Values in Exposure Column
**Location:** R/tvexpose.R, Parameter validation section (after line 420)  
**Function:** tvexpose()  
**Risk Level:** HIGH  

**Current Code:**
```r
# Check for NA values in critical date columns
if (any(is.na(exposure_data[[start]]))) {
  stop("start variable in exposure_data contains NA values")
}

# BUT NO CHECK FOR NA IN EXPOSURE VALUE COLUMN!
```

**Problem:**
- Exposure values (e.g., drug types) can contain NAs
- These NAs are then used in all downstream classifications
- Categories with NA might cause type coercion issues
- NA exposure values are ambiguous: does it mean "unexposed" or "missing data"?

**Why It's Critical:**
- Ambiguous NA handling: is NA treated as reference or special category?
- Could silently treat missing as unexposed (type I error) or vice versa
- User needs explicit control over how NAs are handled

**What Needs To Be Fixed:**
```r
# Add to validation
if (any(is.na(exposure_data[[exposure]]))) {
  na_count <- sum(is.na(exposure_data[[exposure]]))
  stop(sprintf(
    "exposure variable '%s' contains %d NA value(s).\nPlease recode NA to specific category or remove rows.",
    exposure,
    na_count
  ))
}
```

---

#### ISSUE #10: No Validation for keepvars Variables
**Location:** R/tvexpose.R, Parameter validation section (after line 420)  
**Function:** tvexpose()  
**Risk Level:** HIGH  

**Current Code:**
```r
# Check required columns exist in master
if (!id %in% names(master)) {
  stop(sprintf("id variable '%s' not found in master dataset", id))
}
# ... other checks ...

# BUT NO CHECK FOR KEEPVARS!
if (!is.null(keepvars)) {
  master_cols <- c(master_cols, keepvars)
}
```

**Problem:**
- If user specifies `keepvars = c("age", "typo_varname")`
- Error occurs later in `select(all_of(master_cols))` with cryptic message
- User doesn't know that "typo_varname" doesn't exist
- Error message doesn't clearly indicate the problem

**Why It's Critical:**
- Typos in keepvars names cause confusing downstream errors
- Error happens far from where user specified the variable
- User must debug to find the variable name typo

**What Needs To Be Fixed:**
```r
# Add validation
validate_keepvars <- function(master, keepvars) {
  if (is.null(keepvars)) return(invisible(TRUE))
  
  missing_vars <- setdiff(keepvars, names(master))
  if (length(missing_vars) > 0) {
    stop(sprintf(
      "Variables in keepvars not found in master:\n  %s",
      paste(missing_vars, collapse = ", ")
    ))
  }
  invisible(TRUE)
}
```

---

#### ISSUE #11: No Validation for Parameter Conflicts
**Location:** R/tvexpose.R, Parameter validation section (after line 420)  
**Function:** tvexpose()  
**Risk Level:** HIGH  

**Current Code:**
```r
# Determine exposure type from parameters
exposure_type <- "timevarying"  # Default
if (evertreated) exposure_type <- "evertreated"
if (currentformer) exposure_type <- "currentformer"
if (!is.null(duration)) exposure_type <- "duration"
if (!is.null(continuousunit) && is.null(duration)) exposure_type <- "continuous"
if (!is.null(recency)) exposure_type <- "recency"

# PROBLEM: If user specifies both evertreated=TRUE and currentformer=TRUE,
# the last one wins (currentformer) but behavior is undefined!
```

**Problem:**
- Multiple exposure type parameters can be specified simultaneously
- Last one wins (due to sequential if statements), but this is confusing
- User might think both parameters are active
- Behavior is undocumented

**Why It's Critical:**
- User confusion about which parameter is actually active
- Easy mistake to specify conflicting parameters
- No warning or error to alert user

**What Needs To Be Fixed:**
```r
# Add validation
validate_no_conflicting_exposure_types <- function(evertreated, currentformer,
                                                    duration, recency, continuousunit) {
  type_flags <- c(
    evertreated = evertreated,
    currentformer = currentformer,
    duration = !is.null(duration),
    recency = !is.null(recency),
    continuous = !is.null(continuousunit)
  )
  
  n_types <- sum(type_flags)
  
  if (n_types > 1) {
    active_types <- names(type_flags)[type_flags]
    stop(sprintf(
      "Only one exposure type can be specified.\nYou specified: %s\nChoose only ONE of: evertreated, currentformer, duration, recency, continuous",
      paste(active_types, collapse = ", ")
    ))
  }
  invisible(TRUE)
}
```

---

#### ISSUE #12: No Validation for Overlapping IDs in tvmerge
**Location:** R/tvmerge.R, Input validation section (after line 470)  
**Function:** tvmerge()  
**Risk Level:** HIGH  

**Current Code:**
```r
# Load datasets if file paths provided
for (i in seq_along(datasets)) {
  if (is.character(datasets[[i]])) {
    # Load from file
  }
  if (!is.data.frame(datasets[[i]])) {
    stop(sprintf("Dataset %d must be a data frame", i))
  }
}

# BUT NO CHECK FOR COMMON IDS ACROSS DATASETS!
```

**Problem:**
- tvmerge requires datasets to have overlapping IDs
- If dataset 1 has IDs {1,2,3} and dataset 2 has IDs {4,5,6}, result is empty
- No error or warning about lack of overlap
- User gets empty output (0 rows) with no explanation

**Why It's Critical:**
- No-overlap scenario produces silent failure (empty output)
- User might assume merge worked but nobody has both exposures
- Hard to debug: user doesn't know why output is empty

**What Needs To Be Fixed:**
```r
# Add validation function
validate_overlapping_ids <- function(datasets, id) {
  all_ids <- lapply(datasets, function(df) unique(df[[id]]))
  
  common_ids <- Reduce(intersect, all_ids)
  
  if (length(common_ids) == 0) {
    stop(sprintf(
      "No common IDs found across all %d datasets.\nDataset 1 has %d IDs, Dataset 2 has %d IDs.\nDatasets must share at least some IDs.",
      length(datasets),
      length(all_ids[[1]]),
      length(all_ids[[2]])
    ))
  }
  
  # Warn if overlap is low
  for (i in seq_along(all_ids)) {
    pct_overlap <- length(common_ids) / length(all_ids[[i]]) * 100
    if (pct_overlap < 50) {
      warning(sprintf(
        "Only %.1f%% of IDs in dataset %d are common across all datasets.",
        pct_overlap, i
      ))
    }
  }
  
  invisible(TRUE)
}
```

---

### CATEGORY 3: EDGE CASES WITHOUT PROPER HANDLING (8 Issues - HIGH/MEDIUM)

#### ISSUE #13: Zero-Length Periods Not Explicitly Documented
**Location:** R/tvexpose.R, Data preparation section (lines 580-625)  
**Function:** tvexpose()  
**Risk Level:** MEDIUM  

**Current Code:**
```r
# Remove invalid periods (start > stop)
invalid_periods <- exp_data %>%
  filter(exp_start > exp_stop)

if (nrow(invalid_periods) > 0) {
  message(sprintf("Warning: Dropping %d periods with start > stop", nrow(invalid_periods)))
  exp_data <- exp_data %>%
    filter(exp_start <= exp_stop)  # This allows exp_start == exp_stop
}
```

**Problem:**
- Zero-length periods (start == stop) are implicitly allowed
- These represent point-in-time events (e.g., single day exposure)
- Not explicitly documented what should happen with these
- Could represent valid point-in-time data or data errors

**Why It's an Issue:**
- Ambiguous handling: valid point-in-time data or error?
- User doesn't know if zero-length periods are expected or indicate problems
- Documentation should explicitly say they're allowed and what they mean

**What Needs To Be Fixed:**
1. Add explicit handling code with comment explaining zero-length periods are valid
2. Add option to filter them out if user wants only multi-day periods
3. Document in function help that zero-length periods (start == stop) are allowed

---

#### ISSUE #14: Large Cartesian Products Without Memory Warning
**Location:** R/tvmerge.R, Lines 735-777 (Cartesian merge section)  
**Function:** tvmerge()  
**Risk Level:** CRITICAL  

**Current Code:**
```r
# Create cartesian product by joining on id only
cartesian <- merged_data %>%
  inner_join(dfk_clean, by = "id_var", relationship = "many-to-many")

# Calculate interval intersection
cartesian <- cartesian %>%
  mutate(
    new_start = pmax(start_var, start_k),
    new_stop = pmin(stop_var, stop_k)
  ) %>%
  # Keep only valid intersections
  filter(new_start <= new_stop, !is.na(new_start), !is.na(new_stop))
```

**Problem:**
- Cartesian join creates all combinations before filtering
- If person has 50 periods in dataset 1 and 50 in dataset 2: 50 × 50 = 2,500 temporary rows
- For 100 persons: 100 × 2,500 = 250,000 temporary rows
- No warning about size or memory usage
- Large Cartesian products can cause out-of-memory crashes

**Why It's Critical:**
- Users can accidentally create millions of rows
- No warning before the operation
- R will crash with cryptic memory error if dataset too large
- No guidance on how to fix the problem

**What Needs To Be Fixed:**
```r
# Before Cartesian join, add:
# Estimate output size
size_est <- estimate_cartesian_size(merged_data, dfk_clean, "id_var")

# Warn if very large
if (size_est$total_rows > 1e6) {
  warning(sprintf(
    "Large Cartesian merge: %.0f rows estimated. This may take several minutes.",
    size_est$total_rows
  ))
}

# Error if extremely large
if (size_est$total_rows > 1e8) {
  stop(sprintf(
    "Cartesian merge would create %s rows (>100 million). Would exhaust memory.",
    format(size_est$total_rows, big.mark = ",")
  ))
}
```

---

#### ISSUE #15: No Guidance on Character Date Input
**Location:** R/tvexpose.R and R/tvmerge.R, date conversion sections  
**Function:** tvexpose(), tvmerge()  
**Risk Level:** HIGH  

**Current Code:**
```r
# No type checking before as.numeric()
mutate(
  study_entry = floor(as.numeric(study_entry)),
  study_exit = ceiling(as.numeric(study_exit))
)

# Character dates like "2020-01-01" silently become NA
```

**Problem:**
- If user provides character dates (common from CSV files), they silently become NA
- No error message to indicate the problem
- Users expect as.numeric() to try parsing the date string
- Should error clearly with instruction to use as.Date() first

**Why It's an Issue:**
- Silent failure: NA propagates through entire analysis
- User has no idea their dates were invalid
- Should provide clear guidance on how to fix

**What Needs To Be Fixed:**
- Implement safe conversion helper (addresses Issue #1-4)
- If input is character, explicitly try as.Date() first
- If that fails, error with clear message suggesting correct format

---

### SUMMARY TABLE: All Issues

| # | Issue | File | Lines | Risk | Category |
|---|-------|------|-------|------|----------|
| 1 | Unsafe date conversion (master entry/exit) | tvexpose.R | 527-528 | CRITICAL | Type Safety |
| 2 | Unsafe date conversion (exposure start/stop) | tvexpose.R | 558-559 | CRITICAL | Type Safety |
| 3 | Unsafe date conversion (tvmerge dataset 1) | tvmerge.R | 618-619 | CRITICAL | Type Safety |
| 4 | Unsafe date conversion (tvmerge output) | tvmerge.R | 796-797 | CRITICAL | Type Safety |
| 5 | No empty master validation | tvexpose.R | ~420 | CRITICAL | Validation |
| 6 | No duplicate ID validation | tvexpose.R | ~420 | CRITICAL | Validation |
| 7 | No ID type mismatch validation | tvexpose.R | ~420 | CRITICAL | Validation |
| 8 | No infinite date validation | tvexpose.R | ~420 | HIGH | Validation |
| 9 | No NA exposure value validation | tvexpose.R | ~420 | HIGH | Validation |
| 10 | No keepvars existence validation | tvexpose.R | ~420 | HIGH | Validation |
| 11 | No conflicting parameter validation | tvexpose.R | ~420 | HIGH | Validation |
| 12 | No overlapping ID validation (tvmerge) | tvmerge.R | ~480 | HIGH | Validation |
| 13 | Zero-length periods undocumented | tvexpose.R | 580-625 | MEDIUM | Edge Case |
| 14 | No Cartesian product memory warning | tvmerge.R | 735-777 | CRITICAL | Performance |
| 15 | No guidance on character dates | both | multiple | HIGH | Type Safety |

---

## RISK ASSESSMENT

### Critical (4 issues)
- **Type-Safe Dates:** 4 locations where silent conversion to NA is possible
- **Cartesian Explosion:** Can cause out-of-memory crashes
- **Impact:** Data integrity compromised, analysis results invalid, silent failures

### High (7 issues)
- **Empty master:** Undetected invalid input
- **Duplicate IDs:** Violates fundamental design assumption
- **ID type mismatch:** Silent merge failure (0 rows)
- **Infinite dates:** Invalid calculations silently propagate
- **NA in exposure:** Ambiguous handling
- **keepvars:** Cryptic errors from typos
- **Parameter conflicts:** Undefined behavior

### Medium (4 issues)
- **Zero-length periods:** Ambiguous documentation
- **Overlapping IDs:** Silent empty output
- **Character dates:** Silent NA conversion
- **Conflicting parameters:** Last wins, confusing behavior

---

## TESTING RECOMMENDATIONS

To verify these issues exist and that fixes work:

1. **Test empty master:** Run tvexpose with 0-row master
2. **Test duplicate IDs:** Run tvexpose with duplicate IDs in master
3. **Test type mismatch:** numeric IDs in master, character in exposure
4. **Test infinite dates:** Use Inf for entry/exit dates
5. **Test character dates:** Pass "2020-01-01" strings instead of Date objects
6. **Test Cartesian explosion:** Merge datasets with 50+ overlapping periods per person
7. **Test conflicting parameters:** Specify evertreated=TRUE and currentformer=TRUE simultaneously

All 15 issues should be addressed before production release.

---

**Audit Completed:** 2025-11-19  
**Next Steps:** Implement fixes from NEXT_STEPS_COMPREHENSIVE_GUIDE.md
