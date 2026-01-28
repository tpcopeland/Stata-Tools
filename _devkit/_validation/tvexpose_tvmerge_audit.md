# tvexpose and tvmerge Boundary Audit

**Date**: 2025-12-18
**Author**: Claude Code
**Context**: Following the tvevent v1.3.4 boundary bug fix, audit of tvexpose and tvmerge for similar issues

---

## Executive Summary

| Command | Boundary Bug Found | Action Required |
|---------|-------------------|-----------------|
| tvexpose | **No** | None |
| tvmerge | **No** (minor cosmetic issue) | Optional |

Both commands correctly handle boundary conditions in their core logic.

---

## tvexpose Audit

### Methodology
Reviewed `tvexpose.ado` for boundary handling in interval splitting logic.

### Key Code Review

**Line 556 - Split point iteration:**
```stata
forvalues i = 1/`n_splits' {
    local sp = split_points[`i', 1]
```

**Lines 560-562 - Interval boundary check:**
```stata
if `sp' > start & `sp' < stop {
    // Split only if strictly inside interval
}
```

**Lines 564-565 - New interval boundaries:**
```stata
local new_start = start
local new_stop = `sp' - 1
```

### Analysis

The boundary handling is **mathematically correct**:

1. **Split points** are defined as `exp_start` (exposure begins) and `exp_stop + 1` (day after exposure ends)

2. **Strict inequality** (`sp > start & sp < stop`) is correct because:
   - Split points mark the START of new states
   - A split at `exp_start` creates `[..., exp_start-1]` and `[exp_start, ...]`
   - This ensures exposure is captured correctly

3. **No off-by-one error**: The `sp - 1` in `new_stop` combined with the split point definitions ensures:
   - Pre-exposure period: `[original_start, exp_start - 1]`
   - Exposure period: `[exp_start, exp_stop]`
   - Post-exposure: `[exp_stop + 1, original_stop]`

### Conclusion

**No bugs found.** The strict inequality is intentional and correct for split-point-based interval splitting.

---

## tvmerge Audit

### Methodology
Reviewed `tvmerge.ado` for boundary handling in interval intersection logic.

### Key Code Review

**Lines 861-865 - Core intersection logic:**
```stata
by `idvar': gen double new_start = max(start[_n-1], start) if _n > 1
by `idvar': gen double new_stop = min(stop[_n-1], stop) if _n > 1
// ...
keep if new_start <= new_stop
```

### Analysis

The core merge logic is **correct**:

1. **Intersection calculation**: `max(start1, start2)` to `min(stop1, stop2)` is standard interval intersection

2. **Validity check**: `new_start <= new_stop` correctly allows:
   - Multi-day intersections: `new_start < new_stop`
   - **Single-day intersections**: `new_start == new_stop`

3. **Verified by test**: Created `test_boundary_edge.do` with:
   - Dataset 1: `[100, 200]`
   - Dataset 2: `[200, 300]`
   - Result: Single-day intersection `[200, 200]` correctly preserved with both exposures

### Minor Cosmetic Issue

**Lines 484, 686, 1019 - Diagnostic overlap warnings:**
```stata
by `startvar': gen byte _overlap = `startvar' < `stopvar'[_n-1] if _n > 1
```

This uses `<` instead of `<=`, so warnings about overlapping intervals miss single-day overlaps (where stop of one = start of next). This is cosmetic only - it affects diagnostic messages, not merge results.

**Recommendation**: Low priority fix. The overlap detection in warnings could use `<=` for completeness, but this doesn't affect data correctness.

### Conclusion

**No critical bugs found.** Core intersection logic correctly handles all boundary cases including single-day overlaps.

---

## Test Coverage

### Existing Tests
The validation suite `validation_tvtools_boundary.do` includes:
- Tests 7.1-7.2: tvexpose boundary handling
- The 13 tests in the file cover various boundary scenarios

### New Test
Created `test_boundary_edge.do` to specifically verify tvmerge single-day intersection handling.

---

## Comparison with tvevent Bug

The tvevent v1.3.4 bug was different in nature:

| Aspect | tvevent Bug | tvexpose/tvmerge |
|--------|-------------|------------------|
| Issue | Explicitly filtered out boundary events | N/A - no explicit filter |
| Code | `replace event = 0 if stop == _orig_stop` | Uses correct inequality |
| Result | Events at stop boundaries were missed | Boundaries correctly handled |

The tvevent bug was an explicit incorrect filter, while tvexpose and tvmerge use standard interval arithmetic that is inherently correct.

---

## Summary

1. **tvexpose**: No bugs. Strict inequality in split detection is correct given how split points are defined.

2. **tvmerge**: No bugs in core logic. Minor cosmetic issue in diagnostic warnings (could use `<=` instead of `<` for overlap detection).

3. **Risk Assessment**: Low. Both commands use mathematically correct interval operations.
