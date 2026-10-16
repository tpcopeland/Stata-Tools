clear all
set more off
version 16.0
set varabbrev off

* crossval_iivw_published_coulombe-2021-biometrics.do
*
* PUBLISHED REPRODUCTION: Coulombe J, Moodie EEM, Platt RW. Weighted regression
* analysis to correct for informative monitoring times and confounders in
* longitudinal studies. Biometrics 2021;77(1):162-174. Held copy: the accepted
* manuscript as Chapter 3 of the author's McGill PhD thesis
* (coulombe-2021-thesis.pdf). Index row: _literature/iivw/index.md, key
* coulombe-2021-biometrics.
*
* What is reproduced and credited: Table 3.1 of the thesis chapter (PDF p.89),
* the simulation study of section 3.3 (PDF pp.86-88): n = 250, tau = 2,
* alpha(t) = 3, 1,000 simulated data sets, true marginal treatment effect 1. The
* table reports the absolute bias and the empirical variance of five estimators
* for three monitoring-dependence settings (gamma1, gamma2). This suite asserts
* only the two columns whose estimator iivw implements on a visit-row input, in
* all three settings:
*   OLS   iivw_fit, unweighted       (|bias| 0.72, 1.05, 1.98; variance .41, .19, .12)
*   IPT   iivw_weight, wtype(iptw)   (|bias| 0.06, 1.77, 2.65; variance 1.06, .40, .30)
* IPT is the evidence that the IPTW route reproduces a published simulation under
* informative monitoring. This suite is credited for the unweighted-GEE and IPTW
* routes only.
*
* DOCUMENTED NON-REPRODUCTION (VW and FIPTM columns; not asserted, not a pass).
* The paper's VW (monitoring-weighted) and FIPTM (FIPTIW) estimators fit an
* intensity model to Z(t), drawn afresh at every 0.01 step. iivw_weight's input is
* one row per visit, so Z(t) at the other subjects' risk times, which the
* Andersen-Gill risk set needs, is not in the data. Consequences, measured in
* probe_iivw_coulombe_fiptiw.do (same DGP; probe, not a gate):
*   informative settings: iivw |bias| VW 1.14 / 2.02, FIPTM 1.84 / 2.75 (probe P1,
*     60 data sets) against published VW 0.72 / 0.76 and FIPTM 0.04 / 0.00; the
*     same DGP with the true intensity weights returns VW 0.68 / 0.73 and FIPTM
*     0.04 / 0.01 (probe P2, 150 data sets), so the DGP is right and the input
*     format is the cause.
*   setting (0,0): |bias| matches (iivw VW 0.70, FIPTM 0.07; published 0.71 and
*     0.09) but is uninformative, since the published VW is about OLS (0.72) and
*     the published FIPTM about IPT (0.06): the weights are near-null there, so
*     those rows do not distinguish weighting from no weighting.
*   variance at (0,0): iivw VW 0.48 and FIPTM 0.89 (R = 1000, first run of this
*     suite) against published 0.30 and 0.77, outside the variance band. True
*     weights cannot explain it (at (0,0) they equal the OLS weights, variance
*     0.40-0.44), and the paper's estimator on the full 0.01 grid, run outside
*     iivw, gave 0.420 against OLS 0.382 (probe P4, 400 data sets), so the
*     published 0.30 is reproduced neither by iivw nor by the estimator as defined. Cause unresolved;
*     not attributed to iivw.
* The FIPTIW and IIW routes are therefore NOT credited by this suite.
*
* DGP (thesis section 3.3, PDF pp.86-87), simulated on the 0.01 grid:
*   K1 ~ N(1,1)  K2 ~ Bernoulli(0.55)  K3 ~ N(0,1)
*   I ~ Bernoulli(expit(0.5 + 0.8 K1 + 0.05 K2 - K3))
*   Z(t) | I=1 ~ N(2, 1),  Z(t) | I=0 ~ N(4, var 4)  (independent at each step)
*   Y(t) = 3 + I + 3 (Z(t) - E[Z|I]) + 0.4 K1 + 0.05 K2 - 0.6 K3 + eps(t),
*   eps ~ N(phi, var 0.01), phi ~ N(0, var 0.04)
*   monitoring: Bernoulli draws on the grid with probability
*   eta exp(gamma1 I + gamma2 Z(t)) * 0.01, eta ~ Gamma(mean 1, var 0.01);
*   the baseline rate (1 per unit time) is NOT stated in the thesis. It was TUNED
*   to the published visit counts (median 1 (IQR 1-2), 2 (1-3), 5 (4-7) in
*   Table 3.1; mean visits per subject 1.50, 2.18, 5.36), so T1 is a calibration
*   check of the DGP, not independent evidence. T1 asserts that the mean visits
*   per subject lie inside the published inter-quartile range.
*   C ~ U(tau/2, tau), tau = 2
* Zero-visit subjects stay in the risk set through a t = 0 carrier row
* (y = ., baseline(entry)).
*
* Estimators as published: OLS and IPT use a constant intercept and I only
* (timespec(none)); IPT weights use K1-K3 in the propensity model. The paper's
* weights are non-stabilized and iivw's are stabilized; for a model that is
* saturated in I a numerator that depends only on I rescales each arm and leaves
* the point estimate unchanged.
*
* Oracle: Table 3.1, a published simulation result. Tolerance, computed in the
* suite per cell:
*   absolute bias: | |mean(beta-hat) - 1| - bias_pub | <= 0.005 + 3 sqrt(MCSE_ours^2 + MCSE_pub^2)
*     MCSE_ours = SD/sqrt(R); MCSE_pub = sqrt(var_pub/1000) (0.005 is half a unit of
*     the published two decimals)
*   empirical variance: relative gap <= 0.005/var_pub + 3 sqrt((kurt-1)/R + (kurt-1)/1000)
*     (the standard error of a sample variance, kurt = our sample kurtosis)
* Monte Carlo size R = 1000 data sets per setting; seeds 71001, 71002, 71003.
* The first full run also fitted VW and FIPTM at (0,0) (seed stream as above); that
* code now lives only in the probe.
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do crossval_iivw_published_coulombe-2021-biometrics.do [n]

args run_only
do "`c(pwd)'/_iivw_qa_common.do"
iivw_qa_selector "`run_only'"
local run_only = `r(run_only)'

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "crossval_iivw_published_coulombe-2021-biometrics.do must be run from iivw/qa"
    exit 198
}
iivw_qa_bootstrap
display as text "REFERENCE: Coulombe J, Moodie EEM, Platt RW. Biometrics 2021;77(1):162-174, thesis chapter 3 (coulombe-2021-thesis.pdf), Table 3.1 PDF p.89"

local MCSE_K = 3
local R_PUB = 1000
local R = 1000
local N = 250

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _gen_cb
program define _gen_cb
    version 16.0
    syntax , N(integer) G1(real) G2(real)
    clear
    set obs `n'
    gen long id = _n
    gen double K1 = rnormal(1, 1)
    gen byte K2 = runiform() < 0.55
    gen double K3 = rnormal(0, 1)
    gen byte A = runiform() < invlogit(0.5 + 0.8 * K1 + 0.05 * K2 - K3)
    gen double phi = rnormal(0, 0.2)
    gen double eta = rgamma(100, 0.01)
    gen double C = runiform(1, 2)
    tempfile base
    quietly save `base'
    quietly expand 200
    bysort id: gen int k = _n
    quietly drop if k > 100 * C
    gen double t = k / 100
    gen double Z = cond(A == 1, rnormal(2, 1), rnormal(4, 2))
    gen double EZ = cond(A == 1, 2, 4)
    gen byte vis = runiform() < eta * exp(`g1' * A + `g2' * Z) * 0.01
    quietly keep if vis
    gen double y = 3 + A + 3 * (Z - EZ) + 0.4 * K1 + 0.05 * K2 - 0.6 * K3 + rnormal(phi, 0.1)
    gen byte entry = 0
    drop k vis
    tempfile visits
    quietly save `visits'
    quietly use `base', clear
    gen double t = 0
    gen double y = .
    gen byte entry = 1
    quietly append using `visits'
    sort id t
end

* one data set -> beta_A under OLS / IPT, + visit count
capture program drop _fit_cb
program define _fit_cb, rclass
    foreach c in ols ipt {
        return scalar b_`c' = .
    }
    quietly count if entry == 0
    return scalar nvis = r(N)
    capture quietly iivw_fit y A, unweighted id(id) time(t) ///
        timespec(none) nolog
    if _rc == 0 return scalar b_ols = _b[A]
    capture quietly {
        iivw_weight, id(id) time(t) treat(A) treat_cov(K1 K2 K3) wtype(iptw) ///
            nolog replace
        iivw_fit y A, timespec(none) vce(fixed) nolog replace
    }
    if _rc == 0 return scalar b_ipt = _b[A]
end

* published oracle: |bias| and empirical variance, Table 3.1 (n = 250, alpha(t) = 3)
tempfile pub
clear
input byte set str4 est double(abs_bias var_pub)
1 ols .72 .41
1 ipt .06 1.06
2 ols 1.05 .19
2 ipt 1.77 .40
3 ols 1.98 .12
3 ipt 2.65 .30
end
save "`pub'"

* settings: 1 = (0,0), 2 = (-0.3,0.2), 3 = (0.6,0.3)
tempfile mcres
capture postclose _pf
postfile _pf byte set int rep double(nvis ols ipt) using "`mcres'", replace
local si = 0
foreach gs in "0 0" "-0.3 0.2" "0.6 0.3" {
    local ++si
    local g1 : word 1 of `gs'
    local g2 : word 2 of `gs'
    set seed `=71000 + `si''
    forvalues r = 1/`R' {
        _gen_cb, n(`N') g1(`g1') g2(`g2')
        _fit_cb
        post _pf (`si') (`r') (r(nvis)) (r(b_ols)) (r(b_ipt))
    }
    display as text "    setting `si' (gamma1=`g1', gamma2=`g2'): `R' data sets done"
}
postclose _pf

* per (set, estimator): our |bias|, variance, kurtosis, MCSEs and verdicts
use "`mcres'", clear
rename (ols ipt) (v1 v2)
reshape long v, i(set rep) j(c)
gen str4 est = cond(c == 1, "ols", "ipt")
gen double err = v - 1
bysort set est: egen double m_err = mean(err)
bysort set est: egen double s_err = sd(err)
gen double z4 = ((err - m_err) / s_err)^4
collapse (mean) bias=err kurt=z4 (sd) sd=err (count) nok=v, by(set est)
gen double abs_ours = abs(bias)
merge 1:1 set est using "`pub'", keep(match) nogenerate
gen double mcse = sd / sqrt(nok)
gen double mcse_pub = sqrt(var_pub / `R_PUB')
gen double tol_b = 0.005 + `MCSE_K' * sqrt(mcse^2 + mcse_pub^2)
gen double dev_b = abs_ours - abs_bias
gen byte ok_b = abs(dev_b) <= tol_b
gen double var_ours = sd^2
gen double rel_var = var_ours / var_pub - 1
gen double tol_v = 0.005 / var_pub + `MCSE_K' * sqrt((kurt - 1) / nok + (kurt - 1) / `R_PUB')
gen byte ok_v = abs(rel_var) <= tol_v
tempfile cells
save "`cells'"
display as text "Cell table: |bias| and variance, ours vs published (Table 3.1)"
list set est abs_ours abs_bias tol_b ok_b var_ours var_pub rel_var tol_v ok_v, ///
    noobs sepby(set) abbreviate(10)

* T1 - the DGP reproduces the published monitoring intensity (visit counts)
local ++test_count
if `run_only' == 0 | `run_only' == 1 {
    capture noisily {
        use "`mcres'", clear
        * per-subject visit count in each setting: nvis is the data-set total
        gen double per = nvis / `N'
        collapse (mean) per, by(set)
        list set per, noobs
        * published medians per subject (Table 3.1): 1, 2, 5; means must sit in
        * the published inter-quartile ranges (1-2, 1-3, 4-7)
        assert per[1] >= 1 & per[1] <= 2
        assert per[2] >= 1 & per[2] <= 3
        assert per[3] >= 4 & per[3] <= 7
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: T1 simulated visit counts fall inside the published inter-quartile ranges"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' T1"
        display as error "FAIL: T1 visit counts (error `=_rc')"
    }
}

* T2 - every planned fit succeeded
local ++test_count
if `run_only' == 0 | `run_only' == 2 {
    capture noisily {
        use "`cells'", clear
        assert nok == `R'
        assert !missing(mcse, tol_b, tol_v, kurt)
        quietly count
        assert r(N) == 6
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: T2 all planned fits succeeded (6 set-estimator cells, none dropped)"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' T2"
        display as error "FAIL: T2 completeness (error `=_rc')"
    }
}

* T3 - OLS: published bias and variance, all three settings
local ++test_count
if `run_only' == 0 | `run_only' == 3 {
    capture noisily {
        use "`cells'", clear
        keep if est == "ols"
        quietly count
        assert r(N) == 3
        assert ok_b == 1
        assert ok_v == 1
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: T3 unweighted GEE matches Table 3.1 OLS (|bias| 0.72, 1.05, 1.98; variances)"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' T3"
        display as error "FAIL: T3 OLS vs published (error `=_rc')"
    }
}

* T4 - IPT: published bias and variance, all three settings
local ++test_count
if `run_only' == 0 | `run_only' == 4 {
    capture noisily {
        use "`cells'", clear
        keep if est == "ipt"
        quietly count
        assert r(N) == 3
        assert ok_b == 1
        assert ok_v == 1
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: T4 IPTW matches Table 3.1 IPT (|bias| 0.06, 1.77, 2.65; variances)"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' T4"
        display as error "FAIL: T4 IPT vs published (error `=_rc')"
    }
}

* T5 - negative control: the OLS estimate is not the published IPT bias at (0.6, 0.3)
*      (the bands must separate a confounded estimator from a corrected one)
local ++test_count
if `run_only' == 0 | `run_only' == 5 {
    capture noisily {
        use "`cells'", clear
        keep if set == 3
        sort est
        local ols_abs = abs_ours[2]
        local ipt_pub = abs_bias[1]
        local tol = tol_b[2]
        display as text "    |bias OLS| = " %7.4f `ols_abs' "  published IPT 2.65 (OLS published 1.98); band " %6.4f `tol'
        assert est[2] == "ols" & est[1] == "ipt"
        assert abs(`ols_abs' - `ipt_pub') > `tol'
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: T5 the bias band separates OLS from the published IPT value at (0.6, 0.3)"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' T5"
        display as error "FAIL: T5 negative control did not separate (error `=_rc')"
    }
}

set linesize 255
iivw_qa_summary, name(crossval_iivw_published_coulombe-2021-biometrics) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') runonly(`run_only') failedtests("`failed_tests'")

clear
