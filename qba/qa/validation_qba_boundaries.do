* validation_qba_boundaries.do -- additional hand-computed boundary checks
* Package: qba (Quantitative Bias Analysis)
* Usage: cd qba/qa && stata-mp -b do validation_qba_boundaries.do

clear all

* === Bootstrap ===
local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
capture confirm file "`pkg_dir'/qba.pkg"
if _rc {
    local pkg_dir "`qa_dir'"
    capture confirm file "`pkg_dir'/qba.pkg"
    if _rc {
        display as error "could not locate qba package root from `c(pwd)'"
        exit 601
    }
    local qa_dir "`pkg_dir'/qa"
}

capture ado uninstall qba
net install qba, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

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
* B1: Differential outcome misclassification known answers
* ============================================================

* B1.1: Differential outcome misclassification, OR scale
*   Table: a=90, b=70, c=210, d=630
*   Exposed:   Se=0.88, Sp=0.97, denominator=0.85, N1=300
*   Unexposed: Se=0.76, Sp=0.93, denominator=0.69, N0=700
*   a*=(90 - 0.03*300)/0.85 = 95.2941176
*   c*=300 - a* = 204.7058824
*   b*=(70 - 0.07*700)/0.69 = 30.4347826
*   d*=700 - b* = 669.5652174
*   observed OR = (90*630)/(70*210) = 27/7 = 3.8571429
*   corrected OR = 10.2413793
local ++test_count
capture noisily {
    qba_misclass, a(90) b(70) c(210) d(630) ///
        seca(.88) spca(.97) secb(.76) spcb(.93) type(outcome)
    _assert_close `=r(observed)' 3.8571429 0.0001
    _assert_close `=r(corrected_a)' 95.2941176 0.0001
    _assert_close `=r(corrected_b)' 30.4347826 0.0001
    _assert_close `=r(corrected_c)' 204.7058824 0.0001
    _assert_close `=r(corrected_d)' 669.5652174 0.0001
    _assert_close `=r(corrected)' 10.2413793 0.0001
    * Outcome misclassification preserves exposure-stratum column totals.
    _assert_close `=r(corrected_a) + r(corrected_c)' 300 0.0001
    _assert_close `=r(corrected_b) + r(corrected_d)' 700 0.0001
}
if _rc == 0 {
    display as result "  PASS: B1.1 Differential outcome misclass OR known-answer"
    local ++pass_count
}
else {
    display as error "  FAIL: B1.1 Differential outcome OR (error `=_rc')"
    local ++fail_count
}

* B1.2: Same corrected table, RR scale
*   observed RR = (90/300)/(70/700) = 3
*   corrected RR = (95.2941176/300)/(30.4347826/700) = 7.3058824
local ++test_count
capture noisily {
    qba_misclass, a(90) b(70) c(210) d(630) ///
        seca(.88) spca(.97) secb(.76) spcb(.93) ///
        type(outcome) measure(RR)
    _assert_close `=r(observed)' 3.0 0.0001
    _assert_close `=r(corrected)' 7.3058824 0.0001
}
if _rc == 0 {
    display as result "  PASS: B1.2 Differential outcome misclass RR known-answer"
    local ++pass_count
}
else {
    display as error "  FAIL: B1.2 Differential outcome RR (error `=_rc')"
    local ++fail_count
}

* ============================================================
* B2: Selection bias boundary probabilities
* ============================================================

* B2.1: Selection probabilities at upper boundary and small fractions
*   Table: a=7, b=11, c=13, d=17
*   S=(1, .25, .5, .8)
*   corrected cells: 7, 44, 26, 21.25
*   observed OR = 119/143 = 0.8321678
*   corrected OR = 148.75/1144 = 0.1300262
*   SBF = (1*.8)/(.25*.5) = 6.4
local ++test_count
capture noisily {
    qba_selection, a(7) b(11) c(13) d(17) ///
        sela(1) selb(.25) selc(.5) seld(.8)
    _assert_close `=r(observed)' 0.8321678 0.0001
    _assert_close `=r(corrected_a)' 7 0.0001
    _assert_close `=r(corrected_b)' 44 0.0001
    _assert_close `=r(corrected_c)' 26 0.0001
    _assert_close `=r(corrected_d)' 21.25 0.0001
    _assert_close `=r(corrected)' 0.1300262 0.0001
    _assert_close `=r(bias_factor)' 6.4 0.0001
    _assert_close `=r(observed)' `=r(corrected) * r(bias_factor)' 0.0001
}
if _rc == 0 {
    display as result "  PASS: B2.1 Selection OR boundary known-answer"
    local ++pass_count
}
else {
    display as error "  FAIL: B2.1 Selection OR boundary (error `=_rc')"
    local ++fail_count
}

* B2.2: Same selected table on RR scale
*   observed RR = (7/20)/(11/28) = 0.8909091
*   corrected RR = (7/33)/(44/65.25) = 0.3145661
local ++test_count
capture noisily {
    qba_selection, a(7) b(11) c(13) d(17) ///
        sela(1) selb(.25) selc(.5) seld(.8) measure(RR)
    _assert_close `=r(observed)' 0.8909091 0.0001
    _assert_close `=r(corrected)' 0.3145661 0.0001
}
if _rc == 0 {
    display as result "  PASS: B2.2 Selection RR boundary known-answer"
    local ++pass_count
}
else {
    display as error "  FAIL: B2.2 Selection RR boundary (error `=_rc')"
    local ++fail_count
}

* ============================================================
* B3: Confounding boundary and protective-effect checks
* ============================================================

* B3.1: Maximum positive prevalence contrast, p1=1 and p0=0
*   estimate=2, rrcd=4, BF=(1*(4-1)+1)/(0*(4-1)+1)=4
*   corrected=2/4=0.5, ratio=0.25
local ++test_count
capture noisily {
    qba_confound, estimate(2) p1(1) p0(0) rrcd(4)
    _assert_close `=r(bias_factor)' 4 0.0001
    _assert_close `=r(corrected)' 0.5 0.0001
    _assert_close `=r(ratio)' 0.25 0.0001
}
if _rc == 0 {
    display as result "  PASS: B3.1 Confounding p1=1/p0=0 boundary"
    local ++pass_count
}
else {
    display as error "  FAIL: B3.1 Confounding high boundary (error `=_rc')"
    local ++fail_count
}

* B3.2: Opposite prevalence contrast, p1=0 and p0=1
*   estimate=2, rrcd=4, BF=1/4=0.25
*   corrected=2/.25=8, ratio=4
local ++test_count
capture noisily {
    qba_confound, estimate(2) p1(0) p0(1) rrcd(4)
    _assert_close `=r(bias_factor)' 0.25 0.0001
    _assert_close `=r(corrected)' 8 0.0001
    _assert_close `=r(ratio)' 4 0.0001
}
if _rc == 0 {
    display as result "  PASS: B3.2 Confounding p1=0/p0=1 boundary"
    local ++pass_count
}
else {
    display as error "  FAIL: B3.2 Confounding low boundary (error `=_rc')"
    local ++fail_count
}

* B3.3: E-value for protective effect and protective CI bound
*   estimate=.4 => inverse RR=2.5
*   E = 2.5 + sqrt(2.5*1.5) = 4.4364917
*   ci_bound=.7 => inverse RR=10/7
*   E_CI = 10/7 + sqrt((10/7)*(3/7)) = 2.2110322
local ++test_count
capture noisily {
    qba_confound, estimate(.4) evalue ci_bound(.7)
    _assert_close `=r(evalue)' 4.4364917 0.0001
    _assert_close `=r(evalue_ci)' 2.2110322 0.0001
}
if _rc == 0 {
    display as result "  PASS: B3.3 Protective E-value known-answer"
    local ++pass_count
}
else {
    display as error "  FAIL: B3.3 Protective E-value (error `=_rc')"
    local ++fail_count
}

* B3.4: Protective confounder-disease association, rrcd < 1
*   estimate=2, p1=.6, p0=.2, rrcd=.5
*   BF=(.6*(.5-1)+1)/(.2*(.5-1)+1)=.7/.9=0.7777778
*   corrected=2/(7/9)=18/7=2.5714286, ratio=9/7=1.2857143
local ++test_count
capture noisily {
    qba_confound, estimate(2) p1(.6) p0(.2) rrcd(.5)
    _assert_close `=r(bias_factor)' 0.7777778 0.0001
    _assert_close `=r(corrected)' 2.5714286 0.0001
    _assert_close `=r(ratio)' 1.2857143 0.0001
}
if _rc == 0 {
    display as result "  PASS: B3.4 Protective confounder RR known-answer"
    local ++pass_count
}
else {
    display as error "  FAIL: B3.4 Protective confounder RR (error `=_rc')"
    local ++fail_count
}

* ============================================================
* B4: Multi-bias no-op and confound-only invariants
* ============================================================

* B4.1: All active biases configured as no-op return the observed OR
*   Misclass Se=Sp=1, all selection probabilities=1, and p1=p0 make BF=1.
local ++test_count
capture restore
capture noisily {
    tempfile noop
    qba_multi, a(90) b(70) c(210) d(630) reps(200) ///
        seca(1) spca(1) sela(1) selb(1) selc(1) seld(1) ///
        p1(.25) p0(.25) rrcd(7) ///
        dist_se("constant 1") dist_sp("constant 1") ///
        dist_sela("constant 1") dist_selb("constant 1") ///
        dist_selc("constant 1") dist_seld("constant 1") ///
        dist_p1("constant .25") dist_p0("constant .25") ///
        dist_rr("constant 7") seed(123) saving("`noop'", replace)
    _assert_close `=r(observed)' 3.8571429 0.0001
    _assert_close `=r(corrected)' `=r(observed)' 0.0001
    _assert_close `=r(mean)' `=r(observed)' 0.0001
    assert r(sd) < 0.000001
    assert r(n_valid) == r(reps)
    assert r(n_biases) == 3
    preserve
    use "`noop'", clear
    assert _N == 200
    summarize a_corr, meanonly
    _assert_close `=r(min)' 90 0.0001
    _assert_close `=r(max)' 90 0.0001
    summarize b_corr, meanonly
    _assert_close `=r(min)' 70 0.0001
    _assert_close `=r(max)' 70 0.0001
    summarize c_corr, meanonly
    _assert_close `=r(min)' 210 0.0001
    _assert_close `=r(max)' 210 0.0001
    summarize d_corr, meanonly
    _assert_close `=r(min)' 630 0.0001
    _assert_close `=r(max)' 630 0.0001
    summarize corrected_or, meanonly
    _assert_close `=r(min)' 3.8571429 0.0001
    _assert_close `=r(max)' 3.8571429 0.0001
    restore
}
if _rc == 0 {
    display as result "  PASS: B4.1 Multi-bias no-op invariant"
    local ++pass_count
}
else {
    display as error "  FAIL: B4.1 Multi-bias no-op invariant (error `=_rc')"
    local ++fail_count
}

* B4.2: Multi-bias with confounding only matches the closed-form correction
*   observed OR=27/7=3.8571429
*   BF=(.45*(2.5-1)+1)/(.15*(2.5-1)+1)=1.675/1.225=1.3673469
*   corrected=(27/7)/1.3673469=2.8208955
local ++test_count
capture noisily {
    qba_multi, a(90) b(70) c(210) d(630) reps(200) ///
        p1(.45) p0(.15) rrcd(2.5) ///
        dist_p1("constant .45") dist_p0("constant .15") ///
        dist_rr("constant 2.5") seed(99)
    _assert_close `=r(observed)' 3.8571429 0.0001
    _assert_close `=r(corrected)' 2.8208955 0.0001
    _assert_close `=r(mean)' 2.8208955 0.0001
    assert r(sd) < 0.000001
    assert r(n_valid) == r(reps)
    assert r(n_biases) == 1
}
if _rc == 0 {
    display as result "  PASS: B4.2 Multi-bias confound-only known-answer"
    local ++pass_count
}
else {
    display as error "  FAIL: B4.2 Multi confound-only (error `=_rc')"
    local ++fail_count
}

* B4.3: Multi-bias differential outcome misclassification matches hand solution
*   Uses the same corrected table as B1.1 in the qba_multi Monte Carlo engine.
*   Constant draws make every replication identical.
local ++test_count
capture restore
capture noisily {
    tempfile multi_diff_outcome
    qba_multi, a(90) b(70) c(210) d(630) reps(200) ///
        seca(.88) spca(.97) secb(.76) spcb(.93) mctype(outcome) ///
        dist_se("constant .88") dist_sp("constant .97") ///
        dist_se1("constant .76") dist_sp1("constant .93") ///
        seed(101) saving("`multi_diff_outcome'", replace)
    _assert_close `=r(observed)' 3.8571429 0.0001
    _assert_close `=r(corrected)' 10.2413793 0.0001
    _assert_close `=r(mean)' 10.2413793 0.0001
    assert r(sd) < 0.000001
    assert r(n_valid) == r(reps)
    assert r(n_biases) == 1
    assert "`r(order)'" == "misclass"

    preserve
    use "`multi_diff_outcome'", clear
    assert _N == 200
    summarize a_corr, meanonly
    _assert_close `=r(min)' 95.2941176 0.0001
    _assert_close `=r(max)' 95.2941176 0.0001
    summarize b_corr, meanonly
    _assert_close `=r(min)' 30.4347826 0.0001
    _assert_close `=r(max)' 30.4347826 0.0001
    summarize c_corr, meanonly
    _assert_close `=r(min)' 204.7058824 0.0001
    _assert_close `=r(max)' 204.7058824 0.0001
    summarize d_corr, meanonly
    _assert_close `=r(min)' 669.5652174 0.0001
    _assert_close `=r(max)' 669.5652174 0.0001
    gen double exposed_total = a_corr + c_corr
    gen double unexposed_total = b_corr + d_corr
    summarize exposed_total, meanonly
    _assert_close `=r(min)' 300 0.0001
    _assert_close `=r(max)' 300 0.0001
    summarize unexposed_total, meanonly
    _assert_close `=r(min)' 700 0.0001
    _assert_close `=r(max)' 700 0.0001
    summarize corrected_or, meanonly
    _assert_close `=r(min)' 10.2413793 0.0001
    _assert_close `=r(max)' 10.2413793 0.0001
    restore
}
if _rc == 0 {
    display as result "  PASS: B4.3 Multi differential outcome OR invariant"
    local ++pass_count
}
else {
    display as error "  FAIL: B4.3 Multi differential outcome OR (error `=_rc')"
    local ++fail_count
}

* B4.4: Same multi-bias differential outcome path on RR scale
local ++test_count
capture noisily {
    qba_multi, a(90) b(70) c(210) d(630) reps(200) measure(RR) ///
        seca(.88) spca(.97) secb(.76) spcb(.93) mctype(outcome) ///
        dist_se("constant .88") dist_sp("constant .97") ///
        dist_se1("constant .76") dist_sp1("constant .93") ///
        seed(101)
    _assert_close `=r(observed)' 3.0 0.0001
    _assert_close `=r(corrected)' 7.3058824 0.0001
    _assert_close `=r(mean)' 7.3058824 0.0001
    assert r(sd) < 0.000001
    assert r(n_valid) == r(reps)
}
if _rc == 0 {
    display as result "  PASS: B4.4 Multi differential outcome RR invariant"
    local ++pass_count
}
else {
    display as error "  FAIL: B4.4 Multi differential outcome RR (error `=_rc')"
    local ++fail_count
}

* ============================================================
* SUMMARY
* ============================================================

display as text ""
display as result "Boundary validation: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    capture ado uninstall qba
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
    capture ado uninstall qba
}
