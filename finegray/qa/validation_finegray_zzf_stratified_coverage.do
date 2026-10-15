* validation_finegray_zzf_stratified_coverage.do
* ---------------------------------------------------------------------------
* Coverage of 95% intervals for the stratified delayed-entry weight
* (Zhang, Zhang and Fine 2011, equation 6), fitted with the same factor named
* in strata() and truncstrata().
*
* Data are generated as in validation_finegray_zzf_factorization.do: the event
* process of Zhang, Zhang and Fine section 4.1 (true log-SHRs 0.5 for binary x1
* and -0.5 for normal x2), and a discrete factor W, correlated with x1, that
* raises both the censoring hazard and the entry time. The correctly specified
* fit is therefore strata(W) truncstrata(W). Follow-up ends at time 3 (6 in
* that file), which leaves the true coefficients unchanged. With follow-up to 6,
* about 5% of samples had a late time in some stratum when no one was under
* observation, and finegray stops with r(459) at such a gap.
*
* Four designs, 1,000 replications each (entry multiplier: 0.5 moderate, 1 heavy):
*   K2_n500     W with 2 levels, n = 500,   moderate entry
*   K2_n2000    W with 2 levels, n = 2,000, moderate entry
*   K4_n2000    W with 4 levels, n = 2,000, moderate entry
*   K2_heavy    W with 2 levels, n = 2,000, heavy entry
*
* For each fit, the default fixed-weight sandwich interval and the model-based
* (norobust) interval are recorded. A few samples still contain such a gap, and
* finegray stops with r(459) rather than fit them; these are counted and
* excluded. A design passes when every other replication gives a converged fit
* and sandwich coverage for both coefficients lies in 0.925 to 0.975, the band
* used in validation_finegray_zzf_coverage.do.
* Model-based coverage and SE/SD are reported, not tested.
*
* Run from the finegray/qa directory. Smaller settings for a quick check:
*   global ZZF_SC_REPS 50
* ===========================================================================

clear all
set varabbrev off
set linesize 120
version 16.0

capture log close _all
log using "validation_finegray_zzf_stratified_coverage.log", replace name(_zzfsc)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture confirm file "`pkg_dir'/finegray.pkg"
if _rc {
    display as error "run this from the finegray/qa directory"
    exit 601
}
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace
which finegray

local REPS = 1000
if "$ZZF_SC_REPS" != "" local REPS = $ZZF_SC_REPS
local SEED0 = 20261015
local TRUTH1 =  0.5
local TRUTH2 = -0.5
local LO = 0.925
local HI = 0.975
local z  = invnormal(0.975)

display as text _newline "Coverage of the stratified delayed-entry weight"
display as text "  replications per design = `REPS', base seed = `SEED0'"
display as text "  truth: b1 = `TRUTH1' (x1), b2 = `TRUTH2' (x2)"
if `REPS' < 1000 display as error "  REDUCED SETTINGS: not the reported run"

* Data generation: _zzffac_gen of validation_finegray_zzf_factorization.do
* with depend(on), plus tend().
capture program drop _zzfsc_gen
program define _zzfsc_gen, rclass
    syntax , n(integer) seed(integer) [klevels(integer 2) entrymul(real 1.0) ///
        over(integer 10) tend(real 6) cwslope(real 1.5) lwslope(real 1.3)]

    clear
    set seed `seed'
    quietly set obs `=`n' * `over''

    gen byte   x1 = runiform() < 0.5
    gen double x2 = rnormal()
    gen double ez = exp(0.5 * x1 - 0.5 * x2)
    gen double p1 = 1 - (1 - 0.5)^ez
    gen byte   cause = cond(runiform() < p1, 1, 2)
    gen double v     = runiform()
    gen double tev = -ln(1 - (1 - (1 - v * p1)^(1 / ez)) / 0.5) if cause == 1
    replace    tev = rexponential(1 / (0.5 * exp(0.5 * x1 + 0.5 * x2))) if cause == 2

    gen double s = 1.4 * x1 + rnormal()
    gen byte W = 0
    forvalues j = 1/`=`klevels'-1' {
        quietly replace W = W + (s > invnormal(`j' / `klevels'))
    }
    gen double wfac = W / `=`klevels'-1'

    gen double cens = min(rexponential(1 / (0.15 * exp(`cwslope' * wfac))), `tend')
    gen double t0   = rexponential(`entrymul' * 0.9 * exp(`lwslope' * wfac))

    gen double t      = min(tev, cens)
    gen byte   status = cond(tev <= cens, cause, 0)
    gen byte   anyev  = status > 0

    quietly count
    local pre = r(N)
    quietly drop if !(t0 < t)
    quietly count
    return scalar truncfrac = 1 - r(N) / `pre'
    if r(N) < `n' {
        display as error "oversample exhausted: only `r(N)' of `n' survived truncation"
        exit 498
    }
    quietly keep in 1/`n'
    gen long id = _n
end

tempname pf
tempfile mc
postfile `pf' str9 design int rep int rc double(trunc maxw b1 b2 se1 se2 mb1 mb2) ///
    using "`mc'", replace

local designs K2_n500 K2_n2000 K4_n2000 K2_heavy
*                 n     K  entry
local p_K2_n500   500   2  0.5
local p_K2_n2000  2000  2  0.5
local p_K4_n2000  2000  4  0.5
local p_K2_heavy  2000  2  1
local TEND = 3

local d = 0
foreach des of local designs {
    local ++d
    tokenize `p_`des''
    local n_d `1'
    local k_d `2'
    local e_d `3'
    display as text _newline "design `des': n = `n_d', K = `k_d', entry multiplier = `e_d', end = `TEND'"
    forvalues r = 1/`REPS' {
        local s = `SEED0' + 100000 * `d' + `r'
        capture _zzfsc_gen, n(`n_d') seed(`s') klevels(`k_d') entrymul(`e_d') tend(`TEND')
        if _rc {
            post `pf' ("`des'") (`r') (-1) (.) (.) (.) (.) (.) (.) (.) (.)
            continue
        }
        local tf = r(truncfrac)
        quietly stset t, failure(anyev == 1) id(id) enter(time t0)

        capture quietly finegray x1 x2, compete(status) cause(1) strata(W) truncstrata(W)
        local rc = _rc
        if !`rc' & e(converged) != 1 local rc = 430
        if `rc' {
            post `pf' ("`des'") (`r') (`rc') (`tf') (.) (.) (.) (.) (.) (.) (.)
            continue
        }
        local b1  = _b[x1]
        local b2  = _b[x2]
        local se1 = _se[x1]
        local se2 = _se[x2]
        local mw  = e(max_lt_weight)

        capture quietly finegray x1 x2, compete(status) cause(1) strata(W) truncstrata(W) norobust
        local rc = _rc
        if !`rc' & e(converged) != 1 local rc = 430
        if `rc' {
            display as error "  replication `r': norobust refit failed, rc = `rc'"
            local mb1 = .
            local mb2 = .
        }
        else {
            local mb1 = _se[x1]
            local mb2 = _se[x2]
        }
        post `pf' ("`des'") (`r') (0) (`tf') (`mw') (`b1') (`b2') (`se1') (`se2') (`mb1') (`mb2')
        if mod(`r', 100) == 0 display as text "  `r' replications"
    }
}
postclose `pf'

use "`mc'", clear
gen byte ok = !missing(b1, b2, se1, se2, mb1, mb2)
forvalues k = 1/2 {
    gen byte cov`k'  = abs(b`k' - `TRUTH`k'') <= `z' * se`k'  if ok
    gen byte mcov`k' = abs(b`k' - `TRUTH`k'') <= `z' * mb`k' if ok
}

local fails = 0
display as text _newline "{hline 112}"
display as text "Design      r(459)  usable  trunc%  med max w   bias b1   bias b2   sandwich cov   model-based cov   sandwich SE/SD"
display as text "{hline 112}"
foreach des of local designs {
    quietly count if design == "`des'" & ok
    local nok = r(N)
    quietly count if design == "`des'" & rc == 459
    local ngap = r(N)
    quietly summarize trunc if design == "`des'"
    local tp = 100 * r(mean)
    quietly summarize maxw if design == "`des'" & ok, detail
    local mw = r(p50)
    forvalues k = 1/2 {
        quietly summarize b`k' if design == "`des'" & ok
        local bias`k' = r(mean) - `TRUTH`k''
        local sd`k'   = r(sd)
        quietly summarize se`k' if design == "`des'" & ok
        local ratio`k' = r(mean) / `sd`k''
        quietly summarize cov`k' if design == "`des'" & ok
        local c`k' = r(mean)
        quietly summarize mcov`k' if design == "`des'" & ok
        local m`k' = r(mean)
    }
    display as result %-10s "`des'" %8.0f `ngap' %8.0f `nok' %8.1f `tp' %11.2f `mw' ///
        %10.4f `bias1' %10.4f `bias2' "    " %5.3f `c1' " / " %5.3f `c2' ///
        "    " %5.3f `m1' " / " %5.3f `m2' "      " %4.2f `ratio1' " / " %4.2f `ratio2'
    local pass = (`nok' + `ngap' == `REPS' & inrange(`c1', `LO', `HI') & inrange(`c2', `LO', `HI'))
    if !`pass' local ++fails
}
display as text "{hline 112}"
display as text "r(459): samples with an observation gap, which finegray declines to fit."
display as text "Bias is the mean estimate minus the truth; cov = coverage of b1 / b2."
tab design rc

if `fails' {
    display as error _newline "FAIL: `fails' design(s) outside `LO'-`HI' or with failures other than r(459)"
    log close _zzfsc
    exit 9
}
display as result _newline "PASS: sandwich coverage within `LO'-`HI' in every design; every unusable sample was an r(459) gap"
log close _zzfsc
