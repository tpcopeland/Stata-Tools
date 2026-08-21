* test_kmplot_v1210.do
* Regression tests for kmplot 1.2.10
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-08-21

clear all
version 16.0
set varabbrev off

**# Bootstrap
local qa_dir "`c(pwd)'"
do "`qa_dir'/_kmplot_qa_common.do"
_kmplot_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Regression tests
**## R1: An older in-memory helper is replaced before use

local ++test_count
capture noisily {
    capture program drop _kmplot_risktable
    program define _kmplot_risktable, rclass
        version 16.0
        noisily display as error "STALE_HELPER_EXECUTED"
        exit 459
    end

    sysuse cancer, clear
    keep if inlist(drug, 1, 2)
    stset studytime, failure(died)
    kmplot, by(drug) colors(black gray) lpattern(solid dash) ///
        risktable riskevents riskmono ///
        timepoints(0 5 10 15 20 25 30 35) ///
        xlabel(0 5 10 15 20 25 30 35) ///
        name(v1210_stale, replace)

    assert r(N) == 34
    assert r(n_groups) == 2
    assert r(n_timepoints) == 8
}
if _rc == 0 {
    display as result "  PASS: R1 stale helper replaced"
    local ++pass_count
}
else {
    display as error "  FAIL: R1 stale helper replacement (rc=`=_rc')"
    local ++fail_count
}

**## R2: Repeated calls safely reload the installed helper

local ++test_count
capture noisily {
    sysuse cancer, clear
    keep if inlist(drug, 1, 2)
    stset studytime, failure(died)

    forvalues call = 1/2 {
        kmplot, by(drug) colors(black gray) lpattern(solid dash) ///
            risktable riskevents riskmono ///
            timepoints(0 10 20 30) xlabel(0 10 20 30) ///
            name(v1210_repeat`call', replace)
        assert r(N) == 34
        assert r(n_groups) == 2
        assert r(n_timepoints) == 4
    }
}
if _rc == 0 {
    display as result "  PASS: R2 repeated helper reload"
    local ++pass_count
}
else {
    display as error "  FAIL: R2 repeated helper reload (rc=`=_rc')"
    local ++fail_count
}

**# Summary
if `fail_count' > 0 {
    display as error "RESULT: test_kmplot_v1210 tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "RESULT: test_kmplot_v1210 tests=`test_count' pass=`pass_count' fail=`fail_count'"
