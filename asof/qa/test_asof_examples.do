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

**# Inline synthetic data and all documented workflows
local ++test_count
capture noisily {
    tempfile events master

    clear
    input long id double visit_date score edss eq5d_uk eq5d_se eq_vas
    1 21990 4 2.0 .80 .78 75
    1 22010 6 2.5 .76 .74 70
    1 22480 8 3.0 .71 .69 65
    2 22070 5 1.5 .85 .83 80
    2 22130 7 2.0 .81 .79 76
    2 22390 9 2.5 .77 .75 72
    3 21950 3 1.0 .90 .88 88
    3 22220 6 1.5 .86 .84 82
    3 22610 8 2.0 .82 .80 78
    end
    format %td visit_date
    save `events'

    clear
    input long id double(index_date study_start followup_date)
    1 22000 21500 22500
    2 22100 21700 22400
    3 22200 22000 22600
    end
    format %td index_date study_start followup_date
    save `master'

    * README/help example 1: closest value on either side.
    use `master', clear
    asof score using `events', id(id) date(visit_date) ///
        anchor(index_date) direction(both) select(nearest) ///
        generate(score_index) datename(score_date) gapname(score_gap) ///
        matchname(score_found)
    assert score_index[1] == 4 & score_index[2] == 5 & score_index[3] == 6
    assert score_gap[1] == -10 & score_gap[2] == -30 & score_gap[3] == 20
    assert score_found == 1

    * README example 2: protocol and observability windows.
    use `master', clear
    asof edss using `events', id(id) date(visit_date) ///
        anchor(index_date) direction(onorbefore) select(nearest) ///
        window(-365 0) range(study_start followup_date) ///
        generate(edss_baseline)
    assert edss_baseline[1] == 2
    assert edss_baseline[2] == 1.5
    assert missing(edss_baseline[3])

    * README/help example 3: last available values.
    use `master', clear
    asof eq5d_uk eq5d_se eq_vas using `events', ///
        id(id) date(visit_date) anchor(followup_date) ///
        direction(onorbefore) select(last) ///
        range(study_start followup_date) suffix(_last) ///
        datename(eq5d_date_last)
    assert abs(eq5d_uk_last[1] - .71) < 1e-6
    assert abs(eq5d_se_last[2] - .75) < 1e-6
    assert eq_vas_last[3] == 82
    assert eq5d_date_last[1] == 22480
    assert eq5d_date_last[2] == 22390
    assert eq5d_date_last[3] == 22220
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
