clear all
set processors 1
set varabbrev off
version 16.0

capture log close _all
log using "test_asof_examples.log", replace text nomsg
global ASOF_QA_STATUS "fail"

do "_asof_qa_common.do"
quietly _asof_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Current help-file examples, copied verbatim from asof.sthlp
local ++test_count
capture noisily {
    tempfile events

    clear
    input long id double visit_date score edss
    1 90 4 2
    1 110 6 2.5
    1 140 8 3
    2 190 5 1.5
    2 230 9 2.5
    end
    format %td visit_date
    save `events'

    clear
    input long id double(index_date study_start followup_date)
    1 100 50 150
    2 200 160 240
    end
    format %td index_date study_start followup_date

    asof score using `events', id(id) date(visit_date) anchor(index_date) direction(both) select(nearest) generate(score_index) datename(score_date) gapname(score_gap) matchname(score_found)
    assert score_index[1] == 4 & score_index[2] == 5
    assert score_date[1] == 90 & score_date[2] == 190
    assert score_gap[1] == -10 & score_gap[2] == -10
    assert score_found == 1

    asof edss using `events', id(id) date(visit_date) anchor(followup_date) range(study_start followup_date) direction(onorbefore) select(last) suffix(_last)
    assert edss_last[1] == 3 & edss_last[2] == 2.5
    assert r(N_matched) == 2 & r(N_unmatched) == 0
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Public examples do not require an undisclosed checkout substitution
local ++test_count
capture noisily {
    tempfile filtered_help filtered_readme filtered_demo
    local dev_repo = "Stata" + char(45) + "Dev"
    filefilter "`pkg_dir'/asof.sthlp" `filtered_help', ///
        from("/path/to/_data/asof") to("__forbidden_path__")
    assert r(occurrences) == 0
    filefilter "`pkg_dir'/README.md" `filtered_readme', ///
        from("/path/to/`dev_repo'/_data/asof") to("__forbidden_path__")
    assert r(occurrences) == 0
    filefilter "`pkg_dir'/demo/demo_asof.do" `filtered_demo', ///
        from("`dev_repo'/_data/asof") to("__forbidden_path__")
    assert r(occurrences) == 0
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_asof_examples tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 {
    capture log close _all
    exit 1
}
global ASOF_QA_STATUS "pass"
log close _all
