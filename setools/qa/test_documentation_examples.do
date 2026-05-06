/*
test_documentation_examples.do
Installed-user documentation reality checks for setools examples.

The examples use the same commands shown in README.md and .sthlp files. Public
GitHub data URLs are mapped to the repository's local _data mirror so this test
does not depend on network availability.

Run from setools/qa/:
    stata-mp -b do test_documentation_examples.do
*/

version 16.0
capture log close _all
set varabbrev off

**# Setup

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'"
local pkg_dir : subinstr local pkg_dir "/qa" "", all
local data_dir "`pkg_dir'/../_data"

capture ado uninstall setools
quietly net install setools, from("`pkg_dir'") replace

**# Help Files

local ++test_count
capture noisily {
    foreach cmd in setools cci_se migrations sustainedss cdp pira {
        help `cmd'
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: help files open after local net install"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' help_files"
    display as error "  FAIL: help files open after local net install (error `=_rc')"
}

**# setools Overview Examples

local ++test_count
capture noisily {
    setools
    assert "`r(commands)'" == "cci_se migrations sustainedss cdp pira"
    setools, list category(ms)
    assert "`r(commands)'" == "sustainedss cdp pira"
    setools, detail category(codes)
    assert "`r(commands)'" == "cci_se"
    setools, category(migration)
    assert "`r(commands)'" == "migrations"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: setools README/sthlp overview examples run"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' setools_examples"
    display as error "  FAIL: setools README/sthlp overview examples run (error `=_rc')"
}

**# cci_se README And Help Examples

local ++test_count
capture noisily {
    use "`data_dir'/diagnoses.dta", clear
    cci_se, id(id) icd(icd) date(visit_date) components noisily
    confirm variable charlson
    confirm variable cci_mi
    summarize charlson
    assert r(N) > 0
    assert r(max) >= r(min)

    use "`data_dir'/diagnoses.dta", clear
    cci_se, id(id) icd(icd) date(visit_date) dates
    confirm variable cci_mi_date
    confirm variable cci_chf_date
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: cci_se documentation examples run with shipped data"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' cci_examples"
    display as error "  FAIL: cci_se documentation examples run with shipped data (error `=_rc')"
}

**# migrations README And Help Examples

local ++test_count
capture noisily {
    use "`data_dir'/cohort.dta", clear
    migrations, migfile("`data_dir'/migrations_wide.dta") startvar(study_entry) verbose
    confirm variable migration_out_dt
    assert r(N_final) > 0

    use "`data_dir'/cohort.dta", clear
    migrations, migfile("`data_dir'/migrations_wide.dta") startvar(study_entry) keepimmigrants
    confirm variable migration_in_dt
    gen double effective_start = cond(!missing(migration_in_dt), migration_in_dt, study_entry)
    format effective_start %tdCCYY/NN/DD
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: migrations documentation examples run with shipped data"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' migrations_examples"
    display as error "  FAIL: migrations documentation examples run with shipped data (error `=_rc')"
}

**# MS Progression README And Help Examples

local ++test_count
capture noisily {
    use "`data_dir'/relapses.dta", clear
    sustainedss id edss edss_date, threshold(4) keepall
    confirm variable sustained4_dt
    gen byte reached_edss4 = !missing(sustained4_dt)
    tab reached_edss4

    use "`data_dir'/relapses.dta", clear
    cdp id edss edss_date, dxdate(dx_date) keepall
    confirm variable cdp_date
    gen byte had_cdp = !missing(cdp_date)
    tab had_cdp
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: sustainedss/cdp documentation examples run with shipped data"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' ms_examples"
    display as error "  FAIL: sustainedss/cdp documentation examples run with shipped data (error `=_rc')"
}

**# pira README And Help Examples

local ++test_count
capture noisily {
    use "`data_dir'/relapses.dta", clear
    pira id edss edss_date, dxdate(dx_date) relapses("`data_dir'/relapses_only.dta") keepall
    confirm variable pira_date
    confirm variable raw_date

    gen str4 prog_type = cond(!missing(pira_date), "PIRA", cond(!missing(raw_date), "RAW", "None"))
    tab prog_type

    use "`data_dir'/relapses.dta", clear
    pira id edss edss_date, dxdate(dx_date) relapses("`data_dir'/relapses_only.dta") ///
        windowbefore(0) windowafter(30)

    use "`data_dir'/relapses.dta", clear
    pira id edss edss_date, dxdate(dx_date) relapses("`data_dir'/relapses_only.dta") ///
        rebaselinerelapse keepall
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: pira documentation examples run with shipped data"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' pira_examples"
    display as error "  FAIL: pira documentation examples run with shipped data (error `=_rc')"
}

**# Summary

display as text ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_documentation_examples tests=`test_count' pass=`pass_count' fail=`fail_count'"

if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    display as error "SOME TESTS FAILED"
    exit 1
}

display as result "ALL TESTS PASSED"
