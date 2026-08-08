* =============================================================================
* probe_bootstrap_t_screen.do - §13.3 item 4: bootstrap-t screen
* =============================================================================
* The stacked sandwich fails at n=300 (coverage 0.905) and the delete-one
* jackknife is structurally broken for this estimator (coverage 0.28). The
* bootstrap-t is the remaining candidate because it estimates the pivot's
* quantiles empirically and is agnostic to whether the defect is scale or shape.
*
* For each outer replication s = 1..SIMS:
*   1. Generate data from the FIPTIW DGP using the registered seed
*   2. Full-sample fit: iivw_weight with scores -> iivw_fit vce(stacked)
*      -> beta-hat, SE_stacked
*   3. For b = 1..BDRAWS:
*      a. Resample subjects with replacement
*      b. Refit weights with scores on the bootstrap sample
*      c. Refit outcome with vce(stacked)
*      -> beta*_b, SE*_b
*   4. Compute the studentized statistic: t*_b = (beta*_b - beta-hat) / SE*_b
*   5. Bootstrap-t interval:
*      [beta-hat - q_{1-alpha/2}(t*) * SE_stacked,
*       beta-hat - q_{alpha/2}(t*) * SE_stacked]
*   6. Also record the stacked Wald, fixed Wald, and percentile bootstrap
*      for comparison.
*
* BDRAWS defaults to 199. The plan's 999 is for the gate; 199 is sufficient to
* estimate the 2.5th and 97.5th percentiles at the screen level.
*
* DIAGNOSTIC ONLY. Same standing as probe_stacked_screen.do.
*
* Usage (from a scratch copy of the package):
*   stata-mp -b do probe_bootstrap_t_screen.do NSUB [SIMS] [SEED] [FROM] [TO]
*   stata-mp -b do probe_bootstrap_t_screen.do NSUB SIMS SEED COMBINE
* NSUB is required. SIMS defaults to 200. SEED defaults to 20260715.
* BDRAWS is controlled by a local below (default 199).
* =============================================================================

clear all
version 16.0
set varabbrev off

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "probe_bootstrap_t_screen.do must be run from iivw/qa"
    exit 198
}
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap

if "`1'" == "" {
    display as error "NSUB required: probe_bootstrap_t_screen.do NSUB [SIMS] [SEED] [FROM] [TO]"
    exit 198
}
local nsub = real("`1'")
local sims = 200
local master = 20260715
local arm = 3
local truth = 1
local bdraws = 199
local from = 1
local to = 0
local combine = 0
if "`2'" != "" local sims = real("`2'")
if "`3'" != "" local master = real("`3'")
if "`4'" != "" {
    if "`4'" == "COMBINE" | "`4'" == "combine" {
        local combine = 1
    }
    else {
        local from = real("`4'")
        if "`5'" != "" local to = real("`5'")
    }
}
if `to' == 0 & `combine' == 0 local to = `sims'
if `combine' == 0 & (`from' < 1 | `to' > `sims' | `from' > `to') {
    display as error "block range `from'-`to' is not inside 1-`sims'"
    exit 198
}
local zc = invnormal(0.975)

* Seed ledger
capture program drop _bt_dgpseed
program define _bt_dgpseed, rclass
    args master arm rep
    return local seed = `master' + `arm'*1000000 + `rep'
end
capture program drop _bt_bootseed
program define _bt_bootseed, rclass
    args master arm rep
    return local seed = `master' + `arm'*1000000 + 500000 + `rep'
end

* FIPTIW DGP
capture program drop _bt_dgp
program define _bt_dgp
    version 16.0
    syntax , seed(integer) [NSUB(integer 300)]
    clear
    set seed `seed'
    set obs `nsub'
    gen long id = _n
    gen double K1 = rnormal(1,1)
    gen byte   K2 = runiform() < 0.55
    gen double K3 = rnormal(0,1)
    gen byte   A  = runiform() < invlogit(0.5 + 0.8*K1 + 0.05*K2 - K3)
    gen double Z  = cond(A==1, rnormal(2,1), rnormal(4,2))
    gen double EZ = cond(A==1, 2, 4)
    gen double phi = rnormal(0, 0.2)
    gen double eta = rgamma(100, 0.01)
    gen double C   = runiform(1, 2)
    gen double lam = eta * exp(0.6*A + 0.3*Z)
    tempfile base
    quietly save `base'
    quietly expand 150
    bysort id: gen int k = _n
    gen double gap = -ln(runiform()) / lam
    bysort id (k): gen double t = sum(gap)
    bysort id (k): egen double _tmax = max(t)
    quietly count if _tmax < C
    if r(N) > 0 {
        display as error "DGP truncated before C"
        exit 459
    }
    quietly drop if t > C
    gen double y = 3 + 1*A + 3*(Z - EZ) + 0.4*K1 + 0.05*K2 - 0.6*K3 ///
        + rnormal(phi, 0.1)
    gen byte entry = 0
    drop k gap _tmax
    tempfile visits
    quietly save `visits'
    quietly use `base', clear
    gen double t = 0
    gen double y = .
    gen byte entry = 1
    quietly append using `visits'
    sort id t
end

* One outer replication: full-sample fit + B bootstrap-t draws
capture program drop _bt_run
program define _bt_run, rclass
    version 16.0
    syntax , TRUTH(real) BDRAWS(integer) BOOTseed(integer)

    * Full-sample fit with stacked SE
    quietly iivw_weight, id(id) time(t) treat(A) treat_cov(K1 K2 K3) ///
        visit_cov(Z) wtype(fiptiw) censor(C) baseline(entry) scores nolog
    quietly iivw_fit y A, timespec(none) vce(stacked) nolog replace
    local b_full = _b[A]
    local se_stk = _se[A]

    * Also grab fixed for comparison
    quietly iivw_fit y A, timespec(none) vce(fixed) nolog replace
    local se_fix = _se[A]

    * Identify subjects and save the raw data (before any weight columns)
    * Actually the weight columns are already there from iivw_weight above.
    * For the bootstrap we need the weighted dataset — but each draw re-does
    * iivw_weight, so we need the raw pre-weight data. However, the DGP
    * output doesn't have weight columns, and iivw_weight added them.
    * We need to save the data as-is (with the weight columns) because
    * the bootstrap draws will need the covariates. iivw_weight on the
    * bootstrap sample will overwrite the weight columns via replace.
    quietly levelsof id, local(ids)
    local m : word count `ids'

    tempfile fulldata
    quietly save `fulldata'

    * Bootstrap draws
    tempname tstar
    matrix `tstar' = J(`bdraws', 1, .)
    tempname bstar_vec
    matrix `bstar_vec' = J(`bdraws', 1, .)
    local n_bdone = 0

    set seed `bootseed'
    forvalues b = 1/`bdraws' {
        quietly {
            use `fulldata', clear

            * Resample subjects with replacement
            * Create a bootstrap sample by drawing m subjects with replacement
            tempvar _bsid _bsseq
            preserve
            clear
            set obs `m'
            gen long `_bsid' = ceil(runiform() * `m')
            gen long `_bsseq' = _n
            tempfile bskeys
            save `bskeys'
            restore

            * Expand: for each drawn subject, include all their rows
            * Use joinby-like logic: rename id, merge
            rename id _origid
            gen long `_bsseq' = .
            tempfile expanded
            local first = 1
            forvalues k = 1/`m' {
                * This approach is too slow. Use a faster method.
            }
        }
        * The manual resample loop above is O(m^2). Use bsample instead.
        break
    }

    * FASTER APPROACH: use Stata's bsample for the resampling,
    * then refit weights and stacked SE on each draw.
    forvalues b = 1/`bdraws' {
        quietly {
            use `fulldata', clear

            * bsample resamples clusters (subjects) with replacement
            * It physically replaces the data with the bootstrap sample
            bsample, cluster(id) idcluster(_bsid)

            * Refit weights on the bootstrap sample (no scores needed
            * for the inner weight refit — scores are only for the
            * stacked SE computation)
            capture {
                iivw_weight, id(_bsid) time(t) treat(A) ///
                    treat_cov(K1 K2 K3) visit_cov(Z) wtype(fiptiw) ///
                    censor(C) baseline(entry) scores replace nolog
                iivw_fit y A, timespec(none) vce(stacked) nolog replace
            }
            if _rc {
                matrix `tstar'[`b', 1] = .
                matrix `bstar_vec'[`b', 1] = .
                continue
            }

            local b_star = _b[A]
            local se_star = _se[A]
            matrix `bstar_vec'[`b', 1] = `b_star'

            if `se_star' > 0 & !missing(`se_star') {
                matrix `tstar'[`b', 1] = (`b_star' - `b_full') / `se_star'
                local ++n_bdone
            }
            else {
                matrix `tstar'[`b', 1] = .
            }
        }
    }

    if `n_bdone' < `bdraws' * 0.8 {
        display as error "too many bootstrap failures: `=`bdraws'-`n_bdone''/`bdraws'"
        error 459
    }

    * Bootstrap-t quantiles from the non-missing t* values
    * Put them into a dataset to use _pctile
    preserve
    clear
    quietly set obs `bdraws'
    quietly gen double tval = .
    quietly gen double bval = .
    forvalues b = 1/`bdraws' {
        quietly replace tval = el(`tstar', `b', 1) in `b'
        quietly replace bval = el(`bstar_vec', `b', 1) in `b'
    }
    quietly drop if missing(tval)

    * Bootstrap-t: use quantiles of t* to form the interval
    * CI = [b_full - q_{1-alpha/2}(t*) * SE_stk, b_full - q_{alpha/2}(t*) * SE_stk]
    _pctile tval, p(2.5 97.5)
    local tq025 = r(r1)
    local tq975 = r(r2)

    * Percentile bootstrap for comparison
    _pctile bval, p(2.5 97.5)
    local pct_lo = r(r1)
    local pct_hi = r(r2)

    restore

    * Bootstrap-t interval
    local bt_lo = `b_full' - `tq975' * `se_stk'
    local bt_hi = `b_full' - `tq025' * `se_stk'

    local zc = invnormal(0.975)

    return scalar b_full   = `b_full'
    return scalar se_stk   = `se_stk'
    return scalar se_fix   = `se_fix'
    return scalar cov_stk  = (`truth' >= `b_full' - `zc'*`se_stk' & ///
        `truth' <= `b_full' + `zc'*`se_stk')
    return scalar cov_fix  = (`truth' >= `b_full' - `zc'*`se_fix' & ///
        `truth' <= `b_full' + `zc'*`se_fix')
    return scalar cov_bt   = (`truth' >= `bt_lo' & `truth' <= `bt_hi')
    return scalar cov_pct  = (`truth' >= `pct_lo' & `truth' <= `pct_hi')
    return scalar bt_lo    = `bt_lo'
    return scalar bt_hi    = `bt_hi'
    return scalar tq025    = `tq025'
    return scalar tq975    = `tq975'
    return scalar n_bdone  = `n_bdone'
    return scalar m        = `m'
end

local is_block = (`from' != 1 | `to' != `sims') & `combine' == 0

* ---- COMBINE PATH ----
if `combine' {
    display as text ""
    display as text "probe_bootstrap_t_screen COMBINE -- nsub=`nsub' sims=`sims'"
    local allfiles : dir "." files "probe_bootstrap_t_screen_`nsub'_*.dta"
    local n_files : word count `allfiles'
    if `n_files' == 0 {
        display as error "no block files found for nsub=`nsub'"
        exit 601
    }
    clear
    foreach f of local allfiles {
        append using "`f'"
    }
    quietly count
    local n_ok = r(N)
    isid sim
    quietly summarize sim
    if r(min) != 1 | r(max) != `sims' {
        display as error "blocks do not tile 1..`sims'"
        exit 459
    }
    if `n_ok' != `sims' {
        display as error "expected `sims' rows, got `n_ok'"
        exit 459
    }
    local n_fail = 0
    display as text "  combined `n_files' block file(s), `n_ok' rows, tile verified"
}
* ---- SIMULATION PATH ----
else {
    display as text ""
    if `is_block' {
        display as text "probe_bootstrap_t_screen BLOCK -- nsub=`nsub' from=`from' to=`to'"
    }
    else {
        display as text "probe_bootstrap_t_screen -- nsub=`nsub' sims=`sims'"
    }
    display as text "DIAGNOSTIC ONLY. Not a coverage verdict for any gate."
    display as text "bdraws=`bdraws' per outer replication"
    display as text ""

    tempfile out
    tempname pf
    postfile `pf' int(sim) ///
        double(b se_stk se_fix cov_stk cov_fix cov_bt cov_pct ///
               bt_lo bt_hi tq025 tq975 n_bdone nsub_actual) ///
        using "`out'", replace

    local n_ok = 0
    local n_fail = 0
    forvalues s = `from'/`to' {
        _bt_dgpseed `master' `arm' `s'
        local dgpseed = `r(seed)'
        _bt_bootseed `master' `arm' `s'
        local bootseed = `r(seed)'
        quietly {
            capture noisily {
                _bt_dgp, seed(`dgpseed') nsub(`nsub')
                _bt_run, truth(`truth') bdraws(`bdraws') bootseed(`bootseed')
                post `pf' (`s') ///
                    (`r(b_full)') (`r(se_stk)') (`r(se_fix)') ///
                    (`r(cov_stk)') (`r(cov_fix)') (`r(cov_bt)') (`r(cov_pct)') ///
                    (`r(bt_lo)') (`r(bt_hi)') ///
                    (`r(tq025)') (`r(tq975)') ///
                    (`r(n_bdone)') (`r(m)')
                local ++n_ok
            }
            if _rc {
                display as error "sim `s' failed (rc " _rc ")"
                local ++n_fail
            }
        }
        if mod(`s' - `from' + 1, 5) == 0 {
            display as text "  sim `s' done (`n_ok' ok, `n_fail' fail)"
        }
    }
    postclose `pf'

    if `is_block' {
        use "`out'", clear
        local blkfile "probe_bootstrap_t_screen_`nsub'_`from'_`to'.dta"
        quietly save "`blkfile'", replace
        display as text "BLOCK `from'-`to': wrote `n_ok' rows to `blkfile' (`n_fail' failed)"
        display as text "BLOCK-ONLY: no verdict. Run with COMBINE to aggregate."
        exit
    }

    if `n_ok' < 50 {
        display as error "too few replications (`n_ok'/`sims')"
        exit 2000
    }

    use "`out'", clear
}

* ---- ANALYSIS ----
summarize cov_fix
local cf = r(mean)
summarize cov_stk
local cs = r(mean)
summarize cov_bt
local cbt = r(mean)
summarize cov_pct
local cpct = r(mean)

summarize b, detail
local sd_b   = r(sd)
local iqrs_b = (r(p75) - r(p25)) / 1.349
local mean_b = r(mean)
local bias   = `mean_b' - `truth'

summarize se_stk, detail
local meds = r(p50)

gen byte cov_oracle = abs(b - `truth') < `zc' * `sd_b'
summarize cov_oracle
local co = r(mean)

summarize tq025, detail
local med_tq025 = r(p50)
summarize tq975, detail
local med_tq975 = r(p50)

local p_hat = `cbt'
local n_w   = _N
local z2    = `zc'^2
local wi_lo = (`p_hat' + `z2'/(2*`n_w') - `zc'*sqrt((`p_hat'*(1-`p_hat') + `z2'/(4*`n_w'))/`n_w')) / (1 + `z2'/`n_w')
local wi_hi = (`p_hat' + `z2'/(2*`n_w') + `zc'*sqrt((`p_hat'*(1-`p_hat') + `z2'/(4*`n_w'))/`n_w')) / (1 + `z2'/`n_w')

display as text ""
display as text "=== BOOTSTRAP-T SCREEN: nsub=`nsub' sims=`=_N' (failed `n_fail') ==="
display as text ""
display as text "sampling distribution (truth `truth')"
display as text "  bias/empSD " %6.3f `bias'/`sd_b' ///
    "  SD/IQRscale " %6.3f `sd_b'/`iqrs_b'
display as text ""
display as text "coverage of the nominal 95% interval"
display as text "  fixed Wald         " %6.4f `cf'
display as text "  stacked Wald       " %6.4f `cs'
display as text "  bootstrap-t        " %6.4f `cbt' ///
    "  Wilson [" %5.3f `wi_lo' ", " %5.3f `wi_hi' "]"
display as text "  percentile         " %6.4f `cpct'
display as text "  oracle (empSD)     " %6.4f `co'
display as text ""
display as text "bootstrap-t quantiles (median across reps)"
display as text "  q(0.025) " %7.4f `med_tq025' "   q(0.975) " %7.4f `med_tq975' ///
    "   (symmetric normal: -1.96, +1.96)"
display as text ""
display as text "BTSCREEN: nsub=`nsub' sims=`=_N' " ///
    "bias_sd=" %6.3f `bias'/`sd_b' ///
    " sd_iqr=" %6.3f `sd_b'/`iqrs_b' ///
    " cov_bt=" %6.4f `cbt' " cov_stk=" %6.4f `cs' ///
    " cov_fix=" %6.4f `cf' " cov_pct=" %6.4f `cpct' ///
    " cov_orc=" %6.4f `co' ///
    " tq025=" %7.4f `med_tq025' " tq975=" %7.4f `med_tq975'
