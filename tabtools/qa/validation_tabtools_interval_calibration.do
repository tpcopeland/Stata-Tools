* validation_tabtools_interval_calibration.do - known-truth recovery and
* interval calibration for the intervals tabtools computes itself
*
* Each block draws data from a known truth, runs the public command, and reads
* its interval from r() or its frame. Coverage is the share of K independent
* intervals that contain the truth.
*
* RC1 ratetab ci(exact): mean rate recovers the true rate; exact Poisson
*     limits cover at least the nominal level (they are conservative)
* RC2 ratetab ci(poisson): log-rate limits cover close to nominal
* RC3 ratetab ci(cluster()): clustered Poisson limits cover close to nominal
* RC4 stratetab rateratio: geometric-mean IRR recovers the true ratio; the
*     log-normal (Wald) interval covers close to nominal
* RC5 survtab rmst(): mean RMST recovers the exponential truth; its interval
*     covers close to nominal
* RC6 survtab difference: the survival-difference interval at t covers the
*     exponential truth close to nominal
* RC7 tabcell np, ci(exact): Clopper-Pearson limits cover at least nominal
* RC8 crosstab cochran: rejection rate under a true null is the nominal size
*
* Tolerances are fixed before the run from the Monte Carlo error of a share
* over K draws, se = sqrt(p(1 - p)/K): an exact interval must cover at least
* nominal - 3.5 se; an approximate one must lie within 3.5 se plus a 0.015
* allowance for its known small-sample bias. Seeds are fixed, so the run is
* reproducible. Truth comes from the data-generating process, never from the
* command under test. Run from tabtools/qa.

clear all
version 17.0
set more off
set varabbrev off
set linesize 255

capture log close _rcal
log using "validation_tabtools_interval_calibration.log", replace text name(_rcal)

local test_count = 0
local pass_count = 0
local failed ""

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear

tempfile scratch
global RCAL_DIR "`scratch'_d"
capture mkdir "$RCAL_DIR"

capture program drop _rcal_result
program define _rcal_result, rclass
    args rc label
    if `rc' == 0 display as result "  PASS: `label'"
    else display as error "  FAIL: `label' (rc=`rc')"
    return scalar pass = (`rc' == 0)
end

* _rcal_check NAME COVERED K EXACT: coverage of K intervals against 0.95
capture program drop _rcal_check
program define _rcal_check
    args name covered K exact
    local cov = `covered' / `K'
    local se = sqrt(0.95 * 0.05 / `K')
    display as text "  `name': coverage " %6.4f `cov' " over `K' intervals (MC se " %6.4f `se' ")"
    if `exact' assert `cov' >= 0.95 - 3.5 * `se'
    else assert abs(`cov' - 0.95) <= 3.5 * `se' + 0.015
end

**# RC1 / RC2: ratetab exact and log-rate limits over 1,500 levels
local ++test_count
capture noisily {
    clear
    set seed 20261012
    local K 1500
    local lambda 0.05
    quietly set obs `K'
    gen long lev = _n
    gen double Y = 60 + 80 * runiform()
    gen long D = rpoisson(`lambda' * Y)
    * recovery: the rate per level, averaged over levels, against lambda
    quietly ratetab lev, events(D) exposure(Y) per(1) ci(exact)
    matrix rcal_E = r(estimates)
    assert rowsof(rcal_E) == `K'
    mata: E = st_matrix("rcal_E"); st_numscalar("rcal_m", mean(E[., 6])); ///
        st_numscalar("rcal_s", sqrt(variance(E[., 6]) / rows(E))); ///
        st_numscalar("rcal_c", sum((E[., 7] :<= `lambda') :& (E[., 8] :>= `lambda')))
    display as text "  RC1 mean rate " %8.6f scalar(rcal_m) " (truth `lambda', MC se " %8.6f scalar(rcal_s) ")"
    assert abs(scalar(rcal_m) - `lambda') <= 3.5 * scalar(rcal_s)
    _rcal_check "RC1 ratetab exact" scalar(rcal_c) `K' 1
    quietly ratetab lev, events(D) exposure(Y) per(1) ci(poisson)
    matrix rcal_E = r(estimates)
    mata: E = st_matrix("rcal_E"); ///
        st_numscalar("rcal_c", sum((E[., 7] :<= `lambda') :& (E[., 8] :>= `lambda')))
    _rcal_check "RC2 ratetab poisson" scalar(rcal_c) `K' 0
}
_rcal_result `=_rc' "RC1/RC2 ratetab exact and log-rate intervals recover and cover the true rate"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' RC1/RC2"

**# RC3: ratetab clustered limits, 200 replicates x 2 levels
local ++test_count
capture noisily {
    set seed 3101
    local R 200
    local covered 0
    local lambda 0.04
    forvalues r = 1/`R' {
        clear
        quietly set obs 120
        gen long cl = _n
        gen byte g = mod(_n, 2)
        quietly expand 5
        gen double Y = 20 + 40 * runiform()
        gen long D = rpoisson(`lambda' * Y)
        quietly ratetab g, events(D) exposure(Y) per(1) ci(cluster(cl))
        matrix rcal_E = r(estimates)
        forvalues i = 1/2 {
            local covered = `covered' + (rcal_E[`i', 7] <= `lambda' & rcal_E[`i', 8] >= `lambda')
        }
    }
    _rcal_check "RC3 ratetab cluster" `covered' `=2 * `R'' 0
}
_rcal_result `=_rc' "RC3 ratetab clustered intervals cover the true rate"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' RC3"

**# RC4: stratetab rateratio, 1,000 matched categories in one call
local ++test_count
capture noisily {
    set seed 4404
    local K 1000
    local theta 1.5
    forvalues f = 1/2 {
        clear
        quietly set obs `K'
        gen long cat = _n
        forvalues k = 1/`K' {
            label define rcal_c `k' "c`k'", add
        }
        label values cat rcal_c
        gen double _Y = 400 + 200 * runiform()
        gen double _D = rpoisson(0.05 * cond(`f' == 2, `theta', 1) * _Y)
        gen double _Rate = _D / _Y
        gen double _Lower = _Rate * .8
        gen double _Upper = _Rate * 1.2
        label variable _Lower "Lower 95% confidence limit"
        label variable _Upper "Upper 95% confidence limit"
        quietly save "$RCAL_DIR/irr`f'.dta", replace
        label drop rcal_c
    }
    quietly stratetab, using("$RCAL_DIR/irr1" "$RCAL_DIR/irr2") outcomes(1) ///
        rateratio ratiodigits(8) frame(rcal_s, replace)
    frame rcal_s {
        quietly keep if ustrregexm(c5, "^[0-9.]+ \(")
        assert _N == `K'
        gen double irr = real(ustrregexs(1)) if ustrregexm(c5, "^([0-9.]+) \(")
        gen double lb = real(ustrregexs(1)) if ustrregexm(c5, "\(([0-9.]+), ")
        gen double ub = real(ustrregexs(1)) if ustrregexm(c5, ", ([0-9.]+)\)$")
        assert !missing(irr, lb, ub)
        gen double lnirr = ln(irr)
        quietly summarize lnirr
        local gm = exp(r(mean))
        local gse = r(sd) / sqrt(r(N))
        display as text "  RC4 geometric-mean IRR " %8.5f `gm' " (truth `theta')"
        * 0.01 allows the small-count bias of ln(D1/D0), about
        * 1/(2 mu0) - 1/(2 mu1) = 0.007 at these expected counts
        assert abs(ln(`gm') - ln(`theta')) <= 3.5 * `gse' + 0.01
        quietly count if lb <= `theta' & ub >= `theta'
        local covered = r(N)
    }
    _rcal_check "RC4 stratetab IRR" `covered' `K' 0
}
_rcal_result `=_rc' "RC4 stratetab rate-ratio interval recovers and covers the true IRR"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' RC4"

**# RC5 / RC6: survtab RMST and survival difference, 400 replicates
local ++test_count
capture noisily {
    set seed 5505
    local R 400
    local l1 0.10
    local l2 0.15
    local tau 10
    local tt 5
    * truth: exponential RMST to tau, and S1(tt) - S2(tt) in percent
    local rmst_true = (1 - exp(-`l1' * `tau')) / `l1'
    local diff_true = 100 * (exp(-`l1' * `tt') - exp(-`l2' * `tt'))
    local cov_r 0
    local cov_d 0
    local sum_r 0
    local ss_r 0
    forvalues r = 1/`R' {
        clear
        quietly set obs 300
        gen byte grp = 1 + (_n > 150)
        gen double t = -ln(runiform()) / cond(grp == 1, `l1', `l2')
        gen double c = 30 * runiform()
        gen byte d = t <= c
        quietly replace t = min(t, c)
        quietly stset t, failure(d)
        preserve
        quietly keep if grp == 1
        quietly survtab, times(`tt') rmst(`tau')
        local cov_r = `cov_r' + (r(rmst_lb_1) <= `rmst_true' & r(rmst_ub_1) >= `rmst_true')
        local sum_r = `sum_r' + r(rmst_1)
        local ss_r = `ss_r' + r(rmst_1)^2
        restore
        quietly survtab, times(`tt') by(grp) difference digits(6) frame(rcal_v, replace)
        frame rcal_v {
            * the column headed "Difference (1 - 2)"
            local lastc ""
            foreach v of varlist c* {
                if strpos(`v'[2], "Difference") == 1 local lastc `v'
            }
            assert "`lastc'" != ""
            quietly gen double lb = real(ustrregexs(1)) if ustrregexm(`lastc', "\((-?[0-9.]+), ")
            quietly gen double ub = real(ustrregexs(1)) if ustrregexm(`lastc', ", (-?[0-9.]+)\)")
            quietly count if !missing(lb, ub)
            assert r(N) == 1
            quietly summarize lb, meanonly
            local dlb = r(min)
            quietly summarize ub, meanonly
            local dub = r(min)
        }
        local cov_d = `cov_d' + (`dlb' <= `diff_true' & `dub' >= `diff_true')
    }
    local m = `sum_r' / `R'
    local s = sqrt((`ss_r' / `R' - `m'^2) / `R')
    display as text "  RC5 mean RMST " %8.5f `m' " (truth " %8.5f `rmst_true' ", MC se " %7.5f `s' ")"
    assert abs(`m' - `rmst_true') <= 3.5 * `s'
    _rcal_check "RC5 survtab RMST" `cov_r' `R' 0
    _rcal_check "RC6 survtab difference" `cov_d' `R' 0
}
_rcal_result `=_rc' "RC5/RC6 survtab RMST and survival-difference intervals recover and cover the truth"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' RC5/RC6"

**# RC7: tabcell np, ci(exact), 2,000 binomial draws
local ++test_count
capture noisily {
    set seed 7707
    local K 2000
    local p 0.2
    local covered 0
    forvalues k = 1/`K' {
        local n = rbinomial(30, `p')
        quietly tabcell np, n(`n') d(30) ci(exact)
        local covered = `covered' + (r(lb) <= 100 * `p' & r(ub) >= 100 * `p')
    }
    _rcal_check "RC7 tabcell exact binomial" `covered' `K' 1
}
_rcal_result `=_rc' "RC7 tabcell exact binomial limits cover at least nominal"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' RC7"

**# RC8: crosstab cochran, size under the null over 600 tables
local ++test_count
capture noisily {
    set seed 8808
    local R 600
    local rej 0
    forvalues r = 1/`R' {
        clear
        quietly set obs 200
        gen byte x = 1 + floor(4 * runiform())
        gen byte y = runiform() < 0.3
        quietly crosstab y x, cochran
        assert !missing(r(p_trend))
        local rej = `rej' + (r(p_trend) < 0.05)
    }
    local size = `rej' / `R'
    local se = sqrt(0.05 * 0.95 / `R')
    display as text "  RC8 crosstab cochran size " %6.4f `size' " over `R' null tables (MC se " %6.4f `se' ")"
    assert abs(`size' - 0.05) <= 3.5 * `se'
}
_rcal_result `=_rc' "RC8 crosstab Cochran-Armitage test holds its size under the null"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' RC8"

**# Summary
capture shell rm -rf "$RCAL_DIR"
capture frame drop rcal_s
capture frame drop rcal_v
capture matrix drop rcal_E
capture scalar drop rcal_m rcal_s rcal_c
capture mata: mata drop E
capture macro drop RCAL_DIR
local fail_count = `test_count' - `pass_count'
if `fail_count' display as error "failed:`failed'"
display as text "RESULT: validation_tabtools_interval_calibration tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _rcal
if `fail_count' > 0 exit 1
exit 0
