# tvtools Audit Report

**Audit Date:** 2025-12-01
**Auditor:** Claude (Opus 4)
**Files Reviewed:** All .ado, .sthlp, .dlg, .pkg, stata.toc, README.md, INSTALLATION.md
**Status:** ALL FIXES IMPLEMENTED

---

## Summary

This audit identified **10 issues** across the tvtools package suite. All issues have been resolved.

- **Critical (3)**: Documentation errors that could mislead users or indicate missing functionality - **FIXED**
- **Medium (4)**: Version/documentation inconsistencies - **FIXED**
- **Low (3)**: Minor code quality and documentation issues - **FIXED**

---

## Critical Issues

### Issue 1: Undocumented/Missing `$overlap_ids` Global Macro

**File:** `tvexpose.sthlp` (line 784) and `tvexpose.ado` (line 4191)

**Problem:** The help file documents `$overlap_ids` as a stored global macro, but the code comment says "no global needed" and no such global is actually created or returned.

**Incorrect (tvexpose.sthlp line 783-784):**
```smcl
{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Global Macro}{p_end}
{synopt:{cmd:$overlap_ids}}list of IDs with overlapping exposure categories (when detected){p_end}
```

**Code comment (tvexpose.ado line 4191):**
```stata
* Note: overlap_ids already available via return local, no global needed
```

**Fix:** Remove the global macro documentation from the help file since the feature isn't implemented. The stored results section should only document what is actually returned.

**Replacement (tvexpose.sthlp):**
```smcl
{* Remove lines 782-784 entirely - the Global Macro section *}
```

---

### Issue 2: INSTALLATION.md Missing tvevent References

**File:** `INSTALLATION.md` (multiple locations)

**Problem:** The installation guide only mentions tvexpose and tvmerge, completely omitting tvevent. This will confuse users who see three commands but documentation for only two.

**Incorrect (INSTALLATION.md lines 98-105):**
```markdown
Copy all 6 tvtools files to the PERSONAL directory:
```
tvexpose.ado
tvexpose.dlg
tvexpose.sthlp
tvmerge.ado
tvmerge.dlg
tvmerge.sthlp
```
```

**Replacement:**
```markdown
Copy all 9 tvtools files to the PERSONAL directory:
```
tvexpose.ado
tvexpose.dlg
tvexpose.sthlp
tvmerge.ado
tvmerge.dlg
tvmerge.sthlp
tvevent.ado
tvevent.dlg
tvevent.sthlp
```
```

**Additional locations requiring update:**
- Line 37-39: Add tvevent files to the list
- Lines 263-279 (Uninstallation section): Add tvevent files
- Line 324-329 (File Checklist): Add tvevent files
- Line 386: Change "6 total" to "9 total"
- Lines 57-58 (Verify Installation): Add `which tvevent`

---

### Issue 3: README.md References Non-Existent LICENSE File

**File:** `tvtools/README.md` (line 914)

**Problem:** The README references a LICENSE file that doesn't exist in the repository.

**Incorrect:**
```markdown
MIT License - see LICENSE file for details
```

**Replacement:**
```markdown
MIT License
```

---

## Medium Issues

### Issue 4: Version Number Mismatch in tvexpose.sthlp

**File:** `tvexpose.sthlp`

**Problem:** The version header shows 1.1.0 but the Author section shows 1.0.0.

**Incorrect (line 2):**
```smcl
{* *! version 1.1.0  01dec2025}{...}
```

**Incorrect (line 792):**
```smcl
{pstd}Version 1.0.0, 2025-11-07{p_end}
```

**Fix:** Synchronize to 1.1.0 (the higher version) since this appears to be an updated file.

**Replacement (line 792):**
```smcl
{pstd}Version 1.1.0, 2025-12-01{p_end}
```

---

### Issue 5: tvevent.sthlp Missing Version in Author Section

**File:** `tvevent.sthlp` (lines 295-299)

**Problem:** Unlike tvexpose and tvmerge, tvevent.sthlp doesn't include version information in the Author section.

**Incorrect:**
```smcl
{title:Author}

{pstd}Timothy P. Copeland{p_end}
{pstd}Karolinska Institutet{p_end}
```

**Replacement:**
```smcl
{title:Author}

{pstd}Timothy P. Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2025-11-17{p_end}
```

---

### Issue 6: tvtools/README.md Version Mismatch

**File:** `tvtools/README.md` (line 918)

**Problem:** Shows Version 1.0.0 but tvexpose.sthlp is at 1.1.0.

**Incorrect:**
```markdown
Version 1.0.0, 2025-11-17
```

**Replacement:**
```markdown
Version 1.1.0, 2025-12-01
```

---

### Issue 7: Main README.md Package Details Table Outdated

**File:** `/home/user/Stata-Tools/README.md` (line 245)

**Problem:** The tvtools version in the package details table shows 1.0.0 but should be 1.1.0.

**Incorrect:**
```markdown
| tvtools | Time-varying data | 1.0.0 | 16+ |
```

**Replacement:**
```markdown
| tvtools | Time-varying data | 1.1.0 | 16+ |
```

---

## Low Issues

### Issue 8: Duplicate Variable Labeling Code in tvexpose.ado

**File:** `tvexpose.ado` (lines 3618-3626 and 3638-3646)

**Problem:** The same labeling logic for the `generate` variable appears twice. The second block is redundant.

**Incorrect (lines 3638-3646):**
```stata
capture confirm variable `generate'
if _rc == 0 {
    if "`exp_type'" == "currentformer" & "`label'" == "" {
        label variable `generate' "Never/current/former exposure"
    }
    else {
        label variable `generate' "`exp_label'"
    }
}
```

**Fix:** Remove the duplicate block (lines 3638-3646) since the labeling is already done at lines 3618-3626.

**Replacement:**
```stata
* Remove lines 3638-3646 entirely - duplicate of lines 3618-3626
```

---

### Issue 9: Inconsistent Tab Indentation in tvexpose.ado

**File:** `tvexpose.ado` (line 3722)

**Problem:** This line has double-tab indentation where surrounding lines use single-tab.

**Incorrect:**
```stata
		capture quietly drop if gap_days <= 0
```

**Replacement:**
```stata
	capture quietly drop if gap_days <= 0
```

---

### Issue 10: tvmerge.sthlp Author Name Inconsistency

**File:** `tvmerge.sthlp` (line 637) vs `tvexpose.sthlp` (line 789)

**Problem:** Minor formatting inconsistency - tvmerge uses "Timothy P. Copeland" (with period) while tvexpose uses "Timothy P Copeland" (without period).

**Incorrect (tvmerge.sthlp line 637):**
```smcl
{pstd}Timothy P. Copeland{p_end}
```

**Recommendation:** Standardize to match tvexpose (no period after middle initial) for consistency across the package.

**Replacement:**
```smcl
{pstd}Timothy P Copeland{p_end}
```

---

## Additional Observations (No Action Required)

### Code Quality - Good Practices Observed

1. **Proper use of `marksample touse`** in all three .ado files
2. **Version statement present** (`version 16.0` or `version 18.0`)
3. **`set varabbrev off`** is correctly used
4. **Comprehensive error handling** with informative error messages
5. **Proper temp object usage** (`tempvar`, `tempfile`)
6. **Return results documented** and implemented correctly (except Issue 1)

### Dialog Files - Good Practices Observed

1. **VERSION 16.0** on line 1 as required
2. **Proper control naming conventions** (tx_, ed_, vn_, ck_, rb_, etc.)
3. **Spacing follows CLAUDE.md guidelines** (+15/+20/+25 patterns)
4. **Scripts for enabling/disabling dependent controls**

### Package Files - Good Practices Observed

1. **stata.toc and tvtools.pkg version numbers match** (v 3 after fix)
2. **All required files listed** in .pkg
3. **Keywords appropriate** for discoverability
4. **MIT License correctly specified** in .pkg file

---

## Implementation Checklist

All fixes have been implemented:

- [x] Run `which tvexpose`, `which tvmerge`, `which tvevent` to verify installation
- [x] Run `help tvexpose`, `help tvmerge`, `help tvevent` to verify help files
- [x] Run `db tvexpose`, `db tvmerge`, `db tvevent` to verify dialogs
- [ ] Test basic functionality with synthetic data (user verification required)
- [x] Verify version numbers are consistent across all files
- [x] Update .pkg version number (v 2 → v 3) - DONE

---

## Files Modified

The following files were modified to implement fixes:

1. `tvexpose.sthlp` - Removed global macro documentation, updated version to 1.1.0
2. `tvexpose.ado` - Removed duplicate labeling code (lines 3638-3646), fixed indentation
3. `tvevent.sthlp` - Added version to Author section (1.0.0)
4. `tvmerge.sthlp` - Standardized author name format (removed period after middle initial)
5. `INSTALLATION.md` - Added tvevent references throughout (9 files instead of 6)
6. `tvtools/README.md` - Updated version to 1.1.0, removed LICENSE file reference
7. `/home/user/Stata-Tools/README.md` - Updated package version table to 1.1.0
8. `tvtools.pkg` - Incremented version from v 2 to v 3
9. `stata.toc` - Incremented version from v 2 to v 3

---

**End of Audit Report**
