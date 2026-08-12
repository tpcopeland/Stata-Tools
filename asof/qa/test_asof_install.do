clear all
set processors 1
set varabbrev off
version 16.0

capture log close _all
log using "test_asof_install.log", replace text nomsg
global ASOF_QA_STATUS "fail"

do "_asof_qa_common.do"
quietly _asof_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Every runtime helper resolves from the installed package
local ++test_count
capture noisily {
    discard
    which asof
    which _asof_parse_rules
    which _asof_load_using
    which _asof_join
    which _asof_report
    findfile _asof_mata.ado
    findfile asof.sthlp
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# A fresh call after clear mata reloads the shipped engine
local ++test_count
capture noisily {
    tempfile events
    clear mata
    clear
    input long id double visit value
    1 90 9
    1 110 11
    end
    save `events'
    clear
    input long id double anchor
    1 100
    end
    asof value using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest)
    assert value_asof == 9
    mata: _asof_mata_present()
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# The documented basic workflow runs after net install
local ++test_count
capture noisily {
    tempfile visits
    clear
    input long id double visit_date score
    1 90 4
    1 110 6
    2 205 8
    end
    format %td visit_date
    save `visits'
    clear
    input long id double index_date
    1 100
    2 200
    end
    format %td index_date
    asof score using `visits', id(id) date(visit_date) anchor(index_date) ///
        direction(both) select(nearest) generate(score_index) ///
        datename(score_date) gapname(score_gap) matchname(score_found)
    assert score_index[1] == 4 & score_index[2] == 8
    assert score_gap[1] == -10 & score_gap[2] == 5
    assert score_found == 1
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# A stale Mata marker cannot shadow the installed scan implementation
local ++test_count
capture noisily {
    tempfile events
    clear mata
    mata: void _asof_mata_present() {}
    clear
    input long id double visit value
    1 90 9
    1 110 11
    end
    save `events'
    clear
    input long id double anchor
    1 100
    end
    asof value using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) generate(got)
    assert got == 9
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Package metadata declares every shipped runtime source
local ++test_count
capture noisily {
    foreach file in asof.ado _asof_parse_rules.ado _asof_load_using.ado ///
        _asof_join.ado _asof_report.ado _asof_mata.ado asof.sthlp {
        confirm file "`pkg_dir'/`file'"
    }
    confirm file "`pkg_dir'/asof.pkg"
    confirm file "`pkg_dir'/stata.toc"
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_asof_install tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 {
    capture log close _all
    exit 1
}
global ASOF_QA_STATUS "pass"
log close _all
