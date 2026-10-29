* validation_kmplot_cif_calibration.do
* Inference calibration: coverage of kmplot's pointwise 95% intervals for the
* Aalen-Johansen cumulative incidence under compete()
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-10-29
*
* Usage (from kmplot/qa):
*   stata-mp -b do validation_kmplot_cif_calibration.do          gate (R = 1000)
*   stata-mp -b do validation_kmplot_cif_calibration.do smoke    code path only
*
* ADEMP (Morris, White & Crowther 2019, Table 1), written before the run
*   Aims        Do kmplot's reported pointwise intervals for the cumulative
*               incidence F1(t) of the event of interest, with a competing
*               event, have nominal coverage under each citransform()?
*   DGP         n = 200; latent T1 ~ Exponential(rate 0.6) (event of interest)
*               and T2 ~ Exponential(rate 0.4) (competing event), observed
*               T = min(T1, T2) with its cause; independent C ~ U(0, 3).
*               Constant cause-specific hazards 0.6 and 0.4.
*   Estimand    F1(t) = 0.6 (1 - exp(-t)) at t1 = ln 2 (F1 = .30) and
*               t2 = ln 4 (F1 = .45).
*   Methods     kmplot, ci compete(cause == 2) citransform(loglog | log |
*               plain) landmark(t1 t2)
*   Performance coverage of the 95% interval (gate); every replicate returns
*               finite bounds (gate); bias of the point estimate with its
*               MCSE (reported; validation_kmplot_cif_oracle.do and
*               crossval_kmplot_cif.do pin the point estimate exactly).
*
* GATES (computed from R, never typed)
*   coverage in 0.95 +/- 3 * sqrt(0.95 * 0.05 / R)
*   every replicate returns a finite estimate and both bounds
* Expected class per cell: NOMINAL (n = 200 keeps F1(t) well inside (0, 1)).
*
* WORKED RUN
*   2026-10-29: see the RESULT block of the gated run's log.

clear all
version 16.0
set more off
set varabbrev off

args mode
local smoke = ("`mode'" == "smoke")
if "`mode'" != "" & !`smoke' {
    display as error "unknown argument `mode'; the only accepted argument is smoke"
    exit 198
}

local qa_dir "`c(pwd)'"
quietly do "`qa_dir'/_kmplot_qa_common.do"
_kmplot_qa_bootstrap

local R = cond(`smoke', 25, 1000)
local n 200
local h1 0.6
local h2 0.4
local t1 = ln(2)
local t2 = ln(4)
local transforms "loglog log plain"
set seed 20261029

tempname post
tempfile results
postfile `post' str6 transform byte point double(t truth est lo hi) ///
    using "`results'", replace
forvalues r = 1/`R' {
    if mod(`r', 100) == 0 display as text "replicate `r' of `R'"
    quietly {
        clear
        set obs `n'
        gen double t1 = rexponential(1 / `h1')
        gen double t2 = rexponential(1 / `h2')
        gen double cc = runiform() * 3
        gen double t = min(t1, t2, cc)
        gen byte cause = cond(cc < min(t1, t2), 0, cond(t1 <= t2, 1, 2))
        stset t, failure(cause == 1)
    }
    foreach tr of local transforms {
        quietly kmplot, ci cistyle(line) citransform(`tr') ///
            compete(cause == 2) landmark(`t1' `t2') nodraw name(kmcifcal, replace)
        tempname L
        matrix `L' = r(landmarks)
        forvalues j = 1/2 {
            local truth = `h1' / (`h1' + `h2') * (1 - exp(-(`h1' + `h2') * `t`j''))
            post `post' ("`tr'") (`j') (`L'[`j', 2]) (`truth') (`L'[`j', 3]) ///
                (`L'[`j', 4]) (`L'[`j', 5])
        }
    }
}
postclose `post'
capture graph drop kmcifcal

use "`results'", clear
local band = 3 * sqrt(0.95 * 0.05 / `R')
local lo_gate = 0.95 - `band'
local hi_gate = 0.95 + `band'
local test_count = 0
local pass_count = 0
local fail_count = 0
foreach tr of local transforms {
    forvalues j = 1/2 {
        local ++test_count
        quietly count if transform == "`tr'" & point == `j'
        local ncell = r(N)
        * every landmark row sits at its requested time, in order
        quietly count if transform == "`tr'" & point == `j' & ///
            reldif(t, `t`j'') > 1e-12
        local nbadt = r(N)
        quietly count if transform == "`tr'" & point == `j' & ///
            missing(est, lo, hi)
        local nmiss = r(N) + (`ncell' != `R') + `nbadt'
        quietly count if transform == "`tr'" & point == `j' & ///
            lo <= truth & truth <= hi
        local cover = r(N) / `R'
        quietly summarize truth if transform == "`tr'" & point == `j', meanonly
        local truth_j = r(mean)
        quietly summarize est if transform == "`tr'" & point == `j'
        local bias = r(mean) - `truth_j'
        local mcse = r(sd) / sqrt(r(N))
        display as text "`tr' t`j' (F1 = " %4.2f `truth_j' "): coverage " %6.4f `cover' ///
            " [band " %6.4f `lo_gate' ", " %6.4f `hi_gate' "]" ///
            "  bias " %8.5f `bias' " (MCSE " %7.5f `mcse' ")  missing `nmiss'"
        if `smoke' {
            * Smoke checks the code path only; the band is never applied.
            if `nmiss' == 0 local ++pass_count
            else local ++fail_count
        }
        else if `nmiss' == 0 & `cover' >= `lo_gate' & `cover' <= `hi_gate' {
            local ++pass_count
        }
        else {
            local ++fail_count
            display as error "  FAIL: `tr' t`j' outside the calibration gate"
        }
    }
}
if `smoke' {
    display "RESULT: validation_kmplot_cif_calibration tests=`test_count' pass=`pass_count' fail=`fail_count' smoke=1"
}
else {
    display "RESULT: validation_kmplot_cif_calibration tests=`test_count' pass=`pass_count' fail=`fail_count' R=`R'"
}
if `fail_count' > 0 exit 1
