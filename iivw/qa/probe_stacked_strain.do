* =============================================================================
* probe_stacked_strain.do - WHY does the strong-confounding cell undercover?
* =============================================================================
* probe_stacked_calibration.do established that vce(stacked) is the right size
* where the asymptotics apply (mild cell: SE/empSD 0.988, coverage 0.944) and
* left one question open: under positivity strain the stacked interval covered
* 0.832 at n=400 and only 0.880 at n=1600, and the reason was argued from a
* SD/IQR-scale statistic rather than measured.
*
* That argument cannot distinguish three different failures, which call for
* three different responses:
*
*   (1) THE SE IS TOO SMALL. The correction misses something that matters under
*       strain. Response: the implementation is wrong or incomplete.
*   (2) THE PIVOT IS NOT NORMAL. The SE is right but 1.96 is the wrong critical
*       value for a heavy-tailed sampling distribution. Response: no variance
*       estimator repairs this; only a different interval method does.
*   (3) THE ESTIMATOR IS BIASED. beta-hat is off-centre, so a correctly sized
*       interval still misses. Response: not an inference problem at all.
*
* The discriminator is the ORACLE interval: beta-hat +/- 1.96 * empSD, using the
* empirical SD of beta-hat across replications as if it were known. No variance
* estimator can beat it, so:
*
*   oracle coverage ~ 0.95  and stacked below it   -> cause (1), the SE
*   oracle coverage well below 0.95                -> cause (2) or (3), not the SE
*
* and the mean-centred oracle separates the last two: re-centring on mean(b)
* removes bias, so if the truth-centred oracle undercovers while the centred one
* is 0.95, the gap is bias, not shape.
*
* Reported alongside: median(SE) / IQR-scale(b), which compares SE to spread with
* a robust statistic on BOTH sides (the calibration probe's mean/SD ratio is
* tail-sensitive on both), and the empirical p95 of |t| = |b - 0.5| / SE, which
* is the critical value that WOULD deliver 95% with the SE as computed.
*
* DIAGNOSTIC, NOT A GATE. Same standing as probe_stacked_calibration.do: a
* different DGP, weight type, sample size and seed set from the preregistered
* FIPTIW cell (FIPTIW_NSCALE_2026-07-23.md:5-7). Nothing here may be reported as
* a coverage verdict or used to change a default.
*
* Usage (from a scratch copy of the package, per the isolation rule). One cell
* per invocation, so a ladder runs as concurrent jobs:
*   stata-mp -b do probe_stacked_strain.do NSUB PSCOEF REPS SEED
* Defaults: NSUB=400 PSCOEF=1.2 REPS=500 SEED=880000.
* PSCOEF 0.5 reproduces the calibration probe's mild cell, 1.2 its strong cell.
* About 1.5 s per replication at NSUB=400, scaling roughly linearly in NSUB.
* =============================================================================

clear all
version 16.0
set varabbrev off

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "probe_stacked_strain.do must be run from iivw/qa"
    exit 198
}
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap

local nsub   = 400
local pscoef = 1.2
local reps   = 500
local seed   = 880000
if "`1'" != "" local nsub   = real("`1'")
if "`2'" != "" local pscoef = real("`2'")
if "`3'" != "" local reps   = real("`3'")
if "`4'" != "" local seed   = real("`4'")
if `reps' < 100 {
    display as error "REPS below 100 cannot resolve a coverage difference of a"
    display as error "  few points, which is the whole question here"
    exit 198
}

local truth = 0.5

tempfile out
tempname pf
postfile `pf' double(b sef ses maxw essr) using "`out'", replace

local kept = 0
local failed = 0
forvalues r = 1/`reps' {
    quietly {
        clear
        set seed `=`seed' + `r''
        set obs `nsub'
        gen long id = _n
        gen double k1 = rnormal()
        gen double k2 = rnormal()
        * Same DGP as probe_stacked_calibration.do, so the cells are comparable:
        * treatment and outcome share k1 and k2, and pscoef sets the strain.
        gen byte a = runiform() < invlogit(`pscoef'*k1 - `=`pscoef'*0.8'*k2)
        expand 5
        bysort id: gen int j = _n
        gen double t = j
        gen double y = 1 + 0.5*a + 0.8*k1 - 0.6*k2 + 0.1*t + rnormal()
        sort id t

        capture iivw_weight, id(id) time(t) treat(a) treat_cov(k1 k2) ///
            wtype(iptw) scores nolog
        if _rc {
            local ++failed
            continue
        }
        * Capture the strain summaries here: iivw_fit overwrites r().
        local mw = r(max_weight)
        local er = r(ess_ratio)
        capture iivw_fit y a, timespec(linear) vce(fixed)
        if _rc {
            local ++failed
            continue
        }
        local bhat = _b[a]
        local sf   = _se[a]
        capture iivw_fit y a, timespec(linear) vce(stacked)
        if _rc {
            local ++failed
            continue
        }
        post `pf' (`bhat') (`sf') (_se[a]) (`mw') (`er')
        local ++kept
    }
}
postclose `pf'

* A cell that lost replications reports an empirical SD conditioned on
* convergence. Report the loss rather than dividing by whatever survived.
if `failed' > 0 {
    display as error ///
        "note: kept `kept'/`reps' replications; `failed' failed to fit"
}
if `kept' < 100 {
    display as error "too few replications to report"
    exit 2000
}

use "`out'", clear

summarize b, detail
local mean_b = r(mean)
local sd     = r(sd)
local iqrs   = (r(p75) - r(p25)) / 1.349
local skew   = r(skewness)
local kurt   = r(kurtosis)
local bias   = `mean_b' - `truth'

* Coverage of the nominal Wald intervals actually built by the package.
gen byte covf = abs(b - `truth') < 1.96 * sef
gen byte covs = abs(b - `truth') < 1.96 * ses

* The oracle: 1.96 * the empirical SD, i.e. the SE treated as known. No
* variance estimator can do better, so a deficit here is not the SE's fault.
gen byte covo = abs(b - `truth')  < 1.96 * `sd'
gen byte covoc = abs(b - `mean_b') < 1.96 * `sd'

* The studentized pivot: p95 of |t| is the critical value that WOULD give 95%
* coverage with the stacked SE exactly as computed.
gen double tstk = (b - `truth') / ses
gen double atstk = abs(tstk)

summarize covf
local cf = r(mean)
summarize covs
local cs = r(mean)
summarize covo
local co = r(mean)
summarize covoc
local coc = r(mean)

summarize sef, detail
local mf     = r(mean)
local medf   = r(p50)
summarize ses, detail
local ms     = r(mean)
local meds   = r(p50)

summarize tstk, detail
local t_sd   = r(sd)
local t_iqrs = (r(p75) - r(p25)) / 1.349
_pctile atstk, p(95)
local crit95 = r(r1)

summarize maxw, detail
local mw_p50 = r(p50)
local mw_p99 = r(p99)
summarize essr, detail
local er_p50 = r(p50)
local er_p05 = r(p5)

* Does the miss concentrate in the strained replications? If the stacked
* interval fails only where the weights blow up, that is the tail; if it fails
* uniformly across the strain distribution, it is the SE.
_pctile maxw, p(75)
local mw_cut = r(r1)
summarize covs if maxw <= `mw_cut'
local cs_lo = r(mean)
local n_lo  = r(N)
summarize covs if maxw > `mw_cut'
local cs_hi = r(mean)
local n_hi  = r(N)

display as text ""
display as text "probe_stacked_strain -- nsub=`nsub' pscoef=`pscoef' " ///
    "reps=`reps' seed=`seed' kept=`kept'"
display as text "DIAGNOSTIC ONLY. Not a coverage verdict for any gate."
display as text ""
display as text "sampling distribution of beta-hat (truth `truth')"
display as text "  mean       " %9.5f `mean_b' "   bias " %9.5f `bias' ///
    "   bias/empSD " %6.3f `bias'/`sd'
display as text "  empSD      " %9.5f `sd' "   IQR-scale " %9.5f `iqrs' ///
    "   SD/IQRscale " %6.3f `sd'/`iqrs'
display as text "  skewness   " %9.4f `skew' "   kurtosis  " %9.4f `kurt'
display as text ""
display as text "SE size, robust on both sides (median SE vs IQR-scale of b)"
display as text "  fixed    medSE " %9.5f `medf' "  medSE/IQRscale " %6.4f ///
    `medf'/`iqrs' "   meanSE/empSD " %6.4f `mf'/`sd'
display as text "  stacked  medSE " %9.5f `meds' "  medSE/IQRscale " %6.4f ///
    `meds'/`iqrs' "   meanSE/empSD " %6.4f `ms'/`sd'
display as text ""
display as text "coverage of the nominal 95% Wald interval"
display as text "  fixed                       " %6.4f `cf'
display as text "  stacked                     " %6.4f `cs'
display as text "  ORACLE  1.96*empSD          " %6.4f `co' ///
    "   <- no SE can beat this"
display as text "  ORACLE  1.96*empSD, centred " %6.4f `coc' ///
    "   <- bias removed"
display as text ""
display as text "studentized pivot t = (b - `truth') / stacked SE"
display as text "  SD " %7.4f `t_sd' "   IQR-scale " %7.4f `t_iqrs' ///
    "   p95 of |t| " %7.4f `crit95' "  (1.96 is nominal)"
display as text ""
display as text "weight strain"
display as text "  max weight  p50 " %9.4f `mw_p50' "  p99 " %9.4f `mw_p99'
display as text "  ESS ratio   p50 " %9.4f `er_p50' "  p5  " %9.4f `er_p05'
display as text "  stacked coverage, low-strain 75%%  " %6.4f `cs_lo' ///
    " (n=`n_lo')"
display as text "  stacked coverage, high-strain 25%% " %6.4f `cs_hi' ///
    " (n=`n_hi')"
display as text ""
display as text "READING"
display as text "  oracle near 0.95 and stacked below it  -> the SE is short"
display as text "  oracle itself well below 0.95          -> shape or bias, not the SE"
display as text "  centred oracle recovers 0.95           -> the gap is bias"
display as text "  p95 of |t| near 1.96                   -> the SE is calibrated;"
display as text "                                            the tail is elsewhere"
display as text ""
display as text "STRAIN: nsub=`nsub' pscoef=`pscoef' kept=`kept' " ///
    "bias_sd=" %6.3f `bias'/`sd' " sd_iqr=" %6.3f `sd'/`iqrs' ///
    " medratio=" %6.4f `meds'/`iqrs' " covs=" %6.4f `cs' ///
    " covf=" %6.4f `cf' " covo=" %6.4f `co' " covoc=" %6.4f `coc' ///
    " crit=" %6.4f `crit95'
