*! test_setools_option_errors.do  1.0.0  2026/08/23
*! Boundary option-error and caller-state contracts for setools commands.

version 16.0
capture log close _all

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
do "`qa_dir'/_setools_qa_common.do" setup "`pkg_dir'"

local tests = 0
local pass = 0
local fail = 0

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
    cf _all using "`before'"
    capture confirm variable pira_bad raw_bad
    assert _rc == 111
    set varabbrev off
}
if _rc == 0 local ++pass
else local ++fail

* The -1 sentinel means use threshold(); other negative baseline thresholds
* are invalid and must not alter data.
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
    cf _all using "`before'"
    capture confirm variable sustained_bad
    assert _rc == 111
    set varabbrev off
}
if _rc == 0 local ++pass
else local ++fail

display "RESULT: test_setools_option_errors tests=`tests' pass=`pass' fail=`fail'"

do "`qa_dir'/_setools_qa_common.do" teardown
if `fail' exit 1
