* test_tabtools_v103.do - Regression tests for v1.0.3 fixes
* Generated: 2026-04-13
* Covers:
*   - Short option abbreviations now match the .sthlp documentation
*     (sub, dis, border, tr in crosstab, ev in survtab, ratio in stratetab)
*   - survtab RMST/Greenwood pass uses tempvars and no longer collides
*     with user variables named _dt, _area, _n_at_risk, _d_count,
*     _last_in_t, _n_risk_first, _tail_area, _gw_term
*   - tabtools.ado defensive `cap prog drop _tabtools_detail` allows the
*     subprogram to be redefined after the user manually drops the parent

clear all
set more off
set varabbrev off

capture log close _v103
log using "test_tabtools_v103.log", replace text name(_v103)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* ============================================================
* Short-abbreviation regression: each option must match the
* shortest form documented in the .sthlp synopsis line.
* ============================================================

sysuse auto, clear

* T1: crosstab `dis`, `border`, `tr`
local ++test_count
capture noisily crosstab foreign rep78, ///
    border(thin) tr dis
if _rc == 0 {
    display as result "  PASS T1: crosstab dis/border/tr abbreviations"
    local ++pass_count
}
else {
    display as error "  FAIL T1: crosstab abbreviations (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T1"
}

* T2: corrtab `dis`, `border`
local ++test_count
capture noisily corrtab price mpg weight length, ///
    border(thin) dis
if _rc == 0 {
    display as result "  PASS T2: corrtab dis/border abbreviations"
    local ++pass_count
}
else {
    display as error "  FAIL T2: corrtab abbreviations (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T2"
}

* T3: diagtab `dis`, `border`
local ++test_count
gen byte _gold = foreign
gen byte _test = (mpg >= 25)
capture noisily diagtab _test _gold, ///
    border(thin) dis
drop _gold _test
if _rc == 0 {
    display as result "  PASS T3: diagtab dis/border abbreviations"
    local ++pass_count
}
else {
    display as error "  FAIL T3: diagtab abbreviations (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T3"
}

* T5: regtab `dis`, `border`
local ++test_count
collect clear
quietly collect: regress price mpg weight foreign
capture noisily regtab, dis border(thin)
if _rc == 0 {
    display as result "  PASS T5: regtab dis/border abbreviations"
    local ++pass_count
}
else {
    display as error "  FAIL T5: regtab abbreviations (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T5"
}
collect clear

* T6: comptab uses regtab frames; just exercise dis/border on the
*     downstream call. Build a small regtab frame first.
local ++test_count
collect clear
quietly collect: regress price mpg weight
capture noisily regtab, frame(_v103_fr1, replace)
if _rc == 0 {
    capture noisily comptab _v103_fr1, ///
        rows("1 2") border(thin) dis
}
if _rc == 0 {
    display as result "  PASS T6: comptab dis/border abbreviations"
    local ++pass_count
}
else {
    display as error "  FAIL T6: comptab abbreviations (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T6"
}
capture frame drop _v103_fr1
collect clear

* ============================================================
* survtab `ev` short form + RMST tempvar collision regression
* ============================================================

webuse drugtr, clear
stset studytime, failure(died)

* T7: survtab events option via `ev` short form
local ++test_count
capture noisily survtab, times(20 40) by(drug) ev dis
if _rc == 0 {
    display as result "  PASS T7: survtab ev short form"
    local ++pass_count
}
else {
    display as error "  FAIL T7: survtab ev short form (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T7"
}

* T8: survtab RMST with user variables that collide with the old
*     hard-coded names. Pre-1.0.3 this crashed with "_dt already defined".
local ++test_count
gen double _dt = .
gen double _area = .
gen double _n_at_risk = .
gen double _d_count = .
gen byte _last_in_t = .
gen double _n_risk_first = .
gen double _tail_area = .
gen double _gw_term = .
capture noisily survtab, times(20 40) by(drug) rmst(40) dis
local _rmst_rc = _rc
* user variables must still be present after the call (preserve/restore)
foreach v in _dt _area _n_at_risk _d_count _last_in_t _n_risk_first _tail_area _gw_term {
    capture confirm variable `v'
    if _rc local _rmst_rc = 9001
}
drop _dt _area _n_at_risk _d_count _last_in_t _n_risk_first _tail_area _gw_term
if `_rmst_rc' == 0 {
    display as result "  PASS T8: survtab RMST safe with user _dt/_area/etc."
    local ++pass_count
}
else {
    display as error "  FAIL T8: survtab RMST collision (rc=`_rmst_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T8"
}

* ============================================================
* stratetab `ratio` short form
* ============================================================

* T9: stratetab ratiodigits via `ratio` short form. Build two synthetic
*     strate output files (two exposure groups) and exercise the ratio()
*     abbreviation alongside rateratio.
quietly {
    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n==1, 25, cond(_n==2, 18, 32))
    gen _Y = cond(_n==1, 5000, cond(_n==2, 4500, 5200))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.65
    gen _Upper = _Rate * 1.35
    label define _v103_lbl 0 "Never" 1 "Former" 2 "Current"
    label values exposure _v103_lbl
    save "`output_dir'/_v103_strate1.dta", replace

    replace _D = cond(_n==1, 30, cond(_n==2, 22, 28))
    replace _Y = cond(_n==1, 4800, cond(_n==2, 4600, 5100))
    replace _Rate = _D / _Y
    replace _Lower = _Rate * 0.65
    replace _Upper = _Rate * 1.35
    save "`output_dir'/_v103_strate2.dta", replace
}
local ++test_count
capture noisily stratetab, using("`output_dir'/_v103_strate1" "`output_dir'/_v103_strate2") ///
    outcomes(1) rateratio ratio(3) border(thin) ///
    explabels("Group A" \ "Group B") ///
    xlsx("`output_dir'/_v103_stratetab.xlsx")
if _rc == 0 {
    display as result "  PASS T9: stratetab ratio short form"
    local ++pass_count
}
else {
    display as error "  FAIL T9: stratetab ratio short form (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T9"
}
capture erase "`output_dir'/_v103_strate1.dta"
capture erase "`output_dir'/_v103_strate2.dta"
capture erase "`output_dir'/_v103_stratetab.xlsx"

* ============================================================
* tabtools.ado defensive cap prog drop _tabtools_detail
* ============================================================

* T10: drop tabtools by name only, then call tabtools detail again. Pre-1.0.3
*      this errored with "_tabtools_detail already defined" on the second run.
local ++test_count
capture program drop tabtools
capture noisily tabtools, detail cat(all)
if _rc == 0 {
    display as result "  PASS T10: tabtools detail re-loads after manual drop"
    local ++pass_count
}
else {
    display as error "  FAIL T10: tabtools detail re-load (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T10"
}

* T11: diagtab single-cutoff zebra + headershade. Pre-1.0.3 the measures
*      header was hardcoded to row 6 and zebra started at the Test- row,
*      shading the confusion-matrix block instead of the measures section.
*      The smoke test here is just that the export still succeeds end-to-end
*      with both options enabled (no out-of-bounds putexcel).
sysuse auto, clear
gen byte _gold = foreign
gen byte _test = (mpg >= 25)
local ++test_count
capture noisily diagtab _test _gold, ///
    xlsx("`output_dir'/_v103_diagtab.xlsx") sheet("Test") ///
    zebra headershade border(thin)
if _rc == 0 {
    display as result "  PASS T11: diagtab single-cutoff zebra/headershade"
    local ++pass_count
}
else {
    display as error "  FAIL T11: diagtab zebra (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T11"
}
drop _gold _test
capture erase "`output_dir'/_v103_diagtab.xlsx"

* ============================================================
* Summary
* ============================================================

display _newline
display as result "v1.0.3 regression: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "FAILED: `failed_tests'"
    log close _v103
    exit 1
}
else {
    display as result "ALL v1.0.3 REGRESSION TESTS PASSED"
}

log close _v103
