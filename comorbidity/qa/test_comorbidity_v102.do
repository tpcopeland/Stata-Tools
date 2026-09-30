*! comorbidity 1.0.2 review regressions
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set varabbrev off
capture log close _all
log using "test_comorbidity_v102.log", replace nomsg
do "_comorbidity_qa_common.do"
_comorbidity_qa_bootstrap
do "_qa_state.do"
do "_qa_hostile.do"
local test_count = 0
local pass_count = 0
local fail_count = 0

**# F1: Exact custom-weight transport at band boundaries

local ++test_count
capture noisily {
    clear
    set obs 1
    gen str8 name = "tiny"
    gen str8 pattern = "I21"
    gen double weight = 3 - 2^-51
    tempname truth W B
    scalar `truth' = weight[1]
    tempfile codes
    local codepath "`codes'.dta"
    save "`codepath'", replace
    clear
    input long pid str6 dx
    1 "I21"
    end
    comorbidity dx, id(pid) custom("`codepath'") band
    matrix `W' = r(weights)
    matrix `B' = r(bands)
    * Exact equality is intentional: this is lossless double transport.
    assert !missing(custom, `truth')
    assert custom == `truth'
    assert `W'[1,1] == `truth'
    assert `B'[rownumb(`B', "score1_2"),1] == 1
    assert `B'[rownumb(`B', "score5plus"),1] == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: dta weight immediately below 3"
}
else {
    local ++fail_count
    display as error "FAIL: dta weight immediately below 3 (error `=_rc')"
}

local ++test_count
capture noisily {
    clear
    set obs 1
    gen str8 name = "tiny"
    gen str8 pattern = "I21"
    gen double weight = 5 - 2^-50
    tempname truth W B
    scalar `truth' = weight[1]
    tempfile codes
    local codepath "`codes'.dta"
    save "`codepath'", replace
    clear
    input long pid str6 dx
    1 "I21"
    end
    comorbidity dx, id(pid) custom("`codepath'") band
    matrix `W' = r(weights)
    matrix `B' = r(bands)
    * Exact equality is intentional: this is lossless double transport.
    assert !missing(custom, `truth')
    assert custom == `truth'
    assert `W'[1,1] == `truth'
    assert `B'[rownumb(`B', "score3_4"),1] == 1
    assert `B'[rownumb(`B', "score5plus"),1] == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: dta weight immediately below 5"
}
else {
    local ++fail_count
    display as error "FAIL: dta weight immediately below 5 (error `=_rc')"
}

local ++test_count
capture noisily {
    clear
    set obs 1
    gen str8 name = "tiny"
    gen str8 pattern = "I21"
    gen double weight = 3 - 2^-51
    tempname truth W B
    scalar `truth' = weight[1]
    tempfile codes
    local codepath "`codes'.csv"
    format weight %24.17g
    export delimited using "`codepath'", replace datafmt
    clear
    input long pid str6 dx
    1 "I21"
    end
    comorbidity dx, id(pid) custom("`codepath'") band
    matrix `W' = r(weights)
    matrix `B' = r(bands)
    * Exact equality is intentional: this is lossless double transport.
    assert !missing(custom, `truth')
    assert custom == `truth'
    assert `W'[1,1] == `truth'
    assert `B'[rownumb(`B', "score1_2"),1] == 1
    assert `B'[rownumb(`B', "score5plus"),1] == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: csv weight immediately below 3"
}
else {
    local ++fail_count
    display as error "FAIL: csv weight immediately below 3 (error `=_rc')"
}

local ++test_count
capture noisily {
    clear
    set obs 1
    gen str8 name = "tiny"
    gen str8 pattern = "I21"
    gen double weight = 5 - 2^-50
    tempname truth W B
    scalar `truth' = weight[1]
    tempfile codes
    local codepath "`codes'.csv"
    format weight %24.17g
    export delimited using "`codepath'", replace datafmt
    clear
    input long pid str6 dx
    1 "I21"
    end
    comorbidity dx, id(pid) custom("`codepath'") band
    matrix `W' = r(weights)
    matrix `B' = r(bands)
    * Exact equality is intentional: this is lossless double transport.
    assert !missing(custom, `truth')
    assert custom == `truth'
    assert `W'[1,1] == `truth'
    assert `B'[rownumb(`B', "score3_4"),1] == 1
    assert `B'[rownumb(`B', "score5plus"),1] == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: csv weight immediately below 5"
}
else {
    local ++fail_count
    display as error "FAIL: csv weight immediately below 5 (error `=_rc')"
}

**# F4: Merge preserves declared sort keys and encounter order

local ++test_count
capture noisily {
    clear
    input long pid byte visit str6 dx
    1 2 "I21"
    1 1 "I50"
    2 1 "E119"
    end
    sort pid visit
    gen long original_row = _n
    local before : sortedby
    comorbidity dx, id(pid) charlson(original) merge
    local after : sortedby
    assert "`after'" == "`before'"
    assert original_row == _n
    by pid visit: assert _N == 1
    assert charlson == 2 if pid == 1
    assert charlson == 1 if pid == 2
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: merge retains composite sortedby and by usability"
}
else {
    local ++fail_count
    display as error "FAIL: merge retains composite sortedby and by usability (error `=_rc')"
}

local ++test_count
capture noisily {
    clear
    input long pid str6 dx
    2 "I21"
    1 "E119"
    2 "I50"
    end
    gen long original_row = _n
    local before : sortedby
    assert "`before'" == ""
    comorbidity dx, id(pid) charlson(original) merge
    assert original_row == _n
    local after : sortedby
    assert "`after'" == ""
    assert charlson == 2 if pid == 2
    assert charlson == 1 if pid == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: unsorted merge retains encounter order"
}
else {
    local ++fail_count
    display as error "FAIL: unsorted merge retains encounter order (error `=_rc')"
}

**# F5: Exact variable identities

local ++test_count
capture noisily {
    clear
    input long CHARLSON str6 dx
    1 "I21"
    end
    comorbidity dx, id(CHARLSON) charlson(original)
    assert CHARLSON == 1
    assert charlson == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: case-distinct identifier is legal"
}
else {
    local ++fail_count
    display as error "FAIL: case-distinct identifier is legal (error `=_rc')"
}

local ++test_count
capture noisily {
    clear
    input str8 name str8 pattern double weight
    "CUSTOM" "I50" 3
    end
    tempfile codes
    save "`codes'.dta", replace
    clear
    input long pid str6 dx1 str6 dx2
    1 "I21" "I50"
    end
    comorbidity dx1 dx2, id(pid) custom("`codes'.dta")
    assert pid == 1
    assert CUSTOM == 1 & custom == 3
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: case-distinct custom output names are legal"
}
else {
    local ++fail_count
    display as error "FAIL: case-distinct custom output names are legal (error `=_rc')"
}

**# F6: Invalid bounds refuse before changing caller data

local ++test_count
capture noisily {
    clear
    input long pid str6 dx int dt int ref
    1 "I21" 100 200
    end
    tempfile before
    save "`before'", replace
    capture comorbidity dx, id(pid) charlson(original) date(dt) refdate(ref) lookback(-2)
    local cmd_rc = _rc
    assert `cmd_rc' == 198
    unab current_vars : _all
    preserve
    use "`before'", clear
    unab expected_vars : _all
    restore
    assert "`current_vars'" == "`expected_vars'"
    cf _all using "`before'", all
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: lookback below sentinel refuses atomically"
}
else {
    local ++fail_count
    display as error "FAIL: lookback below sentinel refuses atomically (error `=_rc')"
}

local ++test_count
capture noisily {
    clear
    input long pid str6 dx int dt int ref
    1 "I21" 100 200
    end
    tempfile before
    save "`before'", replace
    capture comorbidity dx, id(pid) charlson(original) date(dt) refdate(ref) lookforward(-2)
    local cmd_rc = _rc
    assert `cmd_rc' == 198
    unab current_vars : _all
    preserve
    use "`before'", clear
    unab expected_vars : _all
    restore
    assert "`current_vars'" == "`expected_vars'"
    cf _all using "`before'", all
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: lookforward below sentinel refuses atomically"
}
else {
    local ++fail_count
    display as error "FAIL: lookforward below sentinel refuses atomically (error `=_rc')"
}

local ++test_count
capture noisily {
    foreach bound in -1 0 10 {
        clear
        set obs 3
        gen long pid = 1
        gen str6 dx = cond(_n == 1, "I21", cond(_n == 2, "I50", "E119"))
        gen int dt = 100 * _n
        gen int ref = 200
        local inc = cond(`bound' >= 0, "inclusive", "")
        comorbidity dx, id(pid) charlson(original) date(dt) refdate(ref) ///
            lookback(`bound') lookforward(`bound') `inc'
        assert charlson == cond(`bound' == -1, 3, 1)
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: sentinel zero and positive windows retain legal semantics"
}
else {
    local ++fail_count
    display as error "FAIL: sentinel zero and positive windows retain legal semantics (error `=_rc')"
}


**# Adversarial caller-state receipts
local ++test_count
capture noisily {
    clear
    set obs 4
    gen long pid = _n
    gen double x = _n
    gen double y = _n^2
    gen str6 dx = "I21"
    quietly regress y x
    matrix wmat = (42, 99)
    scalar custom_abs_total = 42
    char _dta[user_sentinel] "retain"
    sort pid
    set varabbrev on
    qa_state_snapshot, tag(cmb_success) rreturn
    comorbidity dx, id(pid) charlson(original) merge
    * merge documents adding indicators and score; rclass posts r().
    qa_state_compare, tag(cmb_success) allow(data r)
    assert charlson == 1
    qa_state_snapshot, tag(cmb_err) rreturn
    capture comorbidity dx, id(pid) charlson(original) nosuchoption
    local cmd_rc = _rc
    assert `cmd_rc' == 198
    assert `cmd_rc' != 0
    qa_state_compare, tag(cmb_err) allow(r)
    tempfile missing_codes
    qa_state_snapshot, tag(cmb_late_err) rreturn
    capture noisily comorbidity dx, id(pid) custom("`missing_codes'_absent.dta") merge
    local cmd_rc = _rc
    assert `cmd_rc' == 601
    qa_state_compare, tag(cmb_late_err) allow(r)
    set varabbrev off
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: populated caller-state success and early-error fingerprints"
}
else {
    local ++fail_count
    display as error "FAIL: caller-state fingerprints (error `=_rc')"
}

local ++test_count
capture noisily {
    qa_hostile_codes, clear
    gen str6 dx = "I21"
    comorbidity dx, id(code) charlson(original)
    assert r(N) == 5
    assert _N == 5
    assert charlson == 1
    count if code == 3000000000
    assert r(N) == 1
    count if code == 3000000001
    assert r(N) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: hostile double identifiers stay distinct"
}
else {
    local ++fail_count
    display as error "FAIL: hostile double identifiers (error `=_rc')"
}

**# Summary
_comorbidity_result test_comorbidity_v102 `test_count' `pass_count' `fail_count'
log close _all
