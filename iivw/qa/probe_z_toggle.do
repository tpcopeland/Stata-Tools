* =============================================================================
* probe_z_toggle.do - Does making Z subject-constant create the coverage gap?
* =============================================================================
* Coulombe et al. (2021) Table A.3 reports 95.5% coverage at n=250 with their
* original DGP where Z is TIME-VARYING (redrawn at each visit). The package
* adaptation makes Z SUBJECT-CONSTANT, and coverage is 0.905-0.914 at n=300.
*
* This probe runs BOTH DGPs side by side — time-varying Z (Coulombe original)
* and subject-constant Z (package adaptation) — on the same seeds, and compares
* coverage. If the gap appears only with subject-constant Z, the coverage
* deficit is an artifact of the DGP choice, not a property of FIPTIW.
*
* The stacked sandwich is the variance estimator for both arms, since it is
* the one the paper derives.
*
* DIAGNOSTIC ONLY. Same standing as the other probes.
*
* Usage:
*   stata-mp -b do probe_z_toggle.do [NSUB] [SIMS] [SEED]
* Defaults: NSUB=300, SIMS=500, SEED=990000.
* =============================================================================

clear all
version 16.0
set varabbrev off

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "probe_z_toggle.do must be run from iivw/qa"
    exit 198
}
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap

local nsub = 300
local sims = 500
local seed = 990000
local truth = 1
if "`1'" != "" local nsub = real("`1'")
if "`2'" != "" local sims = real("`2'")
if "`3'" != "" local seed = real("`3'")
if `sims' < 50 {
    display as error "SIMS below 50 cannot resolve this"
    exit 198
}

* DGP with SUBJECT-CONSTANT Z (package adaptation)
capture program drop _zt_dgp_constant
program define _zt_dgp_constant
    version 16.0
    syntax , seed(integer) nsub(integer)
    clear
    set seed `seed'
    set obs `nsub'
    gen long id = _n
    gen double K1 = rnormal(1,1)
    gen byte   K2 = runiform() < 0.55
    gen double K3 = rnormal(0,1)
    gen byte   A  = runiform() < invlogit(0.5 + 0.8*K1 + 0.05*K2 - K3)
    * Z is SUBJECT-CONSTANT: drawn once per subject
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
        display as error "truncated"
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

* DGP with TIME-VARYING Z (Coulombe original)
* Z is redrawn at each visit, but the intensity that GENERATES visit times
* still uses the subject-level Z (since the visit process is defined before
* visits exist). The time-varying Z enters the OUTCOME and the WEIGHT MODEL
* but not the visit generation process — matching the paper's eq. (3.12).
*
* Actually, re-reading the paper: the visit intensity IS a function of Z(t),
* and the visits are generated from a nonhomogeneous Poisson with rate
* lambda_i(t) = eta_i * exp(gamma1*I_i + gamma2*Z_i(t)). But Z(t) is only
* known at visit times, so the process is self-exciting in a way.
*
* For a clean comparison, use the SAME visit-generation process (subject-
* constant Z drives the exponential gaps) but make Z time-varying in the
* OUTCOME and WEIGHT models. This isolates the effect of Z's variation on
* the sandwich variance, which is the question.
capture program drop _zt_dgp_varying
program define _zt_dgp_varying
    version 16.0
    syntax , seed(integer) nsub(integer)
    clear
    set seed `seed'
    set obs `nsub'
    gen long id = _n
    gen double K1 = rnormal(1,1)
    gen byte   K2 = runiform() < 0.55
    gen double K3 = rnormal(0,1)
    gen byte   A  = runiform() < invlogit(0.5 + 0.8*K1 + 0.05*K2 - K3)
    * Z_base is subject-constant, used for visit generation
    gen double Z_base = cond(A==1, rnormal(2,1), rnormal(4,2))
    gen double EZ = cond(A==1, 2, 4)
    gen double phi = rnormal(0, 0.2)
    gen double eta = rgamma(100, 0.01)
    gen double C   = runiform(1, 2)
    gen double lam = eta * exp(0.6*A + 0.3*Z_base)
    tempfile base
    quietly save `base'
    quietly expand 150
    bysort id: gen int k = _n
    gen double gap = -ln(runiform()) / lam
    bysort id (k): gen double t = sum(gap)
    bysort id (k): egen double _tmax = max(t)
    quietly count if _tmax < C
    if r(N) > 0 {
        display as error "truncated"
        exit 459
    }
    quietly drop if t > C
    * Z is TIME-VARYING: redrawn at each visit
    gen double Z = cond(A==1, rnormal(2,1), rnormal(4,2))
    gen double y = 3 + 1*A + 3*(Z - EZ) + 0.4*K1 + 0.05*K2 - 0.6*K3 ///
        + rnormal(phi, 0.1)
    gen byte entry = 0
    drop k gap _tmax Z_base
    tempfile visits
    quietly save `visits'
    quietly use `base', clear
    rename Z_base Z
    gen double t = 0
    gen double y = .
    gen byte entry = 1
    quietly append using `visits'
    sort id t
end

display as text ""
display as text "probe_z_toggle -- nsub=`nsub' sims=`sims' seed=`seed'"
display as text "DIAGNOSTIC ONLY."
display as text ""

tempfile out
tempname pf
postfile `pf' int(sim) ///
    double(b_const se_const cov_const b_vary se_vary cov_vary) ///
    using "`out'", replace

local n_ok = 0
local n_fail = 0
local zc = invnormal(0.975)
forvalues s = 1/`sims' {
    local dseed = `seed' + `s'
    quietly {
        capture noisily {
            * Subject-constant Z arm
            _zt_dgp_constant, seed(`dseed') nsub(`nsub')
            iivw_weight, id(id) time(t) treat(A) treat_cov(K1 K2 K3) ///
                visit_cov(Z) wtype(fiptiw) censor(C) baseline(entry) ///
                scores nolog
            iivw_fit y A, timespec(none) vce(stacked) nolog replace
            local b_c  = _b[A]
            local se_c = _se[A]
            local cov_c = (`truth' >= _b[A]-`zc'*_se[A] & ///
                `truth' <= _b[A]+`zc'*_se[A])

            * Time-varying Z arm
            _zt_dgp_varying, seed(`dseed') nsub(`nsub')
            iivw_weight, id(id) time(t) treat(A) treat_cov(K1 K2 K3) ///
                visit_cov(Z) wtype(fiptiw) censor(C) baseline(entry) ///
                scores nolog
            iivw_fit y A, timespec(none) vce(stacked) nolog replace
            local b_v  = _b[A]
            local se_v = _se[A]
            local cov_v = (`truth' >= _b[A]-`zc'*_se[A] & ///
                `truth' <= _b[A]+`zc'*_se[A])

            post `pf' (`s') ///
                (`b_c') (`se_c') (`cov_c') (`b_v') (`se_v') (`cov_v')
            local ++n_ok
        }
        if _rc {
            display as error "sim `s' failed (rc " _rc ")"
            local ++n_fail
        }
    }
    if mod(`s', 50) == 0 {
        display as text "  sim `s'/`sims' done (`n_ok' ok, `n_fail' fail)"
    }
}
postclose `pf'

if `n_ok' < 50 {
    display as error "too few replications (`n_ok'/`sims')"
    exit 2000
}

use "`out'", clear

summarize cov_const
local cc = r(mean)
summarize cov_vary
local cv = r(mean)

summarize b_const, detail
local sd_c   = r(sd)
local iqr_c  = (r(p75) - r(p25)) / 1.349
local bias_c = r(mean) - `truth'
summarize se_const, detail
local med_se_c = r(p50)

summarize b_vary, detail
local sd_v   = r(sd)
local iqr_v  = (r(p75) - r(p25)) / 1.349
local bias_v = r(mean) - `truth'
summarize se_vary, detail
local med_se_v = r(p50)

local p_c = `cc'
local p_v = `cv'
local n_w = `n_ok'
local z2  = `zc'^2
local wi_c_lo = (`p_c'+`z2'/(2*`n_w')-`zc'*sqrt((`p_c'*(1-`p_c')+`z2'/(4*`n_w'))/`n_w'))/(1+`z2'/`n_w')
local wi_c_hi = (`p_c'+`z2'/(2*`n_w')+`zc'*sqrt((`p_c'*(1-`p_c')+`z2'/(4*`n_w'))/`n_w'))/(1+`z2'/`n_w')
local wi_v_lo = (`p_v'+`z2'/(2*`n_w')-`zc'*sqrt((`p_v'*(1-`p_v')+`z2'/(4*`n_w'))/`n_w'))/(1+`z2'/`n_w')
local wi_v_hi = (`p_v'+`z2'/(2*`n_w')+`zc'*sqrt((`p_v'*(1-`p_v')+`z2'/(4*`n_w'))/`n_w'))/(1+`z2'/`n_w')

display as text ""
display as text "=== Z-TOGGLE RESULTS: nsub=`nsub' sims=`n_ok' (failed `n_fail') ==="
display as text ""
display as text "Z subject-constant (package adaptation)"
display as text "  coverage           " %6.4f `cc' ///
    "  Wilson [" %5.3f `wi_c_lo' ", " %5.3f `wi_c_hi' "]"
display as text "  medSE/IQR-scale    " %6.4f `med_se_c'/`iqr_c'
display as text "  SD/IQR-scale       " %6.3f `sd_c'/`iqr_c'
display as text "  bias/empSD         " %6.3f `bias_c'/`sd_c'
display as text ""
display as text "Z time-varying (Coulombe original)"
display as text "  coverage           " %6.4f `cv' ///
    "  Wilson [" %5.3f `wi_v_lo' ", " %5.3f `wi_v_hi' "]"
display as text "  medSE/IQR-scale    " %6.4f `med_se_v'/`iqr_v'
display as text "  SD/IQR-scale       " %6.3f `sd_v'/`iqr_v'
display as text "  bias/empSD         " %6.3f `bias_v'/`sd_v'
display as text ""
display as text "ZTOGGLE: nsub=`nsub' sims=`n_ok' " ///
    "cov_const=" %6.4f `cc' " cov_vary=" %6.4f `cv' ///
    " medratio_c=" %6.4f `med_se_c'/`iqr_c' ///
    " medratio_v=" %6.4f `med_se_v'/`iqr_v' ///
    " sdiqr_c=" %6.3f `sd_c'/`iqr_c' ///
    " sdiqr_v=" %6.3f `sd_v'/`iqr_v'
