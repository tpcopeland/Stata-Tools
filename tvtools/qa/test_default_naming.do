clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "test_default_naming.log", replace nomsg

* Shared scaffold: sandboxed install bootstrap
do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display as result "tvtools QA: tvexpose default output naming -- $S_DATE $S_TIME"

* -------------------------------------------------------------------------
* Fixtures: a one-person cohort and a single exposure episode. The exposure
* value column is named `drug', so the derived default output is tv_drug.
* -------------------------------------------------------------------------
capture program drop _make_fixtures
program define _make_fixtures
    args expvar idvar
    if "`expvar'" == "" local expvar drug
    if "`idvar'"  == "" local idvar  id
    tempfile cohort exp
    clear
    set obs 1
    gen `idvar' = 1
    gen study_entry = mdy(1,1,2020)
    gen study_exit  = mdy(12,31,2020)
    format %td study_entry study_exit
    save "$TVTOOLS_QA_RUN_DIR/_tvdn_cohort.dta", replace
    clear
    set obs 1
    gen `idvar' = 1
    gen double start = mdy(3,1,2020)
    gen double stop  = mdy(5,31,2020)
    gen int `expvar' = 1
    format %td start stop
    save "$TVTOOLS_QA_RUN_DIR/_tvdn_exp.dta", replace
end

* ===== TEST 1: omitted generate() derives tv_<exposure> + r(genvar) =====
local ++test_count
capture {
    _make_fixtures drug id
    use "$TVTOOLS_QA_RUN_DIR/_tvdn_cohort.dta", clear
    tvexpose using "$TVTOOLS_QA_RUN_DIR/_tvdn_exp.dta", id(id) start(start) stop(stop) ///
        exposure(drug) reference(0) entry(study_entry) exit(study_exit)
    assert "`r(genvar)'" == "tv_drug"
    confirm variable tv_drug
    capture confirm variable tv_exposure
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: omitted generate() -> tv_drug, r(genvar)=tv_drug, no tv_exposure"
    local ++pass_count
}
else {
    display as error "  FAIL: derived default name (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

* ===== TEST 2: explicit generate() still wins (regression) =====
local ++test_count
capture {
    use "$TVTOOLS_QA_RUN_DIR/_tvdn_cohort.dta", clear
    tvexpose using "$TVTOOLS_QA_RUN_DIR/_tvdn_exp.dta", id(id) start(start) stop(stop) ///
        exposure(drug) reference(0) entry(study_entry) exit(study_exit) generate(myexp)
    assert "`r(genvar)'" == "myexp"
    confirm variable myexp
    capture confirm variable tv_drug
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: explicit generate(myexp) overrides derivation"
    local ++pass_count
}
else {
    display as error "  FAIL: explicit generate() override (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

* ===== TEST 3: derived name colliding with id falls back to tv_exposure =====
* exposure var is `drug' (-> tv_drug) but the id var is literally tv_drug.
local ++test_count
capture {
    clear
    set obs 1
    gen tv_drug = 1
    gen study_entry = mdy(1,1,2020)
    gen study_exit  = mdy(12,31,2020)
    format %td study_entry study_exit
    save "$TVTOOLS_QA_RUN_DIR/_tvdn_cohort2.dta", replace
    clear
    set obs 1
    gen tv_drug = 1
    gen double start = mdy(3,1,2020)
    gen double stop  = mdy(5,31,2020)
    gen int drug = 1
    format %td start stop
    save "$TVTOOLS_QA_RUN_DIR/_tvdn_exp2.dta", replace
    use "$TVTOOLS_QA_RUN_DIR/_tvdn_cohort2.dta", clear
    tvexpose using "$TVTOOLS_QA_RUN_DIR/_tvdn_exp2.dta", id(tv_drug) start(start) stop(stop) ///
        exposure(drug) reference(0) entry(study_entry) exit(study_exit)
    assert "`r(genvar)'" == "tv_exposure"
    confirm variable tv_exposure
}
if _rc == 0 {
    display as result "  PASS: id collision falls back to tv_exposure"
    local ++pass_count
}
else {
    display as error "  FAIL: id-collision fallback (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}

* ===== TEST 4: derived name >32 chars falls back to tv_exposure =====
* exposure var is 30 chars -> tv_ + 30 = 33 chars (illegal), must fall back.
local ++test_count
capture {
    local longexp "drugexposurecategoryvariablexx"   // 30 chars
    assert strlen("`longexp'") == 30
    clear
    set obs 1
    gen id = 1
    gen study_entry = mdy(1,1,2020)
    gen study_exit  = mdy(12,31,2020)
    format %td study_entry study_exit
    save "$TVTOOLS_QA_RUN_DIR/_tvdn_cohort3.dta", replace
    clear
    set obs 1
    gen id = 1
    gen double start = mdy(3,1,2020)
    gen double stop  = mdy(5,31,2020)
    gen int `longexp' = 1
    format %td start stop
    save "$TVTOOLS_QA_RUN_DIR/_tvdn_exp3.dta", replace
    use "$TVTOOLS_QA_RUN_DIR/_tvdn_cohort3.dta", clear
    tvexpose using "$TVTOOLS_QA_RUN_DIR/_tvdn_exp3.dta", id(id) start(start) stop(stop) ///
        exposure(`longexp') reference(0) entry(study_entry) exit(study_exit)
    assert "`r(genvar)'" == "tv_exposure"
    confirm variable tv_exposure
}
if _rc == 0 {
    display as result "  PASS: >32-char derived name falls back to tv_exposure"
    local ++pass_count
}
else {
    display as error "  FAIL: long-name fallback (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

* ===== TEST 5: distinct exposures get distinct names -> tvmerge w/o rename =====
local ++test_count
capture {
    * Build two exposures with different value-column names.
    clear
    set obs 1
    gen id = 1
    gen study_entry = mdy(1,1,2020)
    gen study_exit  = mdy(12,31,2020)
    format %td study_entry study_exit
    save "$TVTOOLS_QA_RUN_DIR/_tvdn_coh.dta", replace
    foreach v in drugA drugB {
        clear
        set obs 1
        gen id = 1
        gen double start = mdy(3,1,2020)
        gen double stop  = mdy(5,31,2020)
        gen int `v' = 1
        format %td start stop
        save "$TVTOOLS_QA_RUN_DIR/_tvdn_`v'.dta", replace
    }
    use "$TVTOOLS_QA_RUN_DIR/_tvdn_coh.dta", clear
    tvexpose using "$TVTOOLS_QA_RUN_DIR/_tvdn_drugA.dta", id(id) start(start) stop(stop) ///
        exposure(drugA) reference(0) entry(study_entry) exit(study_exit) ///
        saveas("$TVTOOLS_QA_RUN_DIR/_tvdn_outA.dta") replace
    use "$TVTOOLS_QA_RUN_DIR/_tvdn_coh.dta", clear
    tvexpose using "$TVTOOLS_QA_RUN_DIR/_tvdn_drugB.dta", id(id) start(start) stop(stop) ///
        exposure(drugB) reference(0) entry(study_entry) exit(study_exit) ///
        saveas("$TVTOOLS_QA_RUN_DIR/_tvdn_outB.dta") replace
    * No rename needed: derived names are distinct (tv_drugA/tv_drugB), so the
    * exposure() list does not collide and tvmerge keeps the original names
    * (contrast the auto-suffix path forced by the old shared tv_exposure name).
    tvmerge "$TVTOOLS_QA_RUN_DIR/_tvdn_outA.dta" "$TVTOOLS_QA_RUN_DIR/_tvdn_outB.dta", ///
        id(id) start(start start) stop(stop stop) ///
        exposure(tv_drugA tv_drugB) saveas("$TVTOOLS_QA_RUN_DIR/_tvdn_merged.dta") replace
    use "$TVTOOLS_QA_RUN_DIR/_tvdn_merged.dta", clear
    confirm variable tv_drugA
    confirm variable tv_drugB
}
if _rc == 0 {
    display as result "  PASS: distinct exposures chain into tvmerge without renames"
    local ++pass_count
}
else {
    display as error "  FAIL: distinct-name chaining (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}

* ===== Summary =====
display as result _newline "default output naming Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: test_default_naming tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"
