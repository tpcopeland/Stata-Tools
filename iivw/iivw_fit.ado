*! iivw_fit Version 2.1.0  2026/07/21
*! Fit weighted outcome model for IIW/IPTW/FIPTIW analysis
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: eclass (returns results in e())

/*
Basic syntax:
  iivw_fit depvar [indepvars] [if] [in] , [options]

Description:
  Fits a weighted outcome model using weights from iivw_weight.
  Supports GEE (default) or mixed models. GEE uses independence
  working correlation as required by IIW theory.

Options:
  model(string)       - gee (default) or mixed
  family(string)      - GEE family (default: gaussian)
  link(string)        - GEE link (default: canonical)
  timespec(string)    - Time specification: linear, quadratic, cubic, ns(#), categorical, none
  interaction(varlist) - Create time x covariate interaction terms
  categorical(varlist)- Variables in indepvars to expand into dummies
  basecat(#)          - Reference category for categorical (default: lowest)
  timebasecat(#)      - Reference category for categorical time (default: lowest)
  cluster(varname)    - Cluster variable (default: id from metadata)
  bootstrap(#)        - Bootstrap replicates (0 = sandwich SE only)
  level(#)            - Confidence level (default: 95)
  nolog               - Suppress iteration log
  geeopts(string)     - Additional options passed to glm
  mixedopts(string)   - Additional options passed to mixed

See help iivw_fit for complete documentation
*/

program define iivw_fit, eclass
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off
    local __iivw_smcl_lb = char(123)
    local __iivw_smcl_rb = char(125)

    * Name-transaction state. Initialized before the captured block so the
    * cleanup zone can always roll back, however early an error fires.
    * __iivw_created_vars: every variable this call generated (dropped on error)
    * __iivw_bk_names/_temps: prior iivw outputs renamed aside (restored on error)
    local __iivw_created_vars ""
    local __iivw_bk_names ""
    local __iivw_bk_temps ""
    local __iivw_nonconv = 0

    capture noisily {

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================

    syntax varlist(numeric min=1) [if] [in] , ///
        [MODel(string) ///
         FAMily(string) LINk(string) ///
         TIMESpec(string) ///
         INTeraction(varlist numeric) ///
         CATEGorical(varlist numeric) ///
         BASEcat(string) ///
         TIMEBASEcat(string) ///
         CLuster(varname) ///
         UNWeighted ///
         ID(varname) TIME(varname) ///
         VCE(string asis) ///
         BOOTstrap(integer -999999) REFITweights ALLOWFAILEDReps ///
         Level(cilevel) noLOG ///
         REPLACE ALLOWNONCONVerged EXPERIMENTALmixed ///
         GEEopts(string asis) MIXEDopts(string asis) COLlect]

    * =========================================================================
    * CHECK PREREQUISITES
    * =========================================================================

    * Parse depvar and indepvars
    gettoken depvar indepvars : varlist

    * Defaults needed before metadata checks because timespec(none) does not
    * require a time variable in unweighted mode.
    if "`model'" == "" local model "gee"
    if "`family'" == "" local family "gaussian"
    if "`timespec'" == "" local timespec "linear"

    * bootstrap() default is an out-of-band SENTINEL so three states stay
    * distinct: option omitted (sentinel) triggers the cleared refit-bootstrap
    * default; an explicit bootstrap(0) is the legacy "no bootstrap, use the
    * fixed sandwich" spelling; and an explicit negative like bootstrap(-1) is an
    * INVALID value that must still error at the >= 0 check below. The sentinel is
    * far outside any value a user would type, so bootstrap(-1) is never mistaken
    * for "unset". Normalise only the sentinel back to 0.
    * (Broke test_iivw_expanded E21 and test_iivw_fit_adversarial A16 before this.)
    local _boot_sentinel = -999999
    local _boot_explicit = (`bootstrap' != `_boot_sentinel')
    if `bootstrap' == `_boot_sentinel' local bootstrap 0

    if "`unweighted'" == "" {
        if "`id'" != "" {
            display as error "id() is only allowed with unweighted"
            error 198
        }
        if "`time'" != "" {
            display as error "time() is only allowed with unweighted"
            error 198
        }

        _iivw_check_weighted
        _iivw_get_settings

        local panel_id   "`r(id)'"
        local panel_time "`r(time)'"
        local weighttype "`r(weighttype)'"
        local weight_var "`r(weight_var)'"
        local prefix     "`r(prefix)'"

        * Weight-construction replay spec (used only by refitweights bootstrap).
        *
        * visit_cov_raw and lagvars, NOT visit_covars. visit_covars is the union
        * -- raw covariates plus the generated *_lag1 columns -- and it is the
        * right thing to REPORT. It is the wrong thing to REPLAY with: handing it
        * to iivw_weight's visit_cov() passes the observed panel's precomputed
        * lags into a resampled panel as if they were raw data, so the lags are
        * never rebuilt within the draw and the terminal censoring row gets the
        * value from two visits back. The raw list plus the lag SOURCES lets each
        * replicate reconstruct its own lags with the same code that built the
        * observed weights.
        local rep_visitcov "`r(visit_cov_raw)'"
        local rep_lagvars  "`r(lagvars)'"
        local rep_allowmissw "`r(allowmissingweights)'"
        local rep_treat    "`r(treat)'"
        local rep_treatcov "`r(treat_covars)'"
        local rep_stabcov  "`r(stabcov)'"
        local rep_truncvisit "`r(truncvisit)'"
        local rep_trunctreat "`r(trunctreat)'"
        local rep_truncfinal "`r(truncfinal)'"
        local rep_efron    "`r(efron)'"
        local rep_entry    "`r(entry)'"
        local rep_baseevent "`r(baseevent)'"
        local rep_censor_mode "`r(censor_mode)'"
        local rep_censor_var  "`r(censor_var)'"
        local rep_maxfu       "`r(maxfu)'"
        local rep_treat_in_visit "`r(treat_in_visit)'"
    }
    else {
        local panel_id "`id'"
        local panel_time "`time'"
        if "`panel_time'" != "" {
            confirm numeric variable `panel_time'
        }
        if "`panel_id'" == "" {
            local panel_id : char _dta[_iivw_id]
        }
        if "`panel_time'" == "" {
            local panel_time : char _dta[_iivw_time]
        }
        if "`panel_id'" == "" {
            display as error "id() required with unweighted when no iivw metadata are present"
            error 198
        }
        if "`timespec'" != "none" & "`panel_time'" == "" {
            display as error "time() required with unweighted when timespec() is not none and no iivw metadata are present"
            error 198
        }

        local weighttype "unweighted"
        local weight_var ""
        local prefix "_iivw_"
    }

    * =========================================================================
    * VARIANCE CONTRACT: vce()
    * =========================================================================
    * The reliability-cleared inferential path is a subject-level bootstrap that
    * REFITS every nuisance model inside each draw, so the interval reflects the
    * uncertainty in estimating the weights and not just the outcome-model
    * uncertainty with the weights frozen. That is the variance Buzkova & Lumley
    * (2007) and Coulombe, Moodie & Platt (2021) actually derive.
    *
    * vce() is the contract for choosing it. The legacy bootstrap()/refitweights
    * spellings are retained as deprecated shims (they still work, with a note)
    * so existing analysis code does not break, but they are no longer the way to
    * ask for a variance: bootstrap(#) alone was ambiguous -- it meant "fixed
    * weights" only because refitweights was absent -- and vce() removes that
    * ambiguity by naming each method exactly once.
    *
    *   vce(bootstrap, reps(#) [seed(#)])   refit bootstrap  (recommended)
    *   vce(bootstrap, reps(#) fixedweights) bootstrap, weights held fixed
    *   vce(fixed)                          analytic cluster-robust sandwich
    *
    * vce(fixed) and the fixedweights bootstrap both treat the estimated weights
    * as KNOWN. Naming one of them explicitly IS the acknowledgment that the SE
    * omits nuisance-estimation uncertainty; the disclosure note still prints.
    * Preserve the outer if/in across the vce() suboption parse. That parse runs
    * a nested -syntax- on a rebuilt `0', which RESETS the `if'/`in' macros the
    * later -marksample- depends on. Without this save/restore, any iivw_fit that
    * combines an if/in restriction with vce() silently marks the WHOLE sample
    * and fits it at rc=0 -- a wrong sample reported as success. (Latent until the
    * Phase 3B call-site migration first combined if/in with vce(fixed); pinned by
    * test_iivw Test 85/Test 91.)
    local _iivw_if `"`if'"'
    local _iivw_in `"`in'"'
    local vce_seed ""
    if `"`vce'"' != "" {
        if `bootstrap' > 0 | "`refitweights'" != "" {
            display as error "specify the variance through vce() OR the legacy"
            display as error "  bootstrap()/refitweights options, not both"
            error 198
        }

        * Split "method , suboptions" on the first comma.
        gettoken _vcemethod _vcesub : vce, parse(",")
        local _vcemethod = strtrim("`_vcemethod'")
        local _vcesub = strtrim(`"`_vcesub'"')
        if substr(`"`_vcesub'"', 1, 1) == "," ///
            local _vcesub = strtrim(substr(`"`_vcesub'"', 2, .))

        if !inlist("`_vcemethod'", "bootstrap", "fixed") {
            display as error "vce() must be bootstrap or fixed"
            display as error "  vce(bootstrap, reps(#) [seed(#)])   refit bootstrap (recommended)"
            display as error "  vce(bootstrap, reps(#) fixedweights) bootstrap, weights held fixed"
            display as error "  vce(fixed)                          analytic sandwich (weights known)"
            error 198
        }

        * Parse the method-specific suboptions off a rebuilt command line. The
        * primary syntax has already been consumed, so reusing local 0 here is
        * safe and the sub-option names collide with nothing above.
        * Keep an explicit reps(0) or reps(-1) distinct from omission. Using 0
        * as syntax's default collapsed all three states: bootstrap typos
        * silently launched 999 draws, and fixed,reps(0) silently passed even
        * though fixed takes no suboptions.
        local _vce_reps_sentinel = -999999
        local 0 `", `_vcesub'"'
        capture syntax [, REPS(integer -999999) SEED(string) FIXEDWEIGHTS]
        if _rc {
            display as error "invalid vce() suboptions: `_vcesub'"
            display as error "  allowed: reps(#), seed(#), fixedweights"
            error 198
        }

        if "`_vcemethod'" == "fixed" {
            if `reps' != `_vce_reps_sentinel' | ///
                "`seed'" != "" | "`fixedweights'" != "" {
                display as error "vce(fixed) takes no suboptions"
                display as error "  it is the analytic cluster-robust sandwich; there are no replicates"
                error 198
            }
            local bootstrap 0
            local refitweights ""
        }
        else {
            * vce(bootstrap): the release-frozen default is 999 refit draws
            * (COVERAGE_R at contract freeze). reps() omitted takes 999; fewer
            * than two draws is rejected (a bootstrap variance is undefined from
            * a single replicate); fewer than 999 is allowed but stamped
            * uncleared-low-reps below, because the coverage gate was frozen at
            * 999 and a smaller run has not earned the release claim.
            if `reps' == `_vce_reps_sentinel' {
                local reps 999
            }
            if `reps' < 2 {
                display as error "vce(bootstrap) needs reps() >= 2"
                display as error "  a bootstrap variance is undefined from a single draw"
                display as error "  the release-cleared count is 999; omit reps() to get it"
                error 198
            }
            local bootstrap `reps'
            if "`fixedweights'" != "" {
                local refitweights ""
            }
            else {
                local refitweights "refitweights"
            }
            local vce_seed "`seed'"
        }
    }
    else if `bootstrap' > 0 | "`refitweights'" != "" {
        * Legacy spelling. Map is unchanged; just steer the user to vce().
        local _legacy_target "vce(bootstrap, reps(`bootstrap')"
        if "`refitweights'" == "" local _legacy_target "`_legacy_target' fixedweights"
        local _legacy_target "`_legacy_target')"
        display as text ///
            "note: bootstrap()/refitweights is deprecated; use `_legacy_target'"
    }
    else if "`weighttype'" != "unweighted" & "`model'" == "gee" & `_boot_explicit' == 0 {
        * ---------------------------------------------------------------------
        * THE CANDIDATE DEFAULT (IIVW-B02): a WEIGHTED model(gee) fit with no vce()
        * and no legacy spelling gets the 999-draw subject bootstrap that REFITS
        * every nuisance model inside each draw. Treating the estimated weights as
        * known (vce(fixed)) omits the weight-estimation term that both source
        * papers put inside the sandwich (B&L p.10-11; Coulombe PDF p.86), so it
        * is now an explicit opt-in, not the silent default it used to be.
        * model(mixed) is deliberately excluded: the weighted random-effects path
        * is experimental and never inherits the candidate default (it keeps the
        * analytic sandwich unless a variance is named explicitly).
        *
        * The refit bootstrap needs the stored replay contract (raw visit
        * covariates, treatment model, risk-set end); the block below already
        * errors with a precise message if iivw_weight was run before 2.0.0
        * separated them. Unweighted fits fall through this branch and keep the
        * analytic cluster sandwich -- they estimate no nuisance weights, so
        * there is nothing to propagate.
        * ---------------------------------------------------------------------
        local bootstrap 999
        local refitweights "refitweights"
        display as text ///
            "note: weighted fit with no vce(); using the default" ///
            " vce(bootstrap, reps(999)) [refit]"
        display as text ///
            "  for the weights-known analytic sandwich, request vce(fixed) explicitly"
        * A measured coverage shortfall must be visible at the point of use, not
        * only in a stored macro a user has to know to look for.
        if "`weighttype'" == "fiptiw" {
            display as text ///
                "  FIPTIW note: in the 2026-07-22 coverage study this interval" ///
                " covered 0.914, not 0.95"
            display as text ///
                "    (point estimate unbiased; interval ~14% too narrow)." ///
                " See {help iivw_fit##inference:inference status}."
        }
    }

    * =========================================================================
    * MARK SAMPLE
    * =========================================================================

    * Restore the outer if/in (see the save above): the vce() parse may have
    * cleared them, and marksample must see the user's real restriction.
    local if `"`_iivw_if'"'
    local in `"`_iivw_in'"'
    marksample touse

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        error 2000
    }
    local N = r(N)

    * =========================================================================
    * SET DEFAULTS
    * =========================================================================

    if "`cluster'" == "" local cluster "`panel_id'"

    * Extend markout to variables not in varlist(). strok: the cluster
    * variable (default: the subject id) may legitimately be a string;
    * without strok, markout silently marks EVERY observation out for a
    * string variable and the fit dies with a misleading "no observations".
    markout `touse' `cluster', strok
    if "`timespec'" != "none" {
        markout `touse' `panel_time'
    }
    if "`categorical'" != "" {
        markout `touse' `categorical'
    }
    if "`interaction'" != "" {
        markout `touse' `interaction'
    }

    * ---------------------------------------------------------------------
    * Outcome ELIGIBILITY, recorded before weight availability.
    *
    * `touse' is about to be marked out on the weight column, which is right
    * for the observed fit: a row with no weight cannot enter a weighted
    * estimating equation. It is wrong for the refit bootstrap, which
    * recomputes the weights inside every draw -- there, weight availability
    * is a property OF THE DRAW, not a fact to be frozen at the observed
    * sample. So snapshot eligibility here, one line before the weight
    * markout, and hand that marker to the bootstrap helper. The helper
    * re-applies its own draw's weight completeness (markout on the
    * recomputed weight) after it refits.
    *
    * This marker is also what keeps the resampling frame and the outcome
    * frame separate: the prefix now resamples the whole visit panel, and
    * this column -- a row attribute, so it travels with resampled rows --
    * decides which of those rows the outcome model is allowed to use.
    * ---------------------------------------------------------------------
    tempvar oc_touse
    quietly gen byte `oc_touse' = `touse'

    if "`weight_var'" != "" {
        markout `touse' `weight_var'
    }

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        error 2000
    }

    * Validate model type
    if !inlist("`model'", "gee", "mixed") {
        display as error "model() must be gee or mixed"
        error 198
    }

    if `bootstrap' < 0 | `bootstrap' == 1 {
        display as error "bootstrap() must be 0 or at least 2"
        display as error "  a bootstrap variance is undefined from one draw"
        error 198
    }

    * refitweights: re-estimate IIW/IPTW/FIPTIW weights inside each bootstrap
    * replicate so the interval reflects weight-estimation uncertainty, not just
    * outcome-model uncertainty with the weights held fixed.
    if "`refitweights'" != "" {
        if `bootstrap' == 0 {
            display as error "refitweights requires bootstrap(#) with # > 0"
            display as error "  it re-estimates the weights inside each bootstrap replicate"
            error 198
        }
        if "`unweighted'" != "" {
            display as error "refitweights is not compatible with unweighted"
            display as error "  there are no weights to re-estimate"
            error 198
        }
        if "`cluster'" != "`panel_id'" {
            display as error "refitweights resamples at the subject (id) level"
            display as error "  cluster() other than the panel id (`panel_id') is not supported with refitweights"
            error 198
        }
        * A contract written before 2.0.0 stored only the UNION of the raw visit
        * covariates and the generated lag columns, so the raw list is empty here
        * and the replay cannot be reconstructed. Refuse rather than fall back to
        * the union: falling back is precisely the defect this separation prevents.
        if inlist("`weighttype'", "iivw", "fiptiw") & "`rep_visitcov'" == "" {
            display as error "refitweights needs the stored raw visit-model covariates"
            display as error "  these weights were built before iivw 2.0.0 separated the raw"
            display as error "  covariates from the generated lag columns, so the replay cannot"
            display as error "  rebuild the lags inside each resampled subject"
            display as error "  re-run iivw_weight before iivw_fit, refitweights"
            error 198
        }

        * -----------------------------------------------------------------
        * The RESAMPLING FRAME is the visit panel, not the outcome sample.
        *
        * A refit bootstrap has to draw from the data the WEIGHT model was
        * estimated on, because that is the model each replicate re-estimates.
        * iivw_weight takes no if/in: it consumed every row in memory. So the
        * frame is the whole dataset, and the prefix must be given that frame
        * rather than `touse'.
        *
        * Handing the prefix `if `touse'' instead -- which is what every build
        * before 2.1 did -- silently deleted the monitoring-only rows before
        * the helper ever ran. A visit whose OUTCOME is missing is still a
        * visit: it is an event in the visit-intensity counting process, and
        * dropping it changes the intensity model, the weights, and therefore
        * the estimator being bootstrapped. A probe on 2026-07-21 with 668
        * panel rows and 581 outcome rows put the identity draw at 0.63015547
        * against an observed estimate of 0.63280949 -- every replicate was
        * bootstrapping a different estimator than the one being reported.
        *
        * bootstrap() drops rows with a missing cluster id rather than
        * erroring, which would silently shrink the frame back down. Prove the
        * frame is intact instead of assuming it.
        * -----------------------------------------------------------------
        tempvar bs_frame
        quietly gen byte `bs_frame' = 1

        quietly count if missing(`panel_id')
        if r(N) > 0 {
            local _n_badid = r(N)
            display as error "refitweights needs a complete visit panel to resample"
            display as error "  `_n_badid' observation(s) have a missing `panel_id'"
            display as error "  the weight model was fitted on every row in memory, so a row the"
            display as error "  resampler cannot place would change the estimator being"
            display as error "  bootstrapped; drop those rows before iivw_weight, or fix the id"
            error 459
        }
        if "`panel_time'" != "" {
            quietly count if missing(`panel_time')
            if r(N) > 0 {
                local _n_badtime = r(N)
                display as error "refitweights needs a complete visit panel to resample"
                display as error "  `_n_badtime' observation(s) have a missing `panel_time'"
                display as error "  the visit-intensity model cannot order a visit with no time"
                error 459
            }
        }
        if inlist("`weighttype'", "iptw", "fiptiw") & "`rep_treat'" == "" {
            display as error "refitweights needs the stored treatment-model contract"
            display as error "  re-run iivw_weight before iivw_fit, refitweights"
            error 198
        }
        if "`panel_time'" == "" & inlist("`weighttype'", "iivw", "fiptiw") {
            display as error "refitweights needs the stored panel time variable"
            display as error "  re-run iivw_weight before iivw_fit, refitweights"
            error 198
        }
        * Replay flags for the per-replicate iivw_weight call.
        * _iivw_baseevent stores exclude_base: 1 = baseline is study entry (the
        * 2.0.0 default), 0 = the legacy baseline-as-event contract, which the
        * replicates must opt back into explicitly.
        local rep_efron_flag = cond("`rep_efron'" != "", "efron", "")
        local rep_base_flag = cond("`rep_baseevent'" == "0", "baseline(event)", "baseline(entry)")

        * The replicates must rebuild the SAME risk set the observed weights were
        * built on. A bootstrap that refits the visit-intensity model on a
        * truncated risk set is bootstrapping a different estimator than the one
        * being reported, and its interval does not cover the reported point.
        if inlist("`weighttype'", "iivw", "fiptiw") {
            if "`rep_censor_mode'" == "" {
                display as error "refitweights needs the stored end-of-follow-up contract"
                display as error "  these weights were built before iivw 2.0.0 recorded the risk set"
                display as error "  re-run iivw_weight before iivw_fit, refitweights"
                error 198
            }
            if "`rep_censor_mode'" == "censor" {
                confirm numeric variable `rep_censor_var'
            }
        }
        local rep_cens_opt "endatlastvisit"
        if "`rep_censor_mode'" == "censor" local rep_cens_opt "censor(`rep_censor_var')"
        if "`rep_censor_mode'" == "maxfu"  local rep_cens_opt "maxfu(`rep_maxfu')"
        if "`weighttype'" == "iptw"        local rep_cens_opt ""

        * The observed weights were computed with rows left unweighted, and the
        * user acknowledged that. Replay the acknowledgment, or every replicate
        * that loses a row to the same missingness would hard-error instead.
        local rep_amw_flag = ///
            cond("`rep_allowmissw'" == "1", "allowmissingweights", "")

        * FIPTIW puts treat() in the visit-intensity denominator by construction,
        * so a replicate reproduces it without being told. The experimental
        * OPT-OUT has to be replayed explicitly: otherwise every draw would refit
        * a visit model that the observed pass never fitted, and the interval
        * would belong to an estimator the user never asked for. A stored contract
        * that predates the field cannot be replayed either way -- refuse it here
        * rather than guess, on the same footing as a missing risk-set contract.
        local rep_ntv_flag ""
        if "`weighttype'" == "fiptiw" {
            if "`rep_treat_in_visit'" == "" {
                display as error "refitweights needs the stored visit-model treatment contract"
                display as error "  these FIPTIW weights were built before iivw recorded whether"
                display as error "  treat() is in the visit-intensity model, so the replicates"
                display as error "  cannot reproduce the visit model they came from"
                display as error "  re-run iivw_weight before iivw_fit, refitweights"
                error 198
            }
            if "`rep_treat_in_visit'" == "0" {
                local rep_ntv_flag "experimentalnotreatvisit"
            }
        }

        * The lag sources must still be in the data to be re-lagged per draw.
        if "`rep_lagvars'" != "" {
            foreach v of local rep_lagvars {
                capture confirm numeric variable `v'
                if _rc {
                    display as error "refitweights needs the raw lag source `v', which is not in the data"
                    display as error "  the replicates rebuild lagvars() from the source variables"
                    error 111
                }
            }
        }
    }

    * =========================================================================
    * PANEL / CLUSTER NESTING
    * =========================================================================
    * A cluster bootstrap resamples whole clusters and then rebuilds the panel
    * unit inside each draw as group(draw, panel_id). That is only meaningful if
    * every panel unit lives in exactly one cluster. A subject whose rows span
    * two clusters would be silently split into two "subjects" by one draw and
    * duplicated by another -- an incoherent resampling scheme reported as if it
    * were a valid one. Refuse it.
    if `bootstrap' > 0 & "`cluster'" != "`panel_id'" {
        tempvar _iivw_ncl
        quietly bysort `panel_id' (`cluster'): gen long `_iivw_ncl' = ///
            sum(`cluster' != `cluster'[_n-1]) if `touse'
        quietly bysort `panel_id' (`cluster'): replace `_iivw_ncl' = ///
            `_iivw_ncl'[_N] if `touse'
        quietly count if `_iivw_ncl' > 1 & `touse'
        if r(N) > 0 {
            quietly levelsof `panel_id' if `_iivw_ncl' > 1 & `touse', local(_bad_ids)
            local _n_bad : word count `_bad_ids'
            display as error "panel unit is not nested within cluster()"
            display as error "  `_n_bad' `panel_id' value(s) appear in more than one `cluster'"
            display as error "  a cluster bootstrap resamples whole clusters and rebuilds each"
            display as error "  subject inside the draw, which requires one cluster per subject"
            error 459
        }
        drop `_iivw_ncl'
    }

    * collect is only wired into the non-bootstrap model(gee) path; refuse it
    * elsewhere rather than silently ignoring it.
    if "`collect'" != "" {
        if c(stata_version) < 17 {
            display as error "collect requires Stata 17 or later"
            error 198
        }
        if "`model'" == "mixed" {
            display as error "collect is only supported with model(gee)"
            display as error "  the collect: prefix is not applied to mixed models"
            error 198
        }
        if `bootstrap' > 0 {
            display as error "collect is not supported with bootstrap()"
            display as error "  the collect: prefix is not applied to bootstrap fits"
            error 198
        }
    }

    * Validate time spec
    if regexm("`timespec'", "^ns\(([0-9]+)\)$") {
        * Natural spline - valid
    }
    else if !inlist("`timespec'", "linear", "quadratic", "cubic", "categorical", "none") {
        display as error "timespec() must be linear, quadratic, cubic, ns(#), categorical, or none"
        error 198
    }

    * =========================================================================
    * PROTECTED INPUTS
    * =========================================================================
    * Every variable the user handed us as science, in any role. No generated
    * time term, dummy, or interaction may take one of these names -- replace
    * authorizes overwriting a prior iivw output, never destroying an input.
    * Each creation site below claims its name against this list BEFORE writing,
    * and renames any prior output aside rather than dropping it, so an error at
    * any point rolls the whole dataset back.

    local __iivw_protected ///
        "`depvar' `indepvars' `panel_id' `panel_time' `cluster' `weight_var'"
    local __iivw_protected ///
        "`__iivw_protected' `categorical' `interaction'"
    local __iivw_protected : list uniq __iivw_protected

    if "`timebasecat'" != "" & "`timespec'" != "categorical" {
        display as error "timebasecat() requires timespec(categorical)"
        error 198
    }
    if "`timebasecat'" != "" {
        capture confirm number `timebasecat'
        if _rc {
            display as error "timebasecat() must be numeric"
            error 198
        }
    }

    * Validate interaction + timespec compatibility
    if "`interaction'" != "" & "`timespec'" == "none" {
        display as error "interaction() requires time variables; not compatible with timespec(none)"
        error 198
    }

    * Reject panel time variable in indepvars when timespec auto-adds it.
    * Including both produces a duplicate column (silently dropped as
    * collinear by glm/mixed) and a misleading row in the effects table.
    if "`timespec'" != "none" {
        foreach ipred of local indepvars {
            if "`ipred'" == "`panel_time'" {
                display as error ///
                    "`panel_time' (panel time variable) is in indepvars but timespec(`timespec') also adds it"
                display as error ///
                    "  remove `panel_time' from indepvars, or use timespec(none) to suppress automatic time terms"
                error 198
            }
        }
    }

    * Validate categorical/basecat options
    if "`basecat'" != "" & "`categorical'" == "" {
        display as error "basecat() requires categorical()"
        error 198
    }
    if "`basecat'" != "" {
        capture confirm integer number `basecat'
        if _rc {
            display as error "basecat() must be an integer"
            error 198
        }
    }

    * Mixed model requires Stata 17+
    if "`model'" == "mixed" {
        if c(stata_version) < 17 {
            display as error "mixed model requires Stata 17 or later"
            error 198
        }
    }

    local log_opt ""
    if "`log'" == "nolog" local log_opt "nolog"

    * =========================================================================
    * DISPLAY HEADER
    * =========================================================================

    local wtype_display = upper("`weighttype'")
    local header_wtype "`wtype_display'"
    local fit_display "Weighted Outcome Model"
    if "`unweighted'" != "" {
        local header_wtype "Unweighted"
        local fit_display "Outcome Model"
    }

    display as text ""
    display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"
    display as result "iivw_fit" as text " - `header_wtype' `fit_display'"
    display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"
    display as text ""
    display as text "Model type:       " as result "`model'"
    display as text "Outcome:          " as result "`depvar'"
    local predictor_display "`indepvars'"
    if "`predictor_display'" == "" local predictor_display "(none)"
    display as text "Predictors:       " as result "`predictor_display'"
    display as text "Time spec:        " as result "`timespec'"
    if "`interaction'" != "" {
        display as text "Interactions:     " as result "`interaction'"
    }
    if "`categorical'" != "" {
        display as text "Categorical:      " as result "`categorical'"
        if "`basecat'" != "" {
            display as text "Base category:    " as result "`basecat'"
        }
    }
    if "`model'" == "gee" {
        display as text "Family:           " as result "`family'"
        if "`link'" != "" {
            display as text "Link:             " as result "`link'"
        }
        display as text "Estimation:       " as result "GLM with clustered robust SEs"
    }
    if "`unweighted'" != "" {
        display as text "Weight var:       " as result "(none, unweighted)"
    }
    else {
        display as text "Weight var:       " as result "`weight_var'"
    }
    display as text "Cluster var:      " as result "`cluster'"
    if `bootstrap' > 0 {
        display as text "Bootstrap reps:   " as result "`bootstrap'"
        if "`refitweights'" != "" {
            display as text "Bootstrap weights:" as result ///
                " re-estimated per replicate (propagates weight uncertainty)"
        }
        else if "`unweighted'" == "" {
            display as text "Bootstrap weights:" as result " held fixed"
        }
    }
    display as text ""

    * =========================================================================
    * BUILD TIME SPECIFICATION VARIABLES
    * =========================================================================

    * Every design column this command generates is a package output owned under
    * this prefix in the `design' role. `replace' overwrites one of ours; it does
    * not overwrite a user column that happens to share the name. See _iivw_own.
    _iivw_own token, role(design) prefix(`prefix')
    local __iivw_design_token "`r(token)'"

    * Prior fit metadata is NOT cleared here. Under the name transaction, every
    * generated variable is created fresh and every prior output is renamed aside
    * rather than dropped, so an error below restores the previous fit's variables
    * exactly -- and the previous contract still describes them truthfully. State
    * is cleared and rewritten atomically at the commit point, once the outcome
    * model has actually converged.

    local time_vars ""
    local time_vars_created ""
    local time_cat_vars_created ""
    local time_basecat_used ""

    if "`timespec'" != "none" {
        if "`timespec'" == "categorical" {
            quietly levelsof `panel_time' if `touse', local(time_levels)
            local n_time_levels : word count `time_levels'

            if `n_time_levels' < 2 {
                display as error "timespec(categorical) requires at least two observed time categories"
                error 198
            }

            local base_time : word 1 of `time_levels'
            if "`timebasecat'" != "" {
                local tbase_found = 0
                foreach tlev of local time_levels {
                    if `tlev' == `timebasecat' local tbase_found = 1
                }
                if `tbase_found' == 1 {
                    local base_time "`timebasecat'"
                }
                else {
                    display as text "note: timebasecat(`timebasecat') not found in `panel_time'; using lowest value"
                }
            }
            local time_basecat_used "`base_time'"

            local tvar_vallbl : value label `panel_time'
            local tvar_label : variable label `panel_time'
            if `"`tvar_label'"' == "" local tvar_label "`panel_time'"

            local base_text : display %9.0g `base_time'
            local base_text = strtrim("`base_text'")
            if "`tvar_vallbl'" != "" & floor(`base_time') == `base_time' {
                local base_ltext : label `tvar_vallbl' `base_time'
                if `"`base_ltext'"' != "" local base_text `"`base_ltext'"'
            }

            local tcat_index = 0
            foreach tlev of local time_levels {
                if `tlev' == `base_time' continue
                local ++tcat_index

                local tcat_name "`prefix'tcat_`tcat_index'"
                _iivw_reserve_names, generated(`tcat_name') ///
                    owntokens(`__iivw_design_token') ///
                    protected(`__iivw_protected') `replace' context(iivw_fit)
                capture confirm variable `tcat_name'
                if _rc == 0 {
                    tempvar __iivw_bk
                    quietly rename `tcat_name' `__iivw_bk'
                    local __iivw_bk_names "`__iivw_bk_names' `tcat_name'"
                    local __iivw_bk_temps "`__iivw_bk_temps' `__iivw_bk'"
                }
                local __iivw_created_vars "`__iivw_created_vars' `tcat_name'"

                local lev_text : display %9.0g `tlev'
                local lev_text = strtrim("`lev_text'")
                if "`tvar_vallbl'" != "" & floor(`tlev') == `tlev' {
                    local lev_ltext : label `tvar_vallbl' `tlev'
                    if `"`lev_ltext'"' != "" local lev_text `"`lev_ltext'"'
                }

                gen byte `tcat_name' = (`panel_time' == `tlev') if `touse'
                label variable `tcat_name' `"`tvar_label': `lev_text' (vs. `base_text')"'
                local time_vars "`time_vars' `tcat_name'"
                local time_vars_created "`time_vars_created' `tcat_name'"
                local time_cat_vars_created "`time_cat_vars_created' `tcat_name'"
            }
        }
        else {
            local time_vars "`panel_time'"

            if inlist("`timespec'", "quadratic", "cubic") {
                _iivw_reserve_names, generated(`prefix'time_sq) ///
                    owntokens(`__iivw_design_token') ///
                    protected(`__iivw_protected') `replace' context(iivw_fit)
                capture confirm variable `prefix'time_sq
                if _rc == 0 {
                    tempvar __iivw_bk
                    quietly rename `prefix'time_sq `__iivw_bk'
                    local __iivw_bk_names "`__iivw_bk_names' `prefix'time_sq"
                    local __iivw_bk_temps "`__iivw_bk_temps' `__iivw_bk'"
                }
                local __iivw_created_vars "`__iivw_created_vars' `prefix'time_sq"
                gen double `prefix'time_sq = `panel_time'^2
                label variable `prefix'time_sq "Time squared"
                local time_vars "`time_vars' `prefix'time_sq"
                local time_vars_created "`time_vars_created' `prefix'time_sq"
            }
            if "`timespec'" == "cubic" {
                _iivw_reserve_names, generated(`prefix'time_cu) ///
                    owntokens(`__iivw_design_token') ///
                    protected(`__iivw_protected') `replace' context(iivw_fit)
                capture confirm variable `prefix'time_cu
                if _rc == 0 {
                    tempvar __iivw_bk
                    quietly rename `prefix'time_cu `__iivw_bk'
                    local __iivw_bk_names "`__iivw_bk_names' `prefix'time_cu"
                    local __iivw_bk_temps "`__iivw_bk_temps' `__iivw_bk'"
                }
                local __iivw_created_vars "`__iivw_created_vars' `prefix'time_cu"
                gen double `prefix'time_cu = `panel_time'^3
                label variable `prefix'time_cu "Time cubed"
                local time_vars "`time_vars' `prefix'time_cu"
                local time_vars_created "`time_vars_created' `prefix'time_cu"
            }
            if regexm("`timespec'", "^ns\(([0-9]+)\)$") {
                local ns_df = regexs(1)

                * Use the same natural spline approach as msm
                * Generate basis variables inline
                local n_knots = `ns_df' + 1

                quietly summarize `panel_time' if `touse'
                local xmin = r(min)
                local xmax = r(max)
                local xrange = `xmax' - `xmin'

                if `xrange' == 0 {
                    display as error "time variable has no variation"
                    error 198
                }

                if `ns_df' == 1 {
                    _iivw_reserve_names, generated(`prefix'tns1) ///
                        owntokens(`__iivw_design_token') ///
                    protected(`__iivw_protected') `replace' context(iivw_fit)
                    capture confirm variable `prefix'tns1
                    if _rc == 0 {
                        tempvar __iivw_bk
                        quietly rename `prefix'tns1 `__iivw_bk'
                        local __iivw_bk_names "`__iivw_bk_names' `prefix'tns1"
                        local __iivw_bk_temps "`__iivw_bk_temps' `__iivw_bk'"
                    }
                    local __iivw_created_vars "`__iivw_created_vars' `prefix'tns1"
                    gen double `prefix'tns1 = `panel_time'
                    local time_vars "`prefix'tns1"
                    local time_vars_created "`prefix'tns1"
                }
                else {
                    * Calculate knot positions
                    local n_internal = `ns_df' - 1
                    forvalues k = 1/`n_internal' {
                        local pct = 100 * `k' / (`n_internal' + 1)
                        quietly _pctile `panel_time' if `touse', percentiles(`pct')
                        local knot`k' = r(r1)
                    }
                    local knot0 = `xmin'
                    local knot`ns_df' = `xmax'

                    * Require strictly increasing knots to avoid division-by-zero
                    local knots ""
                    forvalues k = 0/`ns_df' {
                        local knots "`knots' `knot`k''"
                    }
                    local uniq_knots : list uniq knots
                    local n_knots : word count `knots'
                    local n_uniq  : word count `uniq_knots'
                    if `n_uniq' < `n_knots' {
                        display as error "ns(`ns_df') produced tied knots (time variable has many ties)"
                        display as error "reduce ns() degrees of freedom or use a coarser time scale"
                        error 198
                    }

                    * First basis: linear time
                    _iivw_reserve_names, generated(`prefix'tns1) ///
                        owntokens(`__iivw_design_token') ///
                    protected(`__iivw_protected') `replace' context(iivw_fit)
                    capture confirm variable `prefix'tns1
                    if _rc == 0 {
                        tempvar __iivw_bk
                        quietly rename `prefix'tns1 `__iivw_bk'
                        local __iivw_bk_names "`__iivw_bk_names' `prefix'tns1"
                        local __iivw_bk_temps "`__iivw_bk_temps' `__iivw_bk'"
                    }
                    local __iivw_created_vars "`__iivw_created_vars' `prefix'tns1"
                    gen double `prefix'tns1 = `panel_time'
                    local time_vars "`prefix'tns1"
                    local time_vars_created "`prefix'tns1"

                    * Harrell restricted cubic spline
                    * K-2 nonlinear bases using knots 0..n_internal-1
                    local t_last = `knot`ns_df''
                    local t_pen  = `knot`n_internal''
                    local jmax = `n_internal' - 1

                    forvalues j = 0/`jmax' {
                        local jj = `j' + 2
                        _iivw_reserve_names, generated(`prefix'tns`jj') ///
                            owntokens(`__iivw_design_token') ///
                    protected(`__iivw_protected') `replace' context(iivw_fit)
                        capture confirm variable `prefix'tns`jj'
                        if _rc == 0 {
                            tempvar __iivw_bk
                            quietly rename `prefix'tns`jj' `__iivw_bk'
                            local __iivw_bk_names "`__iivw_bk_names' `prefix'tns`jj'"
                            local __iivw_bk_temps "`__iivw_bk_temps' `__iivw_bk'"
                        }
                        local __iivw_created_vars "`__iivw_created_vars' `prefix'tns`jj'"
                        gen double `prefix'tns`jj' = ///
                            (max(0, `panel_time' - `knot`j'')^3 - ///
                             max(0, `panel_time' - `t_last')^3) / ///
                            (`t_last' - `knot`j'') - ///
                            (max(0, `panel_time' - `t_pen')^3 - ///
                             max(0, `panel_time' - `t_last')^3) / ///
                            (`t_last' - `t_pen')
                        local time_vars "`time_vars' `prefix'tns`jj'"
                        local time_vars_created "`time_vars_created' `prefix'tns`jj'"
                    }
                }
            }
        }
    }
    local time_vars = strtrim("`time_vars'")
    local time_vars_created = strtrim("`time_vars_created'")
    local time_cat_vars_created = strtrim("`time_cat_vars_created'")

    * =========================================================================
    * EXPAND CATEGORICAL VARIABLES
    * =========================================================================

    local expanded_indepvars "`indepvars'"
    local cat_vars_created ""
    local expanded_interaction "`interaction'"
    local all_cat_names ""

    * Running inventory of every name this call has already committed to, and a
    * monotone counter for the collision-proof indexed fallback. Seeded with the
    * time terms so a dummy can never take a time term's name.
    local all_gen_names "`time_vars_created'"
    local cat_seq = 0

    if "`categorical'" != "" {

        * Validate all categorical vars are in indepvars
        foreach cvar of local categorical {
            local found_in_indep = 0
            foreach ipred of local indepvars {
                if "`cvar'" == "`ipred'" local found_in_indep = 1
            }
            if `found_in_indep' == 0 {
                display as error "`cvar' in categorical() not found in predictor variables"
                error 198
            }
        }

        foreach cvar of local categorical {

            * Validate integer values
            quietly count if `touse' & `cvar' != int(`cvar') & !missing(`cvar')
            if r(N) > 0 {
                display as error "`cvar' in categorical() contains non-integer values"
                error 198
            }

            * Get unique levels
            quietly levelsof `cvar' if `touse', local(levels)
            local n_levels : word count `levels'

            if `n_levels' < 2 {
                display as error "`cvar' in categorical() has fewer than 2 unique values"
                error 198
            }

            * Determine base category
            local base_val : word 1 of `levels'
            if "`basecat'" != "" {
                local base_found = 0
                foreach lev of local levels {
                    if `lev' == `basecat' local base_found = 1
                }
                if `base_found' == 1 {
                    local base_val = `basecat'
                }
                else {
                    display as text "note: basecat(`basecat') not found in `cvar'; using lowest value"
                }
            }

            * Get value label name and base label
            local cvar_vallbl : value label `cvar'
            local base_label ""
            if "`cvar_vallbl'" != "" {
                local base_label : label `cvar_vallbl' `base_val'
            }

            * First pass: build sanitized names and check for collisions
            local collision = 0
            local n_nonbase = 0

            if "`cvar_vallbl'" != "" {
                foreach lev of local levels {
                    if `lev' == `base_val' continue
                    local ++n_nonbase
                    local lev_label : label `cvar_vallbl' `lev'

                    * Sanitize: lowercase, common separators to underscores,
                    * strip non-alphanumeric, collapse underscores
                    local san = lower(`"`lev_label'"')
                    local san = subinstr(`"`san'"', " ", "_", .)
                    local san = subinstr(`"`san'"', "-", "_", .)
                    local san = subinstr(`"`san'"', "/", "_", .)
                    local san = subinstr(`"`san'"', ".", "_", .)
                    local san = ustrregexra(`"`san'"', "[^a-z0-9_]", "")
                    while strpos("`san'", "__") > 0 {
                        local san = subinstr("`san'", "__", "_", .)
                    }
                    while substr("`san'", 1, 1) == "_" & strlen("`san'") > 1 {
                        local san = substr("`san'", 2, .)
                    }
                    while substr("`san'", -1, 1) == "_" & strlen("`san'") > 1 {
                        local san = substr("`san'", 1, strlen("`san'") - 1)
                    }

                    if strlen("`san'") == 0 local collision = 1
                    local san_`n_nonbase' "`san'"
                }

                * Detect collisions between sanitized names
                forvalues i = 1/`n_nonbase' {
                    forvalues j = `=`i'+1'/`n_nonbase' {
                        if "`san_`i''" == "`san_`j''" local collision = 1
                    }
                }
            }

            * Check for cross-variable collisions with previously created names
            if "`cvar_vallbl'" != "" & `collision' == 0 {
                forvalues i = 1/`n_nonbase' {
                    local test_name "`prefix'cat_`san_`i''"
                    foreach prev of local all_cat_names {
                        if "`test_name'" == "`prev'" local collision = 1
                    }
                }
            }

            * Second pass: generate dummies
            local dummy_list ""
            local san_idx = 0

            foreach lev of local levels {
                if `lev' == `base_val' continue
                local ++san_idx

                if "`cvar_vallbl'" != "" & `collision' == 0 {
                    * Label-based naming
                    local vname "`prefix'cat_`san_`san_idx''"
                    local lev_label : label `cvar_vallbl' `lev'
                    local vlabel `"`lev_label' (vs. `base_label')"'
                }
                else {
                    * Numeric naming fallback
                    local lev_suffix : display %9.0g `lev'
                    local lev_suffix = strtrim("`lev_suffix'")
                    local lev_suffix = subinstr("`lev_suffix'", "-", "m", .)
                    local lev_suffix = subinstr("`lev_suffix'", "+", "p", .)
                    local lev_suffix = subinstr("`lev_suffix'", ".", "p", .)
                    local vname "`prefix'cat_`cvar'_`lev_suffix'"
                    if "`base_label'" != "" {
                        local vlabel `"`cvar'=`lev' (vs. `base_label')"'
                    }
                    else {
                        local vlabel "`cvar'=`lev' (vs. `base_val')"
                    }
                }

                * ---------------------------------------------------------
                * Guarantee a unique, legal name for this level.
                *
                * The natural name can exceed 32 characters (a long generate()
                * prefix plus a long variable name plus a wide level value).
                * Blind truncation is what made two levels collapse onto one
                * 32-char name, silently pooling a level into the base category
                * with rc 0. So: if the natural name is too long, or would
                * duplicate a name already assigned, fall back to a short
                * deterministic indexed name that cannot collide. Uniqueness is
                * asserted after the final transformation and before any data is
                * touched.
                * ---------------------------------------------------------
                local ++cat_seq
                local name_ok = 1
                if strlen("`vname'") > 32 local name_ok = 0
                foreach prev of local all_gen_names {
                    if "`vname'" == "`prev'" local name_ok = 0
                }
                if `name_ok' == 0 {
                    local vname "`prefix'cat_`cat_seq'"
                    display as text "note: `cvar'=`lev' indicator named `vname'" ///
                        " (the natural name was too long or not unique)"
                }

                * The indexed fallback is short by construction, but assert the
                * postconditions rather than trusting that: a duplicate name here
                * is exactly the silent-wrong-design-matrix defect.
                if strlen("`vname'") > 32 {
                    display as error "cannot build a legal 32-character name for `cvar'=`lev'"
                    display as error "  use a shorter generate() prefix in iivw_weight"
                    error 198
                }
                foreach prev of local all_gen_names {
                    if "`vname'" == "`prev'" {
                        display as error "generated name `vname' is not unique for `cvar'=`lev'"
                        display as error "  use a shorter generate() prefix in iivw_weight"
                        error 198
                    }
                }

                _iivw_reserve_names, generated(`vname') ///
                    owntokens(`__iivw_design_token') ///
                    protected(`__iivw_protected') `replace' context(iivw_fit)
                capture confirm variable `vname'
                if _rc == 0 {
                    tempvar __iivw_bk
                    quietly rename `vname' `__iivw_bk'
                    local __iivw_bk_names "`__iivw_bk_names' `vname'"
                    local __iivw_bk_temps "`__iivw_bk_temps' `__iivw_bk'"
                }
                local __iivw_created_vars "`__iivw_created_vars' `vname'"
                quietly gen byte `vname' = (`cvar' == `lev') if `touse'
                label variable `vname' `"`vlabel'"'
                local dummy_list "`dummy_list' `vname'"
                local cat_vars_created "`cat_vars_created' `vname'"
                local all_cat_names "`all_cat_names' `vname'"
                local all_gen_names "`all_gen_names' `vname'"
            }

            * Replace original var in expanded_indepvars with dummies
            local new_indepvars ""
            foreach v of local expanded_indepvars {
                if "`v'" == "`cvar'" {
                    local new_indepvars "`new_indepvars'`dummy_list'"
                }
                else {
                    local new_indepvars "`new_indepvars' `v'"
                }
            }
            local expanded_indepvars "`new_indepvars'"

            * Replace in interaction if present
            if "`expanded_interaction'" != "" {
                local new_interaction ""
                foreach v of local expanded_interaction {
                    if "`v'" == "`cvar'" {
                        local new_interaction "`new_interaction'`dummy_list'"
                    }
                    else {
                        local new_interaction "`new_interaction' `v'"
                    }
                }
                local expanded_interaction "`new_interaction'"
            }
        }
    }

    * =========================================================================
    * BUILD INTERACTION VARIABLES
    * =========================================================================

    local ix_vars ""
    local ix_vars_created ""

    if "`expanded_interaction'" != "" {

        * Warn if interaction variable not in predictors (no main effect)
        foreach ivar of local expanded_interaction {
            local found_main = 0
            foreach ipred of local expanded_indepvars {
                if "`ivar'" == "`ipred'" local found_main = 1
            }
            if `found_main' == 0 {
                display as text "note: `ivar' specified in interaction() but not in predictors"
            }
        }

        foreach ivar of local expanded_interaction {
            foreach tvar of local time_vars {

                * Map time variable to suffix
                local tvar_is_cat = 0
                if "`tvar'" == "`panel_time'" {
                    local suffix "time"
                }
                else if "`tvar'" == "`prefix'time_sq" {
                    local suffix "tsq"
                }
                else if "`tvar'" == "`prefix'time_cu" {
                    local suffix "tcu"
                }
                else if substr("`tvar'", 1, strlen("`prefix'tcat_")) == "`prefix'tcat_" {
                    local suffix = substr("`tvar'", strlen("`prefix'") + 1, .)
                    local tvar_is_cat = 1
                }
                else {
                    * Spline basis: strip prefix to get tnsN
                    local suffix = substr("`tvar'", strlen("`prefix'") + 1, .)
                }

                * Determine covariate portion of name
                * Strip _iivw_cat_ prefix from categorical dummies for clean naming
                local cat_prefix_str "`prefix'cat_"
                local cat_prefix_len = strlen("`cat_prefix_str'")
                local is_cat_dummy = (substr("`ivar'", 1, `cat_prefix_len') == "`cat_prefix_str'")
                if `is_cat_dummy' {
                    local ivar_portion = substr("`ivar'", `cat_prefix_len' + 1, .)
                }
                else {
                    local ivar_portion "`ivar'"
                }

                * Build variable name
                local ix_name "`prefix'ix_`ivar_portion'_`suffix'"

                * Truncate covariate portion if name > 32 chars
                if strlen("`ix_name'") > 32 {
                    local max_covar = 32 - strlen("`prefix'ix_") - strlen("_`suffix'")
                    if `max_covar' < 1 {
                        display as error "interaction variable name cannot be made valid with prefix `prefix' and suffix `suffix'"
                        display as error "use a shorter generate() prefix in iivw_weight"
                        error 198
                    }
                    local ivar_trunc = substr("`ivar_portion'", 1, `max_covar')
                    local ix_name "`prefix'ix_`ivar_trunc'_`suffix'"
                    display as text "note: interaction variable name truncated to `ix_name'"
                }

                * Check against every name already committed to, not just other
                * interactions: a truncated interaction name must not shadow a
                * time term or a categorical dummy either.
                local ix_duplicate = 0
                foreach prev of local all_gen_names {
                    if "`ix_name'" == "`prev'" local ix_duplicate = 1
                }
                if `ix_duplicate' {
                    display as error "interaction variable name collision after truncation: `ix_name'"
                    display as error "rename long interaction variables or use a shorter generate() prefix"
                    error 198
                }
                local all_gen_names "`all_gen_names' `ix_name'"

                _iivw_reserve_names, generated(`ix_name') ///
                    owntokens(`__iivw_design_token') ///
                    protected(`__iivw_protected') `replace' context(iivw_fit)
                capture confirm variable `ix_name'
                if _rc == 0 {
                    tempvar __iivw_bk
                    quietly rename `ix_name' `__iivw_bk'
                    local __iivw_bk_names "`__iivw_bk_names' `ix_name'"
                    local __iivw_bk_temps "`__iivw_bk_temps' `__iivw_bk'"
                }
                local __iivw_created_vars "`__iivw_created_vars' `ix_name'"
                gen double `ix_name' = `ivar' * `tvar'

                local ix_time_part "`suffix'"
                if `tvar_is_cat' {
                    local tvar_clean : variable label `tvar'
                    local tvs_pos = strpos(`"`tvar_clean'"', " (vs.")
                    if `tvs_pos' > 0 {
                        local tvar_clean = substr(`"`tvar_clean'"', 1, `tvs_pos' - 1)
                    }
                    if `"`tvar_clean'"' != "" {
                        local ix_time_part `"`tvar_clean'"'
                    }
                }

                * Build label: use clean label for categorical dummies
                if `is_cat_dummy' {
                    local ivar_label : variable label `ivar'
                    local vs_pos = strpos(`"`ivar_label'"', " (vs.")
                    if `vs_pos' > 0 {
                        local ivar_clean = substr(`"`ivar_label'"', 1, `vs_pos' - 1)
                    }
                    else {
                        local ivar_clean `"`ivar_label'"'
                    }
                    label variable `ix_name' `"`ivar_clean' x `ix_time_part'"'
                }
                else {
                    label variable `ix_name' `"`ivar' x `ix_time_part'"'
                }

                local ix_vars "`ix_vars' `ix_name'"
                local ix_vars_created "`ix_vars_created' `ix_name'"
            }
        }
    }

    * =========================================================================
    * BUILD COVARIATE LIST
    * =========================================================================

    local all_covars "`expanded_indepvars'"
    if "`time_vars'" != "" {
        local all_covars "`all_covars' `time_vars'"
    }
    if "`ix_vars'" != "" {
        local all_covars "`all_covars' `ix_vars'"
    }
    local all_covars = strtrim("`all_covars'")

    * The design matrix is complete. Claim every column this call generated, so
    * a rerun's `replace' can prove it is overwriting our output rather than
    * inferring it from the name. Stamping here, before estimation, is safe: if
    * the fit fails, the rollback drops these variables and the marks go with
    * them.
    local __iivw_stamp_vars = strtrim("`__iivw_created_vars'")
    if "`__iivw_stamp_vars'" != "" {
        _iivw_own stamp `__iivw_stamp_vars', role(design) prefix(`prefix')
    }

    * =========================================================================
    * STABILIZATION VALIDITY
    * =========================================================================
    * A stabilized IIW carries the numerator h(X) = exp(delta'X_stab). The
    * weighted estimating equation stays unbiased for the marginal beta only if
    * h is a function of covariates that are IN the outcome mean model: then
    * E[Y - mu(X;beta) | X] = 0 makes the h-weighted score mean-zero whatever h
    * is. Stabilize on a variable the outcome model never sees and that argument
    * collapses -- the weighted equation solves for an h-weighted average of
    * subject-specific effects, not for the beta being reported.
    *
    * iivw_weight cannot check this: it runs before the outcome design exists and
    * has no way to know what the user will eventually fit. iivw_fit CAN, and
    * until now it did not -- the assumption was documented in the help and
    * enforced nowhere. Worse, a shipped recovery scenario stabilized on a
    * variable it explicitly stated was absent from the outcome model and then
    * counted recovery as a pass, which encoded the violation as evidence.
    *
    * The check is deliberately conservative: it requires each stabcov() variable
    * to be a MAIN-EFFECT source of the outcome design (an independent variable,
    * a categorical source, or the panel time variable behind the fitted time
    * terms). A stabilization variable that is some other deterministic function
    * of a design covariate is defensible in theory, but the package cannot prove
    * that from the data, and a guard that accepts what it cannot verify is not a
    * guard. Put the function in the outcome model.
    *
    * interaction() is deliberately NOT a source (SOL-05). interaction(z) with z
    * absent from indepvars fits z x time and no z main effect: the design column
    * is identically zero at time == 0, so the model does not condition on z
    * there, and the numerator h(z) is not a function of what was conditioned on.
    * The pre-fix build put interaction() into this list and returned
    * e(iivw_stabilization_validated) == 1 for exactly that specification -- a
    * guard certifying the case it exists to catch. A z that IS a main effect
    * reaches the list through `indepvars' regardless of any interaction it also
    * appears in, so nothing legitimate is lost by dropping it here.
    local stab_validated = 0
    local stab_terms ""
    if "`unweighted'" == "" & "`rep_stabcov'" != "" {
        local design_sources "`indepvars'"
        if "`categorical'" != ""  local design_sources "`design_sources' `categorical'"
        if "`time_vars'" != "" & "`panel_time'" != "" {
            local design_sources "`design_sources' `panel_time'"
        }
        local design_sources : list uniq design_sources

        * Name the interaction-only case explicitly: "z is in my model" is the
        * user's most likely objection to the error below, and it is true --
        * just not as a main effect.
        local stab_ixonly ""
        if "`interaction'" != "" {
            local stab_ixonly : list rep_stabcov & interaction
            local stab_ixonly : list stab_ixonly - design_sources
        }

        local stab_missing : list rep_stabcov - design_sources
        if "`stab_missing'" != "" {
            display as error "stabilized IIW numerator is not a function of the outcome design"
            display as error ""
            display as error "  stabcov() variables absent from this outcome model:`stab_missing'"
            display as error ""
            display as text  "  The weights were stabilized on:      `rep_stabcov'"
            display as text  "  This outcome model is built from:    `design_sources'"
            display as text  ""
            display as text  "  A stabilized IIW is unbiased for the marginal effect only when its"
            display as text  "  numerator depends on covariates the outcome model conditions on."
            display as text  "  Stabilizing on a variable this model never sees changes the estimand:"
            display as text  "  the weighted fit targets a numerator-weighted average of"
            display as text  "  subject-specific effects, not the beta printed in the table."
            if "`stab_ixonly'" != "" {
                display as text  ""
                display as text  "  Appearing only in interaction() does not count:`stab_ixonly'"
                display as text  "  An interaction with time contributes a column that is identically"
                display as text  "  zero at time == 0, so the model does not condition on the variable"
                display as text  "  there. Add it to the main varlist as well as interaction()."
            }
            display as text  ""
            display as text  "  Either add those variables to the outcome model, or recompute the"
            display as text  "  weights with a stabcov() that this model contains -- including"
            display as text  "  unstabilized, which is always valid."
            error 198
        }
        local stab_validated = 1
        local stab_terms "`rep_stabcov'"
    }

    * =========================================================================
    * FIT MODEL
    * =========================================================================

    * Token-aware pass-through guard (IIVW-B08). Reject any variance/resampling
    * token in geeopts()/mixedopts() BEFORE it can reach the inner glm/mixed and
    * either error or silently substitute a covariance under iivw's label. The
    * post-fit variance lock re-verifies the result; this stops it at the door
    * for every abbreviation and quoting form, not just the literal spellings.
    *
    * Under a bootstrap, additionally refuse glm's IRLS optimizer: it does not
    * set e(converged), which is the scalar every draw is gated on. See the
    * noirls note in _iivw_check_passthru.ado.
    local _noirls ""
    if `bootstrap' > 0 local _noirls "noirls"
    _iivw_check_passthru, optname(geeopts)  value(`"`geeopts'"')  `_noirls'
    _iivw_check_passthru, optname(mixedopts) value(`"`mixedopts'"') `_noirls'

    * vce(bootstrap, seed(#)) fixes the resampling stream for reproducibility.
    * Set it immediately before the draws so no intervening RNG use consumes the
    * stream first. This deliberately advances the global seed, as any seeded
    * bootstrap does.
    if `bootstrap' > 0 & "`vce_seed'" != "" {
        set seed `vce_seed'
    }

    * Capture the exact pre-draw RNG state so a run made WITHOUT an explicit
    * seed() is still replayable: c(rng) is the generator, c(rngstate) is the
    * state the resampler is about to consume. We record but do NOT restore it
    * afterwards -- a randomized command is expected to advance the stream, and
    * restoring would make sequential fits reuse identical draws. Stored in e()
    * below (iivw_rng, iivw_rngstate_start, iivw_vce_seed_explicit).
    local iivw_rng ""
    local iivw_rngstate_start ""
    local iivw_seed_explicit 0
    if `bootstrap' > 0 {
        local iivw_rng "`c(rng)'"
        local iivw_rngstate_start "`c(rngstate)'"
        local iivw_seed_explicit = ("`vce_seed'" != "")
    }

    if "`model'" == "gee" {

        * GLM with clustered SEs is equivalent to independence-correlation
        * GEE with robust SEs. xtgee cannot handle varying weights within
        * panels, so we use glm + vce(cluster) instead.
        local glm_family "family(`family')"
        local glm_link ""
        if "`link'" != "" {
            local glm_link "link(`link')"
        }

        local wt_clause ""
        if "`unweighted'" == "" local wt_clause "[pw=`weight_var']"

        display as text "Fitting `weighttype' GEE model..."
        display as text ""

        if `bootstrap' > 0 & "`refitweights'" != "" {
            tempvar bsid
            bootstrap, reps(`bootstrap') cluster(`cluster') ///
                idcluster(`bsid') level(`level') nodots: ///
                _iivw_bs_refit `depvar' `all_covars' if `bs_frame', ///
                newid(`bsid') panelid(`panel_id') timevar(`panel_time') ///
                outcometouse(`oc_touse') ///
                wtype(`weighttype') ///
                prefix(`prefix') model(gee) ///
                visitcov(`rep_visitcov') lagvars(`rep_lagvars') ///
                treat(`rep_treat') ///
                treatcov(`rep_treatcov') stabcov(`rep_stabcov') ///
                truncvisit(`rep_truncvisit') trunctreat(`rep_trunctreat') ///
                truncfinal(`rep_truncfinal') ///
                `rep_efron_flag' `rep_base_flag' ///
                entry(`rep_entry') `rep_cens_opt' `rep_amw_flag' ///
                `rep_ntv_flag' ///
                family(`family') link(`link') ///
                geeopts(`geeopts') `log_opt'

            _iivw_repost_outcome_n `touse', frame(`bs_frame') cluster(`cluster')
        }
        else if `bootstrap' > 0 {
            local bs_weightopt ""
            if "`unweighted'" == "" local bs_weightopt "weightvar(`weight_var')"
            bootstrap, reps(`bootstrap') cluster(`cluster') level(`level') nodots: ///
                _iivw_bs_estimate `depvar' `all_covars' if `touse', ///
                `bs_weightopt' model(gee) ///
                family(`family') link(`link') `log_opt' ///
                geeopts(`geeopts')
        }
        else {
            local _collect_prefix ""
            if "`collect'" != "" local _collect_prefix "collect:"
            `_collect_prefix' glm `depvar' `all_covars' `wt_clause' if `touse', ///
                `glm_family' `glm_link' ///
                vce(cluster `cluster') level(`level') `log_opt' `geeopts'
        }

        * `== 0', NOT `!= 1', and deliberately so. glm's IRLS optimizer never
        * sets e(converged) at all, so `!= 1' would reject every geeopts(irls)
        * fit -- including converged ones -- on the strength of a scalar that
        * engine does not produce. Under a bootstrap that ambiguity is
        * intolerable and _iivw_check_passthru refuses irls outright (noirls);
        * here, with no draws to gate, a missing flag means "this engine cannot
        * report convergence", which is not the same as "it did not converge".
        *
        * The stcox-based guards in iivw_balance and iivw_exogtest use `!= 1'
        * because stcox always sets the scalar, so there a missing value really
        * is a failure and must fail closed.
        if `bootstrap' == 0 & e(converged) == 0 {
            _iivw_require_converged, model(GEE outcome) ///
                `allownonconverged'
            local __iivw_nonconv = 1
        }
    }
    else if "`model'" == "mixed" {

        local wt_clause ""
        if "`unweighted'" == "" local wt_clause "[pw=`weight_var']"

        * Fence the weighted mixed path: IIVW weights enter mixed via a single
        * observation-level [pw=], which Stata does not rescale across levels.
        * The random-effects variance components are therefore not consistently
        * weight-estimated (Rabe-Hesketh & Skrondal 2006). The marginal (GEE)
        * estimator is the one the IIW theory identifies; model(gee) is the
        * defensible primary weighted analysis.
        *
        * This used to be a `note:'. A note does not stop anyone -- it scrolls
        * past in a long fit log, and the variance components it warns about are
        * printed immediately below it looking exactly as authoritative as any
        * other output. Requiring the acknowledgment makes the user state that
        * they know the random-effects half of this model is not identified by
        * the weighting, which is the whole point of the warning.
        if "`unweighted'" == "" & "`experimentalmixed'" == "" {
            display as error "weighted model(mixed) requires experimentalmixed"
            display as error ""
            display as text "  IIVW weights enter mixed as a single observation-level [pw=], which"
            display as text "  Stata does not rescale across levels. The random-effects variance"
            display as text "  components are therefore NOT consistently weight-estimated"
            display as text "  (Rabe-Hesketh & Skrondal 2006), even though they are reported."
            display as text ""
            display as text "  The IIW theory identifies a MARGINAL estimator. Use:"
            display as text "    iivw_fit ..., model(gee)"
            display as text "  for the primary weighted analysis."
            display as text ""
            display as text "  If you want the fixed-effect (mean) structure anyway and accept that"
            display as text "  the variance components are not a valid weighted estimate, add"
            display as text "  experimentalmixed. model(mixed) is unaffected without weights."
            exit 198
        }
        if "`unweighted'" == "" {
            display as text "note: weighted model(mixed) -- the fixed-effect (mean) structure is the"
            display as text "  target; the random-effects variance components below are not"
            display as text "  consistently weight-estimated. See model(gee)."
        }

        display as text "Fitting `weighttype' mixed model..."
        display as text ""

        if `bootstrap' > 0 & "`refitweights'" != "" {
            tempvar bsid
            bootstrap, reps(`bootstrap') cluster(`cluster') ///
                idcluster(`bsid') level(`level') nodots: ///
                _iivw_bs_refit `depvar' `all_covars' if `bs_frame', ///
                newid(`bsid') panelid(`panel_id') timevar(`panel_time') ///
                outcometouse(`oc_touse') ///
                wtype(`weighttype') ///
                prefix(`prefix') model(mixed) ///
                visitcov(`rep_visitcov') lagvars(`rep_lagvars') ///
                treat(`rep_treat') ///
                treatcov(`rep_treatcov') stabcov(`rep_stabcov') ///
                truncvisit(`rep_truncvisit') trunctreat(`rep_trunctreat') ///
                truncfinal(`rep_truncfinal') ///
                `rep_efron_flag' `rep_base_flag' ///
                entry(`rep_entry') `rep_cens_opt' `rep_amw_flag' ///
                `rep_ntv_flag' ///
                mixedopts(`mixedopts') `log_opt'

            _iivw_repost_outcome_n `touse', frame(`bs_frame') cluster(`cluster')
        }
        else if `bootstrap' > 0 {
            local bs_weightopt ""
            if "`unweighted'" == "" local bs_weightopt "weightvar(`weight_var')"
            * idcluster() relabels each resampled cluster with a unique id, so a
            * cluster drawn twice enters mixed as two separate random-effect
            * groups rather than one merged group. Without it, mixed collapses
            * the duplicated draws into a single panel, biasing the resampled
            * random-effects variance components and understating the intercept
            * SE.
            *
            * But the draw id is not the panel unit when cluster() sits ABOVE the
            * panel -- a clinic. Passing it as the grouping variable made a whole
            * clinic one random-effect group. Hand the helper both ids and let it
            * form group(bsid, panel_id), the resampled subject.
            tempvar bsid
            bootstrap, reps(`bootstrap') cluster(`cluster') ///
                idcluster(`bsid') level(`level') nodots: ///
                _iivw_bs_estimate `depvar' `all_covars' if `touse', ///
                `bs_weightopt' model(mixed) ///
                panelid(`panel_id') bsid(`bsid') `log_opt' ///
                mixedopts(`mixedopts')
        }
        else {
            mixed `depvar' `all_covars' `wt_clause' if `touse' ///
                || `panel_id':, vce(cluster `cluster') level(`level') ///
                `log_opt' `mixedopts'
        }

        if `bootstrap' == 0 & e(converged) == 0 {
            _iivw_require_converged, model(mixed outcome) ///
                `allownonconverged'
            local __iivw_nonconv = 1
        }
    }

    * =========================================================================
    * REPLICATE ACCOUNTING
    * =========================================================================
    * A bootstrap replicate can fail. A resampled panel may contain no variation
    * in a covariate, so the outcome model drops the term and returns a missing
    * coefficient for it; a nuisance model may fail to converge on a draw; a draw
    * may lose every weighted row.
    *
    * Stata's -bootstrap- handles that by computing the variance from the
    * replicates that DID return a number, and recording the shortfall in
    * e(N_misreps). It does not stop, and iivw_fit used to say nothing at all: a
    * measured probe asked for 40 replicates, 6 failed, and the command printed
    * an SE built from 34 draws with no indication anywhere in its own output or
    * in e() that it had done so.
    *
    * That is an SE from an undocumented subset of the draws the user asked for,
    * and the subset is not random with respect to the estimate -- the draws that
    * fail are the ones with the least information about exactly the terms whose
    * SE is being reported. The result is anti-conservative and there is nothing
    * in the output to say so.
    *
    * So: an incomplete bootstrap is an ERROR. allowfailedreps is the explicit
    * acknowledgment, and even then the counts are reported and stored in e().
    local bs_reps_req = 0
    local bs_reps_done = 0
    local bs_reps_fail = 0
    if `bootstrap' > 0 {
        local bs_reps_req = `bootstrap'
        local bs_reps_done = e(N_reps)
        local bs_reps_fail = e(N_misreps)
        if "`bs_reps_fail'" == "" | `bs_reps_fail' >= . local bs_reps_fail = 0
        if "`bs_reps_done'" == "" | `bs_reps_done' >= . local bs_reps_done = 0

        if `bs_reps_fail' > 0 {
            if "`allowfailedreps'" == "" {
                display as error ""
                display as error "`bs_reps_fail' of `bs_reps_req' bootstrap replicates failed"
                display as error ""
                display as text "  The reported standard errors would be computed from the"
                display as text "  `bs_reps_done' replicates that returned a number. That subset is not"
                display as text "  random with respect to what is being estimated: the draws that fail"
                display as text "  are the ones carrying the least information about the very terms"
                display as text "  whose standard error you are reading. The result is"
                display as text "  anti-conservative, and nothing in the table would say so."
                display as text ""
                display as text "  A replicate fails when a resampled panel has no variation in a"
                display as text "  covariate (the term is dropped and returns missing), when a nuisance"
                display as text "  model does not converge on the draw, or when the draw retains no"
                display as text "  weighted rows."
                display as text ""
                display as text "  Either respecify -- a rare binary covariate and a small number of"
                display as text "  subjects is the usual cause -- or add"
                display as text "    allowfailedreps"
                display as text "  to declare that an SE from `bs_reps_done'/`bs_reps_req' draws is what you intend."
                error 430
            }

            display as text ""
            display as text "note: `bs_reps_fail' of `bs_reps_req' bootstrap replicates failed"
            display as text "  allowfailedreps was specified: the standard errors below come from"
            display as text "  the `bs_reps_done' replicates that completed, and are likely anti-conservative."
        }
    }

    * =========================================================================
    * FEW-CLUSTER INFERENCE WARNING
    * =========================================================================
    * Cluster-robust (sandwich) SEs are anti-conservative when the number of
    * clusters is modest, and IIVW weighting concentrates influence on a few
    * subjects, which worsens the effective-cluster count. Only relevant for the
    * analytic-SE path (bootstrap() already resamples clusters).
    if `bootstrap' == 0 {
        tempvar _iivw_cltag
        quietly egen byte `_iivw_cltag' = tag(`cluster') if `touse'
        quietly count if `_iivw_cltag' == 1
        local n_clusters = r(N)
        drop `_iivw_cltag'
        if `n_clusters' < 40 {
            display as text ""
            display as text "note: `n_clusters' clusters (`cluster'); cluster-robust SEs can be"
            display as text "  anti-conservative with few clusters. Consider bootstrap(#) for"
            display as text "  inference (add refitweights to also propagate weight uncertainty)."
        }
    }

    * =========================================================================
    * FIXED-WEIGHT VARIANCE DISCLOSURE
    * =========================================================================
    * The reported SE treats the estimated weights as KNOWN. It is not the
    * variance Buzkova & Lumley derive (they add the visit-model score
    * correction) nor the one Coulombe, Moodie & Platt use (a two-step sandwich).
    * Agreement with R on this number proves only that both programs computed the
    * same incomplete variance.
    *
    * This is stated where the user reads the SE, not only in the help file. It
    * is the single most consequential thing about the output and it was
    * previously invisible.
    if "`unweighted'" == "" & (`bootstrap' == 0 | "`refitweights'" == "") {
        display as text ""
        display as text "{hline 70}"
        if `bootstrap' == 0 {
            display as text "note: these standard errors treat the estimated weights as KNOWN."
        }
        else {
            display as text "note: bootstrap() without refitweights holds the weights FIXED across"
            display as text "  replicates, so these standard errors treat them as known."
        }
        display as text "  They omit the uncertainty from estimating the visit-intensity model"
        display as text "  (and the propensity model, for IPTW/FIPTIW). This is not the variance"
        display as text "  derived by Buzkova & Lumley (2007) or by Coulombe et al. (2021)."
        display as text ""
        display as text "  For inference that propagates weight-estimation uncertainty:"
        display as text "    iivw_fit ..., bootstrap(#) refitweights"
        display as text "{hline 70}"
    }

    * =========================================================================
    * COMMIT: STORE METADATA
    * =========================================================================
    * The outcome model converged (or the user explicitly accepted a
    * nonconverged one) and every generated variable exists. Only now is the
    * prior fit contract cleared and rewritten.

    * _iivw_nonconverged is the WEIGHT stage's stamp and is deliberately NOT in
    * this clear-list. It records that a nuisance model (visit-intensity,
    * stabilization, or treatment) was accepted nonconverged, and that taint
    * survives any number of later outcome fits -- the weights are still the bad
    * ones. Clearing it here would have laundered it: a converged iivw_fit after
    * a nonconverged iivw_weight would erase the only record that the weights
    * are untrustworthy. The outcome model gets its own stamp instead.
    foreach ch in _iivw_fitted _iivw_model _iivw_timespec _iivw_cluster ///
        _iivw_time_vars _iivw_interaction _iivw_ix_vars ///
        _iivw_categorical _iivw_cat_vars _iivw_basecat ///
        _iivw_time_cat_vars _iivw_time_basecat _iivw_fit_nonconverged {
        char _dta[`ch'] ""
    }

    char _dta[_iivw_fitted] "1"
    * Stamp a deliberately-accepted nonconverged fit so the downstream
    * diagnostics can refuse it rather than treating it as a clean fit.
    if `__iivw_nonconv' {
        char _dta[_iivw_fit_nonconverged] "1"
    }
    char _dta[_iivw_model] "`model'"
    char _dta[_iivw_timespec] "`timespec'"
    char _dta[_iivw_cluster] "`cluster'"
    char _dta[_iivw_time_vars] "`time_vars'"
    if "`timespec'" == "categorical" {
        char _dta[_iivw_time_cat_vars] "`time_cat_vars_created'"
        char _dta[_iivw_time_basecat] "`time_basecat_used'"
    }
    if "`interaction'" != "" {
        char _dta[_iivw_interaction] "`interaction'"
        char _dta[_iivw_ix_vars] "`ix_vars'"
    }
    if "`categorical'" != "" {
        char _dta[_iivw_categorical] "`categorical'"
        char _dta[_iivw_cat_vars] "`cat_vars_created'"
        if "`basecat'" != "" {
            char _dta[_iivw_basecat] "`basecat'"
        }
    }

    * =========================================================================
    * DISPLAY SUMMARY
    * =========================================================================

    display as text ""
    display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"
    if "`unweighted'" != "" {
        display as text "Unweighted effects:"
    }
    else {
        display as text "`wtype_display'-weighted effects:"
    }
    display as text ""
    display as text _col(4) "`__iivw_smcl_lb'ralign 18:Variable`__iivw_smcl_rb'" ///
        _col(24) "`__iivw_smcl_lb'ralign 10:Coef.`__iivw_smcl_rb'" ///
        _col(36) "`__iivw_smcl_lb'ralign 9:SE`__iivw_smcl_rb'" ///
        _col(47) "`__iivw_smcl_lb'ralign 16:`level'% CI`__iivw_smcl_rb'" ///
        _col(65) "`__iivw_smcl_lb'ralign 6:P`__iivw_smcl_rb'"
    display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"

    * Build list with intercept first when present
    local table_terms "`all_covars'"
    capture local _cons_b = _b[_cons]
    if _rc == 0 {
        local table_terms "_cons `all_covars'"
    }

    foreach pred of local table_terms {
        local b_val = .
        local se_val = 0
        capture local b_val = _b[`pred']
        local b_rc = _rc
        capture local se_val = _se[`pred']
        local se_rc = _rc
        local coef_rc = max(`b_rc', `se_rc')

        * Use variable label if available, else variable name (or "Intercept"
        * for the model constant, which is not a real variable).
        if "`pred'" == "_cons" {
            local vlab "Intercept"
        }
        else {
            local vlab : variable label `pred'
            if `"`vlab'"' == "" local vlab "`pred'"
        }
        if strlen(`"`vlab'"') > 18 {
            local vlab = substr(`"`vlab'"', 1, 16) + ".."
        }

        if `coef_rc' == 0 & `se_val' > 0 & `se_val' < . {
            local z_val = `b_val' / `se_val'
            local p_val = 2 * normal(-abs(`z_val'))
            local ci_lo = `b_val' - invnormal((100+`level')/200) * `se_val'
            local ci_hi = `b_val' + invnormal((100+`level')/200) * `se_val'

            * Format p-value
            if `p_val' < 0.001 {
                local p_fmt "<0.001"
            }
            else {
                local p_fmt : display %6.3f `p_val'
                local p_fmt = strtrim("`p_fmt'")
            }

            display as text _col(4) "`__iivw_smcl_lb'ralign 18:`vlab'`__iivw_smcl_rb'" ///
                as result _col(24) %10.4f `b_val' ///
                _col(36) %9.4f `se_val' ///
                _col(47) %7.4f `ci_lo' as text "," ///
                as result %7.4f `ci_hi' ///
                as text _col(65) "`__iivw_smcl_lb'ralign 6:`p_fmt'`__iivw_smcl_rb'"
        }
        else {
            * Lookup failed (collinear-dropped or otherwise unestimated).
            * Show a visible "(omitted)" row so the user notices the gap.
            display as text _col(4) "`__iivw_smcl_lb'ralign 18:`vlab'`__iivw_smcl_rb'" ///
                _col(24) "`__iivw_smcl_lb'ralign 41:(omitted)`__iivw_smcl_rb'"
        }
    }

    display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"

    * Store eclass metadata
    ereturn local iivw_cmd "iivw_fit"
    ereturn local iivw_model "`model'"
    ereturn local iivw_weighttype "`weighttype'"
    ereturn local iivw_treat_in_visit "`rep_treat_in_visit'"
    ereturn scalar iivw_stabilization_validated = `stab_validated'
    ereturn local iivw_stab_terms "`stab_terms'"

    * ---------------------------------------------------------------------
    * INFERENCE PROVENANCE
    * ---------------------------------------------------------------------
    * Everything a reader needs to say what the reported SE actually is, without
    * having to reconstruct it from the command line. The variance method, the
    * resampling unit, whether the nuisance models were refit inside the draws,
    * the replicate accounting, and the weight contract the whole thing rests on.
    *
    * e(iivw_vce) is the load-bearing one. "fixed" means the weights were treated
    * as KNOWN: the SE omits the uncertainty in estimating them, which is not the
    * variance either source paper derives. A reader who cannot tell "fixed" from
    * "bootstrap" from the output cannot tell whether the interval means anything.
    if `bootstrap' > 0 & "`refitweights'" != "" {
        ereturn local iivw_vce "bootstrap"
    }
    else if `bootstrap' > 0 {
        ereturn local iivw_vce "bootstrap-fixedweights"
    }
    else {
        ereturn local iivw_vce "fixed"
    }

    * -------------------------------------------------------------------------
    * POST-FIT VARIANCE LOCK (IIVW-B08 defense in depth)
    * -------------------------------------------------------------------------
    * A pre-call string scan of geeopts()/mixedopts() is not evidence that the
    * variance the package believes it computed is the variance actually posted.
    * Read it back from e() and confirm: a bootstrap fit must post e(vce)
    * "bootstrap"; a fixed GEE fit must post e(vce) "cluster" on the package's
    * own cluster variable. If a pass-through token reached glm and changed the
    * VCE, that shows up here as a mismatch and the fit errors rather than
    * reporting a variance under a method label it does not match. Only model(gee)
    * -- the cleared surface -- is locked strictly; model(mixed) is experimental
    * and never carries the cleared claim, so it is recorded unlocked.
    local _obs_vce      "`e(vce)'"
    local _obs_clustvar "`e(clustvar)'"
    local iivw_vce_locked 0
    if "`model'" == "gee" {
        if `bootstrap' > 0 {
            if "`_obs_vce'" == "bootstrap" local iivw_vce_locked 1
        }
        else if "`_obs_vce'" == "cluster" & "`_obs_clustvar'" == "`cluster'" {
            local iivw_vce_locked 1
        }
        if `iivw_vce_locked' == 0 {
            display as error "variance lock failed: the posted covariance does not"
            display as error "  match the package-selected method (`e(iivw_vce)')"
            display as error "  observed e(vce)=`_obs_vce', e(clustvar)=`_obs_clustvar'"
            display as error "  a geeopts()/mixedopts() token may have altered the VCE"
            error 459
        }
    }
    ereturn scalar iivw_vce_locked = `iivw_vce_locked'

    ereturn local iivw_resample_unit = cond(`bootstrap' > 0, "`cluster'", "")
    ereturn scalar iivw_bs_reps_requested = `bs_reps_req'
    ereturn scalar iivw_bs_reps_completed = `bs_reps_done'
    ereturn scalar iivw_bs_reps_failed = `bs_reps_fail'
    ereturn local iivw_allowfailedreps = ///
        cond(`bs_reps_fail' > 0 & "`allowfailedreps'" != "", "1", "0")
    ereturn local iivw_vce_seed "`vce_seed'"

    * The printed interval is the normal/Wald interval from the reported
    * covariance (b +/- z * se), the same convention the coefficient table and
    * the coverage driver use. Percentile/basic/BC/BCa are separate methods and
    * are NOT what "bootstrap" prints here; naming it stops that ambiguity.
    ereturn local iivw_ci_type "wald-normal"

    * RNG provenance: enough to replay a run made without an explicit seed().
    ereturn local iivw_rng "`iivw_rng'"
    ereturn local iivw_rngstate_start "`iivw_rngstate_start'"
    ereturn local iivw_vce_seed_explicit = cond(`bootstrap' > 0, "`iivw_seed_explicit'", "")

    * Inference status: which trust tier this run's variance belongs to. NEVER
    * "cleared" here -- that word is reserved for a release in which the coverage
    * AND mutation gates have actually passed, and this command cannot know that.
    * The refit-999 default is a "candidate"; everything else is explicitly
    * stamped uncleared so a reader can never mistake it for the release method.
    local iivw_infstatus ""
    if "`unweighted'" != "" {
        local iivw_infstatus "not-applicable-unweighted"
    }
    else if `bootstrap' > 0 & "`refitweights'" != "" {
        if `bs_reps_fail' > 0 & "`allowfailedreps'" != "" {
            local iivw_infstatus "uncleared-failed-reps"
        }
        else if `bootstrap' < 999 {
            local iivw_infstatus "uncleared-low-reps"
        }
        else if inlist("`weighttype'", "iivw", "iptw") {
            * Coverage measured 2026-07-22, 1000 sims x 999 draws, preregistered
            * rule in qa/TOLERANCE_FRAMEWORK.md sec 3 (Wilson must contain 0.95,
            * floor 0.92). IIW 0.939 [0.922,0.952]; IPTW 0.954 [0.939,0.965].
            * Record: qa/coverage_results/RESULT_2026-07-22.md.
            * "studied settings" is load-bearing: ONE correct-specification cell
            * per family at one sample size. It is not a claim about every n,
            * every link, or a misspecified visit model.
            local iivw_infstatus "cleared-at-studied-settings"
        }
        else if "`weighttype'" == "fiptiw" {
            * Same run, same rule: FIPTIW coverage 0.914 [0.895,0.930] -- below
            * the 0.92 floor and the Wilson interval excludes 0.95.
            * The POINT ESTIMATOR is fine (bias +0.017 against MCSE 0.039). The
            * INTERVAL is ~14% too narrow: mean SE 1.062 vs empirical SD 1.239.
            * Not a resampler defect -- the refit bootstrap, the fixed-weight
            * bootstrap and the analytic sandwich agree within 0.5% of each
            * other and all three fall equally short.
            local iivw_infstatus "undercovers-at-studied-settings"
        }
        else {
            local iivw_infstatus "candidate"
        }
    }
    else if `bootstrap' > 0 {
        local iivw_infstatus "uncleared-fixedweights-bootstrap"
    }
    else {
        local iivw_infstatus "uncleared-fixedweights-analytic"
    }
    ereturn local iivw_inference_status "`iivw_infstatus'"

    * The weight contract these estimates rest on. If it is empty, the fit was
    * unweighted; if it is stale, _iivw_check_weighted already errored.
    local __iivw_wsig_now : char _dta[_iivw_wsig]
    ereturn local iivw_wsig "`__iivw_wsig_now'"
    local unweighted_flag = ("`unweighted'" != "")
    ereturn local iivw_unweighted "`unweighted_flag'"
    local refit_flag = ("`refitweights'" != "" & `bootstrap' > 0)
    ereturn local iivw_refitweights "`refit_flag'"
    ereturn local iivw_timespec "`timespec'"
    ereturn local iivw_weight_var "`weight_var'"
    ereturn local iivw_cluster "`cluster'"
    ereturn local iivw_id "`panel_id'"
    ereturn local iivw_time "`panel_time'"
    ereturn local iivw_time_vars "`time_vars'"
    ereturn local iivw_display_vars "`all_covars'"
    if "`timespec'" == "categorical" {
        ereturn local iivw_time_cat_vars "`time_cat_vars_created'"
        ereturn local iivw_time_basecat "`time_basecat_used'"
    }
    if "`interaction'" != "" {
        ereturn local iivw_interaction "`interaction'"
        ereturn local iivw_ix_vars "`ix_vars'"
    }
    if "`categorical'" != "" {
        ereturn local iivw_categorical "`categorical'"
        ereturn local iivw_cat_vars "`cat_vars_created'"
    }

    }
    local rc = _rc
    * Roll the name transaction back: drop every variable this call created,
    * then rename the backups of the user's prior outputs into place. The fit
    * contract is written only at the commit point, so it was never touched and
    * still describes the restored variables.
    if `rc' != 0 {
        foreach v of local __iivw_created_vars {
            capture drop `v'
            local __iivw_drop_rc = _rc
        }
        local __iivw_bi = 0
        foreach g of local __iivw_bk_names {
            local ++__iivw_bi
            local __iivw_bt : word `__iivw_bi' of `__iivw_bk_temps'
            capture drop `g'
            capture rename `__iivw_bt' `g'
        }
    }
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
