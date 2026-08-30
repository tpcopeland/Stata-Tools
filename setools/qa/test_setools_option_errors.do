*! test_setools_option_errors.do  1.1.0  2026/08/30
*! Boundary option-error, rollback, and caller-state contracts.

version 16.0
capture log close _all

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
do "`qa_dir'/_setools_qa_common.do" setup "`pkg_dir'"

local tests = 0
local pass = 0
local fail = 0

capture program drop _setools_assert_dataset_exact
program define _setools_assert_dataset_exact
    version 16.0
    args expected

    unab actual_vars : _all
    preserve
    use "`expected'", clear
    unab expected_vars : _all
    restore
    local actual_vars : list sort actual_vars
    local expected_vars : list sort expected_vars
    assert "`actual_vars'" == "`expected_vars'"
    cf `actual_vars' using "`expected'"
end

* Negative PIRA relapse-window widths are invalid and must not alter data.
local ++tests
capture noisily {
    tempfile relapses before
    clear
    input long id long relapse_date
    1 1000
    end
    format relapse_date %td
    save "`relapses'", replace

    clear
    input long id double edss long edss_dt long dx_date
    1 2 100 90
    1 3 200 90
    1 3 400 90
    end
    format edss_dt dx_date %td
    gen double sentinel = 17
    save "`before'", replace
    set varabbrev on
    capture noisily pira id edss edss_dt, dxdate(dx_date) ///
        relapses("`relapses'") windowbefore(-1) confirmdays(100) ///
        baselinewindow(30) keepall generate(pira_bad) ///
        rawgenerate(raw_bad) quietly
    local rc = _rc
    assert `rc' == 198
    assert "`c(varabbrev)'" == "on"
    _setools_assert_dataset_exact "`before'"
    capture confirm variable pira_bad raw_bad
    assert _rc == 111
    set varabbrev off
}
if _rc == 0 local ++pass
else local ++fail

* Negative baseline thresholds are invalid and must not alter data.
local ++tests
capture noisily {
    clear
    input long id double edss long edss_dt
    1 5 100
    1 6 200
    1 6 400
    end
    format edss_dt %td
    gen double sentinel = 17
    tempfile before
    save "`before'", replace
    set varabbrev on
    capture noisily sustainedss id edss edss_dt, threshold(6) ///
        baselinethreshold(-.5) keepall generate(sustained_bad) quietly
    local rc = _rc
    assert `rc' == 198
    assert "`c(varabbrev)'" == "on"
    _setools_assert_dataset_exact "`before'"
    capture confirm variable sustained_bad
    assert _rc == 111
    set varabbrev off
}
if _rc == 0 local ++pass
else local ++fail

* Missing required thresholds must fail instead of returning a no-event result.
local ++tests
capture noisily {
    clear
    input long id double edss long edss_dt
    1 5 100
    1 6 200
    1 6 400
    end
    format edss_dt %td
    gen double sentinel = 17
    tempfile before
    save "`before'", replace
    foreach bad in . .a {
        use "`before'", clear
        set varabbrev on
        capture noisily sustainedss id edss edss_dt, threshold(`bad') ///
            keepall generate(sustained_bad) quietly
        local rc = _rc
        assert `rc' == 198
        assert "`c(varabbrev)'" == "on"
        _setools_assert_dataset_exact "`before'"
        capture confirm variable sustained_bad
        assert _rc == 111
    }
    set varabbrev off
}
if _rc == 0 local ++pass
else local ++fail

* Missing baseline thresholds must fail rather than enter a sentinel path.
local ++tests
capture noisily {
    clear
    input long id double edss long edss_dt
    1 5 100
    1 6 200
    1 6 400
    end
    format edss_dt %td
    gen double sentinel = 17
    tempfile before
    save "`before'", replace
    foreach bad in . .a {
        use "`before'", clear
        set varabbrev on
        capture noisily sustainedss id edss edss_dt, threshold(1) ///
            baselinethreshold(`bad') keepall generate(sustained_bad) quietly
        local rc = _rc
        assert `rc' == 198
        assert "`c(varabbrev)'" == "on"
        _setools_assert_dataset_exact "`before'"
        capture confirm variable sustained_bad
        assert _rc == 111
    }
    set varabbrev off
}
if _rc == 0 local ++pass
else local ++fail

* The former public -1 baseline sentinel is invalid input.
local ++tests
capture noisily {
    clear
    input long id double edss long edss_dt
    1 5 100
    1 6 200
    1 6 400
    end
    format edss_dt %td
    gen double sentinel = 17
    tempfile before
    save "`before'", replace
    set varabbrev on
    capture noisily sustainedss id edss edss_dt, threshold(1) ///
        baselinethreshold(-1) keepall generate(sustained_bad) quietly
    local rc = _rc
    assert `rc' == 198
    assert "`c(varabbrev)'" == "on"
    _setools_assert_dataset_exact "`before'"
    capture confirm variable sustained_bad
    assert _rc == 111
    set varabbrev off
}
if _rc == 0 local ++pass
else local ++fail

* Negative CCI lookback widths must fail rather than silently disable the bound.
local ++tests
capture noisily {
    clear
    input long id str3 icd long dx_date long index_date
    1 "I21" 100 200
    end
    format dx_date index_date %td
    gen double sentinel = 17
    tempfile before
    save "`before'", replace
    set varabbrev on
    capture noisily cci_se, id(id) icd(icd) date(dx_date) ///
        indexdate(index_date) lookback(-1)
    local rc = _rc
    assert `rc' == 198
    assert "`c(varabbrev)'" == "on"
    _setools_assert_dataset_exact "`before'"
    capture confirm variable charlson
    assert _rc == 111
    set varabbrev off
}
if _rc == 0 local ++pass
else local ++fail

display "RESULT: test_setools_option_errors tests=`tests' pass=`pass' fail=`fail'"

do "`qa_dir'/_setools_qa_common.do" teardown
if `fail' exit 1
