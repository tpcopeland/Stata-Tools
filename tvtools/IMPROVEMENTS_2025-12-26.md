# tvtools Improvement Recommendations

**Date:** 2025-12-26
**Last Updated:** 2025-12-29
**Status:** Under Active Development
**Current Test Status:** All tests passing (87 comprehensive, 146 validation)

---

## Recent Developments (Since Initial Review)

Since this document was created, three new commands have been added to tvtools:

| Command | Version | Purpose |
|---------|---------|---------|
| **tvdiagnose** | 1.0.0 | Data quality diagnostics (coverage, gaps, overlaps) |
| **tvbalance** | 1.0.0 | Covariate balance assessment with SMD and Love plots |
| **tvplot** | 1.0.0 | Exposure visualization (swimlane and person-time plots) |

These additions address item #7 (Missing Help File Examples) partially, and item #8 (Missing Integration Tests) should be expanded to cover these new commands.

---

## Executive Summary

The tvtools package (tvexpose, tvmerge, tvevent) is well-architected for time-varying survival analysis with strong documentation and validation tests. This document identifies prioritized opportunities for code quality improvements, documentation enhancements, and test expansion.

---

## Critical Issues (Address Before Next Release)

### 1. Interval Endpoint Documentation Inconsistency

**Severity:** HIGH
**Type:** Documentation/Design Accuracy

#### Problem

The help files and code contain conflicting descriptions of interval endpoint handling:

**tvevent.ado (Line 26):**
```stata
* 1. Identifies events occurring within intervals (start < date < stop).
```
This describes exclusive endpoints on both sides.

**tvevent.ado (Lines 611, 640):**
```stata
keep if `date' > `startvar' & `date' < `stopvar'
gen byte _valid_split = (`date' > `startvar' & `date' < `stopvar')
```
Code enforces exclusive on both ends.

**tvexpose.ado (Lines 2802, 3178):**
```stata
__thresh_date_`suffix'_`i' > exp_start & __thresh_date_`suffix'_`i' <= exp_stop
```
Code uses exclusive start, inclusive stop (opposite pattern).

**tvevent.ado (Lines 778-781):**
```stata
* Note: Events at interval boundaries (where stop == event date) ARE valid events.
* Previous versions incorrectly filtered these out.
```
Comment contradicts the actual code which uses strict inequality (`<`).

#### Files Affected
- `tvtools/tvevent.ado` (lines 26, 611, 640, 778-781)
- `tvtools/tvexpose.ado` (lines 2802, 2836, 3178, 3199)
- `tvtools/tvevent.sthlp` (line 85)

#### Recommended Actions
1. Define formal endpoint convention in a package-level docstring
2. Audit all interval logic for consistency:
   - Choose: `[start, stop)` (inclusive-exclusive) or `(start, stop]` (exclusive-inclusive)
   - Update ALL code to match chosen convention
3. Add explicit examples in each help file showing boundary behavior
4. Add validation test checking interval endpoint consistency

#### Suggested Documentation Addition
Add to each help file:
```smcl
{pmore}
{bf:Note on interval boundaries:} The commands use closed-open intervals [start, stop).
An event on the stop date IS considered to occur within that interval and will be
flagged if it matches.
```

---

### 2. Silent Data Loss Risk in tvmerge

**Severity:** HIGH
**Type:** Data Quality

#### Problem

tvmerge performs silent ID filtering with only a warning when the `force` option is specified:

**File:** `tvtools/tvmerge.ado` (Lines 759-777)
```stata
if `n_only_merged' > 0 | `n_only_dsk' > 0 {
    if "`force'" == "" {
        * No force option - error out (strict mode)
        noisily di as error _newline "ID mismatch detected between datasets!"
        [... lists IDs ...]
        exit 459
    }
    else {
        * Force option specified - warn and continue
        noisily di as text _newline "Warning: ID mismatch detected..."
        [silently drops mismatched IDs]
    }
}
```

**Impact:**
- User doesn't see final observation count change
- No diff before/after merge
- No option to review dropped IDs
- A user could accidentally lose 30% of their data

#### Files Affected
- `tvtools/tvmerge.ado` (lines 759-805)

#### Recommended Actions
1. After `force` filtering, display summary of dropped IDs (count and sample)
2. Add `batch(#)` option documentation to warn about this behavior
3. Consider requiring explicit `keeponly(id_list)` option instead of `force`
4. Add test case verifying warning messages are shown

---

### 3. Version Number Mismatch

**Severity:** LOW
**Type:** Documentation

#### Problem

Version numbers in different files are out of sync:

| File | Current Version | Should Be |
|------|-----------------|-----------|
| tvexpose.ado | 1.2.0 (2025/12/14) | - |
| tvexpose.sthlp | 1.0.0 (2025-12-02) | 1.2.0 (2025-12-14) |
| tvmerge.ado | 1.0.5 (2025/12/18) | - |
| tvmerge.sthlp | 1.0.4 (2025-12-14) | 1.0.5 (2025-12-18) |
| tvevent.ado | 1.4.0 (2025/12/18) | - |
| tvevent.sthlp | 1.4.0 (2025-12-18) | OK |

#### Files Affected
- `tvtools/tvexpose.sthlp` (line 2)
- `tvtools/tvmerge.sthlp` (line 2)
- `tvtools/tvtools.pkg` (line 6 - Distribution-Date)

#### Recommended Actions
1. Update tvexpose.sthlp to match .ado version (1.2.0, 2025-12-14)
2. Update tvmerge.sthlp to match .ado version (1.0.5, 2025-12-18)
3. Update tvtools.pkg Distribution-Date when files are modified

---

## Important Issues (Address in Next 2 Releases)

### 4. Performance Issue: O(n^2) Overlap Detection

**Severity:** MEDIUM
**Type:** Performance

#### Problem

tvexpose.ado contains nested forvalues loops that iterate through dataset rows for overlap detection:

**File:** `tvtools/tvexpose.ado` (Lines 1419-1438)
```stata
forvalues i = 1/`n_rows' {
    local curr_id = id[`i']
    local curr_start = exp_start[`i']
    local curr_stop = exp_stop[`i']
    local curr_rank = priority_rank[`i']

    * Check if any earlier row (higher priority) overlaps
    forvalues j = 1/`=`i'-1' {
        if id[`j'] == `curr_id' & priority_rank[`j'] < `curr_rank' {
            [...check overlap...]
        }
    }
}
```

**Issues:**
- Nested loops: O(n^2) complexity on n_rows
- Reads data values into macros (slow)
- No vectorization of overlap detection
- Large datasets could take minutes/hours

**Impact:**
For a dataset with 10,000 exposure records:
- Expected iterations: ~50 million comparisons
- Estimated time: 15-30 minutes (vs. <1 minute with vectorized approach)

#### Files Affected
- `tvtools/tvexpose.ado` (lines 1419-1438, 1465-1496)

#### Recommended Actions
1. Replace nested loops with Stata's `by` group processing
2. Use temp variables instead of macro reads for comparison
3. Benchmark before/after on 10K+ row datasets
4. Document expected runtime in help file

#### Example Vectorized Approach
```stata
sort id priority_rank exp_start exp_stop
by id priority_rank: gen byte _overlaps_higher = 0
by id: replace _overlaps_higher = 1 if exp_start < exp_stop[_n-1] ///
    & priority_rank > priority_rank[_n-1]
```

---

### 5. Macro Name Length Validation

**Severity:** MEDIUM
**Type:** Code Reliability

#### Problem

Stata silently truncates macro names longer than 31 characters. User-supplied variable names could cause collisions:

```stata
continuous_exposures_list = "very_long_exposure_variable_name_1"
* If exposure variables > 31 chars, silently truncates!
```

#### Files Affected
- `tvtools/tvexpose.ado` (lines 372-380 - continuous list building)
- `tvtools/tvmerge.ado` (lines 259-276 - duplicate check)

#### Recommended Actions
1. Add validation of user-supplied variable names (max 31 chars)
2. Add note to help files: "Variable names must be 31 characters or fewer"
3. Add test case with edge case variable names

---

### 6. Inconsistent Error Messages & Exit Codes

**Severity:** MEDIUM
**Type:** Code Consistency

#### Problem

Error handling is inconsistent across the three commands:

| Command | Line | Code | Issue |
|---------|------|------|-------|
| tvexpose.ado | 198 | 198 | Generic "invalid syntax" for dosecuts validation |
| tvmerge.ado | 459, 777 | 459 | Same custom code for different errors |
| tvevent.ado | 111, 551 | 111 | Same code for different "variable not found" errors |

**Standard Stata Error Codes:**
- 100 = varlist required
- 109 = type mismatch
- 110 = variable already exists
- 111 = variable not found
- 198 = invalid syntax
- 601 = file not found
- 2000 = no observations

#### Files Affected
- `tvtools/tvexpose.ado` (lines 164-197, 200-214)
- `tvtools/tvmerge.ado` (lines 89-132)
- `tvtools/tvevent.ado` (lines 53-66)

#### Recommended Actions
1. Audit all `exit` statements to use standard codes
2. Create consistent error message format
3. Document custom exit codes if used
4. Add test case for each error condition

---

### 7. Missing Help File Examples

**Severity:** MEDIUM
**Type:** Documentation

#### Missing Examples

**tvexpose.sthlp:**
- No example of `grace()` with categorical specification (e.g., `grace(1=30 2=60)`)
- No example showing `carryforward()` behavior
- No example of `window()` for acute exposure analysis
- No example of competing overlapping exposures (layer vs priority vs split)

**tvmerge.sthlp:**
- No example with 3+ datasets
- No example showing continuous exposure handling
- No example of keep() variable naming (_ds1, _ds2, etc.)
- No example of batch() performance impact

**tvevent.sthlp:**
- No example of wide-format recurring events (hosp1, hosp2, ...)
- No example of eventlabel() with custom competing risk labels
- No example of validateoverlap() output interpretation

#### Files Affected
- `tvtools/tvexpose.sthlp` (Examples section, lines 453-821)
- `tvtools/tvmerge.sthlp` (Examples section, lines 261-602)
- `tvtools/tvevent.sthlp` (Examples section, lines 152-323)

#### Recommended Actions
1. Add example for each major option
2. Show before/after output
3. Include expected error cases

---

## Nice to Have (Future Improvements)

### 8. Missing Integration Tests

**Type:** Test Coverage

#### Current Gaps
- [ ] tvmerge + tvevent together (tv_hrt -> tvmerge -> tvevent)
- [ ] Empty dataset propagation through pipeline
- [ ] Very large dataset stress test (100K+ rows)
- [ ] Unicode/special characters in variable names
- [ ] Missing values in all positions (id, start, stop, exposure, date)

#### Missing Unit Tests for Edge Cases
- [ ] tvexpose: All exposure types with missing values
- [ ] tvmerge: 4+ datasets merge (currently only 2-3 shown)
- [ ] tvevent: Multiple competing risks (3+ compete variables)
- [ ] All commands: Zero-duration periods (start == stop)

#### Missing Error Condition Tests
- [ ] tvmerge with force: Verify data loss messages are shown
- [ ] tvexpose with invalid grace() syntax
- [ ] tvevent with recurring events when compete() also specified
- [ ] All: Commands with if/in conditions (currently not tested)

#### Recommended New Test File
Create `tvtools/test_tvtools_edge_cases.do` to test:

1. **Interval Endpoint Edge Cases:**
   - Event exactly on start date
   - Event exactly on stop date
   - Event one day before start
   - Event one day after stop

2. **Empty/Missing Data:**
   - Empty master dataset
   - Empty using dataset
   - All ID values missing
   - All exposure values missing

3. **Boundary Conditions:**
   - Single person, single period
   - Single person with competing events on same date
   - Dataset with 0 observations after merge
   - Very small time intervals (1-day periods)

4. **Large Data Performance:**
   - 100K unique IDs
   - 1M total observations
   - Benchmark merge speed with different batch() settings

---

### 9. Empty Dataset Handling

**Severity:** LOW
**Type:** Edge Case

#### Problem

Commands handle empty datasets but lack consistent validation:

- tvexpose.ado: No explicit check after filtering
- tvmerge.ado: Line 944 - Fallback creates empty structure but doesn't validate
- tvevent.ado: Lines 306-374 - Handles empty event dataset but produces generic output

#### Recommended Actions
1. Add explicit empty dataset checks at every data transformation
2. Display informative message (e.g., "No intervals produced after merge")
3. Return meaningful return values (e.g., `r(N) = 0`)
4. Add test case: "empty dataset after each filter operation"

---

### 10. Preserve/Restore Efficiency

**Severity:** LOW
**Type:** Performance

#### Problem

tvexpose uses excessive `preserve`/`restore` for temporary operations:

**File:** `tvtools/tvexpose.ado`
- Line 206: Initial preserve
- Multiple preserve/restore within loops (efficiency impact)

#### Recommended Actions
1. Use `tempfile` instead of preserve/restore for long operations
2. Keep preserve/restore only for temporary diagnostic checks
3. Benchmark on 100K+ row dataset

---

## Summary Table: All Findings

| # | Finding | File | Lines | Type | Priority |
|---|---------|------|-------|------|----------|
| 1 | Endpoint inconsistency | tvevent.ado | 26, 611, 640, 778-781 | Design | Critical |
| 1 | Endpoint inconsistency | tvexpose.ado | 2802, 2836, 3178, 3199 | Design | Critical |
| 1 | Endpoint docs | tvevent.sthlp | 85, 145 | Docs | Critical |
| 2 | Silent ID loss | tvmerge.ado | 759-805 | Bug risk | Critical |
| 3 | Version mismatch | tvexpose.sthlp | 2, 844 | Docs | Critical |
| 3 | Version mismatch | tvmerge.sthlp | 2, 640 | Docs | Critical |
| 4 | O(n^2) loops | tvexpose.ado | 1419-1438, 1465-1496 | Perf | Important |
| 5 | Macro truncation | tvexpose.ado | 372-380 | Risk | Important |
| 5 | Macro truncation | tvmerge.ado | 259-276 | Risk | Important |
| 6 | Error codes | tvexpose.ado | 164-197, 200-214 | QA | Important |
| 6 | Error codes | tvmerge.ado | 89-132 | QA | Important |
| 6 | Error codes | tvevent.ado | 53-66 | QA | Important |
| 7 | Missing examples | tvexpose.sthlp | 453-821 | Docs | Important |
| 7 | Missing examples | tvmerge.sthlp | 261-602 | Docs | Important |
| 7 | Missing examples | tvevent.sthlp | 152-323 | Docs | Important |
| 8 | Integration tests | - | - | Test | Nice to have |
| 9 | Empty dataset handling | All .ado files | Various | Edge case | Nice to have |
| 10 | Preserve/restore | tvexpose.ado | 206+ | Perf | Nice to have |

---

## Quick Wins (Can Be Done Immediately)

1. **Sync help file versions** - 5 minute fix
2. **Add post-merge summary** when `force` drops IDs - show count and sample
3. **Document endpoint convention** - add note to each help file

## New Commands: Items to Address

The following items should be considered for the new commands (tvdiagnose, tvbalance, tvplot):

### tvdiagnose
- [ ] Add transition matrix report (exposure switching patterns)
- [ ] Add temporal trends in coverage
- [ ] Export diagnostics to CSV/Excel option
- [ ] Integration tests with other commands

### tvbalance
- [ ] Time-varying balance assessment (SMD at each time point)
- [ ] Variance ratio diagnostics
- [ ] Support for continuous exposures (not just binary/categorical)
- [ ] Integration with tvweight (future command)

### tvplot
- [ ] Event markers on swimlane plots
- [ ] Calendar-time axis option
- [ ] Aggregate summary panels
- [ ] Interactive HTML export option
- [ ] Integration tests with tvexpose output

---

## Conclusion

The tvtools package demonstrates strong engineering practices (comprehensive validation tests, clear code structure, good error handling in most areas). The identified improvements are primarily:

1. **Alignment issues** (endpoint documentation/code mismatch)
2. **Edge case handling** (silent data loss, empty datasets)
3. **Performance optimization** (O(n^2) overlap detection)
4. **Documentation completeness** (examples for advanced options)

All improvements are actionable with clear file locations and line numbers provided.

---

**Reviewed by:** Claude Code
**Test Status at Review:** 87/87 comprehensive tests passing, 146/146 validation tests passing
