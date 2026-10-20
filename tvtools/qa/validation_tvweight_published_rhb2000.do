*! validation_tvweight_published_rhb2000.do -- published reproduction for tvweight
*!
*! Source: Robins JM, Hernan MA, Brumback B. Marginal structural models and
*! causal inference in epidemiology. Epidemiology 2000;11(5):550-560,
*! Appendix 1 (pp.558-559). Table A1 gives a point-treatment study of 500
*! subjects stratified by a binary confounder L0; Table A3 lists the IPTW
*! weight w = 1/pr(A0 = a0 | L0 = l0) and the pseudo-population count of every
*! (L0, A0, Y) cell; Tables A4-A5 give the pseudo-population margins and the
*! text gives the causal risks 0.32 and 0.64, RD -0.32, RR 0.50, OR 0.26.
*!
*! The study is rebuilt from Table A1 cell counts. A logistic model of A0 on a
*! binary L0 is saturated, so tvweight's fitted propensities are the stratum
*! shares 0.9 and 0.5 the paper uses, and every published number is
*! reproducible. Published values printed to two decimals are checked at that
*! rounding; values the paper prints exactly are checked to 1e-6.
*!
*! Run standalone:  cd tvtools/qa && stata-mp -b do validation_tvweight_published_rhb2000.do
clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "validation_tvweight_published_rhb2000.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display as result "tvtools validation: tvweight RHB 2000 Appendix 1 reproduction -- $S_DATE $S_TIME"

* Table A1: observed counts by (L0, A0, Y).
*   L0=1: A0=1 Y=1 108, Y=0 252; A0=0 Y=1 24, Y=0 16
*   L0=0: A0=1 Y=1  20, Y=0  30; A0=0 Y=1 40, Y=0 10
capture program drop _rhb_table_a1
program define _rhb_table_a1
    clear
    quietly set obs 8
    generate byte L0 = real(word("1 1 1 1 0 0 0 0", _n))
    generate byte A0 = real(word("1 1 0 0 1 1 0 0", _n))
    generate byte Y  = real(word("1 0 1 0 1 0 1 0", _n))
    generate int  n  = real(word("108 252 24 16 20 30 40 10", _n))
    generate byte cell = _n
    quietly expand n
    drop n
end

**# R1: Table A3 weights w = 1/pr(A0 | L0)
* pr(A0=1|L0=1) = 360/400 = 0.9 -> w = 1/0.9 (printed 1.11) for treated L0=1
* pr(A0=0|L0=1) = 40/400 = 0.1 -> w = 10
* pr(A0=a|L0=0) = 50/100 = 0.5 -> w = 2 for both arms
local ++test_count
capture noisily {
    _rhb_table_a1
    assert _N == 500
    tvweight A0, covariates(L0) generate(w) nolog
    assert !missing(w)
    quietly summarize w if L0 == 1 & A0 == 1
    assert r(N) == 360
    assert reldif(r(min), 1/0.9) < 1e-6 & reldif(r(max), 1/0.9) < 1e-6
    assert round(r(mean), 0.01) == round(1.11, 0.01)
    quietly summarize w if L0 == 1 & A0 == 0
    assert r(N) == 40
    assert reldif(r(min), 10) < 1e-6 & reldif(r(max), 10) < 1e-6
    quietly summarize w if L0 == 0
    assert r(N) == 100
    assert reldif(r(min), 2) < 1e-6 & reldif(r(max), 2) < 1e-6
}
if _rc == 0 {
    display as result "  PASS [R1]: Table A3 weights 1.11, 10, 2, 2 reproduced"
    local ++pass_count
}
else {
    display as error "  FAIL [R1]: Table A3 weights (rc `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' R1"
}

**# R2: Table A3 pseudo-population count of every (L0, A0, Y) cell
* Published N pseudo: 120 280 240 160 40 60 80 20 (cells in Table A1 order).
local ++test_count
capture noisily {
    _rhb_table_a1
    tvweight A0, covariates(L0) generate(w) nolog
    local want "120 280 240 160 40 60 80 20"
    forvalues c = 1/8 {
        quietly summarize w if cell == `c'
        local got = r(sum)
        local exp : word `c' of `want'
        assert !missing(`got')
        assert abs(`got' - `exp') < 1e-4
    }
}
if _rc == 0 {
    display as result "  PASS [R2]: Table A3 pseudo-population counts reproduced"
    local ++pass_count
}
else {
    display as error "  FAIL [R2]: Table A3 pseudo-population counts (rc `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' R2"
}

**# R3: Table A4 margins -- L0 and A0 unassociated in the pseudo-population
* Published totals: L0=1 A0=1 400, A0=0 400; L0=0 A0=1 100, A0=0 100.
local ++test_count
capture noisily {
    _rhb_table_a1
    tvweight A0, covariates(L0) generate(w) nolog
    foreach spec in "1 1 400" "1 0 400" "0 1 100" "0 0 100" {
        local l : word 1 of `spec'
        local a : word 2 of `spec'
        local exp : word 3 of `spec'
        quietly summarize w if L0 == `l' & A0 == `a'
        assert !missing(r(sum))
        assert abs(r(sum) - `exp') < 1e-4
    }
}
if _rc == 0 {
    display as result "  PASS [R3]: Table A4 pseudo-population margins 400/400/100/100"
    local ++pass_count
}
else {
    display as error "  FAIL [R3]: Table A4 margins (rc `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' R3"
}

**# R4: Table A5 crude pseudo-population risks and the causal contrasts
* Published: treated 160/500 = 0.32, untreated 320/500 = 0.64;
* RD -0.32, RR 0.50, OR 0.26 (two decimals).
local ++test_count
capture noisily {
    _rhb_table_a1
    tvweight A0, covariates(L0) generate(w) nolog
    quietly summarize Y [aweight = w] if A0 == 1
    local r1 = r(mean)
    quietly summarize Y [aweight = w] if A0 == 0
    local r0 = r(mean)
    assert !missing(`r1', `r0')
    assert abs(`r1' - 0.32) < 1e-6
    assert abs(`r0' - 0.64) < 1e-6
    assert round(`r1' - `r0', 0.01) == round(-0.32, 0.01)
    assert round(`r1'/`r0', 0.01) == round(0.50, 0.01)
    assert round((`r1'/(1 - `r1'))/(`r0'/(1 - `r0')), 0.01) == round(0.26, 0.01)
}
if _rc == 0 {
    display as result "  PASS [R4]: Table A5 risks 0.32/0.64; RD -0.32, RR 0.50, OR 0.26"
    local ++pass_count
}
else {
    display as error "  FAIL [R4]: Table A5 risks and contrasts (rc `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' R4"
}

* ===== Summary =====
display as result _newline "tvweight RHB 2000 reproduction Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: validation_tvweight_published_rhb2000 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 | `pass_count' != `test_count' {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"
