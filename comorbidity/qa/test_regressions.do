*! Regression tests for review-identified comorbidity defects
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
set varabbrev off
set more off
version 16.0

capture log close _all
log using "test_regressions.log", replace nomsg

do "_comorbidity_qa_common.do"
_comorbidity_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Failure atomicity and output-name safety

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1
    1 "E119"
    end
    tempfile before bad
    save "`before'", replace
    preserve
    clear
    input str8 name str8 pattern
    "dm" "E11"
    end
    save "`bad'.dta", replace
    restore
    capture comorbidity dx1, id(pid) custom("`bad'.dta") collapse
    local cmd_rc = _rc
    assert `cmd_rc' == 198
    cf _all using "`before'", all
}
if _rc == 0 {
    display as result "  PASS: invalid custom codefile leaves caller data unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: invalid custom codefile data preservation (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input long charlson str6 dx1
    1 "E119"
    end
    tempfile before
    save "`before'", replace
    capture comorbidity dx1, id(charlson) charlson(original) collapse replace
    local cmd_rc = _rc
    assert `cmd_rc' == 198
    cf _all using "`before'", all
}
if _rc == 0 {
    display as result "  PASS: score cannot overwrite the identifier"
    local ++pass_count
}
else {
    display as error "  FAIL: identifier/score collision guard (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1
    1 "E119"
    end
    tempfile before custom_collision
    save "`before'", replace
    preserve
    clear
    input str12 name str8 pattern double weight
    "custom" "E11" 1
    end
    save "`custom_collision'.dta", replace
    restore
    capture comorbidity dx1, id(pid) custom("`custom_collision'.dta") collapse replace
    local cmd_rc = _rc
    assert `cmd_rc' == 198
    cf _all using "`before'", all
}
if _rc == 0 {
    display as result "  PASS: custom indicator cannot collide with its score"
    local ++pass_count
}
else {
    display as error "  FAIL: custom indicator/score collision guard (error `=_rc')"
    local ++fail_count
}

**# Patient-level summaries

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1
    1 "I50"
    1 "I50"
    1 "I50"
    2 "C780"
    end
    comorbidity dx1, id(pid) charlson(original) merge band
    matrix B = r(bands)
    assert B[rownumb(B, "score1_2"), colnumb(B, "n")] == 1
    assert B[rownumb(B, "score1_2"), colnumb(B, "percent")] == 50
    assert B[rownumb(B, "score5plus"), colnumb(B, "n")] == 1
    assert B[rownumb(B, "score5plus"), colnumb(B, "percent")] == 50
    tempname total_n total_percent
    scalar `total_n' = 0
    scalar `total_percent' = 0
    forvalues row = 1/`=rowsof(B)' {
        scalar `total_n' = `total_n' + B[`row', colnumb(B, "n")]
        scalar `total_percent' = `total_percent' + B[`row', colnumb(B, "percent")]
    }
    assert `total_n' == 2
    assert !missing(`total_percent', 100)
    assert reldif(`total_percent', 100) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: merge bands count patients rather than encounter rows"
    local ++pass_count
}
else {
    display as error "  FAIL: merge band patient denominator (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1
    1 "F32"
    2 "E66"
    end
    comorbidity dx1, id(pid) elixhauser(vanwalraven) collapse band
    matrix B = r(bands)
    assert B[rownumb(B, "score_negative"), colnumb(B, "n")] == 2
    assert B[rownumb(B, "score_negative"), colnumb(B, "percent")] == 100
    assert B[rownumb(B, "score0"), colnumb(B, "n")] == 0
    tempname total_n total_percent
    scalar `total_n' = 0
    scalar `total_percent' = 0
    forvalues row = 1/`=rowsof(B)' {
        scalar `total_n' = `total_n' + B[`row', colnumb(B, "n")]
        scalar `total_percent' = `total_percent' + B[`row', colnumb(B, "percent")]
    }
    assert `total_n' == 2
    assert !missing(`total_percent', 100)
    assert reldif(`total_percent', 100) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: negative scores have an explicit exhaustive band"
    local ++pass_count
}
else {
    display as error "  FAIL: negative score bands (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 str6 dx2
    1 "C780" "C509"
    end
    comorbidity dx1 dx2, id(pid) charlson(original) collapse
    assert cancer[1] == 0
    matrix S = r(summary)
    local cancer_row = rownumb(S, "cancer")
    assert S[`cancer_row', colnumb(S, "count")] == 0
    assert S[`cancer_row', colnumb(S, "prevalence")] == 0
    assert missing(S[`cancer_row', colnumb(S, "total_hits")])
    assert S[`cancer_row', colnumb(S, "positive_units")] == 0
}
if _rc == 0 {
    display as result "  PASS: r(summary) reflects post-hierarchy indicators"
    local ++pass_count
}
else {
    display as error "  FAIL: post-hierarchy r(summary) (error `=_rc')"
    local ++fail_count
}

**# Summary

_comorbidity_result test_regressions `test_count' `pass_count' `fail_count'
log close _all
