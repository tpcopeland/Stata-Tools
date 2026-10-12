* validation_kmplot_calibration.do
* Inference calibration: coverage of kmplot's pointwise 95% intervals
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-10-12
*
* Usage (from kmplot/qa):
*   stata-mp -b do validation_kmplot_calibration.do          gate (R = 1000)
*   stata-mp -b do validation_kmplot_calibration.do smoke    code path only
*
* ADEMP (Morris, White & Crowther 2019, Table 1), written before the run
*   Aims        Do kmplot's reported pointwise intervals for S(t) have nominal
*               coverage under each citransform()?
*   DGP         n = 200, T ~ Exponential(1), independent C ~ U(0, 3);
*               about 32% censored.
*   Estimand    S(t) = exp(-t) at t1 = ln(4/3) (S = .75) and t2 = ln 2
*               (S = .50).
*   Methods     kmplot, ci citransform(loglog | log | plain) landmark(t1 t2)
*   Performance coverage of the 95% interval (gate); every replicate returns
*               finite bounds (gate); bias of the point estimate with its
*               MCSE (reported; validation_kmplot_recovery.do owns the bias
*               gate).
*
* GATES (computed from R, never typed)
*   coverage in 0.95 +/- 3 * sqrt(0.95 * 0.05 / R)
*   every replicate returns a finite estimate and both bounds
* Expected class per cell: NOMINAL (n = 200 keeps S(t) well inside (0, 1)).
*
* WORKED RUN
*   2026-10-12: see the RESULT block of the gated run's log.

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
local t1 = ln(4/3)
local t2 = ln(2)
local transforms "loglog log plain"
set seed 20261013

tempname post
tempfile results
postfile `post' str6 transform byte point double(truth est lo hi) ///
    using "`results'", replace
forvalues r = 1/`R' {
    if mod(`r', 100) == 0 display as text "replicate `r' of `R'"
    quietly {
        clear
        set obs `n'
        gen double tt = rexponential(1)
        gen double cc = runiform() * 3
        gen byte d = tt <= cc
        gen double t = min(tt, cc)
        stset t, failure(d)
    }
    foreach tr of local transforms {
        quietly kmplot, ci cistyle(line) citransform(`tr') ///
            landmark(`t1' `t2') nodraw name(kmcal, replace)
        tempname L
        matrix `L' = r(landmarks)
        forvalues j = 1/2 {
            local truth = exp(-`t`j'')
            post `post' ("`tr'") (`j') (`truth') (`L'[`j', 3]) ///
                (`L'[`j', 4]) (`L'[`j', 5])
        }
    }
}
postclose `post'
capture graph drop kmcal

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
        quietly count if transform == "`tr'" & point == `j' & ///
            missing(est, lo, hi)
        local nmiss = r(N)
        quietly count if transform == "`tr'" & point == `j' & ///
            lo <= truth & truth <= hi
        local cover = r(N) / `R'
        quietly summarize est if transform == "`tr'" & point == `j'
        local bias = r(mean) - exp(-`t`j'')
        local mcse = r(sd) / sqrt(r(N))
        display as text "`tr' t`j': coverage " %6.4f `cover' ///
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
    display "RESULT: validation_kmplot_calibration tests=`test_count' pass=`pass_count' fail=`fail_count' smoke=1"
}
else {
    display "RESULT: validation_kmplot_calibration tests=`test_count' pass=`pass_count' fail=`fail_count' R=`R'"
}
if `fail_count' > 0 exit 1
