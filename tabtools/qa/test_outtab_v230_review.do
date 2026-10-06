* test_outtab_v230_review.do - independent review regressions for outtab and tabcell, tabtools 2.3.0
* Oracles: hand counts of events per group, Stata's own lincom r() at the
* requested level, and the eform state of r(table) read against e(b).

clear all
set more off
set varabbrev off
version 17.0

capture log close _otr
log using "test_outtab_v230_review.log", replace text name(_otr)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear
global TABTOOLS_set_smallcells

local pass_count = 0
local fail_count = 0

capture program drop _otr_data
program define _otr_data
    version 17.0
    clear
    set seed 1
    set obs 400
    gen long id = ceil(_n / 2)
    gen byte x = _n <= 100
    gen byte y0 = 0
    replace y0 = 1 in 150/180
    gen byte z0 = 0
    replace z0 = 1 in 10/40
    gen byte y1 = runiform() < 0.3
end

**# OV1: zero events in a group never prints a ratio (boundary MLE)
capture noisily {
    _otr_data
    * no exposed events: poisson converges to b = -17 and r(table) is finite
    outtab y0, exposure(x) minevents(0) frame(_ov1, replace)
    matrix T = r(table)
    assert T[1, 2] == 0 & T[1, 4] == 31
    assert T[1, 8] == 459 & missing(T[1, 5])
    frame _ov1: assert c3[1] == "not estimable"
    * no comparator events
    outtab z0, exposure(x) minevents(0) frame(_ov1, replace)
    matrix T = r(table)
    assert T[1, 4] == 0 & T[1, 8] == 459
    frame _ov1: assert c3[1] == "not estimable"
    * logistic regression too (logit drops the exposed rows: sample reduced)
    outtab y0, exposure(x) minevents(0) estimator(logit, or) frame(_ov1, replace)
    frame _ov1: assert strpos(c3[1], "not estimable") == 1
    * control: events in both groups still give a ratio
    outtab y1, exposure(x) frame(_ov1, replace)
    frame _ov1: assert regexm(c3[1], "^[0-9]+\.[0-9][0-9] \(")
    frame drop _ov1
}
if _rc == 0 {
    display as result "  PASS: OV1 a group with no events prints not estimable, never 0.00 (0.00, 0.00)"
    local ++pass_count
}
else {
    display as error "  FAIL: OV1 zero-event group (rc=`=_rc')"
    local ++fail_count
}

**# OV2: eform on an estimator that already reports the ratio is refused
capture noisily {
    _otr_data
    quietly poisson y1 x, irr
    local want = strtrim(string(exp(_b[x]), "%4.2f"))
    capture outtab y1, exposure(x) estimator(poisson, irr) eform
    assert _rc == 198
    capture outtab y1, exposure(x) estimator(logit, or) eform
    assert _rc == 198
    * either alone is the same ratio
    outtab y1, exposure(x) estimator(poisson, irr) frame(_ov2, replace)
    frame _ov2: assert strpos(c3[1], "`want' (") == 1
    outtab y1, exposure(x) estimator(poisson) eform frame(_ov2, replace)
    frame _ov2: assert strpos(c3[1], "`want' (") == 1
    frame drop _ov2
}
if _rc == 0 {
    display as result "  PASS: OV2 eform with irr/or is refused; each alone gives exp(b)"
    local ++pass_count
}
else {
    display as error "  FAIL: OV2 double exponentiation (rc=`=_rc')"
    local ++fail_count
}

**# TV1: tabcell est, lincom after lincom, eform: the interval at another level
capture noisily {
    sysuse auto, clear
    quietly logit foreign mpg weight
    quietly lincom mpg + weight, eform level(90)
    local lb90 = r(lb)
    local ub90 = r(ub)
    local e90 = r(estimate)
    quietly lincom mpg + weight, eform
    tabcell est, lincom level(90) format(%12.10f)
    assert !missing(r(lb), `lb90', r(ub), `ub90')
    assert reldif(r(lb), `lb90') < 1e-10 & reldif(r(ub), `ub90') < 1e-10
    assert !missing(r(estimate), `e90')
    assert reldif(r(estimate), `e90') < 1e-12
    * the stored level is used as stored
    quietly lincom mpg + weight, eform
    local lb95 = r(lb)
    tabcell est, lincom
    assert !missing(r(lb), `lb95')
    assert reldif(r(lb), `lb95') < 1e-12
    * eform on top of an exponentiated lincom is refused
    quietly lincom mpg + weight, eform
    capture tabcell est, lincom eform
    assert _rc == 198
    * a plain lincom with eform still exponentiates once
    quietly lincom mpg + weight, level(90)
    local plb = exp(r(lb))
    quietly lincom mpg + weight
    tabcell est, lincom eform level(90)
    assert !missing(r(lb), `plb')
    assert reldif(r(lb), `plb') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: TV1 lincom, eform: level() recomputed on the log scale; eform twice refused"
    local ++pass_count
}
else {
    display as error "  FAIL: TV1 tabcell lincom eform (rc=`=_rc')"
    local ++fail_count
}

**# OV3: a fit that drops rows of the events/N sample never prints a ratio
capture noisily {
    _otr_data
    gen byte c = runiform() < 0.5
    gen byte y2 = runiform() < 0.4 & c == 0
    quietly count if !missing(y2)
    local nall = r(N)
    * logit drops the c == 1 rows (c predicts failure perfectly)
    quietly logit y2 x c
    assert e(N) < `nall'
    outtab y2, exposure(x) models("" \ "c") estimator(logit, or) frame(_ov3, replace)
    matrix T = r(table)
    assert T[1, 8] == 0 & T[1, 12] == -2 & missing(T[1, 9])
    frame _ov3: assert regexm(c3[1], "^[0-9]+\.[0-9][0-9] \(") & c4[1] == "not estimable (sample reduced)"
    outtab y2, exposure(x) models("" \ "c") estimator(logit, or) droptext("n.e.") frame(_ov3, replace)
    frame _ov3: assert c4[1] == "n.e."
    assert !missing(r(fits)[2, 3]) & !missing(r(fits)[2, 4]) & r(fits)[2, 3] < r(fits)[2, 4]
    * a covariate missing in 10% of rows: complete-case model, ratio printed
    gen double w = runiform() if mod(_n, 10) != 0
    quietly poisson y1 x w, irr vce(robust)
    local want = strtrim(string(exp(_b[x]), "%4.2f"))
    local nfit = e(N)
    outtab y1, exposure(x) models("" \ "w") frame(_ov3, replace)
    matrix T = r(table)
    matrix F = r(fits)
    assert T[1, 12] == 0
    frame _ov3: assert strpos(c4[1], "`want' (") == 1
    assert F[2, 3] == `nfit' & F[2, 3] == F[2, 4] & F[2, 3] < T[1, 1] + T[1, 3]
    assert F[2, 4] == 360 & F[1, 4] == 400 & F[1, 3] == 400
    frame drop _ov3
}
if _rc == 0 {
    display as result "  PASS: OV3 estimator-side drops print droptext() (-2); a complete-case model prints its ratio"
    local ++pass_count
}
else {
    display as error "  FAIL: OV3 reduced fit sample (rc=`=_rc')"
    local ++fail_count
}

**# OV4: r(fits) holds e(N), e(N_clust), e(df_m), e(converged) and the code per fit
capture noisily {
    _otr_data
    gen byte c = runiform() < 0.5
    outtab y1 y0, exposure(x) models("" \ "c") estimator(poisson, irr vce(cluster id)) minevents(1)
    matrix F = r(fits)
    assert rowsof(F) == 4 & colsof(F) == 8
    assert "`: colnames F'" == "row model N N_cc N_clust df_m converged rc"
    quietly poisson y1 x c, irr vce(cluster id)
    assert F[2, 1] == 1 & F[2, 2] == 2
    assert F[2, 3] == e(N) & F[2, 4] == e(N) & F[2, 5] == e(N_clust) & F[2, 6] == e(df_m) & F[2, 7] == e(converged) & F[2, 8] == 0
    quietly poisson y1 x, irr vce(cluster id)
    assert F[1, 3] == e(N) & F[1, 5] == e(N_clust) & F[1, 6] == 1
    * y0 has no exposed events: below minevents(1), never fitted
    assert F[3, 8] == -1 & F[4, 8] == -1 & missing(F[3, 3]) & missing(F[4, 5])
    * without clustering, N_clust is missing
    outtab y1, exposure(x)
    matrix F = r(fits)
    assert missing(F[1, 5]) & F[1, 3] == 400 & F[1, 4] == 400
}
if _rc == 0 {
    display as result "  PASS: OV4 r(fits) per-fit diagnostics equal the direct fits"
    local ++pass_count
}
else {
    display as error "  FAIL: OV4 r(fits) (rc=`=_rc')"
    local ++fail_count
}

local _tc = `pass_count' + `fail_count'
display "RESULT: test_outtab_v230_review tests=`_tc' pass=`pass_count' fail=`fail_count'"
log close _otr
if `fail_count' > 0 exit 1
