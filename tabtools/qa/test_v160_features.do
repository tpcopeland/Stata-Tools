* test_v160_features.do — Tests for tabtools v1.6.0 new features
* Tests: 1.1 (r(version) fix), 1.2 (cheatsheet version), 1.3 (academic border doc),
*        2.1 (effecttab digits), 2.2-2.4 (frame for regtab/effecttab/tablex),
*        2.5 (persistent theme), 2.6 (r(table) matrix),
*        3.1 (regtab console display), 3.2 (effecttab console display),
*        3.4 (keep/drop for regtab)

capture log close _v160
log using "test_v160_features.log", replace text name(_v160)

local n_pass = 0
local n_fail = 0
local n_total = 0

capture ado uninstall tabtools

**# Load package
local pkg_dir "`c(pwd)'/.."
net install tabtools, from("`pkg_dir'") replace

* =========================================================================
**# 1.1: Fix stale r(version)
* =========================================================================

local ++n_total
capture noisily {
    tabtools
    assert r(version) == "1.0.0"
}
if _rc == 0 {
    display as result "  PASS: 1.1 — r(version) = 1.0.0"
    local ++n_pass
}
else {
    display as error "  FAIL: 1.1 — r(version) wrong (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# 2.1: effecttab digits() option
* =========================================================================

* --- 2.1.1: digits(4) accepted ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    effecttab, xlsx("output/test_v160_digits4.xlsx") sheet("Test") digits(4)
    confirm file "output/test_v160_digits4.xlsx"
}
if _rc == 0 {
    display as result "  PASS: 2.1.1 — effecttab digits(4) accepted"
    local ++n_pass
}
else {
    display as error "  FAIL: 2.1.1 — effecttab digits(4) failed (rc=`=_rc')"
    local ++n_fail
}

* --- 2.1.2: digits(0) accepted ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    effecttab, xlsx("output/test_v160_digits0.xlsx") sheet("Test") digits(0)
    confirm file "output/test_v160_digits0.xlsx"
}
if _rc == 0 {
    display as result "  PASS: 2.1.2 — effecttab digits(0) accepted"
    local ++n_pass
}
else {
    display as error "  FAIL: 2.1.2 — effecttab digits(0) failed (rc=`=_rc')"
    local ++n_fail
}

* --- 2.1.3: digits(7) rejected ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    effecttab, xlsx("output/test_v160_digits7.xlsx") sheet("Test") digits(7)
}
if _rc != 0 {
    display as result "  PASS: 2.1.3 — effecttab digits(7) correctly rejected"
    local ++n_pass
}
else {
    display as error "  FAIL: 2.1.3 — effecttab digits(7) should have been rejected"
    local ++n_fail
}

* =========================================================================
**# 2.2: frame() for regtab
* =========================================================================

local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture frame drop myreg
    regtab, xlsx("output/test_v160_frame_regtab.xlsx") sheet("Test") frame(myreg)
    assert r(frame) == "myreg"
    frame myreg: describe
    frame myreg: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: 2.2 — regtab frame() stores data"
    local ++n_pass
}
else {
    display as error "  FAIL: 2.2 — regtab frame() failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop myreg

* =========================================================================
**# 2.3: frame() for effecttab
* =========================================================================

local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    capture frame drop myeff
    effecttab, xlsx("output/test_v160_frame_effecttab.xlsx") sheet("Test") frame(myeff)
    assert r(frame) == "myeff"
    frame myeff: describe
    frame myeff: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: 2.3 — effecttab frame() stores data"
    local ++n_pass
}
else {
    display as error "  FAIL: 2.3 — effecttab frame() failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop myeff

* =========================================================================
**# 2.4: frame() for tablex
* =========================================================================

local ++n_total
capture noisily {
    sysuse auto, clear
    table foreign rep78
    capture frame drop mytab
    capture erase "output/test_v160_frame_tablex.xlsx"
    tablex using "output/test_v160_frame_tablex.xlsx", sheet("Test") frame(mytab)
    assert r(frame) == "mytab"
    frame mytab: describe
    frame mytab: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: 2.4 — tablex frame() stores data"
    local ++n_pass
}
else {
    display as error "  FAIL: 2.4 — tablex frame() failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop mytab

* =========================================================================
**# 2.5: Persistent theme
* =========================================================================

* --- 2.5.1: tabtools set theme lancet ---
local ++n_total
capture noisily {
    tabtools set clear
    tabtools set theme lancet
    tabtools get
    assert r(theme) == "lancet"
}
if _rc == 0 {
    display as result "  PASS: 2.5.1 — tabtools set theme lancet works"
    local ++n_pass
}
else {
    display as error "  FAIL: 2.5.1 — tabtools set theme failed (rc=`=_rc')"
    local ++n_fail
}

* --- 2.5.2: invalid theme rejected ---
local ++n_total
capture noisily {
    tabtools set theme invalid
}
if _rc != 0 {
    display as result "  PASS: 2.5.2 — invalid theme correctly rejected"
    local ++n_pass
}
else {
    display as error "  FAIL: 2.5.2 — invalid theme should have been rejected"
    local ++n_fail
}

* --- 2.5.3: theme applies to regtab without explicit option ---
local ++n_total
capture noisily {
    tabtools set clear
    tabtools set theme lancet
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("output/test_v160_theme_regtab.xlsx") sheet("Test")
    confirm file "output/test_v160_theme_regtab.xlsx"
}
if _rc == 0 {
    display as result "  PASS: 2.5.3 — persistent theme applies to regtab"
    local ++n_pass
}
else {
    display as error "  FAIL: 2.5.3 — persistent theme regtab failed (rc=`=_rc')"
    local ++n_fail
}

* --- 2.5.4: tabtools set clear clears theme ---
local ++n_total
capture noisily {
    tabtools set theme nejm
    tabtools set clear
    tabtools get
    assert `"`r(theme)'"' == ""
}
if _rc == 0 {
    display as result "  PASS: 2.5.4 — set clear clears theme"
    local ++n_pass
}
else {
    display as error "  FAIL: 2.5.4 — set clear did not clear theme (rc=`=_rc')"
    local ++n_fail
}

tabtools set clear

* =========================================================================
**# 2.6: r(table) matrix in regtab
* =========================================================================

local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("output/test_v160_rtable.xlsx") sheet("Test")
    matrix list r(table)
    local nrows = rowsof(r(table))
    assert `nrows' > 0
}
if _rc == 0 {
    display as result "  PASS: 2.6 — r(table) matrix returned with `nrows' rows"
    local ++n_pass
}
else {
    display as error "  FAIL: 2.6 — r(table) matrix failed (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# 3.1: Console display mode for regtab
* =========================================================================

* --- 3.1.1: regtab without xlsx() displays in console ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab
}
if _rc == 0 {
    display as result "  PASS: 3.1.1 — regtab without xlsx() runs (console display)"
    local ++n_pass
}
else {
    display as error "  FAIL: 3.1.1 — regtab without xlsx() failed (rc=`=_rc')"
    local ++n_fail
}

* --- 3.1.2: regtab with display option shows console AND exports ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("output/test_v160_display.xlsx") sheet("Test") display
    confirm file "output/test_v160_display.xlsx"
}
if _rc == 0 {
    display as result "  PASS: 3.1.2 — regtab display + xlsx() works"
    local ++n_pass
}
else {
    display as error "  FAIL: 3.1.2 — regtab display + xlsx() failed (rc=`=_rc')"
    local ++n_fail
}

* --- 3.1.3: regtab without xlsx() still returns r(N_rows) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab
    assert r(N_rows) > 0
    assert r(N_models) > 0
}
if _rc == 0 {
    display as result "  PASS: 3.1.3 — regtab console mode returns r() values"
    local ++n_pass
}
else {
    display as error "  FAIL: 3.1.3 — regtab console mode r() failed (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# 3.2: Console display mode for effecttab
* =========================================================================

* --- 3.2.1: effecttab without xlsx() ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    effecttab
}
if _rc == 0 {
    display as result "  PASS: 3.2.1 — effecttab without xlsx() runs (console display)"
    local ++n_pass
}
else {
    display as error "  FAIL: 3.2.1 — effecttab without xlsx() failed (rc=`=_rc')"
    local ++n_fail
}

* --- 3.2.2: effecttab with display option ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    effecttab, xlsx("output/test_v160_effecttab_display.xlsx") sheet("Test") display
    confirm file "output/test_v160_effecttab_display.xlsx"
}
if _rc == 0 {
    display as result "  PASS: 3.2.2 — effecttab display + xlsx() works"
    local ++n_pass
}
else {
    display as error "  FAIL: 3.2.2 — effecttab display + xlsx() failed (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# 3.4: keep()/drop() for regtab
* =========================================================================

* --- 3.4.1: keep() filters rows ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight i.foreign
    capture frame drop keeptest
    capture erase "output/test_v160_keep.xlsx"
    regtab, xlsx("output/test_v160_keep.xlsx") sheet("Test") keep(mpg weight) frame(keeptest)
    * Frame should have fewer rows than full model
    frame keeptest: assert _N < 10
    frame keeptest: assert _N >= 3
}
if _rc == 0 {
    display as result "  PASS: 3.4.1 — regtab keep() filters rows"
    local ++n_pass
}
else {
    display as error "  FAIL: 3.4.1 — regtab keep() failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop keeptest

* --- 3.4.2: drop() removes rows ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight i.foreign
    capture frame drop droptest
    regtab, xlsx("output/test_v160_drop.xlsx") sheet("Test") drop(_cons) frame(droptest)
    * Frame should not contain _cons
    frame droptest {
        gen byte _has_cons = A == "_cons"
        summarize _has_cons, meanonly
        assert r(max) == 0
    }
}
if _rc == 0 {
    display as result "  PASS: 3.4.2 — regtab drop() removes rows"
    local ++n_pass
}
else {
    display as error "  FAIL: 3.4.2 — regtab drop() failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop droptest

* --- 3.4.3: keep + drop mutual exclusivity ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("output/test_v160_keepdrop.xlsx") sheet("Test") keep(mpg) drop(weight)
}
if _rc != 0 {
    display as result "  PASS: 3.4.3 — keep + drop correctly rejected"
    local ++n_pass
}
else {
    display as error "  FAIL: 3.4.3 — keep + drop should have been rejected"
    local ++n_fail
}

* =========================================================================
**# Multi-model regtab test (display + frame + r(table))
* =========================================================================

local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    collect: regress price mpg weight i.foreign
    capture frame drop multi
    regtab, xlsx("output/test_v160_multi.xlsx") sheet("Test") ///
        models("Model 1 \ Model 2") frame(multi) display
    assert r(N_models) == 2
    matrix list r(table)
    local ncols = colsof(r(table))
    assert `ncols' == 2
}
if _rc == 0 {
    display as result "  PASS: multi-model — 2-model regtab with display + frame + r(table)"
    local ++n_pass
}
else {
    display as error "  FAIL: multi-model — 2-model test failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop multi

* =========================================================================
**# Data preservation test
* =========================================================================

local ++n_total
capture noisily {
    sysuse auto, clear
    local orig_n = _N
    collect clear
    collect: regress price mpg weight
    regtab
    assert _N == `orig_n'
    assert "`=_sortedby'" != ""  | _N > 0
}
if _rc == 0 {
    display as result "  PASS: data preservation — user data intact after console regtab"
    local ++n_pass
}
else {
    display as error "  FAIL: data preservation — user data changed (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# Summary
* =========================================================================

display as text ""
display as text "{hline 60}"
display as text "v1.6.0 Feature Tests Complete"
display as text "{hline 60}"
display as result "  Passed: `n_pass' / `n_total'"
if `n_fail' > 0 {
    display as error "  Failed: `n_fail' / `n_total'"
}
else {
    display as result "  All tests passed!"
}
display as text "{hline 60}"

assert `n_fail' == 0

log close _v160
