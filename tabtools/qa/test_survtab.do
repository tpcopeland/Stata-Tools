* test_survtab.do - complete QA for survtab
* Consolidated in v1.7.0 from: test_new_commands.do, test_review_v1013.do, test_review_v1013_gaps.do, test_tabtools_issue_regressions.do, test_tabtools_v103.do, test_v170_features.do

clear all
set more off
set varabbrev off
version 17.0

capture log close _survtab
log using "test_survtab.log", replace text name(_survtab)

local test_count = 0
local pass_count = 0
local fail_count = 0

local n_total = 0
**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local pkg_root "`pkg_dir'"
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"
local tools_dir "`qa_dir'/tools"
local checker "`tools_dir'/check_xlsx.py"
local md_checker "`tools_dir'/check_markdown.py"
local summary_tool "`tools_dir'/summarize_xlsx.py"

local python_cmd ""
capture noisily shell python3 --version
if _rc == 0 {
    local python_cmd "python3"
}
else {
    capture noisily shell python --version
    if _rc == 0 local python_cmd "python"
}

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear


**# Migrated: core survtab suite

**# SECTION 6: survtab
* ============================================================

* Create survival dataset
clear
set obs 500
set seed 456
gen treatment = cond(runiform() < 0.5, 1, 0)
gen time = rexponential(1/(3 + 2*treatment))
gen event = cond(runiform() < 0.7, 1, 0)
replace time = min(time, 10)
replace event = 0 if time >= 10
label define txlbl 0 "Control" 1 "Treatment"
label values treatment txlbl
stset time, failure(event)
tempfile survdata
save `survdata'

* Test: survtab basic without by()
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    survtab, times(1 3 5) display
}
if _rc == 0 {
    display as result "  PASS: survtab basic without by()"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab basic without by() (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab with by()
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    survtab, times(1 3 5) by(treatment) display
}
if _rc == 0 {
    display as result "  PASS: survtab with by()"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab with by() (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab returns logrank_p when by() used
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    survtab, times(1 3 5) by(treatment) display
    assert !missing(r(logrank_p))
    assert !missing(r(logrank_chi2))
}
if _rc == 0 {
    display as result "  PASS: survtab r(logrank_p)"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab r(logrank_p) (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab median option
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    survtab, times(1 3 5) by(treatment) median display
    assert !missing(r(median_1))
    assert !missing(r(median_2))
}
if _rc == 0 {
    display as result "  PASS: survtab median"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab median (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab riskset option
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    survtab, times(1 3 5) by(treatment) riskset display
}
if _rc == 0 {
    display as result "  PASS: survtab riskset"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab riskset (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab reverse (cumulative incidence)
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    survtab, times(1 3 5) by(treatment) reverse display
}
if _rc == 0 {
    display as result "  PASS: survtab reverse (cumulative incidence)"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab reverse (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab difference option
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    survtab, times(1 3 5) by(treatment) difference display
}
if _rc == 0 {
    display as result "  PASS: survtab difference"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab difference (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab rmst option
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    survtab, times(1 3 5) by(treatment) rmst(5) display
}
if _rc == 0 {
    display as result "  PASS: survtab rmst(5)"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab rmst(5) (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab timeunit option
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    survtab, times(1 3 5) timeunit(months) display
}
if _rc == 0 {
    display as result "  PASS: survtab timeunit(months)"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab timeunit(months) (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab xlsx export
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    capture erase "`output_dir'/test_survtab.xlsx"
    survtab, times(1 3 5) by(treatment) ///
        xlsx("`output_dir'/test_survtab.xlsx") sheet("Survival")
    confirm file "`output_dir'/test_survtab.xlsx"
}
if _rc == 0 {
    display as result "  PASS: survtab xlsx export"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab xlsx export (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab r(table) matrix
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    survtab, times(1 3 5) by(treatment) display
    matrix list r(table)
    assert rowsof(r(table)) > 0
}
if _rc == 0 {
    display as result "  PASS: survtab r(table) matrix"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab r(table) (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab r(methods) returned
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    survtab, times(1 3 5) display
    assert "`r(methods)'" != ""
}
if _rc == 0 {
    display as result "  PASS: survtab r(methods)"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab r(methods) (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab csv export
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    survtab, times(1 3 5) csv("`output_dir'/test_survtab.csv") display
    confirm file "`output_dir'/test_survtab.csv"
}
if _rc == 0 {
    display as result "  PASS: survtab csv export"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab csv export (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab frame output
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    capture frame drop survframe
    survtab, times(1 3 5) frame(survframe) display
    assert r(frame) == "survframe"
    frame survframe: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: survtab frame output"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab frame output (rc=`=_rc')"
    local ++fail_count
}
capture frame drop survframe

* Test: survtab title/footnote
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    capture erase "`output_dir'/test_survtab_titled.xlsx"
    survtab, times(1 3 5) by(treatment) ///
        xlsx("`output_dir'/test_survtab_titled.xlsx") ///
        title("Table 2. Survival Analysis") ///
        footnote("Kaplan-Meier estimates")
    confirm file "`output_dir'/test_survtab_titled.xlsx"
}
if _rc == 0 {
    display as result "  PASS: survtab title/footnote"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab title/footnote (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab difference requires by()
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    survtab, times(1 3 5) difference display
}
if _rc != 0 {
    display as result "  PASS: survtab difference requires by()"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab difference should require by()"
    local ++fail_count
}

* Test: survtab data preservation
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    local orig_n = _N
    survtab, times(1 3 5) display
    assert _N == `orig_n'
}
if _rc == 0 {
    display as result "  PASS: survtab data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab data preservation (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab highlight option
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    capture erase "`output_dir'/test_survtab_highlight.xlsx"
    survtab, times(1 3 5) by(treatment) highlight(0.05) ///
        xlsx("`output_dir'/test_survtab_highlight.xlsx")
    confirm file "`output_dir'/test_survtab_highlight.xlsx"
}
if _rc == 0 {
    display as result "  PASS: survtab highlight option"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab highlight (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab boldp option
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    capture erase "`output_dir'/test_survtab_boldp.xlsx"
    survtab, times(1 3 5) by(treatment) boldp(0.05) ///
        xlsx("`output_dir'/test_survtab_boldp.xlsx")
    confirm file "`output_dir'/test_survtab_boldp.xlsx"
}
if _rc == 0 {
    display as result "  PASS: survtab boldp option"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab boldp (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab zebra option
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    capture erase "`output_dir'/test_survtab_zebra.xlsx"
    survtab, times(1 3 5) by(treatment) zebra ///
        xlsx("`output_dir'/test_survtab_zebra.xlsx")
    confirm file "`output_dir'/test_survtab_zebra.xlsx"
}
if _rc == 0 {
    display as result "  PASS: survtab zebra"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab zebra (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab all options combined
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    capture erase "`output_dir'/test_survtab_full.xlsx"
    survtab, times(1 3 5) by(treatment) median riskset ///
        difference rmst(5) ///
        xlsx("`output_dir'/test_survtab_full.xlsx") ///
        sheet("Full") title("Survival Table") zebra boldp(0.05) ///
        theme(lancet) display
    confirm file "`output_dir'/test_survtab_full.xlsx"
}
if _rc == 0 {
    display as result "  PASS: survtab all options combined"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab all options combined (rc=`=_rc')"
    local ++fail_count
}

* ============================================================

**# Migrated: events option

**# F5: survtab events option
* =========================================================================

* --- F5.1: events option adds Events/N row ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    capture frame drop _f5_1
    survtab, times(10 20 30) by(drug) events frame(_f5_1)
    frame _f5_1 {
        * Check that Events / N row exists
        gen byte _has_events = strpos(c1, "Events / N") > 0
        summarize _has_events, meanonly
        assert r(max) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: F5.1 — survtab events option produces Events/N row"
    local ++pass_count
}
else {
    display as error "  FAIL: F5.1 — survtab events option failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _f5_1

* --- F5.2: events return values ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    survtab, times(10 20 30) by(drug) events
    * Should have events_1, atrisk_1, etc.
    assert r(events_1) > 0
    assert r(atrisk_1) > 0
    assert r(events_1) <= r(atrisk_1)
}
if _rc == 0 {
    display as result "  PASS: F5.2 — survtab events returns events/atrisk scalars"
    local ++pass_count
}
else {
    display as error "  FAIL: F5.2 — survtab events return values failed (rc=`=_rc')"
    local ++fail_count
}

* --- F5.3: events content is correct ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    * Count expected events and N for drug==1
    qui count if drug == 1 & _st & _d == 1
    local expected_events = r(N)
    qui count if drug == 1 & _st
    local expected_n = r(N)
    survtab, times(10 20 30) by(drug) events
    assert r(events_1) == `expected_events'
    assert r(atrisk_1) == `expected_n'
}
if _rc == 0 {
    display as result "  PASS: F5.3 — survtab events counts are correct"
    local ++pass_count
}
else {
    display as error "  FAIL: F5.3 — survtab events counts incorrect (rc=`=_rc')"
    local ++fail_count
}

* --- F5.4: events without by() ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    survtab, times(10 20 30) events
    assert r(events_1) > 0
    assert r(atrisk_1) > 0
}
if _rc == 0 {
    display as result "  PASS: F5.4 — survtab events works without by()"
    local ++pass_count
}
else {
    display as error "  FAIL: F5.4 — survtab events without by() failed (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================

**# Migrated: ev abbreviation + user-variable collision

* ============================================================

webuse drugtr, clear
stset studytime, failure(died)

* T7: survtab events option via `ev` short form
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


**# Migrated: headershade regression

**# 12. survtab headershade option accepted (I8 regression)

**## 12a. survtab with headershade produces a file without error
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    local i8_xlsx "`output_dir'/_rev1013_i8_survtab.xlsx"
    capture erase "`i8_xlsx'"
    survtab, times(10 20 30) by(drug) headershade ///
        xlsx("`i8_xlsx'") sheet("I8Test")
    assert `"`r(xlsx)'"' != ""
    capture confirm file "`i8_xlsx'"
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS [12a]: survtab headershade option accepted and file created"
    local ++pass_count
}
else {
    display as error "  FAIL [12a]: survtab headershade failed (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_rev1013_i8_survtab.xlsx"



**# Migrated: RMST difference column

**# QA Gap 1: survtab RMST difference column
* Contract coverage marker for dynamic stored-result families:
* r(median_) r(rmst_se_) r(rmst_lb_) r(rmst_ub_).

**## 1a. RMST difference is returned in r(rmst_diff) for 2-group comparison
capture noisily {
    sysuse cancer, clear
    * drug has 3 levels; keep only 2 for rmst_diff
    keep if inlist(drug, 1, 2)
    stset studytime, failure(died)
    survtab, times(10 20 30) by(drug) rmst(39)
    assert r(rmst_diff) < .
    assert r(rmst_1) < .
    assert r(rmst_2) < .
    local diff = r(rmst_diff)
    local r1 = r(rmst_1)
    local r2 = r(rmst_2)
    * Verify diff = rmst_1 - rmst_2
    assert abs(`diff' - (`r1' - `r2')) < 0.001
}
if _rc == 0 {
    display as result "  PASS [1a]: survtab RMST diff scalar returned and consistent"
    local ++pass_count
}
else {
    display as error "  FAIL [1a]: survtab RMST diff (rc=`=_rc')"
    local ++fail_count
}

**## 1b. RMST difference shown in output frame (2 groups required)
capture noisily {
    sysuse cancer, clear
    keep if inlist(drug, 1, 2)
    stset studytime, failure(died)
    capture frame drop _rmst_test
    survtab, times(10 20) by(drug) rmst(39) difference frame(_rmst_test, replace)
    frame _rmst_test {
        * Difference column should exist
        local _diff_col = 0
        ds c*
        local _allcols `r(varlist)'
        foreach _v of local _allcols {
            if `_v'[2] == "Difference" local _diff_col = subinstr("`_v'", "c", "", 1)
        }
        assert `_diff_col' > 0
        * Find the RMST row and verify it has a difference value
        local _found 0
        forvalues r = 3/`=_N' {
            if strpos(c1[`r'], "RMST") > 0 {
                assert c`_diff_col'[`r'] != ""
                local _found 1
            }
        }
        assert `_found' == 1
    }
    capture frame drop _rmst_test
}
if _rc == 0 {
    display as result "  PASS [1b]: survtab RMST difference column present in frame"
    local ++pass_count
}
else {
    display as error "  FAIL [1b]: survtab RMST difference in frame (rc=`=_rc')"
    local ++fail_count
}

**## 1c. RMST per-group CIs are returned
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    survtab, times(10 20 30) by(drug) rmst(39)
    assert r(rmst_lb_1) < .
    assert r(rmst_ub_1) < .
    assert r(rmst_lb_2) < .
    assert r(rmst_ub_2) < .
    * CI should bracket the point estimate
    assert r(rmst_lb_1) <= r(rmst_1)
    assert r(rmst_ub_1) >= r(rmst_1)
}
if _rc == 0 {
    display as result "  PASS [1c]: survtab RMST per-group CIs returned and consistent"
    local ++pass_count
}
else {
    display as error "  FAIL [1c]: survtab RMST CIs (rc=`=_rc')"
    local ++fail_count
}



**# Migrated: RMST no-late-entry regression

**# Regression: I3 — survtab RMST with no late entry

**## R4. survtab RMST produces non-zero SE
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    survtab, times(10 20) by(drug) rmst(39)
    assert r(rmst_se_1) > 0
    assert r(rmst_se_2) > 0
    assert r(rmst_lb_1) < r(rmst_1)
    assert r(rmst_ub_1) > r(rmst_1)
}
if _rc == 0 {
    display as result "  PASS [R4]: survtab RMST SE > 0 and CI brackets estimate"
    local ++pass_count
}
else {
    display as error "  FAIL [R4]: survtab RMST SE (rc=`=_rc')"
    local ++fail_count
}



**# Migrated: highlight() bounds validation

* Test 6: survtab validates highlight() bounds
capture noisily {
    clear
    set obs 20
    gen byte group = (_n > 10)
    gen double time = _n
    gen byte event = (_n <= 10)
    stset time, failure(event)
    capture survtab, times(1 2 3) by(group) highlight(0)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: survtab rejects invalid highlight()"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab rejects invalid highlight() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}


**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_survtab tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _survtab
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_survtab tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _survtab
