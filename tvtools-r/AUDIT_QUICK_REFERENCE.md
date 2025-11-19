# AUDIT QUICK REFERENCE: TVTools-R Production Fixes

**Document Date:** 2025-11-19  
**Target Implementation:** ASAP (before production release)  
**Estimated Effort:** 1-2 weeks

---

## CRITICAL ISSUES REQUIRING IMMEDIATE FIXES

### Type-Safe Date Conversions (4 CRITICAL issues)

**Files Affected:** 
- R/tvexpose.R (2 locations)
- R/tvmerge.R (2 locations)

**Lines to Fix:**
1. tvexpose.R:527-528 - Master entry/exit dates
2. tvexpose.R:558-559 - Exposure start/stop dates  
3. tvmerge.R:618-619 - Dataset 1 dates
4. tvmerge.R:796-797 - Output date conversion

**Current Problem:**
```r
# UNSAFE - silently converts "2020-01-01" to NA!
mutate(study_entry = floor(as.numeric(study_entry)))
```

**Fix Pattern:**
1. Add helper function: `convert_to_numeric_date(date_var, var_name)`
2. Add validator: `validate_date_values(date_var, var_name)`
3. Replace all as.numeric() calls with safe conversion
4. Add validation after conversion

**Test with:**
- Character dates: "2020-01-01"
- Date objects: as.Date("2020-01-01")
- Numeric dates: 18262
- Infinite dates: Inf, -Inf

---

### Input Validation (8 CRITICAL/HIGH issues)

**Location:** R/tvexpose.R parameter validation (after line 420) and R/tvmerge.R (after line 470)

**Missing Validations:**
1. ✗ Empty master dataset (0 rows)
2. ✗ Duplicate IDs in master
3. ✗ ID type mismatch (numeric vs character)
4. ✗ Infinite date values (Inf)
5. ✗ NA values in exposure column
6. ✗ keepvars variables don't exist
7. ✗ Conflicting exposure type parameters
8. ✗ No overlapping IDs across tvmerge datasets

**Implementation Checklist:**
```
[ ] Add validate_master_dataset()
[ ] Add validate_exposure_dataset()
[ ] Add validate_id_type_match()
[ ] Add validate_date_values()
[ ] Add validate_keepvars()
[ ] Add validate_no_conflicting_exposure_types()
[ ] Add validate_overlapping_ids() for tvmerge
[ ] Call all validation functions in correct order
```

**Sample Error Messages Needed:**
- "master dataset is empty (0 rows)"
- "master dataset has N duplicate ID(s): [IDs listed]"
- "ID variable has different types: master=numeric, exposure_data=character"
- "entry variable contains infinite (Inf) values"
- "exposure variable contains NA values"
- "Variables in keepvars not found: [variable names]"
- "Only one exposure type can be specified. You specified: [types]"
- "No common IDs found across datasets"

---

### Cartesian Product Memory Explosion (1 CRITICAL issue)

**Location:** R/tvmerge.R lines 735-777

**Current Problem:**
```r
# If person has 50 periods in each dataset:
# 50 × 50 = 2,500 rows per person
# 100 persons × 2,500 = 250,000 temporary rows
# No warning before operation starts!
cartesian <- merged_data %>%
  inner_join(dfk_clean, by = "id_var", relationship = "many-to-many")
```

**Fix:**
1. Add function: `estimate_cartesian_size(merged_data, dfk_clean, id_var)`
2. Calculate: total output rows, max per person, memory estimate
3. Warn if >1M rows
4. Error if >100M rows (would exhaust memory)
5. Provide clear guidance on how to fix

**Warning Threshold:** >1,000,000 rows
**Error Threshold:** >100,000,000 rows

---

## IMPLEMENTATION PHASES

### Phase 1: Type Safety (Priority 1)
**Duration:** 4-6 hours  
**Files:** tvexpose.R, tvmerge.R

1. Create `convert_to_numeric_date()` helper
2. Create `validate_date_values()` helper
3. Replace all 4 unsafe as.numeric() calls
4. Test with edge case data

**Verify with:**
- Empty master test
- Single person test
- Character date test
- Infinite date test

### Phase 2: Input Validation (Priority 2)
**Duration:** 6-8 hours  
**Files:** tvexpose.R, tvmerge.R

1. Create 7 validation functions
2. Add calls in correct order
3. Ensure error messages are clear and actionable
4. Test with all edge case datasets

**Verify with:**
- Empty master
- Duplicate IDs
- Type mismatch IDs
- Infinite dates
- NA exposure values
- keepvars typos
- Conflicting parameters
- No overlapping IDs

### Phase 3: Performance Warnings (Priority 3)
**Duration:** 2-3 hours  
**Files:** tvmerge.R

1. Create `estimate_cartesian_size()` function
2. Add warnings before Cartesian join
3. Add errors for >100M rows
4. Test with large overlapping datasets

**Verify with:**
- Large dataset with many overlapping periods
- 50 periods × 50 periods per person

---

## TESTING CHECKLIST

### Before Making Changes
```bash
cd /home/user/Stata-Tools/tvtools-r
Rscript tests/generate_comprehensive_test_data.R
Rscript -e "devtools::test()"
```

### After Each Phase
```bash
# Run edge case tests
Rscript tests/test_edge_cases_comprehensive.R

# Run full test suite
Rscript -e "devtools::test()"

# Run R CMD check
R CMD build .
R CMD check tvtools_*.tar.gz
```

### Expected Test Results
After all fixes:
- All 15+ edge case tests should PASS
- All existing tests should still PASS
- R CMD check should have no ERRORS or WARNINGS

---

## CODE LOCATIONS REQUIRING CHANGES

### tvexpose.R
```
Line 420-469:   Parameter validation section - ADD NEW VALIDATIONS
Line 527-528:   Master date conversion - REPLACE WITH SAFE CONVERSION
Line 558-559:   Exposure date conversion - REPLACE WITH SAFE CONVERSION
Line 580-625:   Data preparation section - ADD COMMENT ON ZERO-LENGTH PERIODS
```

### tvmerge.R
```
Line 470-480:   Input validation section - ADD NEW VALIDATIONS
Line 618-619:   Dataset 1 date conversion - REPLACE WITH SAFE CONVERSION
Line 735-777:   Cartesian merge section - ADD MEMORY WARNING
Line 796-797:   Output date conversion - REPLACE WITH SAFE CONVERSION
```

---

## QUICK COMMAND REFERENCE

```bash
# Setup
cd /home/user/Stata-Tools/tvtools-r

# Generate test data
Rscript tests/generate_comprehensive_test_data.R

# Run tests
Rscript -e "devtools::test()"
Rscript tests/test_edge_cases_comprehensive.R

# Check package
R CMD build .
R CMD check tvtools_*.tar.gz

# View audit report
less CODE_AUDIT_REPORT_2025-11-19.md

# View implementation guide
less NEXT_STEPS_COMPREHENSIVE_GUIDE.md
```

---

## KEY FILES

**Audit Reports:**
- `CODE_AUDIT_REPORT_2025-11-19.md` - Complete audit with all issues
- `AUDIT_QUICK_REFERENCE.md` - This file
- `NEXT_STEPS_COMPREHENSIVE_GUIDE.md` - Detailed implementation guide with code

**Test Files:**
- `tests/test_edge_cases_comprehensive.R` - Edge case test suite
- `tests/generate_comprehensive_test_data.R` - Test data generator

**Source Files to Modify:**
- `R/tvexpose.R` - Primary function
- `R/tvmerge.R` - Secondary function

---

## EXPECTED OUTCOME

After implementing all fixes:

1. **Type Safety:** No silent NA conversions from date mismatches
2. **Input Validation:** Clear errors for all invalid inputs
3. **Edge Cases:** All edge case tests passing
4. **Performance:** Memory warnings for large Cartesian merges
5. **User Experience:** Clear, actionable error messages
6. **Code Quality:** Comprehensive validation and error handling

**Package Ready for Production:** YES

---

**Last Updated:** 2025-11-19  
**Reference Documents:** See CODE_AUDIT_REPORT_2025-11-19.md for complete details
