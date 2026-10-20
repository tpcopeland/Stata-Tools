* validation_tabtools_known_answers.do - hand-computed known answers for the
* statistics tabtools derives or re-displays from a fitted model or test
*
* Every expected value below is worked out by hand from the literal data in
* the block (closed-form least squares, balanced one-way ML variance
* components, product-limit arithmetic); none is read back from the command
* under test or from the Stata command that produced the fit.
*
* KA1 regtab stats(aic bic ll): OLS log-likelihood in closed form
* KA2 regtab stats(icc): balanced one-way random intercept, ML in closed form
* KA3 regtab stats(qic): Gaussian GEE with fixed scale, QICu = RSS + 2p
* KA4 regtab coefficient table: OLS slope, t interval and p-value
* KA5 table1_tc group test and SMD: pooled t-test p and Yang-Dalton SMD
* KA6 survtab Kaplan-Meier: product-limit survival at chosen times
*
* Run from tabtools/qa.

clear all
version 17.0
set more off
set varabbrev off

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

capture log close _tka
log using "validation_tabtools_known_answers.log", replace text name(_tka)

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* Shared OLS fixture: x = 1..5, y = 1 3 2 5 4.
* xbar = 3, ybar = 3, Sxx = 10, Sxy = 8 -> b1 = 0.8, b0 = 0.6.
* Fitted 1.4 2.2 3.0 3.8 4.6; residuals -0.4 0.8 -1.0 1.2 -0.6; RSS = 3.6.
capture program drop _tka_ols_data
program define _tka_ols_data
    clear
    quietly set obs 5
    generate double x = _n
    generate double y = real(word("1 3 2 5 4", _n))
    label variable x "Dose"
end

**# KA1: regtab AIC/BIC from the closed-form OLS log-likelihood
* ll = -(N/2) * (ln(2*pi) + ln(RSS/N) + 1) with N = 5, RSS = 3.6.
* Stata's information criteria count the k = 2 coefficients.
* AIC = -2 ll + 2 k; BIC = -2 ll + k ln(N).
local ++test_count
capture noisily {
    _tka_ols_data
    local ll_hand = -(5/2) * (ln(2*_pi) + ln(3.6/5) + 1)
    local aic_hand = -2*`ll_hand' + 2*2
    local bic_hand = -2*`ll_hand' + 2*ln(5)
    collect clear
    collect: regress y x
    regtab, stats(aic bic ll n) frame(_tka1, replace)
    assert !missing(r(ll_1), r(aic_1), r(bic_1))
    assert reldif(r(ll_1), `ll_hand') < 1e-10
    assert reldif(r(aic_1), `aic_hand') < 1e-10
    assert reldif(r(bic_1), `bic_hand') < 1e-10
    assert r(n_1) == 5
    capture frame drop _tka1
}
if _rc == 0 {
    display as result "  PASS: KA1 regtab AIC/BIC/ll equal the closed-form OLS values"
    local ++pass_count
}
else {
    display as error "  FAIL: KA1 regtab AIC/BIC/ll (rc=`=_rc')"
    local ++fail_count
}

**# KA2: regtab ICC from balanced one-way ML variance components
* a = 3 groups of n = 2: {1,3} {4,6} {8,10}. Group means 2 5 9, grand 16/3.
* SSW = 2+2+2 = 6, MSW = SSW/(a(n-1)) = 2 = sigma_e^2 (ML, balanced).
* SSB = n * sum (mean - grand)^2 = 2 * 222/9 = 444/9.
* ML sigma_u^2 = (SSB/a - MSW)/n = (444/27 - 2)/2 = 65/9.
* ICC = sigma_u^2/(sigma_u^2 + sigma_e^2) = (65/9)/(65/9 + 18/9) = 65/83.
local ++test_count
capture noisily {
    clear
    input byte g double y
    1 1
    1 3
    2 4
    2 6
    3 8
    3 10
    end
    local icc_hand = 65/83
    collect clear
    collect: mixed y || g:, ml
    regtab, stats(icc) frame(_tka2, replace)
    assert !missing(r(icc_1))
    assert abs(r(icc_1) - `icc_hand') < 1e-5
    capture frame drop _tka2
}
if _rc == 0 {
    display as result "  PASS: KA2 regtab ICC equals the closed-form ML value 65/83"
    local ++pass_count
}
else {
    display as error "  FAIL: KA2 regtab ICC (rc=`=_rc')"
    local ++fail_count
}

**# KA3: regtab QICu for a Gaussian GEE with a fixed scale
* With independence working correlation and scale(1) the GEE is OLS, the
* quasi-likelihood is -RSS/2, and QICu = -2Q + 2p = RSS + 2p = 3.6 + 4 = 7.6.
local ++test_count
capture noisily {
    _tka_ols_data
    generate long id = _n
    generate byte t = 1
    xtset id t
    collect clear
    collect: xtgee y x, family(gaussian) link(identity) corr(independent) scale(1)
    regtab, stats(qic) frame(_tka3, replace)
    assert !missing(r(qic_1))
    assert reldif(r(qic_1), 7.6) < 1e-10
    capture frame drop _tka3
}
if _rc == 0 {
    display as result "  PASS: KA3 regtab QICu equals RSS + 2p = 7.6"
    local ++pass_count
}
else {
    display as error "  FAIL: KA3 regtab QICu (rc=`=_rc')"
    local ++fail_count
}

**# KA4: regtab coefficient, t interval and p-value for the OLS slope
* b1 = Sxy/Sxx = 0.8; s^2 = RSS/(N-2) = 1.2; se(b1) = sqrt(s^2/Sxx) = sqrt(0.12).
* 95% limits b1 -/+ invttail(3, .025) * se; p = 2 * ttail(3, b1/se).
local ++test_count
capture noisily {
    _tka_ols_data
    local se_hand = sqrt(0.12)
    local ll_hand = 0.8 - invttail(3, 0.025)*`se_hand'
    local ul_hand = 0.8 + invttail(3, 0.025)*`se_hand'
    local p_hand = 2*ttail(3, 0.8/`se_hand')
    collect clear
    collect: regress y x
    regtab, frame(_tka4, replace) eplotframe(_tka4_ep, replace)
    frame _tka4_ep {
        quietly count if label == "Dose"
        assert r(N) == 1
        quietly summarize estimate if label == "Dose", meanonly
        assert reldif(r(mean), 0.8) < 1e-10
        quietly summarize ll if label == "Dose", meanonly
        assert reldif(r(mean), `ll_hand') < 1e-10
        quietly summarize ul if label == "Dose", meanonly
        assert reldif(r(mean), `ul_hand') < 1e-10
        quietly summarize pvalue if label == "Dose", meanonly
        assert reldif(r(mean), `p_hand') < 1e-10
    }
    capture frame drop _tka4
    capture frame drop _tka4_ep
}
if _rc == 0 {
    display as result "  PASS: KA4 regtab slope 0.8, t limits and p equal the hand values"
    local ++pass_count
}
else {
    display as error "  FAIL: KA4 regtab coefficient table (rc=`=_rc')"
    local ++fail_count
}

**# KA5: table1_tc pooled t-test p-value and Yang-Dalton SMD
* Group 0: 1 2 3 (mean 2, var 1); group 1: 4 6 8 (mean 6, var 4).
* Pooled s^2 = (2*1 + 2*4)/4 = 2.5; se = sqrt(2.5*(1/3 + 1/3)) = sqrt(5/3);
* t = 4/sqrt(5/3) on 4 df; p = 2 * ttail(4, t).
* SMD = |2 - 6| / sqrt((1 + 4)/2) = 4/sqrt(2.5).
local ++test_count
capture noisily {
    clear
    input byte g double x
    0 1
    0 2
    0 3
    1 4
    1 6
    1 8
    end
    local p_hand = 2*ttail(4, 4/sqrt(5/3))
    local smd_hand = 4/sqrt(2.5)
    table1_tc, by(g) vars(x contn) smd frame(_tka5, replace)
    tempname T
    matrix `T' = r(table)
    local p_got = el(`T', rownumb(`T', "x"), colnumb(`T', "p_value"))
    local smd_got = el(`T', rownumb(`T', "x"), colnumb(`T', "smd"))
    assert !missing(`p_got', `smd_got')
    assert reldif(`p_got', `p_hand') < 1e-10
    assert reldif(`smd_got', `smd_hand') < 1e-10
    capture frame drop _tka5
}
if _rc == 0 {
    display as result "  PASS: KA5 table1_tc t-test p and SMD equal the hand values"
    local ++pass_count
}
else {
    display as error "  FAIL: KA5 table1_tc group test and SMD (rc=`=_rc')"
    local ++fail_count
}

**# KA6: survtab Kaplan-Meier survival from product-limit arithmetic
* Group 1: times 1 2 3 4 5, died 1 0 1 1 0.
*   S(1) = 4/5 = 0.8; S(3) = 0.8 * 2/3; S(4) = 0.8 * 2/3 * 1/2.
* Group 2: times 2 4 6, all died.
*   S(1) = 1; S(3) = 2/3; S(4) = 1/3.
local ++test_count
capture noisily {
    clear
    input byte(g died) double time
    1 1 1
    1 0 2
    1 1 3
    1 1 4
    1 0 5
    2 1 2
    2 1 4
    2 1 6
    end
    stset time, failure(died)
    survtab, times(1 3 4) by(g)
    tempname S
    matrix `S' = r(table)
    assert rowsof(`S') == 3
    assert colsof(`S') == 2
    assert reldif(`S'[1,1], 0.8) < 1e-12
    assert reldif(`S'[2,1], 0.8*2/3) < 1e-12
    assert reldif(`S'[3,1], 0.8*2/3*1/2) < 1e-12
    assert reldif(`S'[1,2], 1) < 1e-12
    assert reldif(`S'[2,2], 2/3) < 1e-12
    assert reldif(`S'[3,2], 1/3) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: KA6 survtab Kaplan-Meier equals product-limit hand values"
    local ++pass_count
}
else {
    display as error "  FAIL: KA6 survtab Kaplan-Meier (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 | `pass_count' != `test_count' {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_tabtools_known_answers tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _tka
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: validation_tabtools_known_answers tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _tka
