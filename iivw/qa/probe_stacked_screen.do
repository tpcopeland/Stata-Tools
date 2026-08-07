* =============================================================================
* probe_stacked_screen.do - §13.3 item 2: R=200 screen at n=300/600/1200
* =============================================================================
* Screens the stacked sandwich on the FIPTIW gate DGP at the three registered
* sample sizes, using the registered seed ledger (master 20260715, arm 3). This
* is the §10 tier-2 screen called for in se_recovery.md §13.3 item 2.
*
* DIAGNOSTIC ONLY. R=200 has a Wilson half-width of ~±3pp — enough to reject a
* candidate at 0.92 or flag one at 0.985, not enough to certify one. This
* carries the same relabelling prohibition as FIPTIW_NSCALE_2026-07-23.md:5-7.
* The DGP and seeds are the registered ones, so the results ARE comparable to
* the existing gate pool, but 200 reps is a screen, not a gate run.
*
* For each generated dataset it forms the Wald interval three ways:
*   fixed    — vce(fixed), the shipped default
*   stacked  — vce(stacked), the §13.3 item 1 implementation
*   refit    — vce(bootstrap, reps(999)), the existing gate candidate
* and records coverage of each against truth=1, plus the oracle (1.96 × empSD).
*
* Usage (from a scratch copy of the package, per the isolation rule):
*   stata-mp -b do probe_stacked_screen.do NSUB [SIMS] [SEED] [FROM] [TO]
* NSUB is required (no silent default — the caller must know what they asked).
* SIMS defaults to 200 (the §10 tier-2 count). SEED defaults to 20260715 (the
* registered master). The arm is always 3 (FIPTIW strong-dependence).
*
* BLOCK SHARDING. FROM/TO run a subset of the 1..SIMS replications and write
* raw rows to probe_stacked_screen_NSUB_FROM_TO.dta without a verdict. A
* separate COMBINE invocation aggregates the blocks:
*   stata-mp -b do probe_stacked_screen.do NSUB SIMS SEED COMBINE
* which reads all probe_stacked_screen_NSUB_*.dta in the cwd, verifies they
* tile 1..SIMS exactly, and reports. The seed ledger is deterministic, so
* sharding is equivalent by construction.
* =============================================================================

clear all
version 16.0
set varabbrev off

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "probe_stacked_screen.do must be run from iivw/qa"
    exit 198
}
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap

if "`1'" == "" {
    display as error "NSUB is required: probe_stacked_screen.do NSUB [SIMS] [SEED]"
    exit 198
}
local nsub = real("`1'")
local sims = 200
local master = 20260715
local arm = 3
local truth = 1
local reps = 999
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

* Seed ledger — identical to validation_iivw_inference.do
capture program drop _scr_dgpseed
program define _scr_dgpseed, rclass
    args master arm rep
    return local seed = `master' + `arm'*1000000 + `rep'
end
capture program drop _scr_bootseed
program define _scr_bootseed, rclass
    args master arm rep
    return local seed = `master' + `arm'*1000000 + 500000 + `rep'
end

* FIPTIW DGP — identical to validation_iivw_inference.do's _inf_dgp_fiptiw
capture program drop _scr_dgp
program define _scr_dgp
    version 16.0
    syntax , seed(integer) [NSUB(integer 300) PSCALE(real 1)]
    clear
    set seed `seed'
    set obs `nsub'
    gen long id = _n
    gen double K1 = rnormal(1,1)
    gen byte   K2 = runiform() < 0.55
    gen double K3 = rnormal(0,1)
    gen byte   A  = runiform() < ///
        invlogit(0.5 + `pscale'*(0.8*K1 + 0.05*K2 - K3))
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
        display as error "DGP: visit process truncated before C for `r(N)' subjects"
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

local is_block = (`from' != 1 | `to' != `sims') & `combine' == 0

* ---- COMBINE PATH ----
if `combine' {
    display as text ""
    display as text "probe_stacked_screen COMBINE -- nsub=`nsub' sims=`sims'"
    local allfiles : dir "." files "probe_stacked_screen_`nsub'_*.dta"
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
        display as error "blocks do not tile 1..`sims' (min=" r(min) " max=" r(max) ")"
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
        display as text "probe_stacked_screen BLOCK -- nsub=`nsub' from=`from' to=`to'"
    }
    else {
        display as text "probe_stacked_screen -- nsub=`nsub' sims=`sims' master=`master'"
    }
    display as text "DIAGNOSTIC ONLY (§10 tier 2). Not a coverage verdict for any gate."
    display as text ""

    tempfile out
    tempname pf
    postfile `pf' int(sim) ///
        double(b_fix se_fix cov_fix b_stk se_stk cov_stk b_ref se_ref cov_ref ///
               cov_pct cov_basic cov_bc cov_bca nsub_actual) ///
        using "`out'", replace

    local n_ok = 0
    local n_fail = 0
    local zc = invnormal(0.975)
    forvalues s = `from'/`to' {
        _scr_dgpseed  `master' `arm' `s'
        local dgpseed = `r(seed)'
        _scr_bootseed `master' `arm' `s'
        local bootseed = `r(seed)'
        quietly {
            capture noisily {
                _scr_dgp, seed(`dgpseed') nsub(`nsub')
                levelsof id, local(_ids)
                local _nsub : word count `_ids'

                iivw_weight, id(id) time(t) treat(A) treat_cov(K1 K2 K3) ///
                    visit_cov(Z) wtype(fiptiw) censor(C) baseline(entry) ///
                    scores nolog

                iivw_fit y A, timespec(none) vce(fixed) nolog replace
                local b_fix  = _b[A]
                local se_fix = _se[A]
                local cov_fix = (`truth' >= _b[A]-`zc'*_se[A] & ///
                    `truth' <= _b[A]+`zc'*_se[A])

                iivw_fit y A, timespec(none) vce(stacked) nolog replace
                local b_stk  = _b[A]
                local se_stk = _se[A]
                local cov_stk = (`truth' >= _b[A]-`zc'*_se[A] & ///
                    `truth' <= _b[A]+`zc'*_se[A])

                iivw_fit y A, timespec(none) ///
                    vce(bootstrap, reps(`reps') seed(`bootseed')) ///
                    citype(bca) nolog replace
                local b_ref  = _b[A]
                local se_ref = _se[A]
                local cov_ref = (`truth' >= _b[A]-`zc'*_se[A] & ///
                    `truth' <= _b[A]+`zc'*_se[A])

                tempname CI_PCT CI_BC CI_BCA
                matrix `CI_PCT' = e(ci_percentile)
                matrix `CI_BC'  = e(ci_bc)
                matrix `CI_BCA' = e(ci_bca)
                local j = colnumb(e(b), "A")
                if missing(`j') | `j' < 1 error 459
                local cov_pct = (`truth' >= el(`CI_PCT',1,`j') & ///
                    `truth' <= el(`CI_PCT',2,`j'))
                local ci_pct_lo = el(`CI_PCT',1,`j')
                local ci_pct_hi = el(`CI_PCT',2,`j')
                local cov_basic = (`truth' >= 2*_b[A]-`ci_pct_hi' & ///
                    `truth' <= 2*_b[A]-`ci_pct_lo')
                local cov_bc = (`truth' >= el(`CI_BC',1,`j') & ///
                    `truth' <= el(`CI_BC',2,`j'))
                local cov_bca = (`truth' >= el(`CI_BCA',1,`j') & ///
                    `truth' <= el(`CI_BCA',2,`j'))

                post `pf' (`s') ///
                    (`b_fix') (`se_fix') (`cov_fix') ///
                    (`b_stk') (`se_stk') (`cov_stk') ///
                    (`b_ref') (`se_ref') (`cov_ref') ///
                    (`cov_pct') (`cov_basic') (`cov_bc') (`cov_bca') ///
                    (`_nsub')
                local ++n_ok
            }
            if _rc {
                display as error "sim `s' failed (rc " _rc ")"
                local ++n_fail
            }
        }
        if mod(`s' - `from' + 1, 25) == 0 {
            display as text "  sim `s' done (`n_ok' ok, `n_fail' fail)"
        }
    }
    postclose `pf'

    if `is_block' {
        use "`out'", clear
        local blkfile "probe_stacked_screen_`nsub'_`from'_`to'.dta"
        quietly save "`blkfile'", replace
        display as text "BLOCK `from'-`to': wrote `n_ok' rows to `blkfile' (`n_fail' failed)"
        display as text "BLOCK-ONLY: no verdict. Run with COMBINE to aggregate."
        exit
    }

    if `n_ok' < 50 {
        display as error "too few replications to screen (`n_ok'/`sims')"
        exit 2000
    }

    use "`out'", clear
}

* Coverage
summarize cov_fix
local cf = r(mean)
summarize cov_stk
local cs = r(mean)
summarize cov_ref
local cr = r(mean)
summarize cov_pct
local cpct = r(mean)
summarize cov_basic
local cbas = r(mean)
summarize cov_bc
local cbc = r(mean)
summarize cov_bca
local cbca = r(mean)

* SE ratios — stacked uses its own b (same point estimate via same weights, but
* re-reading after the repost).
summarize b_stk, detail
local sd_b    = r(sd)
local iqrs_b  = (r(p75) - r(p25)) / 1.349
local mean_b  = r(mean)
local skew_b  = r(skewness)
local kurt_b  = r(kurtosis)
local bias    = `mean_b' - `truth'

summarize se_fix, detail
local medf = r(p50)
summarize se_stk, detail
local meds = r(p50)
summarize se_ref, detail
local medr = r(p50)

* Oracle
gen byte cov_oracle = abs(b_stk - `truth') < `zc' * `sd_b'
gen byte cov_oracle_c = abs(b_stk - `mean_b') < `zc' * `sd_b'
summarize cov_oracle
local co = r(mean)
summarize cov_oracle_c
local coc = r(mean)

* Studentized pivot
gen double t_stk = (b_stk - `truth') / se_stk
gen double at_stk = abs(t_stk)
_pctile at_stk, p(95)
local crit95 = r(r1)
summarize t_stk, detail
local t_iqrs = (r(p75) - r(p25)) / 1.349

* Wilson 95% CI for stacked coverage
local p_hat = `cs'
local n_w   = `n_ok'
local z2    = `zc'^2
local wi_lo = (`p_hat' + `z2'/(2*`n_w') - `zc'*sqrt((`p_hat'*(1-`p_hat') + `z2'/(4*`n_w'))/`n_w')) / (1 + `z2'/`n_w')
local wi_hi = (`p_hat' + `z2'/(2*`n_w') + `zc'*sqrt((`p_hat'*(1-`p_hat') + `z2'/(4*`n_w'))/`n_w')) / (1 + `z2'/`n_w')

display as text ""
display as text "=== SCREEN RESULTS: nsub=`nsub' sims=`n_ok' (failed `n_fail') ==="
display as text ""
display as text "sampling distribution of beta-hat (truth `truth')"
display as text "  mean     " %9.5f `mean_b' "  bias " %9.5f `bias' ///
    "  bias/empSD " %6.3f `bias'/`sd_b'
display as text "  empSD    " %9.5f `sd_b' "  IQR-scale " %9.5f `iqrs_b' ///
    "  SD/IQRscale " %6.3f `sd_b'/`iqrs_b'
display as text "  skewness " %9.4f `skew_b' "  kurtosis  " %9.4f `kurt_b'
display as text ""
display as text "SE size (medSE vs IQR-scale of b)"
display as text "  fixed    " %9.5f `medf' "  ratio " %6.4f `medf'/`iqrs_b'
display as text "  stacked  " %9.5f `meds' "  ratio " %6.4f `meds'/`iqrs_b'
display as text "  refit    " %9.5f `medr' "  ratio " %6.4f `medr'/`iqrs_b'
display as text ""
display as text "coverage of the nominal 95% Wald interval"
display as text "  fixed              " %6.4f `cf'
display as text "  stacked            " %6.4f `cs' ///
    "  Wilson [" %5.3f `wi_lo' ", " %5.3f `wi_hi' "]"
display as text "  refit-bootstrap    " %6.4f `cr'
display as text "  percentile         " %6.4f `cpct'
display as text "  basic              " %6.4f `cbas'
display as text "  bias-corrected     " %6.4f `cbc'
display as text "  BCa                " %6.4f `cbca'
display as text ""
display as text "oracle (1.96 * empSD)"
display as text "  truth-centred      " %6.4f `co'
display as text "  mean-centred       " %6.4f `coc'
display as text ""
display as text "stacked pivot: p95 of |t| " %7.4f `crit95' ///
    "  IQR-scale " %7.4f `t_iqrs' "  (1.96 is nominal)"
display as text ""
display as text "SCREEN: nsub=`nsub' sims=`n_ok' bias_sd=" %6.3f `bias'/`sd_b' ///
    " sd_iqr=" %6.3f `sd_b'/`iqrs_b' ///
    " med_fix=" %6.4f `medf'/`iqrs_b' ///
    " med_stk=" %6.4f `meds'/`iqrs_b' ///
    " med_ref=" %6.4f `medr'/`iqrs_b' ///
    " cov_fix=" %6.4f `cf' " cov_stk=" %6.4f `cs' ///
    " cov_ref=" %6.4f `cr' " cov_pct=" %6.4f `cpct' ///
    " cov_bca=" %6.4f `cbca' ///
    " cov_orc=" %6.4f `co' " crit=" %6.4f `crit95'
