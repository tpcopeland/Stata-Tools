clear all
set more off
version 16.0
set varabbrev off

* crossval_iivw_published_hernan-robins-whatif.do
*
* PUBLISHED REPRODUCTION: Hernan MA, Robins JM. Causal Inference: What If
* (2020 draft of 2019-11-10), Chapter 12, smoking cessation and weight gain in
* NHEFS. Index row: _literature/iivw/index.md, key hernan-robins-whatif.
*
* Routes covered
*   iivw_weight, wtype(iptw)          stabilized IPTW (book 12.3)
*   iivw_fit, vce(fixed)              weighted GEE, estimated weights treated as
*                                     known = the book's "robust variance
*                                     estimator" interval, which it calls valid
*                                     but conservative (book 12.2)
*   iivw_fit, unweighted              crude associational difference (book 12.1)
*
* Oracle: numbers printed in the book, an oracle iivw's author did not write.
* Each is a rounded published number, matched to half a unit in its last
* printed digit, plus nothing:
*   H2  stabilized weights (book p.154): range 0.33 to 4.30, mean 1.00
*       non-stabilized weights (book p.151, Program 12.2): range 1.05 to 16.7,
*       mean 2.00; the non-stabilized value is the stabilized weight divided by
*       its numerator Pr[A=a] (403/1566 for the quitters, book p.154)
*   H3  IP-weighted difference 3.4 kg, robust 95% CI (2.4, 4.5) (book p.152, p.154)
*   H4  crude difference 2.5; group means 4.5 (quitters) and 2.0 (non-quitters)
*       (book p.149). The book's crude CI (1.7, 3.4) is the model-based OLS
*       interval and is NOT asserted: iivw_fit's unweighted fit reports the
*       cluster-robust sandwich, a different published-convention interval.
*   H6  negative control: a propensity model on sex, race and age only misses the
*       published weight range and the published 3.4
*   H5  directional consistency only: the book calls the robust CI conservative,
*       so the two-step (stacked) interval, which carries the propensity-model
*       uncertainty, must be narrower and lie inside the published (2.4, 4.5).
*       This is not a numerical reproduction and no published number is asserted
*       against vce(stacked).
*
* Estimand check. The book fits E[Y|A] = theta0 + theta1*A by weighted least
* squares, which is the saturated mean model; iivw_fit with timespec(none) and
* family(gaussian) on one row per subject (time constant at 1) fits the same
* model, so theta1 is the same estimand (E[Y^{a=1}] - E[Y^{a=0}], book p.154).
* The book's propensity model is logistic in sex, race, age, age^2, education
* (5 categories), cigarettes/day and its square, years smoked and its square,
* recreational exercise (3), activity (3), weight and its square; reproduced
* with indicator columns because treat_cov() takes numeric columns.
*
* Fixture: data/nhefs_whatif.csv, the 1,629 NHEFS rows of the book's teaching
* extract (public, non-commercial teaching use,
* https://miguelhernan.org/whatifbook), 12 columns, exported from the copy
* vendored in Stata-Tools/msm/qa/data/nhefs.dta.
* Fixture SHA-256: b61aef3c4338266dccc294e3c58d02838ccf99c3abb299be285e7777c74c44b1
*
* Tolerance: half a unit in the last published digit (listed per test). Seeds: none;
* the suite is deterministic.
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do crossval_iivw_published_hernan-robins-whatif.do [n]

args run_only
do "`c(pwd)'/_iivw_qa_common.do"
iivw_qa_selector "`run_only'"
local run_only = `r(run_only)'

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "crossval_iivw_published_hernan-robins-whatif.do must be run from iivw/qa"
    exit 198
}
iivw_qa_bootstrap

local data_file "`qa_dir'/data/nhefs_whatif.csv"
local want_sha "b61aef3c4338266dccc294e3c58d02838ccf99c3abb299be285e7777c74c44b1"
display as text "REFERENCE: Hernan MA, Robins JM. Causal Inference: What If, ch. 12 (NHEFS), https://miguelhernan.org/whatifbook, vendored data/nhefs_whatif.csv"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Build the analysis sample exactly as the book does: the 1,566 subjects with a
* known 1982 weight, one row per subject at a constant visit time.
capture program drop _nhefs_load
program define _nhefs_load
    version 16.0
    args file
    import delimited using "`file'", clear
    drop if missing(wt82_71)
    gen byte tm = 1
    gen double age2 = age^2
    gen double si2 = smokeintensity^2
    gen double sy2 = smokeyrs^2
    gen double w2 = wt71^2
    foreach v in education exercise active {
        quietly tabulate `v', generate(`v'_d)
    }
end

capture program drop _nhefs_weight
program define _nhefs_weight
    version 16.0
    syntax [, SCORES]
    iivw_weight, id(seqn) time(tm) treat(qsmk) wtype(iptw) ///
        treat_cov(sex race age age2 education_d2-education_d5 ///
        smokeintensity si2 smokeyrs sy2 exercise_d2 exercise_d3 ///
        active_d2 active_d3 wt71 w2) `scores' nolog replace
end

**# H1: fixture identity (SHA-256, then structure)

local ++test_count
if `run_only' == 0 | `run_only' == 1 {
    capture noisily {
        local got_sha ""
        python: import hashlib; from sfi import Macro; Macro.setLocal("got_sha", hashlib.sha256(open(Macro.getLocal("data_file"), "rb").read()).hexdigest())
        display as text "    fixture sha256 = `got_sha'"
        assert "`got_sha'" == "`want_sha'"
        import delimited using "`data_file'", clear
        assert _N == 1629
        isid seqn
        quietly count if !missing(wt82_71)
        assert r(N) == 1566
        quietly count if qsmk == 1 & !missing(wt82_71)
        * book p.154: the nonparametric numerator is the ratio 403/1566
        assert r(N) == 403
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: H1 fixture SHA-256, 1,629 rows, 1,566 with weight gain, 403 quitters"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' H1"
        display as error "FAIL: H1 fixture identity (error `=_rc')"
    }
}

**# H2: stabilized and non-stabilized weight summaries

local ++test_count
if `run_only' == 0 | `run_only' == 2 {
    capture noisily {
        _nhefs_load "`data_file'"
        _nhefs_weight
        quietly summarize _iivw_tw
        local sw_min = r(min)
        local sw_max = r(max)
        local sw_mean = r(mean)
        display as text "    stabilized: min=" %7.4f `sw_min' " max=" %7.4f `sw_max' " mean=" %7.4f `sw_mean' "  (book 0.33, 4.30, 1.00)"
        assert `sw_min' < . & `sw_max' < . & `sw_mean' < .
        * book p.154: 0.33 to 4.30, mean 1.00 (two decimals: +/- 0.005)
        assert abs(`sw_min' - 0.33) <= 0.005
        assert abs(`sw_max' - 4.30) <= 0.005
        assert abs(`sw_mean' - 1.00) <= 0.005

        * book p.151 Program 12.2: non-stabilized 1/f(A|L) = SW / Pr[A=a],
        * range 1.05 to 16.7, mean 2.00
        quietly count if qsmk == 1
        local p1 = r(N) / _N
        assert abs(`p1' - 403/1566) < 1e-12
        gen double w_ns = cond(qsmk == 1, _iivw_tw / `p1', _iivw_tw / (1 - `p1'))
        quietly summarize w_ns
        display as text "    non-stabilized: min=" %7.4f r(min) " max=" %7.3f r(max) " mean=" %7.4f r(mean) "  (book 1.05, 16.7, 2.00)"
        assert abs(r(min) - 1.05) <= 0.005
        assert abs(r(max) - 16.7) <= 0.05
        assert abs(r(mean) - 2.00) <= 0.005
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: H2 stabilized 0.33-4.30 mean 1.00; non-stabilized 1.05-16.7 mean 2.00"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' H2"
        display as error "FAIL: H2 weight summaries vs book (error `=_rc')"
    }
}

**# H3: IP-weighted difference and its robust (fixed-weight) interval

local ++test_count
if `run_only' == 0 | `run_only' == 3 {
    capture noisily {
        _nhefs_load "`data_file'"
        _nhefs_weight
        iivw_fit wt82_71 qsmk, timespec(none) vce(fixed) nolog
        local b = _b[qsmk]
        local se = _se[qsmk]
        assert `b' < . & `se' < . & `se' > 0
        local lo = `b' - invnormal(0.975) * `se'
        local hi = `b' + invnormal(0.975) * `se'
        display as text "    theta1 = " %7.4f `b' "  95% CI (" %7.4f `lo' ", " %7.4f `hi' ")  (book 3.4; 2.4, 4.5)"
        * book p.152 and p.154: 3.4 kg, CI (2.4, 4.5); one decimal: +/- 0.05
        assert abs(`b' - 3.4) <= 0.05
        assert abs(`lo' - 2.4) <= 0.05
        assert abs(`hi' - 4.5) <= 0.05
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: H3 IPTW difference 3.4 kg, robust CI (2.4, 4.5)"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' H3"
        display as error "FAIL: H3 IP-weighted estimate vs book (error `=_rc')"
    }
}

**# H4: unweighted crude difference and group means

local ++test_count
if `run_only' == 0 | `run_only' == 4 {
    capture noisily {
        _nhefs_load "`data_file'"
        iivw_fit wt82_71 qsmk, unweighted id(seqn) time(tm) ///
            timespec(none) nolog
        local d = _b[qsmk]
        local m0 = _b[_cons]
        local m1 = `m0' + `d'
        assert `d' < . & `m0' < .
        display as text "    crude difference = " %7.4f `d' "  E[Y|A=1] = " %7.4f `m1' "  E[Y|A=0] = " %7.4f `m0' "  (book 2.5; 4.5, 2.0)"
        * book p.149: 2.5, 4.5 and 2.0 kg; one decimal: +/- 0.05
        assert abs(`d' - 2.5) <= 0.05
        assert abs(`m1' - 4.5) <= 0.05
        assert abs(`m0' - 2.0) <= 0.05
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: H4 crude difference 2.5; group means 4.5 and 2.0"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' H4"
        display as error "FAIL: H4 unweighted estimate vs book (error `=_rc')"
    }
}

**# H5: the stacked interval is narrower than the conservative robust interval

local ++test_count
if `run_only' == 0 | `run_only' == 5 {
    capture noisily {
        _nhefs_load "`data_file'"
        _nhefs_weight, scores
        iivw_fit wt82_71 qsmk, timespec(none) vce(stacked) nolog
        local b_st = _b[qsmk]
        local se_st = _se[qsmk]
        iivw_fit wt82_71 qsmk, timespec(none) vce(fixed) nolog replace
        local se_fx = _se[qsmk]
        assert `se_st' < . & `se_fx' < . & `se_st' > 0
        local lo = `b_st' - invnormal(0.975) * `se_st'
        local hi = `b_st' + invnormal(0.975) * `se_st'
        display as text "    SE stacked = " %7.4f `se_st' "  SE fixed = " %7.4f `se_fx' "  stacked CI (" %7.4f `lo' ", " %7.4f `hi' ")"
        * book 12.2: the robust interval is conservative, so the interval that
        * propagates weight estimation is narrower; lower bound 2.4 and upper
        * bound 4.5 are the published (rounded) limits of the wider interval
        assert `se_st' < `se_fx'
        assert `lo' > 2.4 - 0.05
        assert `hi' < 4.5 + 0.05
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: H5 stacked SE below the conservative fixed-weight SE (directional)"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' H5"
        display as error "FAIL: H5 stacked vs conservative robust interval (error `=_rc')"
    }
}

**# H6: negative control, a misspecified propensity model leaves the published bands

local ++test_count
if `run_only' == 0 | `run_only' == 6 {
    capture noisily {
        _nhefs_load "`data_file'"
        * propensity model with only sex, race and age: the confounder set the
        * book says is needed (education, smoking history, activity, weight) is
        * absent, so the weights must miss the published 0.33-4.30 range
        iivw_weight, id(seqn) time(tm) treat(qsmk) wtype(iptw) ///
            treat_cov(sex race age) nolog replace
        quietly summarize _iivw_tw
        display as text "    misspecified: min=" %7.4f r(min) " max=" %7.4f r(max) "  (published 0.33, 4.30)"
        assert r(min) < . & r(max) < .
        assert abs(r(max) - 4.30) > 0.005 | abs(r(min) - 0.33) > 0.005
        iivw_fit wt82_71 qsmk, timespec(none) vce(fixed) nolog
        display as text "    misspecified theta1 = " %7.4f _b[qsmk] "  (published 3.4)"
        assert abs(_b[qsmk] - 3.4) > 0.05
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: H6 a misspecified propensity model misses the published bands"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' H6"
        display as error "FAIL: H6 negative control did not separate (error `=_rc')"
    }
}

set linesize 255
iivw_qa_summary, name(crossval_iivw_published_hernan-robins-whatif) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') runonly(`run_only') failedtests("`failed_tests'")

clear
