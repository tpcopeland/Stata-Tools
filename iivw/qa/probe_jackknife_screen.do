* =============================================================================
* probe_jackknife_screen.do - §13.3 item 3: delete-one-subject jackknife screen
* =============================================================================
* The stacked sandwich fails at n=300 (coverage 0.905, Wilson excludes 0.95) and
* passes at n=600 (0.940, Wilson contains 0.95). The one-step jackknife built on
* the influence function differs from the stacked sandwich by ((m-1)/m)^2 and
* therefore cannot repair the n=300 deficit. The LITERAL delete-one-subject
* jackknife captures the nonlinearity the linearization misses, and jackknife
* variance is known to be upward-biased — a drawback normally, but aimed at the
* defect here.
*
* For each generated dataset:
*   1. Fit the full sample: iivw_weight + iivw_fit vce(stacked) -> beta-hat, SE_stk
*   2. For each subject i=1..m, drop all rows with id==i, refit weights + outcome
*      -> beta-hat_{-i}
*   3. Jackknife SE = sqrt( ((m-1)/m) * sum_i (beta-hat_{-i} - beta-bar)^2 )
*      where beta-bar = mean of the leave-one-out estimates
*   4. Wald interval: beta-hat +/- 1.96 * SE_jack
*
* The refit is FULL: weights are re-estimated on each leave-one-out sample, so
* the jackknife variance reflects weight uncertainty. This is 300 refits per
* outer replication at n=300 — cheap compared to 999 bootstrap draws, and with
* zero Monte Carlo error.
*
* DIAGNOSTIC ONLY. Same standing as probe_stacked_screen.do. Not a coverage
* verdict, not a gate run.
*
* Usage (from a scratch copy of the package, per the isolation rule):
*   stata-mp -b do probe_jackknife_screen.do NSUB [SIMS] [SEED] [FROM] [TO]
*   stata-mp -b do probe_jackknife_screen.do NSUB SIMS SEED COMBINE
* NSUB is required. SIMS defaults to 200. SEED defaults to 20260715.
* FROM/TO shard the simulation; COMBINE aggregates block .dta files.
* =============================================================================

clear all
version 16.0
set varabbrev off

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "probe_jackknife_screen.do must be run from iivw/qa"
    exit 198
}
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap

if "`1'" == "" {
    display as error "NSUB is required: probe_jackknife_screen.do NSUB [SIMS] [SEED] [FROM] [TO]"
    exit 198
}
local nsub = real("`1'")
local sims = 200
local master = 20260715
local arm = 3
local truth = 1
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
capture program drop _jk_dgpseed
program define _jk_dgpseed, rclass
    args master arm rep
    return local seed = `master' + `arm'*1000000 + `rep'
end

* FIPTIW DGP — identical to validation_iivw_inference.do's _inf_dgp_fiptiw
capture program drop _jk_dgp
program define _jk_dgp
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

* Delete-one-subject jackknife of the FIPTIW estimator.
* Returns r(se_jack) and r(b_full).
capture program drop _jk_run
program define _jk_run, rclass
    version 16.0
    syntax , TRUTH(real)

    * Identify subjects and save the RAW dataset before any iivw_weight
    * touches it — iivw_weight adds score columns and chars that interfere
    * with a fresh call on a leave-one-out sample.
    quietly levelsof id, local(ids)
    local m : word count `ids'

    tempfile rawdata
    quietly save `rawdata'

    * Full-sample fit
    quietly iivw_weight, id(id) time(t) treat(A) treat_cov(K1 K2 K3) ///
        visit_cov(Z) wtype(fiptiw) censor(C) baseline(entry) scores nolog
    quietly iivw_fit y A, timespec(none) vce(stacked) nolog replace
    local b_full = _b[A]
    local se_stk = _se[A]

    * Also grab fixed for comparison
    quietly iivw_fit y A, timespec(none) vce(fixed) nolog replace
    local se_fix = _se[A]

    * Leave-one-out refits from the raw (unweighted) dataset
    tempname jk_b
    matrix `jk_b' = J(`m', 1, .)
    local j = 0
    foreach i of local ids {
        local ++j
        quietly {
            use `rawdata', clear
            drop if id == `i'
            capture {
                iivw_weight, id(id) time(t) treat(A) treat_cov(K1 K2 K3) ///
                    visit_cov(Z) wtype(fiptiw) censor(C) baseline(entry) nolog
                iivw_fit y A, timespec(none) vce(fixed) nolog replace
            }
            if _rc {
                matrix `jk_b'[`j', 1] = .
            }
            else {
                matrix `jk_b'[`j', 1] = _b[A]
            }
        }
    }

    * Jackknife variance: ((m-1)/m) * sum(b_i - bbar)^2
    * Count non-missing
    local n_jk = 0
    local sum_b = 0
    forvalues j = 1/`m' {
        if !missing(el(`jk_b', `j', 1)) {
            local ++n_jk
            local sum_b = `sum_b' + el(`jk_b', `j', 1)
        }
    }
    if `n_jk' < `m' - 5 {
        display as error "too many jackknife failures: `=`m'-`n_jk''/`m'"
        error 459
    }
    local bbar = `sum_b' / `n_jk'
    local ssq = 0
    forvalues j = 1/`m' {
        if !missing(el(`jk_b', `j', 1)) {
            local dev = el(`jk_b', `j', 1) - `bbar'
            local ssq = `ssq' + `dev'^2
        }
    }
    local se_jack = sqrt((`n_jk' - 1) / `n_jk' * `ssq')

    local zc = invnormal(0.975)
    return scalar b_full  = `b_full'
    return scalar se_stk  = `se_stk'
    return scalar se_fix  = `se_fix'
    return scalar se_jack = `se_jack'
    return scalar cov_stk = (`truth' >= `b_full' - `zc'*`se_stk' & ///
        `truth' <= `b_full' + `zc'*`se_stk')
    return scalar cov_fix = (`truth' >= `b_full' - `zc'*`se_fix' & ///
        `truth' <= `b_full' + `zc'*`se_fix')
    return scalar cov_jack = (`truth' >= `b_full' - `zc'*`se_jack' & ///
        `truth' <= `b_full' + `zc'*`se_jack')
    return scalar m = `m'
    return scalar n_jk = `n_jk'
    return scalar jack_stk_ratio = `se_jack' / `se_stk'
end

local is_block = (`from' != 1 | `to' != `sims') & `combine' == 0

* ---- COMBINE PATH ----
if `combine' {
    display as text ""
    display as text "probe_jackknife_screen COMBINE -- nsub=`nsub' sims=`sims'"
    local allfiles : dir "." files "probe_jackknife_screen_`nsub'_*.dta"
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
        display as text "probe_jackknife_screen BLOCK -- nsub=`nsub' from=`from' to=`to'"
    }
    else {
        display as text "probe_jackknife_screen -- nsub=`nsub' sims=`sims' master=`master'"
    }
    display as text "DIAGNOSTIC ONLY. Not a coverage verdict for any gate."
    display as text ""

    tempfile out
    tempname pf
    postfile `pf' int(sim) ///
        double(b se_stk se_fix se_jack cov_stk cov_fix cov_jack ///
               jack_stk_ratio nsub_actual) ///
        using "`out'", replace

    local n_ok = 0
    local n_fail = 0
    forvalues s = `from'/`to' {
        _jk_dgpseed `master' `arm' `s'
        local dgpseed = `r(seed)'
        quietly {
            capture noisily {
                _jk_dgp, seed(`dgpseed') nsub(`nsub')
                _jk_run, truth(`truth')
                post `pf' (`s') ///
                    (`r(b_full)') (`r(se_stk)') (`r(se_fix)') (`r(se_jack)') ///
                    (`r(cov_stk)') (`r(cov_fix)') (`r(cov_jack)') ///
                    (`r(jack_stk_ratio)') (`r(m)')
                local ++n_ok
            }
            if _rc {
                display as error "sim `s' failed (rc " _rc ")"
                local ++n_fail
            }
        }
        if mod(`s' - `from' + 1, 10) == 0 {
            display as text "  sim `s' done (`n_ok' ok, `n_fail' fail)"
        }
    }
    postclose `pf'

    if `is_block' {
        use "`out'", clear
        local blkfile "probe_jackknife_screen_`nsub'_`from'_`to'.dta"
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
local zc = invnormal(0.975)

summarize cov_fix
local cf = r(mean)
summarize cov_stk
local cs = r(mean)
summarize cov_jack
local cj = r(mean)

summarize b, detail
local sd_b   = r(sd)
local iqrs_b = (r(p75) - r(p25)) / 1.349
local mean_b = r(mean)
local bias   = `mean_b' - `truth'

summarize se_fix, detail
local medf = r(p50)
summarize se_stk, detail
local meds = r(p50)
summarize se_jack, detail
local medj = r(p50)

summarize jack_stk_ratio, detail
local med_ratio = r(p50)
local mean_ratio = r(mean)

gen byte cov_oracle = abs(b - `truth') < `zc' * `sd_b'
summarize cov_oracle
local co = r(mean)

gen double t_jack = (b - `truth') / se_jack
gen double at_jack = abs(t_jack)
_pctile at_jack, p(95)
local crit95 = r(r1)

local p_hat = `cj'
local n_w   = _N
local z2    = `zc'^2
local wi_lo = (`p_hat' + `z2'/(2*`n_w') - `zc'*sqrt((`p_hat'*(1-`p_hat') + `z2'/(4*`n_w'))/`n_w')) / (1 + `z2'/`n_w')
local wi_hi = (`p_hat' + `z2'/(2*`n_w') + `zc'*sqrt((`p_hat'*(1-`p_hat') + `z2'/(4*`n_w'))/`n_w')) / (1 + `z2'/`n_w')

display as text ""
display as text "=== JACKKNIFE SCREEN: nsub=`nsub' sims=`n_ok' (failed `n_fail') ==="
display as text ""
display as text "sampling distribution (truth `truth')"
display as text "  bias/empSD " %6.3f `bias'/`sd_b' ///
    "  SD/IQRscale " %6.3f `sd_b'/`iqrs_b'
display as text ""
display as text "SE size (medSE vs IQR-scale of b)"
display as text "  fixed    " %9.5f `medf' "  ratio " %6.4f `medf'/`iqrs_b'
display as text "  stacked  " %9.5f `meds' "  ratio " %6.4f `meds'/`iqrs_b'
display as text "  jackknife" %9.5f `medj' "  ratio " %6.4f `medj'/`iqrs_b'
display as text ""
display as text "jackknife / stacked SE ratio: median " %6.4f `med_ratio' ///
    "  mean " %6.4f `mean_ratio'
display as text ""
display as text "coverage of the nominal 95% Wald interval"
display as text "  fixed              " %6.4f `cf'
display as text "  stacked            " %6.4f `cs'
display as text "  jackknife          " %6.4f `cj' ///
    "  Wilson [" %5.3f `wi_lo' ", " %5.3f `wi_hi' "]"
display as text "  oracle (empSD)     " %6.4f `co'
display as text ""
display as text "jackknife pivot: p95 of |t| " %7.4f `crit95' "  (1.96 is nominal)"
display as text ""
display as text "JKSCREEN: nsub=`nsub' sims=`n_ok' " ///
    "bias_sd=" %6.3f `bias'/`sd_b' ///
    " sd_iqr=" %6.3f `sd_b'/`iqrs_b' ///
    " med_jk=" %6.4f `medj'/`iqrs_b' ///
    " med_stk=" %6.4f `meds'/`iqrs_b' ///
    " jk_stk=" %6.4f `med_ratio' ///
    " cov_jk=" %6.4f `cj' " cov_stk=" %6.4f `cs' ///
    " cov_fix=" %6.4f `cf' " cov_orc=" %6.4f `co' ///
    " crit=" %6.4f `crit95'
