* test_qba_documentation_examples.do -- literal displayed help workflows
* Run from qba/qa; no displayed command line is repaired or abbreviated here.

clear all
version 16.0

capture do "_qba_qa_common.do"
if _rc do "qa/_qba_qa_common.do"
_qba_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _qba_doc_result
program define _qba_doc_result
    args label check
    if `check' == 0 {
        display as result "PASS: `label'"
    }
    else {
        display as error "FAIL: `label' (rc=`check')"
    }
end

* The documented tmle/ltmle integration is optional.  Exercise the exact
* e()-contract qba_confound consumes without requiring a third-party command.
capture program drop _qba_doc_fake_tmle
program define _qba_doc_fake_tmle, eclass
    version 16.0
    clear
    set obs 20
    tempvar esample
    generate byte `esample' = 1
    tempname b V
    matrix `b' = (-0.12)
    matrix colnames `b' = ATE
    matrix `V' = (.01)
    matrix colnames `V' = ATE
    matrix rownames `V' = ATE
    ereturn post `b' `V', obs(20) esample(`esample')
    ereturn scalar tau = -0.12
    ereturn scalar se = .1
    ereturn scalar ci_lo = -.316
    ereturn scalar ci_hi = .076
    ereturn local cmd "tmle"
    ereturn local outcome "y"
    ereturn local treatment "a"
    ereturn local estimand "ATE"
end

* qba.sthlp and qba_misclass.sthlp: fixed-parameter examples
foreach spec in ///
    `"a(100) b(200) c(50) d(300) seca(.85) spca(.95)"' ///
    `"a(136) b(297) c(1432) d(6738) seca(.85) spca(.95)"' ///
    `"a(136) b(297) c(1432) d(6738) seca(.90) spca(.95) secb(.80) spcb(.95)"' ///
    `"a(136) b(297) c(1432) d(6738) seca(.92) spca(.98) type(outcome) measure(RR)"' {
    local ++test_count
    capture noisily qba_misclass, `spec'
    local rc = _rc
    if !`rc' assert !missing(r(observed))
    local rc = _rc
    if `rc' local ++fail_count
    else local ++pass_count
    _qba_doc_result "qba_misclass fixed example" `rc'
}

* qba.sthlp and qba_misclass.sthlp: displayed probabilistic workflows.
local ++test_count
capture noisily qba_misclass, a(100) b(200) c(50) d(300) seca(.85) spca(.95) ///
    reps(10000) dist_se("trapezoidal .75 .82 .88 .95") ///
    dist_sp("trapezoidal .90 .93 .97 1.0") seed(12345) saving(mc_results, replace)
local rc = _rc
if !`rc' {
    assert r(reps) == 10000
    confirm file "mc_results.dta"
}
local rc = _rc
if `rc' local ++fail_count
else local ++pass_count
_qba_doc_result "qba.sthlp saved MC example" `rc'

local ++test_count
capture noisily qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95) ///
    reps(10000) dist_se("trapezoidal .75 .82 .88 .95") ///
    dist_sp("trapezoidal .90 .93 .97 1.0") seed(12345)
local rc = _rc
if !`rc' assert r(reps) == 10000
local rc = _rc
if `rc' local ++fail_count
else local ++pass_count
_qba_doc_result "qba_misclass trapezoidal example" `rc'

local ++test_count
capture noisily qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95) ///
    reps(10000) dist_se("beta 17 3") dist_sp("beta 19 1") ///
    seed(12345) saving(mc_results, replace)
local rc = _rc
if !`rc' {
    assert r(reps) == 10000
    confirm file "mc_results.dta"
}
local rc = _rc
if `rc' local ++fail_count
else local ++pass_count
_qba_doc_result "qba_misclass beta saving example" `rc'

local ++test_count
capture noisily qba_misclass, a(215) b(1449) c(668) d(4296) seca(.78) spca(.99) measure(RR) ///
    reps(100000) dist_se("beta 50.6 14.3") dist_sp("beta 70 1") ///
    totalerror seed(12345)
local rc = _rc
if !`rc' assert r(reps) == 100000
local rc = _rc
if `rc' local ++fail_count
else local ++pass_count
_qba_doc_result "qba_misclass total-error example" `rc'

local ++test_count
capture noisily qba_misclass, a(215) b(1449) c(668) d(4296) seca(.78) spca(.99) secb(.75) spcb(.98) ///
    measure(RR) reps(100000) dist_se("beta 50.6 14.3") dist_sp("beta 70 1") ///
    dist_se1("beta 45 15") dist_sp1("beta 70 1") corr(0.80) seed(12345)
local rc = _rc
if !`rc' assert r(reps) == 100000
local rc = _rc
if `rc' local ++fail_count
else local ++pass_count
_qba_doc_result "qba_misclass correlated example" `rc'

local ++test_count
capture noisily qba_misclass, a(387) b(1642) c(685) d(3365) type(outcome) measure(OR) ///
    seca(.92) spca(.98) fcase(1) fctrl(.1) ///
    reps(100000) dist_se("beta 35 3") dist_sp("uniform .96 1") totalerror seed(12345)
local rc = _rc
if !`rc' assert r(reps) == 100000
local rc = _rc
if `rc' local ++fail_count
else local ++pass_count
_qba_doc_result "qba_misclass case-control example" `rc'

* qba_selection.sthlp
foreach spec in ///
    `"a(136) b(297) c(1432) d(6738) sela(.9) selb(.85) selc(.7) seld(.8)"' ///
    `"a(136) b(297) c(1432) d(6738) sela(.9) selb(.85) selc(.7) seld(.8) measure(RR)"' {
    local ++test_count
    capture noisily qba_selection, `spec'
    local rc = _rc
    if !`rc' assert !missing(r(observed))
    local rc = _rc
    if `rc' local ++fail_count
    else local ++pass_count
    _qba_doc_result "qba_selection fixed example" `rc'
}

local ++test_count
capture noisily qba_selection, a(136) b(297) c(1432) d(6738) sela(.9) selb(.85) selc(.7) seld(.8) ///
    reps(10000) dist_sela("uniform .8 1.0") dist_selb("uniform .75 .95") ///
    dist_selc("uniform .6 .8") dist_seld("uniform .7 .9") seed(54321)
local rc = _rc
if !`rc' assert r(reps) == 10000
local rc = _rc
if `rc' local ++fail_count
else local ++pass_count
_qba_doc_result "qba_selection uniform example" `rc'

local ++test_count
capture noisily qba_selection, a(136) b(297) c(1432) d(6738) sela(.9) selb(.85) selc(.7) seld(.8) ///
    reps(10000) dist_sela("trapezoidal .8 .85 .95 1.0") ///
    dist_selb("trapezoidal .7 .80 .90 .95") ///
    dist_selc("trapezoidal .5 .65 .75 .85") ///
    dist_seld("trapezoidal .6 .75 .85 .90") seed(54321) saving(mc_sel, replace)
local rc = _rc
if !`rc' {
    assert r(reps) == 10000
    confirm file "mc_sel.dta"
}
local rc = _rc
if `rc' local ++fail_count
else local ++pass_count
_qba_doc_result "qba_selection saved MC example" `rc'

* qba_confound.sthlp, including its model examples.
foreach spec in ///
    `"estimate(1.5) p1(.4) p0(.2) rrcd(2.0)"' ///
    `"estimate(1.5) p1(.4) p0(.2) rrcd(2.0) evalue"' ///
    `"estimate(2.1) evalue ci_bound(1.3)"' ///
    `"estimate(1.5) measure(OR) p1(.4) p0(.2) rrcd(2.0) evalue ci_bound(1.1)"' ///
    `"estimate(1.5) measure(OR) evalue ci_bound(1.1) commonoutcome"' ///
    `"estimate(1.5) measure(HR) evalue ci_bound(1.1) commonoutcome"' ///
    `"estimate(1.8) p1(.5) p0(.2) rrud(2.5)"' {
    local ++test_count
    capture noisily qba_confound, `spec'
    local rc = _rc
    if !`rc' assert !missing(r(observed))
    local rc = _rc
    if `rc' local ++fail_count
    else local ++pass_count
    _qba_doc_result "qba_confound scalar example" `rc'
}

local ++test_count
capture noisily {
    sysuse auto, clear
    logistic foreign mpg weight
    qba_confound, from_model coef(mpg) p1(.35) p0(.15) rrcd(1.8) evalue
    assert "`r(measure)'" == "OR"
}
local rc = _rc
if `rc' local ++fail_count
else local ++pass_count
_qba_doc_result "qba_confound logistic example" `rc'

local ++test_count
capture noisily {
    sysuse auto, clear
    regress price mpg weight
    qba_confound, from_model coef(weight) p1(.3) p0(.1) confeffect(500)
    assert !missing(r(corrected))
}
local rc = _rc
if `rc' local ++fail_count
else local ++pass_count
_qba_doc_result "qba_confound linear example" `rc'

local ++test_count
capture noisily qba_confound, estimate(1.5) p1(.4) p0(.2) rrcd(2.0) ///
    reps(10000) dist_p1("beta 8 12") dist_p0("beta 4 16") ///
    dist_rr("trapezoidal 1.5 1.8 2.2 3.0") seed(99999)
local rc = _rc
if !`rc' assert r(reps) == 10000
local rc = _rc
if `rc' local ++fail_count
else local ++pass_count
_qba_doc_result "qba_confound probabilistic example" `rc'

* qba_multi.sthlp and the suite overview multi-bias workflow.
foreach spec in ///
    `"a(136) b(297) c(1432) d(6738) reps(10000) seca(.85) spca(.95) sela(.9) selb(.85) selc(.7) seld(.8) p1(.4) p0(.2) rrcd(2.0) seed(12345)"' ///
    `"a(136) b(297) c(1432) d(6738) reps(20000) seca(.85) spca(.95) dist_se("trapezoidal .75 .82 .88 .95") dist_sp("trapezoidal .90 .93 .97 1.0") p1(.4) p0(.2) rrcd(2.0) dist_rr("uniform 1.5 3.0") seed(54321) saving(multi_results, replace)"' ///
    `"a(136) b(297) c(1432) d(6738) reps(10000) sela(.9) selb(.85) selc(.7) seld(.8) p1(.3) p0(.1) rrud(2.0) seed(12345)"' ///
    `"a(136) b(297) c(1432) d(6738) reps(10000) seca(.85) spca(.95) sela(.9) selb(.85) selc(.7) seld(.8) order(selection misclass) measure(RR) seed(12345)"' ///
    `"a(100) b(200) c(50) d(300) reps(10000) seca(.85) spca(.95) sela(.9) selb(.85) selc(.7) seld(.8) p1(.4) p0(.2) rrcd(2.0) seed(12345)"' {
    local ++test_count
    capture noisily qba_multi, `spec'
    local rc = _rc
    if !`rc' assert r(reps) >= 10000
    local rc = _rc
    if `rc' local ++fail_count
    else local ++pass_count
    _qba_doc_result "qba_multi example" `rc'
}
local ++test_count
capture confirm file "multi_results.dta"
local rc = _rc
if `rc' local ++fail_count
else local ++pass_count
_qba_doc_result "qba_multi saved-results artifact" `rc'

* qba_plot.sthlp and all plot calls from the overview/selection/misclass help.
local ++test_count
capture noisily qba_plot, distribution using(mc_results) observed(2.15)
local rc = _rc
if !`rc' assert "`r(plot_type)'" == "distribution"
local rc = _rc
if `rc' local ++fail_count
else local ++pass_count
_qba_doc_result "qba_plot distribution mc_results example" `rc'
capture graph close _all

local ++test_count
capture noisily qba_plot, distribution using(mc_sel) observed(2.15)
local rc = _rc
if !`rc' assert "`r(plot_type)'" == "distribution"
local rc = _rc
if `rc' local ++fail_count
else local ++pass_count
_qba_doc_result "qba_plot distribution mc_sel example" `rc'
capture graph close _all

foreach spec in ///
    `"tornado a(136) b(297) c(1432) d(6738) param1(se) range1(.7 1) param2(sp) range2(.8 1) steps(30)"' ///
    `"tornado a(136) b(297) c(1432) d(6738) param1(p1) range1(0 .6) param2(rrcd) range2(1 4)"' ///
    `"tornado a(136) b(297) c(1432) d(6738) param1(se) range1(.7 1) param2(sp) range2(.8 1) param3(sela) range3(.5 1)"' ///
    `"tipping a(136) b(297) c(1432) d(6738) param1(se) range1(.6 1) param2(sp) range2(.6 1) steps(25)"' ///
    `"tipping a(136) b(297) c(1432) d(6738) param1(p1) range1(0 .6) param2(rrcd) range2(1 5)"' ///
    `"tornado a(136) b(297) c(1432) d(6738) param1(se) range1(.7 1) title("Sensitivity of OR to Misclassification")"' ///
    `"tornado a(100) b(200) c(50) d(300) param1(se) range1(.7 1) param2(sp) range2(.8 1)"' ///
    `"tipping a(100) b(200) c(50) d(300) param1(p1) range1(0 .6) param2(rrcd) range2(1 4)"' {
    local ++test_count
    capture noisily qba_plot, `spec'
    local rc = _rc
    if !`rc' assert inlist("`r(plot_type)'", "tornado", "tipping")
    local rc = _rc
    if `rc' local ++fail_count
    else local ++pass_count
    _qba_doc_result "qba_plot grid example" `rc'
    capture graph close _all
}

* The displayed optional integration requires a separately installed tmle.
* Verify its documented active-estimation contract with a local stand-in.
local ++test_count
capture noisily _qba_doc_fake_tmle
local rc = _rc
if `rc' local ++fail_count
else local ++pass_count
_qba_doc_result "documented tmle contract setup" `rc'

local ++test_count
capture noisily qba_confound, p1(.35) p0(.15) confeffect(.25)
local rc = _rc
if !`rc' assert !missing(r(corrected))
local rc = _rc
if `rc' local ++fail_count
else local ++pass_count
_qba_doc_result "documented qba_confound after tmle" `rc'

local ++test_count
capture noisily qba_confound, evalue
local rc = _rc
if !`rc' {
    local qba_source "`r(source)'"
    local qba_measure "`r(measure)'"
    capture confirm scalar r(evalue)
    assert _rc != 0
    assert "`qba_source'" == "tmle"
    assert "`qba_measure'" == "coefficient"
}
local rc = _rc
if `rc' local ++fail_count
else local ++pass_count
_qba_doc_result "additive tmle contract correctly skips E-value" `rc'

display "RESULT: test_qba_documentation_examples tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 exit 1
