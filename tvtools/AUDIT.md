# tvtools Audit Report

**Date:** 2025-12-01
**Auditor:** Claude (Opus 4)
**Scope:** Full code review of tvtools package (tvexpose, tvmerge, tvevent)
**Status:** ✅ ALL FIXES IMPLEMENTED

---

## Summary

After thorough review of all `.ado`, `.dlg`, `.sthlp`, and documentation files, **one critical documentation error** was identified that would cause user commands to fail. No critical Stata syntax errors were found in the executable code.

**All fixes have been implemented and package version updated to v 4.**

---

## Issue #1: Incorrect Variable Names in tvmerge Examples (CRITICAL)

### Affected Files
- `tvtools/tvmerge.sthlp` (15 occurrences)
- `tvtools/README.md` (10 occurrences)
- `tvtools/tvevent.sthlp` (1 occurrence)
- `tvtools/tvtools_functionality.md` (3 occurrences)

### Description

The tvmerge examples show inconsistent variable names that would cause commands to fail. When tvexpose creates output datasets, the start/stop date variables retain their original names from the input dataset. However, all tvmerge examples incorrectly use the same variable names for both datasets.

### Example of the Error

The documentation shows:

```stata
* Step 1: Create HRT dataset (from hrt.dta with rx_start, rx_stop)
tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ...
    saveas(tv_hrt.dta) replace

* Step 2: Create DMT dataset (from dmt.dta with dmt_start, dmt_stop)
tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ...
    saveas(tv_dmt.dta) replace

* Step 3: Merge (INCORRECT - uses wrong variable names for second dataset)
tvmerge tv_hrt tv_dmt, id(id) ///
    start(rx_start rx_start) stop(rx_stop rx_stop) ///    <-- ERROR
    exposure(tv_exposure tv_exposure)
```

The `tv_dmt.dta` file has variables named `dmt_start` and `dmt_stop`, NOT `rx_start` and `rx_stop`.

### Correct Syntax

```stata
tvmerge tv_hrt tv_dmt, id(id) ///
    start(rx_start dmt_start) stop(rx_stop dmt_stop) ///    <-- CORRECT
    exposure(tv_exposure tv_exposure)
```

### Lines to Fix

#### tvmerge.sthlp
| Line | Incorrect | Correct |
|------|-----------|---------|
| 313 | `start(rx_start rx_start) stop(rx_stop rx_stop)` | `start(rx_start dmt_start) stop(rx_stop dmt_stop)` |
| 341 | `start(rx_start rx_start) stop(rx_stop rx_stop)` | `start(rx_start dmt_start) stop(rx_stop dmt_stop)` |
| 374 | `start(rx_start rx_start) stop(rx_stop rx_stop)` | `start(rx_start dmt_start) stop(rx_stop dmt_stop)` |
| 390 | `start(rx_start rx_start) stop(rx_stop rx_stop)` | `start(rx_start dmt_start) stop(rx_stop dmt_stop)` |
| 405 | `start(rx_start rx_start) stop(rx_stop rx_stop)` | `start(rx_start dmt_start) stop(rx_stop dmt_stop)` |
| 428 | `start(rx_start rx_start rx_start)` | `start(rx_start dmt_start rx_start)` |
| 460 | `start(rx_start rx_start) stop(rx_stop rx_stop)` | `start(rx_start dmt_start) stop(rx_stop dmt_stop)` |
| 475 | `start(rx_start rx_start) stop(rx_stop rx_stop)` | `start(rx_start dmt_start) stop(rx_stop dmt_stop)` |
| 490 | `start(rx_start rx_start) stop(rx_stop rx_stop)` | `start(rx_start dmt_start) stop(rx_stop dmt_stop)` |
| 522 | `start(rx_start rx_start) stop(rx_stop rx_stop)` | `start(rx_start dmt_start) stop(rx_stop dmt_stop)` |
| 551 | `start(rx_start rx_start) stop(rx_stop rx_stop)` | `start(rx_start dmt_start) stop(rx_stop dmt_stop)` |
| 584 | `start(rx_start rx_start) stop(rx_stop rx_stop)` | `start(rx_start dmt_start) stop(rx_stop dmt_stop)` |
| 590 | `start(rx_start rx_start) stop(rx_stop rx_stop)` | `start(rx_start dmt_start) stop(rx_stop dmt_stop)` |
| 596 | `start(rx_start rx_start) stop(rx_stop rx_stop)` | `start(rx_start dmt_start) stop(rx_stop dmt_stop)` |

#### README.md
| Line | Incorrect | Correct |
|------|-----------|---------|
| 411 | `start(rx_start rx_start) stop(rx_stop rx_stop)` | `start(rx_start dmt_start) stop(rx_stop dmt_stop)` |
| 433 | `start(rx_start rx_start) stop(rx_stop rx_stop)` | `start(rx_start dmt_start) stop(rx_stop dmt_stop)` |
| 460 | `start(rx_start rx_start) stop(rx_stop rx_stop)` | `start(rx_start dmt_start) stop(rx_stop dmt_stop)` |
| 472 | `start(rx_start rx_start) stop(rx_stop rx_stop)` | `start(rx_start dmt_start) stop(rx_stop dmt_stop)` |
| 503 | `start(rx_start rx_start rx_start)` | `start(rx_start dmt_start rx_start)` |
| 514 | `start(rx_start rx_start) stop(rx_stop rx_stop)` | `start(rx_start dmt_start) stop(rx_stop dmt_stop)` |
| 520 | `start(rx_start rx_start) stop(rx_stop rx_stop)` | `start(rx_start dmt_start) stop(rx_stop dmt_stop)` |
| 526 | `start(rx_start rx_start) stop(rx_stop rx_stop)` | `start(rx_start dmt_start) stop(rx_stop dmt_stop)` |
| 757 | `start(rx_start rx_start) stop(rx_stop rx_stop)` | `start(rx_start dmt_start) stop(rx_stop dmt_stop)` |
| 881 | `start(rx_start rx_start)` | `start(rx_start dmt_start)` |

#### tvevent.sthlp
| Line | Incorrect | Correct |
|------|-----------|---------|
| 269 | `start(rx_start rx_start) stop(rx_stop rx_stop)` | `start(rx_start dmt_start) stop(rx_stop dmt_stop)` |

#### tvtools_functionality.md
| Line | Incorrect | Correct |
|------|-----------|---------|
| 154 | `start(rx_start rx_start)` | `start(rx_start dmt_start)` |
| 197 | `start(rx_start rx_start) stop(rx_stop rx_stop)` | `start(rx_start dmt_start) stop(rx_stop dmt_stop)` |
| 325 | `start(rx_start rx_start) stop(rx_stop rx_stop)` | `start(rx_start dmt_start) stop(rx_stop dmt_stop)` |

---

## Code Quality Notes (Non-Critical)

### Items Verified as Correct

1. **Stata macro syntax**: All backtick/quote usage for local macros is correct
2. **Dialog spacing**: Follows the +15/+20/+25 conventions properly
3. **marksample usage**: Properly implemented in all .ado files
4. **Error handling**: Appropriate use of capture/confirm statements
5. **Variable renaming logic**: The id/start/stop variable restoration at end of tvexpose.ado is correct
6. **Version declarations**: Consistent use of `version 16.0` for compatibility
7. **Package metadata**: tvtools.pkg and stata.toc versions are synchronized (v 3)

---

## Recommended Actions

1. **Fix all instances** of incorrect variable names in tvmerge examples (29 total occurrences)
2. **Update package version** after fixes:
   - Increment `v 3` to `v 4` in tvtools.pkg and stata.toc
   - Update Distribution-Date to 20251201 in tvtools.pkg
3. **Verify README versions** match across package and main repository README.md

---

## Verification Steps After Fixes

After implementing fixes, verify with:

```stata
* Create test datasets as shown in examples
use cohort, clear
tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///
    exposure(hrt_type) reference(0) ///
    entry(study_entry) exit(study_exit) saveas(tv_hrt.dta) replace

use cohort, clear
tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(study_entry) exit(study_exit) saveas(tv_dmt.dta) replace

* Verify corrected tvmerge syntax works
tvmerge tv_hrt tv_dmt, id(id) ///
    start(rx_start dmt_start) stop(rx_stop dmt_stop) ///
    exposure(tv_exposure tv_exposure)
```

---

**End of Audit Report**
