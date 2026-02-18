# Phase 1: Test Baseline Results (2026-02-18)

## Summary

| Category | Passed | Failed | Notes |
|----------|--------|--------|-------|
| Functional Tests | 6/10 | 4/10 | 3 path failures, 1 data issue |
| Validation Tests | 3/6 | 3/6 | r(199) capture block issues |
| Mathematical Tests | 7/7 | 0/7 | ALL PASS (first run ever!) |
| **Total** | **16/23** | **7/23** | |

## Functional Tests Detail

| Test | Result | Notes |
|------|--------|-------|
| test_tvexpose.do | PASS (61/61) | All assertions pass |
| test_tvmerge.do | FAIL | r(601) on large dataset tests (missing test data) |
| test_tvevent.do | FAIL | 1 failure: "Event on interval boundary" (r(199)) |
| test_tvpipeline.do | FAIL | Path/data creation issues |
| test_tvtrial.do | PASS | All pass |
| test_tvestimate.do | PASS | All pass |
| test_tvweight.do | PASS | All pass |
| test_tvtools_secondary.do | PASS | All pass |
| test_tvtools_comprehensive.do | PASS | All pass |
| test_tvage_fixes.do | PASS (12/12) | All pass |

## Validation Tests Detail

| Test | Result | Notes |
|------|--------|-------|
| validation_tvexpose.do | FAIL | r(199) in capture blocks; commands work when isolated |
| validation_tvmerge.do | FAIL | r(199) in capture blocks; same pattern |
| validation_tvevent.do | PASS | All pass |
| validation_tvpipeline.do | FAIL | Test 3.1 return value mismatch |
| validation_tvestimate.do | PASS | All pass |
| validation_tvweight.do | PASS | All pass |

## Mathematical Validation Tests (NEVER RUN BEFORE)

| Test | Result | Tests |
|------|--------|-------|
| validation_tvexpose_mathematical.do | PASS | 10/10 |
| validation_tvevent_mathematical.do | PASS | 5/5 |
| validation_tvmerge_mathematical.do | PASS | 3/3 |
| validation_tvbalance_mathematical.do | PASS | 4/4 |
| validation_tvage_mathematical.do | PASS | 4/4 |
| validation_tvsensitivity_mathematical.do | PASS | 6/6 |
| validation_tvweight_mathematical.do | PASS | 3/3 |

## Known Issues Identified

1. **Path issue**: Older tests reference `_testing/data/` and `_validation/data/` at repo root
   - Fix: Created symlinks to `_devkit/_testing/` and `_devkit/_validation/`

2. **tvpipeline bug (confirmed)**: Line 387 calls `tvplot` with wrong options
   - Current: `type(swimlane) nmax(20)`
   - Should be: `swimlane sample(20)`

3. **validation_tvpipeline test 3.1**: Return value mismatch (error 9)
   - Needs investigation

4. **validation_tvexpose/tvmerge**: r(199) in capture blocks
   - Commands work correctly when run individually
   - Issue appears to be test infrastructure, not code bugs

5. **test_tvmerge**: Large dataset tests fail with r(601) - missing test data files
