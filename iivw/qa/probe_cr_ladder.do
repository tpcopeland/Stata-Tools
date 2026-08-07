* =============================================================================
* probe_cr_ladder.do - FIPTIW CR ladder at a z critical value (se_recovery 13.2)
* =============================================================================
* WHAT THIS IS, AND WHAT IT IS NOT
* --------------------------------
* This is a DIAGNOSTIC probe, never a gate. It answers one question from
* `_take_action/se_recovery.md' section 13.2: of the ~16% scale deficit in the
* FIPTIW studentized pivot, how much can a leverage-based scale correction to
* the outcome-stage sandwich actually recover?
*
* Section 4 of that document separates two ways a pivot misses nominal coverage
* -- a SCALE defect (SE too small, pivot SD > 1) and a SHAPE defect (heavy
* tails). Section 3 says this one is overwhelmingly scale. A Satterthwaite df
* correction is the instrument for shape, and pairing it with CR2 is what
* produced the 0.985 overcoverage at n=600 that section 5 rejects. So EVERY rung
* here is read against a z critical value and no df correction is applied
* anywhere. That is the entire point of the design.
*
* It emits no gate verdict, and it cannot: it computes no bootstrap, evaluates
* no candidate the package ships, and carries the relabelling prohibition of
* `coverage_results/FIPTIW_NSCALE_2026-07-23.md' lines 5-7. Nothing it prints
* may be folded into a headline coverage number or used to change a default.
* Section 11 of se_recovery.md governs that, and this probe satisfies none of
* its five clauses.
*
* WHY IT REGENERATES RATHER THAN RE-ANALYSES
* ------------------------------------------
* Section 13.2 was costed as a re-analysis of "an existing pool". No such pool
* exists in this repository: the 2026-08-05 gate run predates the retention fix
* recorded in section 2, so `coverage_results/' holds combine LOGS and manifests
* but not one per-replication row, and the external reviewer's regenerated copy
* was never transferred here. The retention fix applies to the next gate run,
* not to that one.
*
* The datasets are regenerated instead. That is exact rather than approximate,
* because the gate's seed ledger derives replication s from (master, arm, s)
* alone -- so `_inf_dgpseed 20260715 3 s' reproduces gate replication s bit for
* bit. `combine' below PROVES the regeneration by checking the reproduced point
* moments against the recorded ones (RESULT_2026-08-05.md: bias +0.01707,
* empSD 1.23911 at nsub=300); a pool that does not reproduce them is not the
* gate's pool and the probe refuses to report on it.
*
* Regeneration is affordable only because the ladder needs no resampling: the
* gate's cost is 999 refit bootstrap draws per replication, and this probe runs
* one weighting pass and one WLS fit.
*
* NO SECOND COPY OF THE DGP
* -------------------------
* The DGP is not transcribed here. `validation_iivw_inference.do' is sourced for
* its program definitions -- MODE=release defines every program and then exits
* rather than running anything -- so `_inf_dgp_fiptiw' and `_inf_dgpseed' are the
* gate's own, and a change to the gate's DGP changes this probe too. The sourcing
* is verified below; if that dispatch behaviour ever changes, this file must
* fail loudly rather than silently fall back to some other DGP.
*
* Usage (from iivw/qa):
*   stata-mp -b do probe_cr_ladder.do run     NSUB SIMS SEED FROM TO
*   stata-mp -b do probe_cr_ladder.do combine NSUB SIMS SEED
*
*   NSUB  300 | 600 | 1200   (the three sample sizes of se_recovery.md section 4)
*   SIMS  total replications in the study (blocks are slices of it)
*   SEED  master seed; 20260715 is the registered one
*
* Blocks land in `_cr_blocks/cr_<NSUB>_<FROM>_<TO>.dta' and carry their own
* provenance stamps; combine refuses a pool whose stamps disagree.
* =============================================================================

args MODE NSUB SIMS SEED FROM TO

if "`MODE'" == "" local MODE run
if "`NSUB'" == "" local NSUB 300
if "`SIMS'" == "" local SIMS 1000
if "`SEED'" == "" local SEED 20260715
if "`FROM'" == "" local FROM 1
if "`TO'"   == "" local TO   `SIMS'

if !inlist("`MODE'", "run", "combine") {
    display as error "MODE must be run or combine (got: `MODE')"
    exit 198
}

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "probe_cr_ladder.do must be run from iivw/qa"
    exit 198
}

* The FIPTIW arm id in the gate's seed ledger. Not a free parameter: change it
* and the datasets stop being the gate's datasets.
local ARM 3
local TRUTH 1

* -----------------------------------------------------------------------------
* Source the gate's programs. MODE=release defines everything and exits 198
* without running a study, which is exactly what is wanted here.
* -----------------------------------------------------------------------------
if "`MODE'" == "run" {
    capture noisily do "`qa_dir'/validation_iivw_inference.do" release

    * Prove the sourcing worked by USING the programs, not by asking whether a
    * name exists. Stata has no `confirm program', and a check that cannot fail
    * is worse than no check: this probe would otherwise run on whatever
    * _inf_dgp_fiptiw happened to be left in memory.
    capture _inf_dgpseed `SEED' `ARM' 1
    local probe_seed "`r(seed)'"
    if _rc | "`probe_seed'" == "" {
        display as error "probe_cr_ladder: _inf_dgpseed is not available after sourcing"
        display as error "  validation_iivw_inference.do. Its MODE dispatch has changed."
        exit 459
    }
    if `probe_seed' != `SEED' + `ARM'*1000000 + 1 {
        display as error "probe_cr_ladder: the gate's seed ledger has changed."
        display as error "  _inf_dgpseed `SEED' `ARM' 1 returned `probe_seed', expected " ///
            `SEED' + `ARM'*1000000 + 1
        display as error "  The regenerated datasets would no longer be the gate's."
        exit 459
    }
    capture _inf_dgp_fiptiw, seed(`probe_seed') nsub(20) pscale(1)
    if _rc {
        display as error "probe_cr_ladder: _inf_dgp_fiptiw is not available after"
        display as error "  sourcing validation_iivw_inference.do (rc=`_rc')."
        display as error "  This probe must use the gate's DGP, not a copy of it --"
        display as error "  fix the sourcing rather than transcribing the DGP here."
        exit 459
    }
    foreach v in id t y A Z K1 K2 K3 C entry {
        capture confirm variable `v'
        if _rc {
            display as error "probe_cr_ladder: the gate DGP no longer produces `v'"
            exit 459
        }
    }
    clear
    display as text "gate DGP programs sourced from validation_iivw_inference.do"

    * That file's sandbox belongs to that file. Establish one that lives for the
    * whole of this run, and reinstall into it.
    do "`qa_dir'/_iivw_qa_common.do"
    iivw_qa_bootstrap
    do "`qa_dir'/_iivw_cr_ladder.do"

    if c(MP) == 1 {
        capture set processors 1
    }
}

local zc = invnormal(0.975)

* =============================================================================
* RUN: one block of replications
* =============================================================================
if "`MODE'" == "run" {

    if `FROM' < 1 | `TO' < `FROM' | `TO' > `SIMS' {
        display as error "bad block range `FROM'-`TO' for SIMS=`SIMS'"
        exit 198
    }

    local blockdir "`qa_dir'/_cr_blocks"
    capture mkdir "`blockdir'"
    local tag = string(`FROM', "%05.0f") + "_" + string(`TO', "%05.0f")
    local outfile "`blockdir'/cr_`NSUB'_`tag'.dta"

    tempname pf
    postfile `pf' int rep int blk_nsub long blk_sims long blk_seed ///
        double b double se_fix double se_cr0 double se_cr1 double se_cr1s ///
        double se_cr2 double se_cr3 double maxlev ///
        int nsing long nclust long nobs int failed ///
        using "`outfile'", replace

    local nfail = 0
    forvalues s = `FROM'/`TO' {
        _inf_dgpseed `SEED' `ARM' `s'
        local dgpseed = r(seed)

        capture noisily {
            _inf_dgp_fiptiw, seed(`dgpseed') nsub(`NSUB') pscale(1)

            * This weighting call is the one in _inf_run_fiptiw (the gate's
            * fiptiw runner). It is repeated rather than sourced because that
            * program also launches 999 bootstrap refits, which is the entire
            * cost this probe exists to avoid. If the gate's weighting spec
            * changes, this line must change with it -- there is no automatic
            * check on that, and it is the one drift risk in this file.
            quietly iivw_weight, id(id) time(t) treat(A) treat_cov(K1 K2 K3) ///
                visit_cov(Z) wtype(fiptiw) censor(C) baseline(entry) nolog

            quietly iivw_fit y A, timespec(none) vce(fixed) nolog replace
        }
        if _rc {
            local ++nfail
            post `pf' (`s') (`NSUB') (`SIMS') (`SEED') ///
                (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) (1)
            continue
        }

        local b_fit  = _b[A]
        local se_fit = _se[A]
        local wvar   "`e(iivw_weight_var)'"
        tempvar esamp
        quietly generate byte `esamp' = e(sample)

        capture noisily iivw_cr_ladder y A if `esamp' == 1, ///
            clustervar(id) weightvar(`wvar')
        if _rc {
            local ++nfail
            post `pf' (`s') (`NSUB') (`SIMS') (`SEED') ///
                (`b_fit') (`se_fit') (.) (.) (.) (.) (.) (.) (.) (.) (.) (1)
            drop `esamp'
            continue
        }

        post `pf' (`s') (`NSUB') (`SIMS') (`SEED') ///
            (`b_fit') (`se_fit') (r(se_cr0)) (r(se_cr1)) (r(se_cr1s)) ///
            (r(se_cr2)) (r(se_cr3)) (r(maxlev)) ///
            (r(n_singular)) (r(nclust)) (r(nobs)) (0)

        drop `esamp'

        if mod(`s' - `FROM' + 1, 25) == 0 {
            display as text "  ... `=`s' - `FROM' + 1' of `=`TO' - `FROM' + 1' done (rep `s')"
        }
    }
    postclose `pf'

    display as text "{hline 74}"
    display as error "RESULT: probe_cr_ladder BLOCK nsub=`NSUB' `FROM'-`TO' non-gate" ///
        " failed=`nfail'"
    display as error "  a block is a diagnostic slice; run MODE=combine over all blocks"
    exit 1
}

* =============================================================================
* COMBINE: one diagnostic table over the union of blocks
* =============================================================================

* Batch mode defaults to linesize 80, which silently clipped the Wilson column
* off the right edge of the ladder table -- the log looked complete and was
* missing a number. Widen before printing anything.
set linesize 120

local blockdir "`qa_dir'/_cr_blocks"
local blocks : dir "`blockdir'" files "cr_`NSUB'_*.dta"
local nblk : word count `blocks'
if `nblk' == 0 {
    display as error "combine: no blocks for nsub=`NSUB' in `blockdir'"
    exit 601
}

tempfile allrows
local first = 1
foreach bf of local blocks {
    quietly use "`blockdir'/`bf'", clear
    if `first' == 0 quietly append using "`allrows'"
    quietly save "`allrows'", replace
    local first = 0
}
quietly use "`allrows'", clear

* Provenance: every row must agree on the configuration, and the blocks must
* tile 1..SIMS exactly. Two blocks run at different NSUB or different seeds
* would otherwise tile perfectly and combine into a table describing no study.
foreach v in blk_nsub blk_sims blk_seed {
    quietly summarize `v'
    if r(min) != r(max) {
        display as error "combine: blocks disagree on `v' (`r(min)' vs `r(max)')"
        exit 459
    }
}
quietly summarize blk_nsub
if r(min) != `NSUB' {
    display as error "combine: blocks carry blk_nsub=`r(min)', asked for `NSUB'"
    exit 459
}
quietly summarize blk_sims
if r(min) != `SIMS' {
    display as error "combine: blocks carry blk_sims=`r(min)', asked for `SIMS'"
    exit 459
}
quietly summarize blk_seed
if r(min) != `SEED' {
    display as error "combine: blocks carry blk_seed=`r(min)', asked for `SEED'"
    exit 459
}

quietly count
if r(N) != `SIMS' {
    display as error "combine: `r(N)' rows for SIMS=`SIMS' -- blocks overlap or a slice is missing"
    exit 459
}
sort rep
quietly count if rep != _n
if r(N) > 0 {
    display as error "combine: block rows do not tile 1..`SIMS' exactly"
    exit 459
}

quietly count if failed == 1
local nfail = r(N)
if `nfail' > 0 {
    display as error "combine: `nfail' replications failed -- the probe is not"
    display as error "  reporting a table over a partial pool"
    exit 459
}

* -----------------------------------------------------------------------------
* Point moments, and the provenance proof against the recorded gate run
* -----------------------------------------------------------------------------
quietly summarize b, detail
local mean_b  = r(mean)
local emp_sd  = r(sd)
local bias    = `mean_b' - `TRUTH'
local mcse    = `emp_sd' / sqrt(`SIMS')

display as text "{hline 74}"
display as result "probe_cr_ladder  nsub=`NSUB'  sims=`SIMS'  seed=`SEED'  arm=`ARM'"
display as text "{hline 74}"
display as text "point estimator"
display as text "  mean b   = " as result %9.5f `mean_b'
display as text "  bias     = " as result %9.5f `bias' as text "  (MCSE " %7.5f `mcse' ")"
display as text "  empSD    = " as result %9.5f `emp_sd'

if `NSUB' == 300 & `SEED' == 20260715 & `SIMS' == 1000 {
    * RESULT_2026-08-05.md records bias +0.01707 and empSD 1.23911 for exactly
    * this cell. The point estimator does not touch the bootstrap, so a correct
    * regeneration must land on those to the recorded precision. This is the
    * check that says the regenerated pool IS the gate's pool.
    local rec_bias  = 0.01707
    local rec_empsd = 1.23911
    local d_bias  = abs(`bias' - `rec_bias')
    local d_empsd = abs(`emp_sd' - `rec_empsd')
    display as text "  recorded gate pool: bias +0.01707  empSD 1.23911"
    display as text "  |delta| bias " as result %9.7f `d_bias' ///
        as text "  |delta| empSD " as result %9.7f `d_empsd'
    if `d_bias' < 0.000005 & `d_empsd' < 0.000005 {
        display as result "  PROVENANCE OK: regenerated pool reproduces the recorded gate moments"
    }
    else {
        display as error "  PROVENANCE FAILED: this is not the gate's pool."
        display as error "  Every number below would describe a different study."
        exit 459
    }
}
else {
    display as text "  (no recorded gate moments for this cell -- provenance not checkable here)"
}

* -----------------------------------------------------------------------------
* The ladder, every rung at z
* -----------------------------------------------------------------------------
quietly generate double lo_fix  = b - `zc'*se_fix
quietly generate double hi_fix  = b + `zc'*se_fix
quietly generate byte cov_fix   = (`TRUTH' >= lo_fix  & `TRUTH' <= hi_fix)
foreach r in cr0 cr1 cr1s cr2 cr3 {
    * A missing SE must make coverage MISSING, not 0. `truth <= b + z*.' is TRUE
    * and `truth >= b - z*.' is FALSE, so an undefined rung would otherwise be
    * booked as a non-covering replication and drag its coverage down silently.
    quietly generate byte cov_`r' = ///
        (`TRUTH' >= b - `zc'*se_`r' & `TRUTH' <= b + `zc'*se_`r') ///
        if !missing(se_`r')
    quietly generate double infl_`r' = se_`r' / se_cr0
}

display as text ""
display as text "SE ladder (identity working target, inverse_var=FALSE, z critical value)"

quietly summarize se_cr0, meanonly
local mse_cr0 = r(mean)
local need = `emp_sd' / `mse_cr0'

display as text "  mean SE(CR0) = " as result %8.5f `mse_cr0' ///
    as text "   empSD/meanSE(CR0) = " as result %6.4f `need'
display as text ""
display as text "  rung    meanSE   meanSE/CR0   median(SE/CR0)   meanSE/empSD   cov(z)   Wilson      n"

foreach r in fix cr0 cr1 cr1s cr2 cr3 {
    quietly summarize se_`r', meanonly
    local m_`r' = r(mean)
    quietly summarize cov_`r', meanonly
    local c_`r' = r(mean)
    * Wilson is computed on the replications this rung actually produced, not
    * on SIMS: a rung with undefined replications has a smaller denominator and
    * a wider interval, and pretending otherwise would understate its noise.
    local n_`r' = r(N)
    local zz = `zc'
    local ph = `c_`r''
    local nn = `n_`r''
    local den = 1 + `zz'^2/`nn'
    local ctr = (`ph' + `zz'^2/(2*`nn'))/`den'
    local hw  = `zz'*sqrt(`ph'*(1-`ph')/`nn' + `zz'^2/(4*`nn'^2))/`den'
    local wlo = `ctr' - `hw'
    local whi = `ctr' + `hw'

    local ratio = `m_`r''/`mse_cr0'
    local vsd   = `m_`r''/`emp_sd'
    local medr = .
    capture confirm variable infl_`r'
    if !_rc {
        quietly summarize infl_`r', detail
        local medr = r(p50)
    }
    display as text "  " %-6s "`r'" "  " as result %8.5f `m_`r'' ///
        as text "   " as result %8.4f `ratio' ///
        as text "        " as result %8.4f `medr' ///
        as text "       " as result %8.4f `vsd' ///
        as text "     " as result %5.3f `c_`r'' ///
        as text "  [" as result %5.3f `wlo' as text "," as result %5.3f `whi' as text "]" ///
        as text "  " as result %5.0f `n_`r''
}

* -----------------------------------------------------------------------------
* CR3 health. A ladder rung that is finite only because a few clusters blew up
* is not a candidate, and the mean SE alone will not show that.
* -----------------------------------------------------------------------------
quietly summarize maxlev, detail
display as text ""
display as text "leverage / conditioning"
display as text "  max diagonal leverage: median " as result %7.4f r(p50) ///
    as text "  p95 " as result %7.4f r(p95) as text "  max " as result %7.4f r(max)
quietly count if nsing > 0 & !missing(nsing)
display as text "  replications with a singular (I - H_g): " as result %4.0f r(N)
quietly count if missing(se_cr3)
display as text "  replications with CR3 undefined:        " as result %4.0f r(N)
quietly summarize infl_cr3, detail
display as text "  SE(CR3)/SE(CR0): median " as result %7.4f r(p50) ///
    as text "  p95 " as result %7.4f r(p95) as text "  max " as result %7.4f r(max)
quietly summarize infl_cr2, detail
display as text "  SE(CR2)/SE(CR0): median " as result %7.4f r(p50) ///
    as text "  p95 " as result %7.4f r(p95) as text "  max " as result %7.4f r(max)

display as text "{hline 74}"
display as error "RESULT: probe_cr_ladder nsub=`NSUB' DIAGNOSTIC non-gate sims=`SIMS'"
display as error "  a diagnostic cell is not a gate verdict and may not be relabelled"
display as error "  as one (FIPTIW_NSCALE_2026-07-23.md:5-7). No default changes on this."
exit 1
