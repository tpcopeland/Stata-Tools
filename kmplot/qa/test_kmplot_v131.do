* test_kmplot_v131.do
* Regression pins for the 2026-09-29 review findings F1-F8
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-09-30

clear all
version 16.0
local qa_dir "`c(pwd)'"
do "`qa_dir'/_kmplot_qa_common.do"
_kmplot_qa_bootstrap
do "`qa_dir'/_qa_hostile.do"
do "`qa_dir'/_qa_state.do"
capture program drop _kmplot_qa_text
program define _kmplot_qa_text, rclass
    version 16.0
    args corpus_global
    mata: st_local("text", st_global(st_local("corpus_global")))
    kmplot, by(drug) risktable timepoints(0) pvalue ///
        title(`"`macval(text)'"') subtitle(`"`macval(text)'"') ///
        xtitle(`"`macval(text)'"') ytitle(`"`macval(text)'"') ///
        note(`"`macval(text)'"') pvaluetext(`"`macval(text)'"')
    qa_assert_text `corpus_global' r(xtitle), property("literal x-axis title")
    qa_assert_text `corpus_global' r(ytitle), property("literal y-axis title")
    qa_assert_text `corpus_global' r(pvalue_label), property("literal p-value label")
    return add
end

local test_count = 0
local pass_count = 0
local fail_count = 0

**## F1 every rendered step retains exact saved bounds
local ++test_count
capture noisily {
    clear
    set obs 5
    gen double t = _n/7
    gen byte d = _n<5
    quietly stset t, failure(d)
    tempfile curve oracle
    kmplot, ci saving("`curve'", replace)
    preserve
    use "`curve'", clear
    sort time
    gen double prevlo = cond(_n==1,lower,lower[_n-1])
    gen double prevhi = cond(_n==1,upper,upper[_n-1])
    keep time lower upper prevlo prevhi
    save "`oracle'", replace
    serset set 0
    serset use, clear
    unab cols : _all
    local hi : word 1 of `cols'
    local lo : word 2 of `cols'
    local tt : word 3 of `cols'
    rename `tt' time
    gen long coord = _n
    assert _N == 12
    merge m:1 time using "`oracle'", assert(match) nogen
    assert !missing(`hi',`lo',lower,upper,prevlo,prevhi)
    assert `hi' == cond(mod(coord,2)==0,upper,prevhi)
    assert `lo' == cond(mod(coord,2)==0,lower,prevlo)
    restore
}
local test_rc = _rc
capture restore
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: F1 every rendered step retains exact saved bounds"
}
else {
    local ++fail_count
    display as error "FAIL: F1 every rendered step retains exact saved bounds (rc=`test_rc')"
}

**## F2 exact and adjacent landmark and risk requests
local ++test_count
capture noisily {
    clear
    set obs 5
    gen double t = _n/7
    gen byte d = _n<5
    quietly stset t, failure(d)
    kmplot, landmark(.14285714285714282 .14285714285714285 .14285714285714288) ///
        risksaving("`c(tmpdir)'/km_precision.dta", replace) ///
        timepoints(.14285714285714282 .14285714285714285 .14285714285714288)
    tempname lm rt
    matrix `lm' = r(landmarks)
    matrix `rt' = r(risktable)
    assert `lm'[1,2] == .14285714285714282
    assert `lm'[2,2] == 1/7
    assert `lm'[3,2] == .14285714285714288
    assert `lm'[1,3] == 1 & abs(`lm'[2,3]-.8)<1e-14 & abs(`lm'[3,3]-.8)<1e-14
    assert `rt'[1,4] == 0 & `rt'[2,4] == 1 & `rt'[3,4] == 1
    assert `rt'[1,3] == 5 & `rt'[2,3] == 5 & `rt'[3,3] == 4
    erase "`c(tmpdir)'/km_precision.dta"
}
local test_rc = _rc
capture restore
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: F2 exact and adjacent landmark and risk requests"
}
else {
    local ++fail_count
    display as error "FAIL: F2 exact and adjacent landmark and risk requests (rc=`test_rc')"
}

**## F3 per-group support and terminal zero
local ++test_count
capture noisily {
    clear
    * H pin: each group has four subjects; three failures then censoring gives S=.25.
    input byte g double t byte d
    1 1 1
    1 2 1
    1 3 1
    1 4 0
    2 2 1
    2 4 1
    2 6 1
    2 8 0
    3 1 1
    3 2 1
    3 3 1
    3 4 1
    end
    quietly stset t, failure(d)
    foreach mode in survival failure {
        local opt ""
        if "`mode'" == "failure" local opt failure
        kmplot, by(g) ci landmark(4 5 8 100) `opt'
        tempname lm
        matrix `lm' = r(landmarks)
        assert !missing(`lm'[1,3]) & missing(`lm'[2,3],`lm'[2,4],`lm'[2,5])
        assert !missing(`lm'[7,3]) & missing(`lm'[8,3])
        assert `lm'[12,3] == ("`mode'" == "failure")
    }
}
local test_rc = _rc
capture restore
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: F3 per-group support and terminal zero"
}
else {
    local ++fail_count
    display as error "FAIL: F3 per-group support and terminal zero (rc=`test_rc')"
}

**## F4 censor count and tail beyond int storage
local ++test_count
capture noisily {
    clear
    set obs 33000
    gen double t = _n
    gen byte d = 0
    quietly stset t, failure(d)
    tempfile curve
    kmplot, censor censorthin(2) saving("`curve'", replace)
    preserve
    use "`curve'", clear
    count if censor==1
    assert r(N)==16500
    count if censor==1 & time>32740
    assert r(N)==130
    assert censor==1 if time==33000
    assert censor==0 if time==32741
    restore
}
local test_rc = _rc
capture restore
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: F4 censor count and tail beyond int storage"
}
else {
    local ++fail_count
    display as error "FAIL: F4 censor count and tail beyond int storage (rc=`test_rc')"
}

**## F5 quoted p-value label and state restoration
local ++test_count
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    set varabbrev on
    global S_1 "caller group"
    global S_5 "caller df"
    global S_6 "caller statistic"
    qa_state_snapshot, tag(quoted)
    kmplot, by(drug) pvalue pvaluetext(`"Treatment "A" test"')
    assert `"`r(pvalue_label)'"' == `"Treatment "A" test"'
    assert !missing(r(p)) & r(p)<.001
    qa_state_compare, tag(quoted)
    qa_state_snapshot, tag(error)
    capture noisily kmplot, by(drug) pvalue pvaluetext(`"Treatment "A" test"') ///
        saving("bad;path.dta", replace)
    local badrc = _rc
    assert `badrc'==198
    qa_state_compare, tag(error)
    assert c(varabbrev)=="on"
}
local test_rc = _rc
capture restore
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: F5 quoted p-value label and state restoration"
}
else {
    local ++fail_count
    display as error "FAIL: F5 quoted p-value label and state restoration (rc=`test_rc')"
}

**## F6 comma titles survive into SVG
local ++test_count
capture noisily {
    clear
    set obs 5
    gen double t = _n/7
    gen byte d = _n<5
    quietly stset t, failure(d)
    tempfile svg
    kmplot, title("Survival, by treatment") subtitle("Follow-up, in years") ///
        export("`svg'", as(svg) replace)
    _kmplot_assert_file_contains using "`svg'", pattern("Survival, by treatment")
    _kmplot_assert_file_contains using "`svg'", pattern("Follow-up, in years")
}
local test_rc = _rc
capture restore
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: F6 comma titles survive into SVG"
}
else {
    local ++fail_count
    display as error "FAIL: F6 comma titles survive into SVG (rc=`test_rc')"
}

**## F7 pweight estimates counts and inference refusals
local ++test_count
capture noisily {
    sysuse cancer, clear
    gen double w = 1+mod(_n,3)
    quietly stset studytime [pw=w], failure(died)
    quietly sts generate native = s
    quietly summarize w, meanonly
    scalar expected_weight = r(sum)
    tempfile curve
    kmplot, risktable timepoints(0) landmark(10) saving("`curve'", replace)
    assert r(risktable)[1,3] == scalar(expected_weight)
    assert r(N)==48
    preserve
    use "`curve'", clear
    assert missing(se,lower,upper)
    assert !missing(estimate)
    restore
    foreach opt in ci pvalue {
        qa_state_snapshot, tag(pwerror)
        capture noisily kmplot, by(drug) `opt'
        local badrc = _rc
        assert `badrc'==198
        qa_state_compare, tag(pwerror)
    }
    * Independent native point oracle, matched on original analysis times.
    preserve
    keep _t native
    rename _t time
    collapse (mean) native, by(time)
    tempfile oracle
    save "`oracle'", replace
    use "`curve'", clear
    merge m:1 time using "`oracle'", keep(master match) nogen
    assert !missing(native,estimate) if anchor==0
    assert abs(native-estimate)<1e-14 if anchor==0
    restore
    scalar drop expected_weight
}
local test_rc = _rc
capture restore
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: F7 pweight estimates counts and inference refusals"
}
else {
    local ++fail_count
    display as error "FAIL: F7 pweight estimates counts and inference refusals (rc=`test_rc')"
}

**## F8 comma filenames across all writers
local ++test_count
capture noisily {
    clear
    set obs 5
    gen double t = _n/7
    gen byte d = _n<5
    quietly stset t, failure(d)
    local curve "`c(tmpdir)'/curve,a.dta"
    local risk "`c(tmpdir)'/risk,a.dta"
    local svg "`c(tmpdir)'/graph,a.svg"
    kmplot, landmark(0) timepoints(0) saving("`curve'", replace) ///
        risksaving("`risk'", replace) export("`svg'", replace)
    assert `"`r(saving)'"' == `"`curve'"'
    assert `"`r(risksaving)'"' == `"`risk'"'
    _kmplot_assert_file_contains using "`svg'", pattern("Survival probability")
    preserve
    use "`curve'", clear
    assert _N==6
    assert estimate==1 if anchor==1
    use "`risk'", clear
    assert _N==1 & at_risk==5 & events==0
    restore
    erase "`curve'"
    erase "`risk'"
    erase "`svg'"
}
local test_rc = _rc
capture restore
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: F8 comma filenames across all writers"
}
else {
    local ++fail_count
    display as error "FAIL: F8 comma filenames across all writers (rc=`test_rc')"
}

**## hostile time requests retain their literal values
local ++test_count
capture noisily {
    clear
    set obs 5
    qa_hostile_times, generate(t)
    local requests "`r(values)'"
    gen byte d=1
    quietly stset t, failure(d)
    * expect: EXACT
    kmplot, landmark(`requests')
    tempname lm
    matrix `lm'=r(landmarks)
    assert rowsof(`lm')==5
    assert abs(`lm'[1,3]-.8)<1e-14
    assert abs(`lm'[2,3]-.6)<1e-14
    assert `lm'[5,3]==0
}
local test_rc = _rc
capture restore
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: hostile time requests retain their literal values"
}
else {
    local ++fail_count
    display as error "FAIL: hostile time requests retain their literal values (rc=`test_rc')"
}

**## numlist grammar and request ordering
* guard: expected green at pre-fix ref; preserves existing integer numlist syntax.
local ++test_count
capture noisily {
    clear
    set obs 5
    gen double t = _n/7
    gen byte d = _n<5
    quietly stset t, failure(d)
    foreach spec in "0(1)4" "0[1]4" "0/4" "0 1 to 4" "0 1:4" "4(-1)0" {
        kmplot, landmark(`spec')
        assert r(n_landmarks)==5
        assert r(landmarks)[1,2]==0 & r(landmarks)[5,2]==4
    }
}
local test_rc = _rc
capture restore
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: numlist grammar and request ordering"
}
else {
    local ++fail_count
    display as error "FAIL: numlist grammar and request ordering (rc=`test_rc')"
}

**## literal text across every label option
local ++test_count
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    * expect: EXACT
    qa_hostile_strings, check(_kmplot_qa_text) result(r(pvalue_label))
}
local test_rc = _rc
capture restore
if `test_rc' == 0 {
    local ++pass_count
    display as result "PASS: literal text across every label option"
}
else {
    local ++fail_count
    display as error "FAIL: literal text across every label option (rc=`test_rc')"
}

display "RESULT: test_kmplot_v131 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
