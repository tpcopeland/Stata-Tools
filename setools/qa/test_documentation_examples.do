*! test_documentation_examples.do  2.0.0  2026/07/13
*! Installed-user documentation examples on self-contained synthetic data

version 16.0
clear all
set more off
set varabbrev off
capture log close _all

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_setools_qa_common.do" setup "`pkg_dir'"

**# Installed help and dispatcher surface
local ++test_count
capture noisily {
    foreach cmd in setools cci_se migrations sustainedss cdp pira {
        which `cmd'
        help `cmd'
    }
    setools
    assert "`r(commands)'" == "cci_se migrations sustainedss cdp pira"
    setools, list category(ms)
    assert "`r(commands)'" == "sustainedss cdp pira"
    setools, detail category(codes)
    assert "`r(commands)'" == "cci_se"
}
if !_rc local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' installed_overview"
}

**# cci_se examples
local ++test_count
capture noisily {
    clear
    input long id str12 icd int year
    1 "I21" 2000
    1 "E112" 2001
    2 "F024" 2002
    end
    gen long diagnosis_date = mdy(1, 1, year)
    format diagnosis_date %td
    cci_se, id(id) icd(icd) date(diagnosis_date) dates noisily
    assert charlson == 3 if id == 1
    assert charlson == 7 if id == 2
    confirm variable cci_mi_date
}
if !_rc local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' cci_examples"
}

**# migrations workflow, including the exact executable stset sequence
local ++test_count
capture noisily {
    tempfile migration_file
    clear
    input long id long in_1 long out_1
    1 . 50
    2 . .
    end
    format in_1 out_1 %td
    save `migration_file', replace

    clear
    input long id long study_entry long followup_end byte outcome
    1 0 100 1
    2 0 100 0
    end
    format study_entry followup_end %td
    migrations, migfile("`migration_file'") startvar(study_entry) verbose
    gen long analysis_end = cond(missing(migration_out_dt), ///
        followup_end, min(followup_end, migration_out_dt))
    format analysis_end %td
    stset analysis_end, origin(time study_entry) failure(outcome) id(id)
    assert _t == 50 if id == 1
    assert _t == 100 if id == 2
}
if !_rc local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' migrations_stset_example"
}

**# sustainedss and cdp option interactions
local ++test_count
capture noisily {
    tempfile edss_source
    clear
    input long id double edss long edss_date long dx_date
    1 2 0   0
    1 3 10  0
    1 3 192 0
    1 4 400 0
    1 4 582 0
    2 6 0   0
    end
    format edss_date dx_date %td
    save `edss_source', replace

    sustainedss id edss edss_date, threshold(6) keepall
    assert sustained6_dt == 0 if id == 2

    use `edss_source', clear
    sustainedss id edss edss_date, threshold(6) ///
        confirmvisit(window) confirmwindow(182) keepall generate(s6_confirmed)
    assert missing(s6_confirmed) if id == 2

    use `edss_source', clear
    cdp id edss edss_date, dxdate(dx_date) roving allevents ///
        eventvar(cdp_event) eventnumvar(sequence) ///
        baseedssvar(reference_edss) quietly
    assert _N == 2
    assert cdp_event == 1
    assert sequence == _n
}
if !_rc local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' edss_examples"
}

**# pira preparation, deduplication, first-event contract, and reload-safe rerun
local ++test_count
capture noisily {
    tempfile relapse_file edss_source
    clear
    input long id long relapse_date
    1 10
    1 10
    end
    format relapse_date %td
    duplicates drop id relapse_date, force
    save `relapse_file', replace

    clear
    input long id double edss long edss_date long dx_date
    1 2 0   0
    1 3 10  0
    1 3 192 0
    2 2 0   0
    2 3 20  0
    2 3 202 0
    end
    format edss_date dx_date %td
    save `edss_source', replace
    pira id edss edss_date, dxdate(dx_date) ///
        relapses("`relapse_file'") keepall quietly
    assert raw_date == 10 if id == 1
    assert pira_date == 20 if id == 2
    assert "`r(event_scope)'" == "first_confirmed_cdp"

    use `edss_source', clear
    pira id edss edss_date, dxdate(dx_date) ///
        relapses("`relapse_file'") windowbefore(0) windowafter(30) ///
        generate(pira_sensitivity) rawgenerate(raw_sensitivity) keepall quietly
    confirm variable pira_sensitivity raw_sensitivity
}
if !_rc local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' pira_examples"
}

display "RESULT: test_documentation_examples tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    exit 9
}

do "`qa_dir'/_setools_qa_common.do" teardown
