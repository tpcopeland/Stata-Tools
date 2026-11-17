* crossval_qba_published_fox-maclehose-lash-2023.do -- reproduce Fox, MacLehose & Lash (2023) Table 3
* Package: qba (Quantitative Bias Analysis)
* Usage: cd qba/qa && stata-mp -b do crossval_qba_published_fox-maclehose-lash-2023.do
*
* Published reproduction. Fox MP, MacLehose RF, Lash TL. SAS and R code for
* probabilistic quantitative bias analysis for misclassified binary variables
* and binary unmeasured confounders. Int J Epidemiol 2023;52:1624-1633.
* Table 2 (p.1628) gives the exposure-misclassification example: diseased
* exposed 40, unexposed 20; non-diseased exposed 60, unexposed 80 (observed
* RR 2.0); Se among diseased ~ beta(25, 3), among non-diseased ~ beta(45, 7);
* Sp among diseased ~ trapezoidal(.9, .93, .97, 1), among non-diseased ~
* trapezoidal(.8, .83, .87, .9); correlation 0.8 between the two Se and
* between the two Sp draws; 1 million simulations. Table 3 (p.1629) prints
* the summary-level medians and 2.5th-97.5th percentiles. Targets are the
* published numbers, compared at the precision the paper prints; one fixed
* seed makes the run deterministic.

clear all
set linesize 255

capture do "_qba_qa_common.do"
if _rc {
    do "qa/_qba_qa_common.do"
}
_qba_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

* _f23_printed <value> <published string>: value rounded to the number of
* decimals the published string shows equals the published value
capture program drop _f23_printed
program define _f23_printed
    args value published
    local dot = strpos("`published'", ".")
    local dec = cond(`dot' > 0, strlen("`published'") - `dot', 0)
    assert !missing(`value')
    assert abs(round(`value', 10^(-`dec')) - `published') < 1e-9
end

**# F1: summary-level Table 3 rows (random, systematic, total error)
local ++test_count
capture noisily {
    qba_misclass, a(40) b(20) c(60) d(80) seca(.89) spca(.95) ///
        secb(.87) spcb(.85) type(exposure) measure(RR) reps(1000000) ///
        dist_se("beta 25 3") dist_sp("trapezoidal .9 .93 .97 1") ///
        dist_se1("beta 45 7") dist_sp1("trapezoidal .8 .83 .87 .9") ///
        corr(.8) totalerror seed(20230501)
    _f23_printed r(observed) 2.0
    * Random error: 2 (1.3-3.2)
    _f23_printed r(re_median) 2
    _f23_printed r(re_lower) 1.3
    _f23_printed r(re_upper) 3.2
    * Systematic error: 2.8 (2.3-5.0)
    _f23_printed r(corrected) 2.8
    _f23_printed r(ci_lower) 2.3
    _f23_printed r(ci_upper) 5.0
    * Total error: 2.8 (1.5-7.8)
    _f23_printed r(te_median) 2.8
    _f23_printed r(te_lower) 1.5
    _f23_printed r(te_upper) 7.8
    assert r(reps) == 1000000
    assert !missing(r(n_valid)) & r(n_valid) > 900000
}
if _rc == 0 {
    display as result "  PASS: F1 Table 3 summary-level results, 9/9 printed values"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 Table 3 reproduction (error `=_rc')"
    local ++fail_count
}

display as result "Fox, MacLehose & Lash (2023) reproduction: `pass_count'/`test_count' passed, `fail_count' failed"
capture ado uninstall qba
if `fail_count' > 0 {
    display "RESULT: crossval_qba_published_fox-maclehose-lash-2023 tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display "RESULT: crossval_qba_published_fox-maclehose-lash-2023 tests=`test_count' pass=`pass_count' fail=`fail_count'"
