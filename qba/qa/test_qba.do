* test_qba.do — Functional tests for the qba package
* Package: qba (Quantitative Bias Analysis)
* Location: ~/Stata-Dev/_devkit/_testing/
* Commands tested: qba, qba_misclass, qba_selection, qba_confound,
*   qba_multi, qba_plot, _qba_distributions

clear all
set more off
adopath ++ "/home/tpcopeland/Stata-Dev/qba"
capture ado uninstall qba
run "/home/tpcopeland/Stata-Dev/qba/_qba_distributions.ado"

local test_count = 0
local pass_count = 0
local fail_count = 0

* Helper for float comparison
capture program drop _assert_close
program define _assert_close
    args actual expected tolerance
    if "`tolerance'" == "" local tolerance = 0.0001
    local diff = abs(`actual' - `expected')
    if `diff' > `tolerance' {
        display as error "Expected: `expected', Got: `actual' (diff: `diff')"
        exit 9
    }
end

* ============================================================
* T1: qba dispatcher
* ============================================================

local ++test_count
capture noisily {
    qba
    assert "`r(version)'" == "1.0.0"
    assert "`r(commands)'" != ""
}
if _rc == 0 {
    display as result "  PASS: T1.1 qba dispatcher returns version and commands"
    local ++pass_count
}
else {
    display as error "  FAIL: T1.1 qba dispatcher (error `=_rc')"
    local ++fail_count
}

* ============================================================
* T2: _qba_distributions
* ============================================================

* T2.1: Parse valid distributions
local ++test_count
capture noisily {
    _qba_parse_dist, dist("trapezoidal 0.7 0.8 0.9 1.0")
    assert "`r(dtype)'" == "trapezoidal"
    _qba_parse_dist, dist("triangular 0.5 0.8 1.0")
    assert "`r(dtype)'" == "triangular"
    _qba_parse_dist, dist("uniform 0.7 0.95")
    assert "`r(dtype)'" == "uniform"
    _qba_parse_dist, dist("beta 2 5")
    assert "`r(dtype)'" == "beta"
    _qba_parse_dist, dist("logit-normal 0 1")
    assert "`r(dtype)'" == "logit-normal"
    _qba_parse_dist, dist("constant 0.85")
    assert "`r(dtype)'" == "constant"
}
if _rc == 0 {
    display as result "  PASS: T2.1 Parse all 6 distribution types"
    local ++pass_count
}
else {
    display as error "  FAIL: T2.1 Parse distributions (error `=_rc')"
    local ++fail_count
}

* T2.2: Invalid distribution type
local ++test_count
capture noisily {
    capture _qba_parse_dist, dist("gamma 2 3")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T2.2 Reject unknown distribution type"
    local ++pass_count
}
else {
    display as error "  FAIL: T2.2 Reject unknown distribution (error `=_rc')"
    local ++fail_count
}

* T2.3: Wrong parameter count
local ++test_count
capture noisily {
    capture _qba_parse_dist, dist("trapezoidal 0.7 0.8")
    assert _rc == 198
    capture _qba_parse_dist, dist("uniform 0.5")
    assert _rc == 198
    capture _qba_parse_dist, dist("beta 2")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T2.3 Reject wrong parameter counts"
    local ++pass_count
}
else {
    display as error "  FAIL: T2.3 Wrong parameter counts (error `=_rc')"
    local ++fail_count
}

* T2.4: Invalid parameter ordering
local ++test_count
capture noisily {
    capture _qba_parse_dist, dist("trapezoidal 0.9 0.8 0.7 0.6")
    assert _rc == 198
    capture _qba_parse_dist, dist("triangular 1.0 0.5 0.8")
    assert _rc == 198
    capture _qba_parse_dist, dist("uniform 0.9 0.1")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T2.4 Reject invalid parameter ordering"
    local ++pass_count
}
else {
    display as error "  FAIL: T2.4 Invalid ordering (error `=_rc')"
    local ++fail_count
}

* T2.5: Draw from each distribution
local ++test_count
capture restore
capture noisily {
    preserve
    clear
    set obs 1000
    set seed 42
    _qba_draw_one, dist("uniform 0.5 1.0") gen(_u) n(1000)
    summarize _u, meanonly
    assert r(min) >= 0.5
    assert r(max) <= 1.0

    _qba_draw_one, dist("constant 0.85") gen(_c) n(1000)
    assert _c[1] == 0.85
    assert _c[500] == 0.85

    _qba_draw_one, dist("beta 2 5") gen(_bt) n(1000)
    summarize _bt, meanonly
    assert r(min) >= 0
    assert r(max) <= 1

    _qba_draw_one, dist("triangular 0.6 0.8 1.0") gen(_t) n(1000)
    summarize _t, meanonly
    assert r(min) >= 0.6
    assert r(max) <= 1.0

    _qba_draw_one, dist("trapezoidal 0.7 0.8 0.9 1.0") gen(_tr) n(1000)
    summarize _tr, meanonly
    assert r(min) >= 0.7
    assert r(max) <= 1.0

    _qba_draw_one, dist("logit-normal 0 1") gen(_ln) n(1000)
    summarize _ln, meanonly
    assert r(min) > 0
    assert r(max) < 1

    restore
}
if _rc == 0 {
    display as result "  PASS: T2.5 Draw from all 6 distribution types"
    local ++pass_count
}
else {
    display as error "  FAIL: T2.5 Distribution draws (error `=_rc')"
    local ++fail_count
}

* ============================================================
* T3: qba_misclass — Simple mode
* ============================================================

* T3.1: Basic nondifferential exposure misclassification
local ++test_count
capture noisily {
    qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95)
    assert r(observed) > 0
    assert r(corrected) > 0
    assert r(corrected_a) > 0
    assert r(corrected_b) > 0
    assert r(corrected_c) > 0
    assert r(corrected_d) > 0
    assert "`r(type)'" == "exposure"
    assert "`r(measure)'" == "OR"
    assert "`r(method)'" == "simple"
}
if _rc == 0 {
    display as result "  PASS: T3.1 Basic nondifferential exposure misclassification"
    local ++pass_count
}
else {
    display as error "  FAIL: T3.1 Basic misclass (error `=_rc')"
    local ++fail_count
}

* T3.2: Outcome misclassification
local ++test_count
capture noisily {
    qba_misclass, a(136) b(297) c(1432) d(6738) seca(.92) spca(.98) type(outcome)
    assert "`r(type)'" == "outcome"
    assert r(corrected) > 0
}
if _rc == 0 {
    display as result "  PASS: T3.2 Outcome misclassification"
    local ++pass_count
}
else {
    display as error "  FAIL: T3.2 Outcome misclass (error `=_rc')"
    local ++fail_count
}

* T3.3: RR measure
local ++test_count
capture noisily {
    qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95) measure(RR)
    assert "`r(measure)'" == "RR"
    assert r(corrected) > 0
}
if _rc == 0 {
    display as result "  PASS: T3.3 RR measure"
    local ++pass_count
}
else {
    display as error "  FAIL: T3.3 RR measure (error `=_rc')"
    local ++fail_count
}

* T3.4: Differential misclassification
local ++test_count
capture noisily {
    qba_misclass, a(136) b(297) c(1432) d(6738) seca(.90) spca(.95) secb(.80) spcb(.95)
    assert r(corrected) > 0
    assert r(secb) == .80
    assert r(spcb) == .95
}
if _rc == 0 {
    display as result "  PASS: T3.4 Differential misclassification"
    local ++pass_count
}
else {
    display as error "  FAIL: T3.4 Differential misclass (error `=_rc')"
    local ++fail_count
}

* T3.5: Row totals preserved
local ++test_count
capture noisily {
    qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95)
    * Row totals: M1 = a+b, M0 = c+d should be preserved
    local M1 = 136 + 297
    local M0 = 1432 + 6738
    _assert_close `=r(corrected_a) + r(corrected_b)' `M1' 0.001
    _assert_close `=r(corrected_c) + r(corrected_d)' `M0' 0.001
}
if _rc == 0 {
    display as result "  PASS: T3.5 Row totals preserved (exposure misclass)"
    local ++pass_count
}
else {
    display as error "  FAIL: T3.5 Row totals (error `=_rc')"
    local ++fail_count
}

* T3.6: Perfect classification returns observed table
local ++test_count
capture noisily {
    qba_misclass, a(136) b(297) c(1432) d(6738) seca(1.0) spca(1.0)
    _assert_close `=r(corrected_a)' 136 0.001
    _assert_close `=r(corrected_b)' 297 0.001
    _assert_close `=r(corrected_c)' 1432 0.001
    _assert_close `=r(corrected_d)' 6738 0.001
}
if _rc == 0 {
    display as result "  PASS: T3.6 Perfect classification returns observed"
    local ++pass_count
}
else {
    display as error "  FAIL: T3.6 Perfect classification (error `=_rc')"
    local ++fail_count
}

* ============================================================
* T4: qba_misclass — Error handling
* ============================================================

* T4.1: Negative cell counts
local ++test_count
capture noisily {
    capture qba_misclass, a(-1) b(297) c(1432) d(6738) seca(.85) spca(.95)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T4.1 Reject negative cell counts"
    local ++pass_count
}
else {
    display as error "  FAIL: T4.1 Negative cells (error `=_rc')"
    local ++fail_count
}

* T4.2: Se/Sp out of range
local ++test_count
capture noisily {
    capture qba_misclass, a(136) b(297) c(1432) d(6738) seca(1.5) spca(.95)
    assert _rc == 198
    capture qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(0)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T4.2 Reject Se/Sp out of range"
    local ++pass_count
}
else {
    display as error "  FAIL: T4.2 Se/Sp range (error `=_rc')"
    local ++fail_count
}

* T4.3: Se + Sp <= 1 (non-identifiable)
local ++test_count
capture noisily {
    capture qba_misclass, a(136) b(297) c(1432) d(6738) seca(.3) spca(.5)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T4.3 Reject non-identifiable Se+Sp<=1"
    local ++pass_count
}
else {
    display as error "  FAIL: T4.3 Non-identifiable (error `=_rc')"
    local ++fail_count
}

* T4.4: Invalid type
local ++test_count
capture noisily {
    capture qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95) type(invalid)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T4.4 Reject invalid type"
    local ++pass_count
}
else {
    display as error "  FAIL: T4.4 Invalid type (error `=_rc')"
    local ++fail_count
}

* T4.5: Invalid measure
local ++test_count
capture noisily {
    capture qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95) measure(HR)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T4.5 Reject invalid measure"
    local ++pass_count
}
else {
    display as error "  FAIL: T4.5 Invalid measure (error `=_rc')"
    local ++fail_count
}

* T4.6: Reps too low
local ++test_count
capture noisily {
    capture qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95) reps(10)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T4.6 Reject reps < 100"
    local ++pass_count
}
else {
    display as error "  FAIL: T4.6 Low reps (error `=_rc')"
    local ++fail_count
}

* ============================================================
* T5: qba_misclass — Probabilistic mode
* ============================================================

* T5.1: Basic probabilistic with seed reproducibility
local ++test_count
capture noisily {
    qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95) ///
        reps(1000) dist_se("trapezoidal .75 .82 .88 .95") ///
        dist_sp("trapezoidal .90 .93 .97 1.0") seed(12345)
    local med1 = r(corrected)
    local lo1 = r(ci_lower)
    local hi1 = r(ci_upper)

    qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95) ///
        reps(1000) dist_se("trapezoidal .75 .82 .88 .95") ///
        dist_sp("trapezoidal .90 .93 .97 1.0") seed(12345)
    _assert_close `=r(corrected)' `med1' 0.0001
    _assert_close `=r(ci_lower)' `lo1' 0.0001
    _assert_close `=r(ci_upper)' `hi1' 0.0001
}
if _rc == 0 {
    display as result "  PASS: T5.1 Probabilistic seed reproducibility"
    local ++pass_count
}
else {
    display as error "  FAIL: T5.1 Seed reproducibility (error `=_rc')"
    local ++fail_count
}

* T5.2: Return values complete
local ++test_count
capture noisily {
    qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95) ///
        reps(500) seed(99)
    assert r(observed) > 0
    assert r(corrected) > 0
    assert r(mean) > 0
    assert r(sd) >= 0
    assert r(ci_lower) > 0
    assert r(ci_upper) > 0
    assert r(ci_lower) <= r(corrected)
    assert r(ci_upper) >= r(corrected)
    assert r(reps) == 500
    assert r(n_valid) > 0
    assert "`r(method)'" == "probabilistic"
}
if _rc == 0 {
    display as result "  PASS: T5.2 Probabilistic return values complete"
    local ++pass_count
}
else {
    display as error "  FAIL: T5.2 Return values (error `=_rc')"
    local ++fail_count
}

* T5.3: Constant distribution = simple mode
local ++test_count
capture noisily {
    qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95)
    local simple_or = r(corrected)
    qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95) ///
        reps(500) dist_se("constant .85") dist_sp("constant .95") seed(1)
    * With constant distributions, all reps give identical result
    assert r(sd) < 0.0001
    _assert_close `=r(corrected)' `simple_or' 0.001
}
if _rc == 0 {
    display as result "  PASS: T5.3 Constant distribution matches simple mode"
    local ++pass_count
}
else {
    display as error "  FAIL: T5.3 Constant dist (error `=_rc')"
    local ++fail_count
}

* T5.4: Saving option
local ++test_count
capture restore
capture noisily {
    capture erase "/tmp/qba_test_save.dta"
    qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95) ///
        reps(200) seed(42) saving("/tmp/qba_test_save", replace)
    preserve
    use "/tmp/qba_test_save", clear
    assert _N == 200
    confirm variable corrected_or
    confirm variable a_corr
    confirm variable se
    confirm variable sp
    restore
    capture erase "/tmp/qba_test_save.dta"
}
if _rc == 0 {
    display as result "  PASS: T5.4 Saving option creates valid dataset"
    local ++pass_count
}
else {
    display as error "  FAIL: T5.4 Saving (error `=_rc')"
    local ++fail_count
}

* ============================================================
* T6: qba_selection — Simple mode
* ============================================================

* T6.1: Basic selection bias
local ++test_count
capture noisily {
    qba_selection, a(136) b(297) c(1432) d(6738) ///
        sela(.9) selb(.85) selc(.7) seld(.8)
    assert r(observed) > 0
    assert r(corrected) > 0
    assert r(bias_factor) > 0
    assert r(ratio) > 0
    assert "`r(method)'" == "simple"
}
if _rc == 0 {
    display as result "  PASS: T6.1 Basic selection bias correction"
    local ++pass_count
}
else {
    display as error "  FAIL: T6.1 Selection bias (error `=_rc')"
    local ++fail_count
}

* T6.2: Equal selection = no bias
local ++test_count
capture noisily {
    qba_selection, a(136) b(297) c(1432) d(6738) ///
        sela(.8) selb(.8) selc(.8) seld(.8)
    _assert_close `=r(bias_factor)' 1.0 0.0001
    _assert_close `=r(corrected)' `=r(observed)' 0.001
}
if _rc == 0 {
    display as result "  PASS: T6.2 Equal selection = no bias"
    local ++pass_count
}
else {
    display as error "  FAIL: T6.2 Equal selection (error `=_rc')"
    local ++fail_count
}

* T6.3: Corrected cells = observed / selection probability
local ++test_count
capture noisily {
    qba_selection, a(100) b(200) c(300) d(400) ///
        sela(.5) selb(.5) selc(.5) seld(.5)
    _assert_close `=r(corrected_a)' 200 0.001
    _assert_close `=r(corrected_b)' 400 0.001
    _assert_close `=r(corrected_c)' 600 0.001
    _assert_close `=r(corrected_d)' 800 0.001
}
if _rc == 0 {
    display as result "  PASS: T6.3 Corrected cells = observed / sel prob"
    local ++pass_count
}
else {
    display as error "  FAIL: T6.3 Corrected cells (error `=_rc')"
    local ++fail_count
}

* T6.4: Selection probabilities out of range
local ++test_count
capture noisily {
    capture qba_selection, a(100) b(200) c(300) d(400) ///
        sela(0) selb(.5) selc(.5) seld(.5)
    assert _rc == 198
    capture qba_selection, a(100) b(200) c(300) d(400) ///
        sela(1.1) selb(.5) selc(.5) seld(.5)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T6.4 Reject selection probs out of range"
    local ++pass_count
}
else {
    display as error "  FAIL: T6.4 Selection range (error `=_rc')"
    local ++fail_count
}

* T6.5: RR measure
local ++test_count
capture noisily {
    qba_selection, a(136) b(297) c(1432) d(6738) ///
        sela(.9) selb(.85) selc(.7) seld(.8) measure(RR)
    assert "`r(measure)'" == "RR"
    assert r(corrected) > 0
}
if _rc == 0 {
    display as result "  PASS: T6.5 Selection bias with RR"
    local ++pass_count
}
else {
    display as error "  FAIL: T6.5 Selection RR (error `=_rc')"
    local ++fail_count
}

* T6.6: Probabilistic selection bias
local ++test_count
capture noisily {
    qba_selection, a(136) b(297) c(1432) d(6738) ///
        sela(.9) selb(.85) selc(.7) seld(.8) ///
        reps(500) dist_sela("uniform .8 1.0") seed(777)
    assert r(corrected) > 0
    assert r(reps) == 500
    assert "`r(method)'" == "probabilistic"
}
if _rc == 0 {
    display as result "  PASS: T6.6 Probabilistic selection bias"
    local ++pass_count
}
else {
    display as error "  FAIL: T6.6 Probabilistic selection (error `=_rc')"
    local ++fail_count
}

* ============================================================
* T7: qba_confound
* ============================================================

* T7.1: Simple confounding correction with rrcd
local ++test_count
capture noisily {
    qba_confound, estimate(1.5) p1(.4) p0(.2) rrcd(2.0)
    assert r(observed) == 1.5
    assert r(corrected) > 0
    assert r(bias_factor) > 0
    assert "`r(method)'" == "simple"
}
if _rc == 0 {
    display as result "  PASS: T7.1 Simple confounding with rrcd"
    local ++pass_count
}
else {
    display as error "  FAIL: T7.1 Confound rrcd (error `=_rc')"
    local ++fail_count
}

* T7.2: Simple confounding with rrud
local ++test_count
capture noisily {
    qba_confound, estimate(1.5) p1(.4) p0(.2) rrud(2.0)
    assert r(observed) == 1.5
    assert r(corrected) > 0
    assert r(rrud) == 2.0
}
if _rc == 0 {
    display as result "  PASS: T7.2 Simple confounding with rrud"
    local ++pass_count
}
else {
    display as error "  FAIL: T7.2 Confound rrud (error `=_rc')"
    local ++fail_count
}

* T7.3: E-value only
local ++test_count
capture noisily {
    qba_confound, estimate(2.0) evalue ci_bound(1.3)
    assert r(evalue) > 0
    assert r(evalue_ci) > 0
    assert r(evalue) > r(evalue_ci)
}
if _rc == 0 {
    display as result "  PASS: T7.3 E-value only mode"
    local ++pass_count
}
else {
    display as error "  FAIL: T7.3 E-value (error `=_rc')"
    local ++fail_count
}

* T7.4: E-value + correction combined
local ++test_count
capture noisily {
    qba_confound, estimate(1.5) p1(.4) p0(.2) rrcd(2.0) evalue ci_bound(1.1)
    assert r(corrected) > 0
    assert r(evalue) > 0
    assert r(evalue_ci) > 0
}
if _rc == 0 {
    display as result "  PASS: T7.4 E-value + correction combined"
    local ++pass_count
}
else {
    display as error "  FAIL: T7.4 Combined (error `=_rc')"
    local ++fail_count
}

* T7.5: No confounder effect => no bias
local ++test_count
capture noisily {
    qba_confound, estimate(2.0) p1(.3) p0(.3) rrcd(1.0)
    _assert_close `=r(bias_factor)' 1.0 0.0001
    _assert_close `=r(corrected)' 2.0 0.0001
}
if _rc == 0 {
    display as result "  PASS: T7.5 No confounder effect => no bias"
    local ++pass_count
}
else {
    display as error "  FAIL: T7.5 No confounder (error `=_rc')"
    local ++fail_count
}

* T7.6: Equal prevalence => no bias
local ++test_count
capture noisily {
    qba_confound, estimate(2.0) p1(.5) p0(.5) rrcd(3.0)
    _assert_close `=r(bias_factor)' 1.0 0.0001
}
if _rc == 0 {
    display as result "  PASS: T7.6 Equal prevalence => no confounding bias"
    local ++pass_count
}
else {
    display as error "  FAIL: T7.6 Equal prevalence (error `=_rc')"
    local ++fail_count
}

* T7.7: Missing estimate
local ++test_count
capture noisily {
    capture qba_confound, p1(.4) p0(.2) rrcd(2.0)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T7.7 Reject missing estimate"
    local ++pass_count
}
else {
    display as error "  FAIL: T7.7 Missing estimate (error `=_rc')"
    local ++fail_count
}

* T7.8: Negative estimate
local ++test_count
capture noisily {
    capture qba_confound, estimate(-1) p1(.4) p0(.2) rrcd(2.0)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T7.8 Reject negative estimate"
    local ++pass_count
}
else {
    display as error "  FAIL: T7.8 Negative estimate (error `=_rc')"
    local ++fail_count
}

* T7.9: from_model option
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly logistic foreign mpg weight
    qba_confound, from_model p1(.3) p0(.1) rrcd(2.0) evalue
    assert r(observed) > 0
    assert r(corrected) > 0
    assert r(evalue) > 0
}
if _rc == 0 {
    display as result "  PASS: T7.9 from_model with logistic"
    local ++pass_count
}
else {
    display as error "  FAIL: T7.9 from_model (error `=_rc')"
    local ++fail_count
}

* T7.10: Probabilistic confounding
local ++test_count
capture noisily {
    qba_confound, estimate(1.5) p1(.4) p0(.2) rrcd(2.0) ///
        reps(500) dist_p1("beta 8 12") dist_rr("uniform 1.5 3.0") seed(555)
    assert r(corrected) > 0
    assert r(reps) == 500
    assert r(sd) > 0
    assert "`r(method)'" == "probabilistic"
}
if _rc == 0 {
    display as result "  PASS: T7.10 Probabilistic confounding"
    local ++pass_count
}
else {
    display as error "  FAIL: T7.10 Probabilistic confound (error `=_rc')"
    local ++fail_count
}

* ============================================================
* T8: qba_multi
* ============================================================

* T8.1: All three biases
local ++test_count
capture noisily {
    qba_multi, a(136) b(297) c(1432) d(6738) reps(500) ///
        seca(.85) spca(.95) ///
        sela(.9) selb(.85) selc(.7) seld(.8) ///
        p1(.4) p0(.2) rrcd(2.0) seed(12345)
    assert r(observed) > 0
    assert r(corrected) > 0
    assert r(n_biases) == 3
    assert "`r(method)'" == "multi-bias"
    assert "`r(order)'" == "misclass selection confound"
}
if _rc == 0 {
    display as result "  PASS: T8.1 Multi-bias with all three biases"
    local ++pass_count
}
else {
    display as error "  FAIL: T8.1 Multi-bias (error `=_rc')"
    local ++fail_count
}

* T8.2: Two biases only (misclass + confound)
local ++test_count
capture noisily {
    qba_multi, a(136) b(297) c(1432) d(6738) reps(500) ///
        seca(.85) spca(.95) ///
        p1(.4) p0(.2) rrcd(2.0) seed(12345)
    assert r(n_biases) == 2
}
if _rc == 0 {
    display as result "  PASS: T8.2 Two biases (misclass + confound)"
    local ++pass_count
}
else {
    display as error "  FAIL: T8.2 Two biases (error `=_rc')"
    local ++fail_count
}

* T8.3: Custom order
local ++test_count
capture noisily {
    qba_multi, a(136) b(297) c(1432) d(6738) reps(500) ///
        seca(.85) spca(.95) ///
        p1(.4) p0(.2) rrcd(2.0) ///
        order(confound misclass) seed(12345)
    assert "`r(order)'" == "confound misclass"
}
if _rc == 0 {
    display as result "  PASS: T8.3 Custom correction order"
    local ++pass_count
}
else {
    display as error "  FAIL: T8.3 Custom order (error `=_rc')"
    local ++fail_count
}

* T8.4: No bias parameters
local ++test_count
capture noisily {
    capture qba_multi, a(136) b(297) c(1432) d(6738) reps(500)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T8.4 Reject no bias parameters"
    local ++pass_count
}
else {
    display as error "  FAIL: T8.4 No params (error `=_rc')"
    local ++fail_count
}

* T8.5: RR measure
local ++test_count
capture noisily {
    qba_multi, a(136) b(297) c(1432) d(6738) reps(500) measure(RR) ///
        seca(.85) spca(.95) p1(.4) p0(.2) rrcd(2.0) seed(99999)
    assert "`r(measure)'" == "RR"
    assert r(corrected) > 0
}
if _rc == 0 {
    display as result "  PASS: T8.5 Multi-bias with RR"
    local ++pass_count
}
else {
    display as error "  FAIL: T8.5 Multi RR (error `=_rc')"
    local ++fail_count
}

* T8.6: Seed reproducibility
local ++test_count
capture noisily {
    qba_multi, a(136) b(297) c(1432) d(6738) reps(500) ///
        seca(.85) spca(.95) ///
        dist_se("uniform .75 .95") dist_sp("uniform .90 1.0") ///
        p1(.4) p0(.2) rrcd(2.0) dist_rr("uniform 1.5 2.5") seed(42)
    local med1 = r(corrected)

    qba_multi, a(136) b(297) c(1432) d(6738) reps(500) ///
        seca(.85) spca(.95) ///
        dist_se("uniform .75 .95") dist_sp("uniform .90 1.0") ///
        p1(.4) p0(.2) rrcd(2.0) dist_rr("uniform 1.5 2.5") seed(42)
    _assert_close `=r(corrected)' `med1' 0.0001
}
if _rc == 0 {
    display as result "  PASS: T8.6 Multi-bias seed reproducibility"
    local ++pass_count
}
else {
    display as error "  FAIL: T8.6 Multi seed (error `=_rc')"
    local ++fail_count
}

* ============================================================
* T9: qba_plot
* ============================================================

* T9.1: Tornado plot
local ++test_count
capture noisily {
    qba_plot, tornado a(136) b(297) c(1432) d(6738) ///
        param1(se) range1(.7 1.0) steps(10) ///
        name(tornado_test, replace)
    assert "`r(plot_type)'" == "tornado"
    graph drop tornado_test
}
if _rc == 0 {
    display as result "  PASS: T9.1 Tornado plot"
    local ++pass_count
}
else {
    display as error "  FAIL: T9.1 Tornado (error `=_rc')"
    local ++fail_count
}

* T9.2: Tornado with 2 parameters
local ++test_count
capture noisily {
    qba_plot, tornado a(136) b(297) c(1432) d(6738) ///
        param1(se) range1(.7 1.0) param2(sp) range2(.8 1.0) steps(10) ///
        name(tornado2_test, replace)
    graph drop tornado2_test
}
if _rc == 0 {
    display as result "  PASS: T9.2 Tornado with 2 parameters"
    local ++pass_count
}
else {
    display as error "  FAIL: T9.2 Tornado 2 params (error `=_rc')"
    local ++fail_count
}

* T9.3: Tipping point plot
local ++test_count
capture noisily {
    qba_plot, tipping a(136) b(297) c(1432) d(6738) ///
        param1(se) range1(.6 1.0) param2(sp) range2(.6 1.0) steps(10) ///
        name(tipping_test, replace)
    assert "`r(plot_type)'" == "tipping"
    graph drop tipping_test
}
if _rc == 0 {
    display as result "  PASS: T9.3 Tipping point plot"
    local ++pass_count
}
else {
    display as error "  FAIL: T9.3 Tipping (error `=_rc')"
    local ++fail_count
}

* T9.4: Distribution plot (needs saved MC data)
local ++test_count
capture noisily {
    capture erase "/tmp/qba_mc_for_plot.dta"
    qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95) ///
        reps(500) dist_se("uniform .75 .95") seed(42) ///
        saving("/tmp/qba_mc_for_plot", replace)
    qba_plot, distribution using("/tmp/qba_mc_for_plot") observed(2.15) ///
        name(dist_test, replace)
    assert "`r(plot_type)'" == "distribution"
    graph drop dist_test
    capture erase "/tmp/qba_mc_for_plot.dta"
}
if _rc == 0 {
    display as result "  PASS: T9.4 Distribution plot from saved MC"
    local ++pass_count
}
else {
    display as error "  FAIL: T9.4 Distribution plot (error `=_rc')"
    local ++fail_count
}

* T9.5: Missing plot type
local ++test_count
capture noisily {
    capture qba_plot, a(100) b(200) c(300) d(400)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T9.5 Reject missing plot type"
    local ++pass_count
}
else {
    display as error "  FAIL: T9.5 Missing plot type (error `=_rc')"
    local ++fail_count
}

* T9.6: Multiple plot types
local ++test_count
capture noisily {
    capture qba_plot, tornado distribution a(100) b(200) c(300) d(400)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T9.6 Reject multiple plot types"
    local ++pass_count
}
else {
    display as error "  FAIL: T9.6 Multiple types (error `=_rc')"
    local ++fail_count
}

* T9.7: base_se/base_sp options
local ++test_count
capture noisily {
    qba_plot, tornado a(136) b(297) c(1432) d(6738) ///
        param1(se) range1(.7 1.0) steps(5) ///
        base_se(.85) base_sp(.95) ///
        name(tornado_base_test, replace)
    graph drop tornado_base_test
}
if _rc == 0 {
    display as result "  PASS: T9.7 Tornado with base_se/base_sp"
    local ++pass_count
}
else {
    display as error "  FAIL: T9.7 Base Se/Sp (error `=_rc')"
    local ++fail_count
}

* T9.8: Default scheme is plotplainblind
local ++test_count
capture noisily {
    qba_plot, tornado a(136) b(297) c(1432) d(6738) ///
        param1(se) range1(.7 1.0) steps(5) ///
        name(scheme_test, replace)
    assert "`r(scheme)'" == "plotplainblind"
    graph drop scheme_test
}
if _rc == 0 {
    display as result "  PASS: T9.8 Default scheme is plotplainblind"
    local ++pass_count
}
else {
    display as error "  FAIL: T9.8 Default scheme (error `=_rc')"
    local ++fail_count
}

* ============================================================
* T10: Data preservation
* ============================================================

* T10.1: Commands don't alter existing data
local ++test_count
capture noisily {
    sysuse auto, clear
    local n_before = _N
    datasignature
    local sig_before "`r(datasignature)'"

    qba_misclass, a(100) b(200) c(300) d(400) seca(.9) spca(.95)
    assert _N == `n_before'
    datasignature
    assert "`r(datasignature)'" == "`sig_before'"

    qba_selection, a(100) b(200) c(300) d(400) sela(.9) selb(.8) selc(.7) seld(.9)
    assert _N == `n_before'
    datasignature
    assert "`r(datasignature)'" == "`sig_before'"

    qba_confound, estimate(1.5) p1(.3) p0(.1) rrcd(2.0) evalue
    assert _N == `n_before'
    datasignature
    assert "`r(datasignature)'" == "`sig_before'"
}
if _rc == 0 {
    display as result "  PASS: T10.1 Simple mode preserves data"
    local ++pass_count
}
else {
    display as error "  FAIL: T10.1 Data preservation (error `=_rc')"
    local ++fail_count
}

* T10.2: Probabilistic mode preserves data
local ++test_count
capture noisily {
    sysuse auto, clear
    local n_before = _N
    datasignature
    local sig_before "`r(datasignature)'"

    qba_misclass, a(100) b(200) c(300) d(400) seca(.9) spca(.95) reps(200) seed(1)
    assert _N == `n_before'
    datasignature
    assert "`r(datasignature)'" == "`sig_before'"

    qba_multi, a(100) b(200) c(300) d(400) reps(200) ///
        seca(.85) spca(.95) p1(.3) p0(.1) rrcd(2.0) seed(1)
    assert _N == `n_before'
    datasignature
    assert "`r(datasignature)'" == "`sig_before'"
}
if _rc == 0 {
    display as result "  PASS: T10.2 Probabilistic mode preserves data"
    local ++pass_count
}
else {
    display as error "  FAIL: T10.2 Probabilistic preservation (error `=_rc')"
    local ++fail_count
}

* ============================================================
* SUMMARY
* ============================================================

display as text ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
