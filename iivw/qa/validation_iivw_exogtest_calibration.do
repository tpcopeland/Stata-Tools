clear all
version 16.0
set more off
set varabbrev off
* the RESULT: line is longer than 80 characters; a wrapped line would hide smoke=
set linesize 255

* validation_iivw_exogtest_calibration.do
*
* Inference calibration for iivw_exogtest: the cluster-robust Wald p-values,
* the confidence interval on the lagged-outcome hazard ratio, and the
* Holm-adjusted family-wise test that drives r(history_association_flag).
*
* Aims      Does iivw_exogtest hold its nominal size, coverage and family-wise
*           error, and does it have power at a planted alternative?
* Data      _iivw_exogtest_dgp.do: G = 4 disjoint arms of N = 300 subjects, first
*           visit at 0, exponential gaps with rate exp(gamma_g * y_lag), common
*           end of follow-up 5, y = u_i + e_ij (variance 0.98). The AG partial
*           likelihood is the true model, so exp(gamma_g) is the true hazard
*           ratio per unit of lagged outcome in arm g.
*           NULL     gamma = (0, 0, 0, 0)
*           ALT      gamma = (.06, .06, .06, .06)   planted alternative (power)
*           PARTIAL  gamma = (.30, 0, 0, 0)         strong-control cell
* Estimand  per arm: the log hazard ratio gamma_g (r(results) b), its HR and
*           Wald CI (hr lb ub, level 95), the raw joint p (p), and the family
*           Holm-adjusted across arms (r(holm_min_p), r(history_association_flag)).
* Methods   iivw_exogtest y, id() time() maxfu(5) by(grp) nolog, one lag, so the
*           joint omnibus test of an arm is that arm's single Wald test.
*           Negative control: the UNADJUSTED family rule (min raw joint p < alpha)
*           must be shown out of band (its FWER is 1-(1-alpha)^4 = 0.185).
* Oracles   the DGP (truth gamma, HR, which nulls are true); closed-form target
*           for the Holm FWER under four independent arms,
*           1 - (1 - alpha/4)^4 = 0.0491; R stats::p.adjust(method = "holm") on the
*           identical raw p-values (parity block H, deterministic, tolerance 1e-10
*           relative: both sides are the same closed-form step-down in double
*           precision, but iivw_exogtest returns holm_min_p and joint_min_p
*           through a local macro, which keeps about 12 significant digits;
*           the measured gap is 9.9e-12. P-values reach R through CSV at 17 digits).
* Gates     computed from R below, never typed. MCSE per Morris, White &
*           Crowther 2019 Table 6. Nominal +/- 3 MCSE:
*             N2 raw per-test size   in 0.05 +/- 3*sqrt(.05*.95/(4R))
*             N3 Holm FWER (flag)    in 0.0491 +/- 3*sqrt(t0*(1-t0)/R)
*             N4 negative control    unadjusted FWER > alpha + 3*MCSE (must be red)
*             N5 CI coverage (null)  in 0.95 +/- 3*sqrt(.95*.05/(4R))
*             N6 SE ratio            |sqrt(mean se^2)/EmpSE - 1| <= 3*MCSE(ratio)
*             A2 CI coverage (ALT)   as N5;  A3 SE ratio as N6
*             A4 power: flag power >= POWER_FLOOR (preregistered 0.80) and exceeds
*                null size by > 3 MCSE; per-test raw power is reported beside it
*             P2 strong control: P(Holm rejects a TRUE null arm) <= alpha + 3 MCSE
*                (rate computed with the Holm routine proven equal to R in H2)
*             H1 package holm_min_p == R min(p.adjust(p, "holm")) on every run
*             H2 Stata step-down used in P2 == R p.adjust on every arm
*             C1 every replicate returns four fitted arms with finite b se p lb ub
* R         1000 per DGP at the gate; smoke form 10 (band never applied; banded
*           tests count as skipped, smoke=1 on the RESULT line). Parity block H:
*           1000 NULL + 1000 PARTIAL vectors at m = 4 plus 20 runs at each of
*           m = 2, 3, 5, 6 (smoke: 2 per m).
* Seed      set seed 20261016 once; each replicate's starting c(rngstate) is kept.
* Expected class per cell: NOMINAL (Wald on 300 clusters per arm; Holm exact under
*           independent arms), except N4 where the unadjusted rule is the control.
*
* Usage:  cd iivw/qa
*   stata-mp -b do validation_iivw_exogtest_calibration.do          gate (sensitivity lane)
*   stata-mp -b do validation_iivw_exogtest_calibration.do smoke    code path only
*
* WORKED RUN (first full-R run, seed 20261016, R=1000; gates were computed from R and
* not changed afterwards except H1b's tolerance, 1e-12 -> 1e-10, after the measured
* macro round-trip gap of 9.9e-12): per-test size 0.0500, Holm FWER 0.0440 (target
* 0.0491), unadjusted FWER 0.1820 (theory 0.1855), CI coverage null 0.9500 / alt
* 0.9515, SE ratio 1.0135 / 1.0078 (MCSE 0.0112), bias at gamma=.06 -0.0003, flag
* power 0.878, per-test power 0.624, P(Holm rejects a true null | partial) 0.0540
* (limit 0.0500 + 3*0.0069 = 0.0707), arm-1 rejection 1.0000.

args mode
local smoke = ("`mode'" == "smoke")
if "`mode'" != "" & !`smoke' {
    display as error "unknown argument `mode'; the only accepted argument is smoke"
    exit 198
}

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "validation_iivw_exogtest_calibration.do must be run from iivw/qa"
    exit 198
}
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap
do "`qa_dir'/_iivw_exogtest_dgp.do"

local R_GATE  = 1000
local SMOKE_R = 10
local R       = cond(`smoke', `SMOKE_R', `R_GATE')
local NPAR    = cond(`smoke', 2, 20)
local SEED    = 20261016
local ALPHA   = 0.05
local G       = 4
local NSUB    = 300
local GALT    = 0.06
local GPART   = 0.30
local POWER_FLOOR = 0.80

local t0 = 1 - (1 - `ALPHA' / `G')^`G'
local mc_test  = sqrt(`ALPHA' * (1 - `ALPHA') / (`G' * `R'))
local mc_fwer  = sqrt(`t0' * (1 - `t0') / `R')
local mc_cov   = sqrt(0.95 * 0.05 / (`G' * `R'))
local mc_rate  = sqrt(`ALPHA' * (1 - `ALPHA') / `R')

display as text "validation_iivw_exogtest_calibration: R=`R' (gate R=`R_GATE'), seed `SEED', smoke=`smoke'"
display as text "  per-test size band  [" %6.4f (`ALPHA' - 3 * `mc_test') ", " %6.4f (`ALPHA' + 3 * `mc_test') "]"
display as text "  Holm FWER target " %6.4f `t0' " band [" %6.4f (`t0' - 3 * `mc_fwer') ", " %6.4f (`t0' + 3 * `mc_fwer') "]"
display as text "  coverage band       [" %6.4f (0.95 - 3 * `mc_cov') ", " %6.4f (0.95 + 3 * `mc_cov') "]"

local tests = 0
local pass = 0
local fail = 0
local skip = 0

* ---------------------------------------------------------------------------
* Holm step-down in Mata: adjusted p for a row of raw p-values (missing beyond m).
* Written independently of iivw_exogtest and checked against R in H2.
mata:
real rowvector _cal_holm(real rowvector p)
{
    real scalar m, i, run
    real colvector o
    real rowvector adj, ps
    m = cols(p)
    o = order(p', 1)
    ps = p[o']
    adj = J(1, m, .)
    run = 0
    for (i = 1; i <= m; i++) {
        run = max((run, min((1, (m - i + 1) * ps[i]))))
        adj[o[i]] = run
    }
    return(adj)
}
end

* _cal_run: R replicates of one DGP. Leaves one row per replicate in memory.
capture program drop _cal_run
program define _cal_run
    syntax , R(integer) N(integer) GAMMAS(numlist) GROUPS(integer) KIND(integer)
    tempname P
    tempfile out
    local vars ""
    foreach s in b se p lb ub {
        forvalues g = 1/`groups' {
            local vars "`vars' `s'`g'"
        }
    }
    postfile `P' int rep byte ok int rc double(`vars' hmp jmp) byte flag str244 rngstate using "`out'", replace
    forvalues rr = 1/`r' {
        local st = c(rngstate)
        iivw_exog_dgp, groups(`groups') n(`n') gammas(`gammas')
        capture quietly iivw_exogtest y, id(id) time(time) maxfu(5) by(grp) nolog
        local rc = _rc
        local ok = 0
        local rowvals ""
        foreach s in b se p lb ub {
            forvalues g = 1/`groups' {
                local v_`s'`g' = .
            }
        }
        local hmp = .
        local jmp = .
        local flag = .
        if `rc' == 0 {
            tempname M
            matrix `M' = r(results)
            if rowsof(`M') == `groups' & r(n_tests) == `groups' & r(n_unknown) == 0 & r(n_skipped) == 0 {
                forvalues g = 1/`groups' {
                    local v_b`g'  = `M'[`g', 3]
                    local v_se`g' = `M'[`g', 4]
                    local v_p`g'  = `M'[`g', 6]
                    local v_lb`g' = `M'[`g', 8]
                    local v_ub`g' = `M'[`g', 9]
                }
                local hmp = r(holm_min_p)
                local jmp = r(joint_min_p)
                local flag = r(history_association_flag)
                local ok = 1
                foreach s in b se p lb ub {
                    forvalues g = 1/`groups' {
                        if missing(`v_`s'`g'') local ok = 0
                    }
                }
                if missing(`hmp', `jmp', `flag') local ok = 0
            }
        }
        local line ""
        foreach s in b se p lb ub {
            forvalues g = 1/`groups' {
                local line "`line' (`v_`s'`g'')"
            }
        }
        post `P' (`rr') (`ok') (`rc') `line' (`hmp') (`jmp') (`flag') ("`st'")
    }
    postclose `P'
    use "`out'", clear
end

* _cal_holmrows: append this DGP's raw p-vectors to the Holm parity file.
capture program drop _cal_holmpost
program define _cal_holmpost
    syntax , HP(name) KIND(integer) GROUPS(integer)
    quietly count
    local nr = r(N)
    forvalues i = 1/`nr' {
        local line ""
        forvalues g = 1/6 {
            if `g' <= `groups' local line "`line' (p`g'[`i'])"
            else local line "`line' (.)"
        }
        post `hp' (`kind') (rep[`i']) (`groups') `line' (hmp[`i']) (jmp[`i'])
    }
end

* _cal_pool: pooled performance over the G arms x replicates in memory, for a DGP in
* which every arm has the same truth (gamma). Sets r(size) the share of raw p < alpha,
* r(cov) coverage of exp(gamma) by the reported [lb, ub], r(ratio) sqrt(mean se^2)/sd(b),
* r(mcse_ratio) per Morris et al. Table 6, r(bias) and r(bias_mcse).
capture program drop _cal_pool
program define _cal_pool, rclass
    syntax , GAMMA(real) ALPHA(real)
    preserve
    quietly keep rep b1-b4 se1-se4 p1-p4 lb1-lb4 ub1-ub4
    quietly reshape long b se p lb ub, i(rep) j(arm)
    local hr = exp(`gamma')
    quietly gen byte rej = (p < `alpha') if p < .
    quietly summarize rej, meanonly
    return scalar size = r(mean)
    quietly gen byte cov = (lb <= `hr' & `hr' <= ub) if !missing(lb, ub)
    quietly summarize cov, meanonly
    return scalar cov = r(mean)
    quietly gen double v = se^2
    quietly summarize v
    local modse = sqrt(r(mean))
    local varv = r(Var)
    local nn = r(N)
    quietly summarize b
    local emp = r(sd)
    return scalar ratio = `modse' / `emp'
    return scalar mcse_ratio = sqrt(`varv' / (4 * `nn' * `modse'^4) + 1 / (2 * (`nn' - 1)))
    return scalar bias = r(mean) - `gamma'
    return scalar bias_mcse = r(sd) / sqrt(r(N))
    return scalar n = `nn'
    restore
end

tempfile holmin
tempname HP
postfile `HP' byte kind int id byte m double(p1 p2 p3 p4 p5 p6 pkg_hmp pkg_jmp) using "`holmin'", replace

set seed `SEED'

**# NULL
display as text _newline "DGP NULL: gamma = (0 0 0 0), N = `NSUB' per arm"
_cal_run, r(`R') n(`NSUB') gammas(0 0 0 0) groups(`G') kind(1)
quietly count if ok == 1
local nok_null = r(N)
* rows that failed keep their rngstate so they can be replayed alone
quietly levelsof rngstate if ok != 1, local(badstates)
foreach s of local badstates {
    display as error "  failed replicate start state: `s'"
}
local null_n_ok = `nok_null'
quietly keep if ok == 1
_cal_holmpost, hp(`HP') kind(1) groups(`G')

quietly count if flag == 1
local fwer_holm = r(N) / _N
quietly count if jmp < `ALPHA'
local fwer_raw = r(N) / _N
_cal_pool, gamma(0) alpha(`ALPHA')
local size_test = r(size)
local cov_null = r(cov)
local ratio_null = r(ratio)
local mcse_ratio_null = r(mcse_ratio)
display as text "  NULL: n_ok `null_n_ok'/`R'  per-test size " %7.4f `size_test' "  Holm FWER " %7.4f `fwer_holm' ///
    "  unadjusted FWER " %7.4f `fwer_raw' "  coverage " %7.4f `cov_null' "  SE ratio " %7.4f `ratio_null' " (MCSE " %6.4f `mcse_ratio_null' ")"

**# ALT
display as text _newline "DGP ALT: gamma = (`GALT' x 4), N = `NSUB' per arm"
_cal_run, r(`R') n(`NSUB') gammas(`GALT' `GALT' `GALT' `GALT') groups(`G') kind(9)
quietly count if ok == 1
local alt_n_ok = r(N)
quietly levelsof rngstate if ok != 1, local(badstates)
foreach s of local badstates {
    display as error "  failed replicate start state: `s'"
}
quietly keep if ok == 1
_cal_pool, gamma(`GALT') alpha(`ALPHA')
local power_test = r(size)
local cov_alt = r(cov)
local ratio_alt = r(ratio)
local mcse_ratio_alt = r(mcse_ratio)
local bias_alt = r(bias)
quietly count if flag == 1
local power_flag = r(N) / _N
display as text "  ALT: n_ok `alt_n_ok'/`R'  per-test power " %7.4f `power_test' "  flag power (Holm) " %7.4f `power_flag' ///
    "  coverage " %7.4f `cov_alt' "  SE ratio " %7.4f `ratio_alt' " (MCSE " %6.4f `mcse_ratio_alt' ")  bias " %8.5f `bias_alt'

**# PARTIAL
display as text _newline "DGP PARTIAL: gamma = (`GPART' 0 0 0), N = `NSUB' per arm"
_cal_run, r(`R') n(`NSUB') gammas(`GPART' 0 0 0) groups(`G') kind(2)
quietly count if ok == 1
local part_n_ok = r(N)
quietly levelsof rngstate if ok != 1, local(badstates)
foreach s of local badstates {
    display as error "  failed replicate start state: `s'"
}
quietly keep if ok == 1
_cal_holmpost, hp(`HP') kind(2) groups(`G')
* Holm step-down per replicate (Mata), then count rejection of any TRUE null arm (2-4)
quietly gen double h1 = .
quietly gen double h2 = .
quietly gen double h3 = .
quietly gen double h4 = .
mata: Praw = st_data(., ("p1", "p2", "p3", "p4"))
mata: Hadj = J(rows(Praw), 4, .)
mata: for (i = 1; i <= rows(Praw); i++) Hadj[i, .] = _cal_holm(Praw[i, .])
mata: st_store(., ("h1", "h2", "h3", "h4"), Hadj)
mata: mata drop Praw Hadj
quietly gen byte anynull = (h2 < `ALPHA') | (h3 < `ALPHA') | (h4 < `ALPHA')
quietly count if anynull == 1
local fwer_partial = r(N) / _N
quietly count if h1 < `ALPHA'
local power_g1 = r(N) / _N
display as text "  PARTIAL: n_ok `part_n_ok'/`R'  P(Holm rejects a true null arm) " %7.4f `fwer_partial' "  P(reject arm 1) " %7.4f `power_g1'

**# PARITY BLOCK (m = 2,3,5,6): runs with varied m and a mix of true/false nulls
display as text _newline "Holm parity runs at m = 2, 3, 5, 6 (`NPAR' each)"
foreach m in 2 3 5 6 {
    forvalues rep = 1/`NPAR' {
        local gl ""
        forvalues g = 1/`m' {
            local gl "`gl' `=cond(mod(`g' + `rep', 2) == 0, .15, 0)'"
        }
        iivw_exog_dgp, groups(`m') n(120) gammas(`gl')
        quietly iivw_exogtest y, id(id) time(time) maxfu(5) by(grp) nolog
        tempname M
        matrix `M' = r(results)
        assert rowsof(`M') == `m'
        local line ""
        forvalues g = 1/6 {
            if `g' <= `m' local line "`line' (`M'[`g', 6])"
            else local line "`line' (.)"
        }
        post `HP' (3) (`m' * 1000 + `rep') (`m') `line' (r(holm_min_p)) (r(joint_min_p))
    }
}
postclose `HP'

**# R reference for the Holm family
tempfile hstub
local ref_dir "`hstub'_holm"
capture mkdir "`ref_dir'"
* p-values go through CSV at 17 significant digits (string form), not export's short default
preserve
use "`holmin'", clear
quietly count
local n_holm_rows = r(N)
foreach v of varlist p1-p6 pkg_hmp pkg_jmp {
    quietly tostring `v', replace format(%21.17g) force
    quietly replace `v' = "" if `v' == "."
}
export delimited kind id m p1-p6 using "`ref_dir'/holm_in.csv", replace
restore
local rscript "`qa_dir'/validation_iivw_exogtest_calibration_holm.R"
capture confirm file "`rscript'"
if _rc {
    display as error "missing R script `rscript'"
    exit 601
}
capture erase "`ref_dir'/holm.ok"
shell Rscript "`rscript'" --outdir="`ref_dir'"
capture confirm file "`ref_dir'/holm.ok"
if _rc {
    display as error "R p.adjust reference did not run to completion (needs Rscript)"
    exit 198
}

preserve
import delimited using "`ref_dir'/holm_ref.csv", clear varnames(1) asdouble
tempfile holmref
quietly save "`holmref'"
restore
preserve
use "`holmin'", clear
quietly merge 1:1 kind id using "`holmref'", assert(match) nogenerate
* H1: package holm_min_p vs R min adjusted p, every run
quietly gen double d1 = abs(pkg_hmp - r_min_adj) / max(abs(r_min_adj), 1e-300)
quietly summarize d1
local h1_max = r(max)
local h1_n = r(N)
quietly count if missing(d1)
local h1_miss = r(N)
* H1b: package joint_min_p == min raw p (the raw p's used are the ones R saw)
quietly egen double _minp = rowmin(p1 p2 p3 p4 p5 p6)
quietly gen double d1b = abs(pkg_jmp - _minp) / max(abs(_minp), 1e-300)
quietly summarize d1b
local h1b_max = r(max)
* H2: Stata step-down (the one used in P2) vs R per arm, kind 3 and 2 vectors
quietly gen double s1 = .
quietly gen double s2 = .
quietly gen double s3 = .
quietly gen double s4 = .
quietly gen double s5 = .
quietly gen double s6 = .
mata: PP = st_data(., ("p1","p2","p3","p4","p5","p6")); mm = st_data(., "m"); SS = J(rows(PP), 6, .)
mata: for (i = 1; i <= rows(PP); i++) SS[i, (1..mm[i])] = _cal_holm(PP[i, (1..mm[i])])
mata: st_store(., ("s1","s2","s3","s4","s5","s6"), SS)
mata: mata drop PP mm SS
local h2_max = 0
local h2_miss = 0
forvalues g = 1/6 {
    quietly gen double d2_`g' = abs(s`g' - a`g') / max(abs(a`g'), 1e-300) if m >= `g'
    quietly summarize d2_`g'
    if r(N) > 0 & r(max) > `h2_max' local h2_max = r(max)
    quietly count if m >= `g' & missing(d2_`g')
    local h2_miss = `h2_miss' + r(N)
}
display as text "  H1 max reldif (package holm_min_p vs R) " %10.3e `h1_max' " over `h1_n' runs; min raw p identity " %10.3e `h1b_max'
display as text "  H2 max reldif (Stata step-down vs R, per arm) " %10.3e `h2_max'
restore

**# Verdicts
capture program drop _cal_verdict
program define _cal_verdict
    args ok label
    if `ok' == 1 display as result "  PASS: `label'"
    else         display as error  "  FAIL: `label'"
end

display as text _newline "Verdicts"

* C1
local ++tests
local ok = (`null_n_ok' == `R' & `alt_n_ok' == `R' & `part_n_ok' == `R')
_cal_verdict `ok' "C1 all replicates returned `G' fitted arms with finite b se p lb ub (null `null_n_ok', alt `alt_n_ok', partial `part_n_ok' of `R')"
if `ok' local ++pass
else local ++fail

* H1, H1b, H2: deterministic, applied in smoke too
local ++tests
local ok = (`h1_max' < 1e-10 & `h1_max' < . & `h1b_max' < 1e-10 & `h1_miss' == 0)
_cal_verdict `ok' "H1 package holm_min_p == R p.adjust(holm) minimum on `n_holm_rows' runs (max reldif " %9.2e `h1_max' ")"
if `ok' local ++pass
else local ++fail
local ++tests
local ok = (`h2_max' < 1e-10 & `h2_max' < . & `h2_miss' == 0)
_cal_verdict `ok' "H2 Stata step-down == R p.adjust(holm) on every arm (max reldif " %9.2e `h2_max' ")"
if `ok' local ++pass
else local ++fail

* Banded gates: skipped in smoke
if `smoke' {
    display as text "  (smoke: banded gates N2-N6, A2-A4, P2 are not run or counted)"
}
else {
    * N2 per-test size
    local ++tests
    local lo = `ALPHA' - 3 * `mc_test'
    local hi = `ALPHA' + 3 * `mc_test'
    local ok = (`size_test' >= `lo' & `size_test' <= `hi' & `size_test' < .)
    _cal_verdict `ok' "N2 per-test size " %6.4f `size_test' " in [" %6.4f `lo' ", " %6.4f `hi' "]"
    if `ok' local ++pass
    else local ++fail

    * N3 Holm FWER
    local ++tests
    local lo = `t0' - 3 * `mc_fwer'
    local hi = `t0' + 3 * `mc_fwer'
    local ok = (`fwer_holm' >= `lo' & `fwer_holm' <= `hi' & `fwer_holm' < .)
    _cal_verdict `ok' "N3 Holm family-wise rejection " %6.4f `fwer_holm' " in [" %6.4f `lo' ", " %6.4f `hi' "] (target " %6.4f `t0' ", alpha " %4.2f `ALPHA' ")"
    if `ok' local ++pass
    else local ++fail

    * N4 negative control: the unadjusted family rule must be OUT of band (above alpha)
    local ++tests
    local ctrl_hi = `ALPHA' + 3 * `mc_rate'
    local would_pass = (`fwer_raw' <= `ctrl_hi' & `fwer_raw' < .)
    local ok = (`would_pass' == 0 & `fwer_raw' < .)
    _cal_verdict `ok' "N4 negative control: unadjusted FWER " %6.4f `fwer_raw' " exceeds alpha+3MCSE " %6.4f `ctrl_hi' " (gate form would be red)"
    if `ok' local ++pass
    else local ++fail

    * N5 coverage under the null
    local ++tests
    local lo = 0.95 - 3 * `mc_cov'
    local hi = 0.95 + 3 * `mc_cov'
    local ok = (`cov_null' >= `lo' & `cov_null' <= `hi' & `cov_null' < .)
    _cal_verdict `ok' "N5 CI coverage of HR=1 " %6.4f `cov_null' " in [" %6.4f `lo' ", " %6.4f `hi' "]"
    if `ok' local ++pass
    else local ++fail

    * N6 SE ratio under the null
    local ++tests
    local ok = (abs(`ratio_null' - 1) <= 3 * `mcse_ratio_null' & `ratio_null' < .)
    _cal_verdict `ok' "N6 ModSE/EmpSE " %6.4f `ratio_null' " within 1 +/- 3*" %6.4f `mcse_ratio_null'
    if `ok' local ++pass
    else local ++fail

    * A2 coverage under the alternative
    local ++tests
    local lo = 0.95 - 3 * `mc_cov'
    local hi = 0.95 + 3 * `mc_cov'
    local ok = (`cov_alt' >= `lo' & `cov_alt' <= `hi' & `cov_alt' < .)
    _cal_verdict `ok' "A2 CI coverage of HR=exp(`GALT') " %6.4f `cov_alt' " in [" %6.4f `lo' ", " %6.4f `hi' "]"
    if `ok' local ++pass
    else local ++fail

    * A3 SE ratio under the alternative
    local ++tests
    local ok = (abs(`ratio_alt' - 1) <= 3 * `mcse_ratio_alt' & `ratio_alt' < .)
    _cal_verdict `ok' "A3 ModSE/EmpSE " %6.4f `ratio_alt' " within 1 +/- 3*" %6.4f `mcse_ratio_alt'
    if `ok' local ++pass
    else local ++fail

    * A4 power
    local ++tests
    local ok = (`power_flag' >= `POWER_FLOOR' & `power_flag' < . & (`power_flag' - `fwer_holm') > 3 * `mc_rate')
    _cal_verdict `ok' "A4 flag power (Holm) " %6.4f `power_flag' " >= " %4.2f `POWER_FLOOR' "; per-test power " %6.4f `power_test' " beside size " %6.4f `size_test'
    if `ok' local ++pass
    else local ++fail

    * P2 strong control
    local ++tests
    local hi = `ALPHA' + 3 * `mc_rate'
    local ok = (`fwer_partial' <= `hi' & `fwer_partial' < . & `power_g1' > 0.95)
    _cal_verdict `ok' "P2 Holm rejects a true-null arm with prob " %6.4f `fwer_partial' " <= " %6.4f `hi' "; arm-1 rejection " %6.4f `power_g1'
    if `ok' local ++pass
    else local ++fail
}

display as text _newline "Worked-run record: R=`R' null size " %6.4f `size_test' ", Holm FWER " %6.4f `fwer_holm' ", unadjusted " %6.4f `fwer_raw' ///
    ", coverage null " %6.4f `cov_null' " / alt " %6.4f `cov_alt' ", power flag " %6.4f `power_flag' ", partial " %6.4f `fwer_partial'
display "RESULT: validation_iivw_exogtest_calibration tests=`tests' pass=`pass' fail=`fail' skip=`skip' smoke=`smoke'"
if `smoke' display as text "SMOKE RUN: code path exercised only; not gate evidence"
iivw_qa_sandbox_restore
if `fail' > 0 exit 1
