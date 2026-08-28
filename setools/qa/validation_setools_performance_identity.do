*! validation_setools_performance_identity.do  1.0.0  2026/08/28
*! Exact identity checks for setools performance helpers

version 16.0
capture log close _all
set more off

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
do "`qa_dir'/_setools_qa_common.do" setup_runner "`pkg_dir'"

local tests = 0
local pass = 0
local fail = 0

capture noisily {
    clear
    input long obs_id long id byte is_visit long event_date double edss ///
        double baseline_edss long baseline_date
     1 1 1 100 2.0 2.0 100
     . 1 0 100   . 2.0 100
     . 1 0 120   . 2.0 100
     2 1 1 149 2.5 2.0 100
     3 1 1 150 3.0 2.0 100
     . 1 0 160   . 2.0 100
     . 1 0 170   . 2.0 100
     4 1 1 199 3.2 2.0 100
     5 1 1 200 3.5 2.0 100
     . 1 0 210   . 2.0 100
     6 1 1 240 4.0 2.0 100
     7 2 1 100 4.0 4.0 100
     8 2 1 200 4.5 4.0 100
     . 3 0 110   . 1.0 100
     . 3 0 140   . 1.0 100
    end
    format event_date baseline_date %td
    sort id event_date is_visit edss obs_id
    by id: gen byte newid = _n == 1
    gen long row_id = _n

    preserve
    gen double expected_edss = baseline_edss
    gen long expected_date = baseline_date
    gen double current_edss = .
    gen long current_date = .
    gen long pending_relapse = .
    quietly count
    local n = r(N)
    forvalues i = 1/`n' {
        if newid[`i'] {
            quietly replace current_edss = baseline_edss in `i'
            quietly replace current_date = baseline_date in `i'
            quietly replace pending_relapse = . in `i'
        }
        else {
            local j = `i' - 1
            quietly replace current_edss = current_edss[`j'] in `i'
            quietly replace current_date = current_date[`j'] in `i'
            quietly replace pending_relapse = pending_relapse[`j'] in `i'
        }
        if is_visit[`i'] == 0 {
            if !missing(event_date[`i']) & event_date[`i'] > current_date[`i'] {
                quietly replace pending_relapse = event_date in `i'
            }
        }
        else {
            if !missing(pending_relapse[`i']) & ///
                event_date[`i'] >= pending_relapse[`i'] + 30 {
                quietly replace current_edss = edss in `i'
                quietly replace current_date = event_date in `i'
                quietly replace pending_relapse = . in `i'
            }
            quietly replace expected_edss = current_edss[`i'] in `i'
            quietly replace expected_date = current_date[`i'] in `i'
        }
    }
    keep row_id expected_edss expected_date
    tempfile expected
    save `expected', replace
    restore

    _setools_pira_rebase event_date edss, newid(newid) ///
        isvisit(is_visit) baseedss(baseline_edss) basedate(baseline_date)
    merge 1:1 row_id using `expected', assert(3) nogen
    assert baseline_edss == expected_edss if is_visit
    assert baseline_date == expected_date if is_visit
    assert baseline_edss == 3.0 & baseline_date == 150 if obs_id == 3
    assert baseline_edss == 3.5 & baseline_date == 200 if obs_id == 5
    assert baseline_edss == 4.0 & baseline_date == 240 if obs_id == 6
    assert baseline_edss == 4.0 & baseline_date == 100 if id == 2
    assert baseline_edss == 1.0 & baseline_date == 100 if id == 3
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: legacy and Mata PIRA rebaseline states differ (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: legacy and Mata PIRA rebaseline states are row-identical"
}

capture noisily {
    clear
    input long id double source
    1 5
    1 .
    1 3
    1 3
    2 .
    3 7
    3 .a
    3 8
    end
    gen long row_id = _n
    quietly egen double expected = min(source), by(id)
    gen double actual = source
    sort id row_id
    _setools_gmin actual, by(id)
    assert actual == expected if !missing(expected)
    assert missing(actual) == missing(expected)
    assert row_id == _n
    assert actual == 3 if id == 1
    assert missing(actual) if id == 2
    assert actual == 7 if id == 3
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: egen and sort-free group minima differ (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: egen and sort-free group minima are row-identical"
}

display "RESULT: validation_setools_performance_identity tests=`tests' pass=`pass' fail=`fail'"
do "`qa_dir'/_setools_qa_common.do" teardown_runner
if `fail' > 0 exit 9
