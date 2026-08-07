* =============================================================================
* probe_stacked_calibration.do - is the stacked sandwich the right SIZE?
* =============================================================================
* test_iivw_stacked.do proves the arithmetic: the inputs are Stata's own, the
* bread reproduces glm, and zeroing the derivative collapses stacked onto fixed.
* None of that establishes that the correction has the right magnitude, because
* every one of those identities would still hold if the cross-derivative G were
* scaled by a constant.
*
* This probe supplies the missing evidence by known-truth simulation, against a
* target that does not depend on the implementation: the empirical SD of the
* estimator across replications, and the realized coverage of the nominal 95%
* interval.
*
* DIAGNOSTIC, NOT A GATE. Nothing here may be relabelled as a coverage verdict
* for the FIPTIW gate (FIPTIW_NSCALE_2026-07-23.md:5-7). It is a different DGP,
* a different weight type, and a different sample size from the preregistered
* cell, and it is not run on the registered seeds. It is excluded from every
* standard lane for the same reason probe_cr_ladder.do is: it is an on-demand
* instrument, not a curated pass/fail suite.
*
* Design. IPTW with a CORRECTLY SPECIFIED propensity model, so the theoretical
* answer is known in advance: treating an estimated propensity score as known is
* conservative for the ATE, so the fixed sandwich must be too WIDE and the
* stacked one must be close to the empirical SD. A correction with the wrong
* sign would make the stacked interval wider still, and a mis-scaled one would
* miss the empirical SD by its scale factor. Neither could produce the result
* the mild cell reports.
*
* Two cells, and the contrast between them is the point:
*   mild    - moderate confounding; the sampling distribution is near-normal
*   strong  - strong confounding; positivity strain makes it heavy-tailed
* SD/IQR-scale is reported for each so a reader can tell which regime they are
* in before reading any ratio. Where that statistic is near 1 the empirical SD
* is a fair target; where it is not, the SD is inflated by a few replications
* and the robust scale is the honest comparison.
*
* Usage (from a scratch copy of the package, per the isolation rule):
*   stata-mp -b do probe_stacked_calibration.do [REPS] [SEED] [NSUB_STRONG]
* Defaults: REPS=250, SEED=770000, NSUB_STRONG=400. About 6 min per cell at
* REPS=250. NSUB_STRONG is separate because the strong cell is the one whose
* behaviour with n is open: raising it is how the n-scaling row in
* coverage_results/STACKED_2026-08-07.md was produced.
* =============================================================================

clear all
version 16.0
set varabbrev off

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "probe_stacked_calibration.do must be run from iivw/qa"
    exit 198
}
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap

local reps = 250
local seed = 770000
local nsub_strong = 400
if "`1'" != "" local reps = real("`1'")
if "`2'" != "" local seed = real("`2'")
if "`3'" != "" local nsub_strong = real("`3'")
if `reps' < 30 {
    display as error "REPS below 30 cannot support an empirical SD"
    exit 198
}

capture program drop stk_cell
program define stk_cell, rclass
    version 16.0
    syntax , NSub(integer) Reps(integer) PSCoef(real) Seed(integer) Tag(string)

    tempfile out
    tempname pf
    postfile `pf' double(b sef ses) using "`out'", replace

    local kept = 0
    forvalues r = 1/`reps' {
        quietly {
            clear
            set seed `=`seed' + `r''
            set obs `nsub'
            gen long id = _n
            gen double k1 = rnormal()
            gen double k2 = rnormal()
            * Treatment and outcome share k1 and k2, so the marginal model below
            * is confounded and the weighting is doing real work.
            gen byte a = runiform() < invlogit(`pscoef'*k1 - `=`pscoef'*0.8'*k2)
            expand 5
            bysort id: gen int j = _n
            gen double t = j
            gen double y = 1 + 0.5*a + 0.8*k1 - 0.6*k2 + 0.1*t + rnormal()
            sort id t

            capture iivw_weight, id(id) time(t) treat(a) treat_cov(k1 k2) ///
                wtype(iptw) scores nolog
            if _rc continue
            capture iivw_fit y a, timespec(linear) vce(fixed)
            if _rc continue
            local b  = _b[a]
            local sf = _se[a]
            capture iivw_fit y a, timespec(linear) vce(stacked)
            if _rc continue
            post `pf' (`b') (`sf') (_se[a])
            local ++kept
        }
    }
    postclose `pf'

    * A cell that lost replications is a cell whose empirical SD is conditioned
    * on convergence. Report the loss rather than dividing by whatever survived.
    if `kept' < `reps' {
        display as error ///
            "note: `tag' kept `kept'/`reps' replications; the rest failed to fit"
    }
    if `kept' < 30 {
        display as error "`tag': too few replications to report"
        exit 2000
    }

    preserve
    use "`out'", clear
    quietly summarize b, detail
    local sd    = r(sd)
    local iqrs  = (r(p75) - r(p25)) / 1.349
    quietly gen byte covf = abs(b - 0.5) < 1.96 * sef
    quietly gen byte covs = abs(b - 0.5) < 1.96 * ses
    quietly summarize covf
    local cf = r(mean)
    quietly summarize covs
    local cs = r(mean)
    quietly summarize sef
    local mf = r(mean)
    quietly summarize ses
    local ms = r(mean)
    restore

    display as text ""
    display as text "CELL `tag': nsub=`nsub' pscoef=`pscoef' kept=`kept'"
    display as text "  empirical SD  " %8.5f `sd' ///
        "   IQR-scale " %8.5f `iqrs' ///
        "   SD/IQR-scale " %5.3f `sd'/`iqrs'
    display as text "  fixed    meanSE " %8.5f `mf' ///
        "  /empSD " %6.4f `mf'/`sd' "  coverage " %5.3f `cf'
    display as text "  stacked  meanSE " %8.5f `ms' ///
        "  /empSD " %6.4f `ms'/`sd' "  coverage " %5.3f `cs'

    return scalar sd = `sd'
    return scalar iqrscale = `iqrs'
    return scalar fixed_ratio = `mf'/`sd'
    return scalar stacked_ratio = `ms'/`sd'
    return scalar fixed_cov = `cf'
    return scalar stacked_cov = `cs'
    return scalar kept = `kept'
end

display as text ""
display as text "probe_stacked_calibration -- REPS=`reps' SEED=`seed' NSUB_STRONG=`nsub_strong'"
display as text "DIAGNOSTIC ONLY. Not a coverage verdict for any gate."

stk_cell, nsub(400) reps(`reps') pscoef(0.5) seed(`seed') tag(mild)
local mild_stk_cov = r(stacked_cov)
local mild_fix_cov = r(fixed_cov)
local mild_stk_rat = r(stacked_ratio)
local mild_fix_rat = r(fixed_ratio)

stk_cell, nsub(`nsub_strong') reps(`reps') pscoef(1.2) seed(`seed') tag(strong)
local strong_stk_cov = r(stacked_cov)
local strong_fix_cov = r(fixed_cov)

display as text ""
display as text "Reading of the mild cell (the one with a near-normal sampling"
display as text "distribution, so the empirical SD is a fair target):"
display as text "  fixed   SE/empSD " %6.4f `mild_fix_rat' ///
    "  coverage " %5.3f `mild_fix_cov'
display as text "  stacked SE/empSD " %6.4f `mild_stk_rat' ///
    "  coverage " %5.3f `mild_stk_cov'
display as text ""
display as text "The strong cell is a positivity-strain regime. Read its"
display as text "SD/IQR-scale before its ratios: where that is well above 1 the"
display as text "empirical SD is inflated by a few replications and no variance"
display as text "estimator repairs a heavy-tailed pivot."
display as text ""
display as text "Executed record: coverage_results/STACKED_2026-08-07.md"
