clear all
set more off
version 16.0
set varabbrev off
* the RESULT: line is longer than 80 characters; a wrapped line would hide smoke=
set linesize 255

* validation_iivw_unweighted_calibration.do
*
* Inference calibration for the REPORTED standard error and 95% interval of
* `iivw_fit, unweighted' (glm independence-GEE + cluster-robust sandwich, G/(G-1)).
*   stata-mp -b do validation_iivw_unweighted_calibration.do          gate (sim lane)
*   stata-mp -b do validation_iivw_unweighted_calibration.do smoke    code path only
* The smoke form runs 10 replicates per DGP, checks every replicate returns a finite
* estimate/SE/interval, never applies a band, prints smoke=1 and exits 0.
*
* ADEMP (Morris, White & Crowther 2019, Table 1; written before the gated run)
*   Aims        Does the reported cluster-robust SE/interval of the unweighted fit have
*               nominal coverage and an SE that tracks the empirical SD?
*   DGPs        the two recovery DGPs of _iivw_unw_dgp.do (A random-intercept/subject x;
*               B time-varying x, random intercept+slope, heteroscedastic), non-informative
*               visits, n = 300 subjects, so the estimator is unbiased (see
*               validation_iivw_unweighted_recovery.do) and any miss is a variance miss.
*   Estimand    b_x (A: .5, B: .7) and b_t (A: .3, B: -.4), set in the DGP.
*   Methods     iivw_fit y x, unweighted id(id) time(t) timespec(linear); the interval is
*               READ from e(iivw_ci), never rebuilt as b +/- 1.96 se. Negative controls
*               on the same replicates: (i) plain `glm' with its iid model-based SE (ignores
*               clustering; must UNDER-cover, ICC is high), (ii) the reported interval
*               shrunk to half width.
*   Performance coverage (gate), ModSE/EmpSE with ModSE = sqrt(mean se^2) (gate), bias with
*               MCSE (reported), failures (gate: zero).
* GATES (computed from R below, never typed)
*   coverage in .95 +/- 3*sqrt(.95*.05/R); R = 1000 -> MCSE .0069, band [.9293, .9707]
*   |ModSE/EmpSE - 1| <= 3*MCSE(ratio), MCSE per Morris et al. Table 6
*   n_ok == R; negative controls must fall BELOW the coverage band
* Seed: set seed 20261301 once per DGP block (A), 20261302 (B); each replicate's
* c(rngstate) is retained and a failing replicate replays alone via set rngstate.
* Expected class per cell: NOMINAL (the help file declares unweighted fits keep the cluster
* sandwich with no weight-estimation term; there is no conservatism to declare).
*
* WORKED RUN (R = 1000 per DGP, first gated run, gates unchanged afterwards)
*   DGP A b_x: bias -0.0019 (MCSE .0044) coverage .941 ModSE/EmpSE .975
*          b_t: bias -0.0001 (.0007)     coverage .947 ModSE/EmpSE .984
*   DGP B b_x: bias -0.0021 (.0014)      coverage .949 ModSE/EmpSE .994
*          b_t: bias +0.0022 (.0014)     coverage .934 ModSE/EmpSE .966
*   negative controls on b_x: iid glm SE coverage .540 (A) / .704 (B), SE ratio .38 / .54;
*   half-width interval coverage .677 / .676; all far below the band [.9293, .9707]

args mode
local smoke = ("`mode'" == "smoke")
if "`mode'" != "" & !`smoke' {
    display as error "unknown argument `mode'; the only accepted argument is smoke"
    exit 198
}
do "`c(pwd)'/_iivw_qa_common.do"
local qa_dir "`c(pwd)'"
if substr("`qa_dir'", -3, 3) != "/qa" {
    display as error "validation_iivw_unweighted_calibration.do must be run from iivw/qa"
    exit 198
}
iivw_qa_bootstrap
do "`qa_dir'/_iivw_unw_dgp.do"

local R_GATE  = 1000
local SMOKE_R = 10
local R       = cond(`smoke', `SMOKE_R', `R_GATE')
local NOMINAL = 0.95
local NOBS    = 300
local cov_mcse = sqrt(`NOMINAL' * (1 - `NOMINAL') / `R')
local cov_lo   = `NOMINAL' - 3 * `cov_mcse'
local cov_hi   = `NOMINAL' + 3 * `cov_mcse'
display as text "validation_iivw_unweighted_calibration: R=`R' per DGP (gate R=`R_GATE'), n=`NOBS', smoke=`smoke'"
display as text "  coverage band [" %6.4f `cov_lo' ", " %6.4f `cov_hi' "] (MCSE " %6.4f `cov_mcse' ")"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _cal_one
program define _cal_one, rclass
    * one fit of the command under test + the iid negative control on the data in memory
    capture quietly iivw_fit y x, unweighted id(id) time(t) timespec(linear) nolog
    if _rc {
        return scalar rc = _rc
        exit
    }
    tempname CI
    matrix `CI' = e(iivw_ci)
    return scalar rc = 0
    return scalar bx = _b[x]
    return scalar sx = _se[x]
    return scalar lx = `CI'[1, colnumb(`CI', "y:x")]
    return scalar ux = `CI'[2, colnumb(`CI', "y:x")]
    return scalar bt = _b[t]
    return scalar st = _se[t]
    return scalar lt = `CI'[1, colnumb(`CI', "y:t")]
    return scalar ut = `CI'[2, colnumb(`CI', "y:t")]
    quietly glm y x t
    return scalar nsx = _se[x]
    return scalar nbx = _b[x]
    return scalar nst = _se[t]
    return scalar nbt = _b[t]
end

capture program drop _cal_block
program define _cal_block
    syntax , DGP(string) N(integer) R(integer) SEED(integer) FILE(string) ///
        TX(real) TT(real)
    tempname P
    postfile `P' int rep int rc double(bx sx lx ux bt st lt ut nbx nsx nbt nst) ///
        str2045 rngstate using "`file'", replace
    set seed `seed'
    forvalues r = 1/`r' {
        local st = c(rngstate)
        _unw_gen, dgp(`dgp') n(`n')
        _cal_one
        if r(rc) == 0 {
            post `P' (`r') (0) (r(bx)) (r(sx)) (r(lx)) (r(ux)) (r(bt)) (r(st)) ///
                (r(lt)) (r(ut)) (r(nbx)) (r(nsx)) (r(nbt)) (r(nst)) ("`st'")
        }
        else {
            post `P' (`r') (r(rc)) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) ("`st'")
        }
    }
    postclose `P'
end

* _cal_perf: summaries for one coefficient in the data in memory.
* stub: bx|bt (reported); ci bounds lx ux | lt ut; sd column sx | st; truth.
capture program drop _cal_perf
program define _cal_perf, rclass
    syntax , B(string) SE(string) LO(string) HI(string) TRUTH(real)
    quietly count if rc == 0 & !missing(`b', `se', `lo', `hi')
    local nok = r(N)
    quietly summarize `b'
    local emp = r(sd)
    local bias = r(mean) - `truth'
    local bmcse = r(sd) / sqrt(r(N))
    tempvar v cv
    quietly gen double `v' = `se'^2
    quietly summarize `v'
    local mod = sqrt(r(mean))
    local varv = r(Var)
    local ratio = `mod' / `emp'
    local rmcse = sqrt(`varv' / (4 * `nok' * `mod'^4) + 1 / (2 * (`nok' - 1)))
    quietly gen byte `cv' = (`lo' <= `truth' & `truth' <= `hi') if !missing(`lo', `hi')
    quietly summarize `cv', meanonly
    return scalar nok = `nok'
    return scalar cov = r(mean)
    return scalar ratio = `ratio'
    return scalar rmcse = `rmcse'
    return scalar bias = `bias'
    return scalar bmcse = `bmcse'
end

tempfile fA fB
local nA = 0
local nB = 0
_cal_block, dgp(A) n(`NOBS') r(`R') seed(20261301) file("`fA'") tx(.5) tt(.3)
_cal_block, dgp(B) n(`NOBS') r(`R') seed(20261302) file("`fB'") tx(.7) tt(-.4)

* per-DGP performance, gathered into locals
foreach d in A B {
    local tx = cond("`d'" == "A", .5, .7)
    local tt = cond("`d'" == "A", .3, -.4)
    use "`f`d''", clear
    quietly count if rc != 0 | missing(bx, sx, lx, ux, bt, st, lt, ut)
    local nbad_`d' = r(N)
    * reported-interval performance
    _cal_perf, b(bx) se(sx) lo(lx) hi(ux) truth(`tx')
    foreach m in nok cov ratio rmcse bias bmcse {
        local `m'_x_`d' = r(`m')
    }
    _cal_perf, b(bt) se(st) lo(lt) hi(ut) truth(`tt')
    foreach m in nok cov ratio rmcse bias bmcse {
        local `m'_t_`d' = r(`m')
    }
    * negative control (i): iid glm model-based interval, b +/- z*se from the plain glm
    quietly gen double nlx = nbx - invnormal(.975) * nsx
    quietly gen double nux = nbx + invnormal(.975) * nsx
    quietly gen byte ncx = (nlx <= `tx' & `tx' <= nux) if !missing(nlx, nux)
    quietly summarize ncx, meanonly
    local negcov_`d' = r(mean)
    quietly gen double v2 = nsx^2
    quietly summarize v2
    local niid = sqrt(r(mean))
    quietly summarize bx
    local negratio_`d' = `niid' / r(sd)
    * negative control (ii): reported interval at half width
    quietly gen byte hcx = ((bx + (lx - bx) / 2) <= `tx' & `tx' <= (bx + (ux - bx) / 2)) if !missing(lx, ux)
    quietly summarize hcx, meanonly
    local halfcov_`d' = r(mean)
    display as text _newline "DGP `d': n_ok `nok_x_`d'' of `R', failed `nbad_`d''"
    display as text "  b_x  bias " %9.5f `bias_x_`d'' " (MCSE " %8.5f `bmcse_x_`d'' ")  coverage " %6.4f `cov_x_`d'' "  ModSE/EmpSE " %6.4f `ratio_x_`d'' " (MCSE " %6.4f `rmcse_x_`d'' ")"
    display as text "  b_t  bias " %9.5f `bias_t_`d'' " (MCSE " %8.5f `bmcse_t_`d'' ")  coverage " %6.4f `cov_t_`d'' "  ModSE/EmpSE " %6.4f `ratio_t_`d'' " (MCSE " %6.4f `rmcse_t_`d'' ")"
    display as text "  neg control (iid model-based, b_x): coverage " %6.4f `negcov_`d'' "  ModSE/EmpSE " %6.4f `negratio_`d''
    display as text "  neg control (half-width interval, b_x): coverage " %6.4f `halfcov_`d''
}

* a gate predicate shared by the real cells and the negative controls, so a control
* that cannot go red would show up as a predicate that cannot fail
capture program drop _cal_incov
program define _cal_incov, rclass
    args cov lo hi
    return scalar ok = (`cov' < . & `cov' >= `lo' & `cov' <= `hi')
end

**# C1: every replicate returned finite b, se, ci in both DGPs (both modes)
local ++test_count
local ok = (`nbad_A' == 0 & `nbad_B' == 0 & `nok_x_A' == `R' & `nok_x_B' == `R')
if `ok' {
    display as result "  PASS: C1 all `R' replicates per DGP returned b, se, ci"
    local ++pass_count
}
else {
    display as error "  FAIL: C1 failed replicates A=`nbad_A' B=`nbad_B'"
    local ++fail_count
    local failed_tests "`failed_tests' C1"
}

if !`smoke' {
    foreach d in A B {
        local cc = cond("`d'" == "A", 2, 4)
        **# C2/C4: coverage of b_x and b_t in the band
        local ++test_count
        _cal_incov `cov_x_`d'' `cov_lo' `cov_hi'
        local okx = r(ok)
        _cal_incov `cov_t_`d'' `cov_lo' `cov_hi'
        local okt = r(ok)
        if `okx' & `okt' {
            display as result "  PASS: C`cc' DGP `d' coverage b_x " %6.4f `cov_x_`d'' ", b_t " %6.4f `cov_t_`d'' " in band"
            local ++pass_count
        }
        else {
            display as error "  FAIL: C`cc' DGP `d' coverage b_x " %6.4f `cov_x_`d'' ", b_t " %6.4f `cov_t_`d'' " outside [" %6.4f `cov_lo' ", " %6.4f `cov_hi' "]"
            local ++fail_count
            local failed_tests "`failed_tests' C`cc'"
        }
        **# C3/C5: ModSE/EmpSE within 3 MCSE of 1
        local ++test_count
        local cr = `cc' + 1
        local okx = (abs(`ratio_x_`d'' - 1) <= 3 * `rmcse_x_`d'' & `ratio_x_`d'' < .)
        local okt = (abs(`ratio_t_`d'' - 1) <= 3 * `rmcse_t_`d'' & `ratio_t_`d'' < .)
        if `okx' & `okt' {
            display as result "  PASS: C`cr' DGP `d' ModSE/EmpSE b_x " %6.4f `ratio_x_`d'' ", b_t " %6.4f `ratio_t_`d'' " within 1 +/- 3 MCSE"
            local ++pass_count
        }
        else {
            display as error "  FAIL: C`cr' DGP `d' ModSE/EmpSE b_x " %6.4f `ratio_x_`d'' ", b_t " %6.4f `ratio_t_`d''
            local ++fail_count
            local failed_tests "`failed_tests' C`cr'"
        }
    }
    **# C6: negative controls fall below the band (the gate goes red on a known-wrong SE)
    local ++test_count
    local allred 1
    foreach d in A B {
        _cal_incov `negcov_`d'' `cov_lo' `cov_hi'
        local r1 = r(ok)
        _cal_incov `halfcov_`d'' `cov_lo' `cov_hi'
        local r2 = r(ok)
        * red = predicate false AND the rate is below (not above) the band
        if `r1' != 0 | `r2' != 0 | `negcov_`d'' >= `cov_lo' | `halfcov_`d'' >= `cov_lo' local allred 0
    }
    if `allred' {
        display as result "  PASS: C6 negative controls (iid SE: A " %6.4f `negcov_A' ", B " %6.4f `negcov_B' "; half-width: A " %6.4f `halfcov_A' ", B " %6.4f `halfcov_B' ") fall below the band"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C6 a negative control did not go red"
        local ++fail_count
        local failed_tests "`failed_tests' C6"
    }
}

display "RESULT: validation_iivw_unweighted_calibration tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0 smoke=`smoke'"
if `smoke' display as text "SMOKE RUN: code path exercised only; not gate evidence"
iivw_qa_sandbox_restore
if `fail_count' > 0 exit 1
