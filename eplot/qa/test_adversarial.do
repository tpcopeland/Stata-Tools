*! test_adversarial.do - qa-lib adversarial axes for eplot
*! Session fingerprint on the error path (unknown option, the data-mode
*! one-limit refusal, the multi-model msymbol() count refusal); lifecycle of
*! eplot . against an overwritten and restored estimation result; parity of
*! the estimate and limits across r(table), the export() frame and its values
*! text, against Stata's own regress r(table); hostile label strings carried
*! byte-identically through labels() into export() and through the missing-row
*! note; and non-decimal doubles carried exactly through data and matrix modes.

clear all
set varabbrev off
set graphics off
version 16.0

capture log close _all
log using "test_adversarial.log", replace text nomsg

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
do "`qa_dir'/_eplot_qa_common.do"
quietly _eplot_qa_bootstrap
do "`qa_dir'/_qa_state.do"
do "`qa_dir'/_qa_hostile.do"
do "`qa_dir'/_qa_lifecycle.do"
do "`qa_dir'/_qa_parity.do"

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

* labels() round trip for qa_hostile_strings: the corpus string g labels
* row 2 (plotted) and row 3 (missing estimate, so it is named in the note);
* the exported label of row 2 must be byte-identical to g.
capture program drop _adv_label_check
program define _adv_label_check
    version 16.0
    args g
    mata: st_local("s", st_global("`g'"))
    clear
    quietly set obs 3
    gen str80 lab = "first"
    quietly replace lab = `"`macval(s)'"' in 2/3
    gen double es = cond(_n == 3, ., _n / 10)
    gen double lo = es - 0.05
    replace lo = 0.1 in 3
    gen double hi = es + 0.05
    replace hi = 0.2 in 3
    capture frame drop _adv_hs
    eplot es lo hi, labels(lab) export(_adv_hs) nodraw
    frame _adv_hs: mata: st_global("ADV_HS_GOT", st_sdata(2, "label"))
    frame drop _adv_hs
end

**# Fingerprint: error paths leave the caller's state untouched
**## 1. unknown option, data-mode one-limit refusal, msymbol() count refusal
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    estimates store adv_a
    quietly regress price mpg
    estimates store adv_b
    quietly regress price weight foreign
    * Objects a careless cleanup would drop: names eplot uses internally.
    matrix table = (1, 2, 3)
    scalar es = 42
    gen double lci = price - 1000
    gen double uci = price + 1000
    replace uci = . in 3
    qa_state_snapshot, tag(adv_err1)
    capture eplot price lci uci in 1/5, nosuchoption nodraw
    assert _rc == 198
    qa_state_compare, tag(adv_err1)
    qa_state_snapshot, tag(adv_err2)
    capture eplot price lci uci in 1/5, nodraw
    assert _rc == 198
    qa_state_compare, tag(adv_err2)
    qa_state_snapshot, tag(adv_err3)
    capture eplot adv_a adv_b, msymbol(O D T) nodraw
    assert _rc == 198
    qa_state_compare, tag(adv_err3)
    matrix drop table
    scalar drop es
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**## 2. success path with a noted missing row: only r() changes
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price weight foreign
    gen double lci = price - 1000
    gen double uci = price + 1000
    sort rep78 make
    replace price = . in 2
    qa_state_snapshot, tag(adv_ok) rreturn
    eplot price lci uci in 1/6, labels(make) nodraw
    qa_state_compare, tag(adv_ok) allow(r)
    assert r(k) == 5
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**# Lifecycle: eplot . describes the restored fit, not the one that overwrote it
**## 3. qa_lifecycle with a different design for fit B
local ++test_count
capture noisily {
    sysuse auto, clear
    qa_lifecycle, fita(regress price mpg weight) ///
        fitb(regress mpg foreign turn if rep78 > 2) ///
        post(eplot ., nodraw; eplot ., eform level(90) nodraw)
    * Fit A is active again and eplot . plots its three coefficients.
    assert "`e(cmd)'" == "regress" & "`e(depvar)'" == "price" & e(N) == 74
    eplot ., nodraw
    assert rowsof(r(table)) == 3
    assert !missing(el(r(table), 1, 1), _b[mpg])
    assert reldif(el(r(table), 1, 1), _b[mpg]) < 1e-12
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**# Parity: one estimate, every sink
**## 4. r(table), export() frame and its values text agree with regress r(table)
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    matrix S = r(table)
    scalar want_b = S[1, 1]
    scalar want_ll = S[5, 1]
    scalar want_ul = S[6, 1]
    capture frame drop adv_par
    eplot ., keep(mpg) values export(adv_par) nodraw
    assert rowsof(r(table)) == 1 & r(k) == 1
    frame adv_par: assert _N == 1
    qa_surface_parity, expect(scalar(want_b)) name(estimate) ///
        result(el(r(table),1,1)) frame(adv_par estimate 1)
    qa_surface_parity, expect(scalar(want_b)) name(values text) ///
        frame(adv_par values 1)
    qa_surface_parity, expect(scalar(want_ll)) name(lower limit) ///
        result(el(r(table),1,2)) frame(adv_par ll 1)
    qa_surface_parity, expect(scalar(want_ul)) name(upper limit) ///
        result(el(r(table),1,3)) frame(adv_par ul 1)
    frame drop adv_par
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**# Hostile strings: labels survive byte-identically, also through the note
**## 5. qa_hostile_strings via labels() and export()
local ++test_count
capture noisily {
    qa_hostile_strings, check(_adv_label_check) result(ADV_HS_GOT)
    * The lone-backtick string, which crashed 1.6.2 with r(132), once more
    * by name.
    _adv_label_check QA_HS_TICK
    qa_assert_text QA_HS_TICK ADV_HS_GOT, property(lone backtick label kept)
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**# Hostile fixture: non-decimal doubles are carried exactly
**## 6. data and matrix modes keep %21x values exact in r(table)
local ++test_count
capture noisily {
    clear
    quietly set obs 5
    qa_hostile_times, generate(t)
    local down `r(down)'
    local up `r(up)'
    local jump `r(jump)'
    gen double lo = t - 1
    gen double hi = t + 1
    eplot t lo hi, nodraw
    matrix D = r(table)
    qa_assert_equal D[1,1] `down', property(data-mode estimate stays exact)
    qa_assert_equal D[2,1] `up', property(data-mode estimate stays exact)
    qa_assert_equal D[4,1] `jump', property(data-mode estimate stays exact)
    mkmat t lo hi, matrix(M)
    eplot, matrix(M) nodraw
    matrix X = r(table)
    qa_assert_equal X[1,1] `down', property(matrix-mode estimate stays exact)
    qa_assert_equal X[4,1] `jump', property(matrix-mode estimate stays exact)
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

capture graph drop _all
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
_eplot_qa_result test_adversarial, tests(`test_count') pass(`pass_count') fail(`fail_count') skip(0)

if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    capture log close
    exit 1
}
capture log close
