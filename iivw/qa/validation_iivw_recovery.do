clear all
set varabbrev off
version 16.0

* validation_iivw_recovery.do
* ----------------------------------------------------------------------------
* Known-truth parameter recovery for iivw. The strongest correctness check for
* an estimator is not "does it match R?" but "does it return the number I built
* into the data?" We write the data-generating process, so the true parameter
* is an exact analytic oracle.
*
* Scenario A — marginal slope recovery (IIVW / inverse-intensity weighting):
*   Subjects have heterogeneous slopes s_i = beta1 + delta*Z_i with Z_i ~ U(-1,1),
*   so the POPULATION marginal slope is exactly beta1 (E[Z]=0). The visit process
*   is a Poisson process with rate exp(gamma*Z), so high-Z (steeper) subjects are
*   over-sampled. A naive pooled regression over-weights steep subjects and is
*   biased upward; IIW reweights by the inverse Andersen-Gill visit intensity and
*   recovers beta1. Truth = beta1 (analytic). Handle: _b[<timevar>].
*
* Scenario B — marginal treatment-effect recovery (FIPTIW):
*   A baseline confounder C drives BOTH treatment assignment (confounding) and the
*   visit intensity (informative visits correlated with treatment). The true
*   marginal treatment effect is the constant additive shift theta. Naive and
*   IIW-only both miss (confounding remains); FIPTIW (IIW visit model + IPTW
*   treatment model) recovers theta. Truth = theta (analytic). Handle: _b[treatment].
*
* Tolerances are set from the Monte-Carlo error observed at the shipped seed/N,
* NOT from whatever makes the test pass. Each scenario asserts a NAIVE estimator
* MISSES the truth first, proving the scenario actually exercises what the
* estimator is meant to fix.
* ----------------------------------------------------------------------------

capture log close
log using "validation_iivw_recovery.log", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

* Bootstrap: derive package root from qa/ working directory (relocatable)
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

**# Scenario A: marginal slope recovery (IIVW)

* DGP parameters
local Na      = 25000
local Kmax    = 60
local Tmax    = 10
local rho     = 1.5
local gamma   = 0.7
local beta0   = 10
local beta1   = 0.5      // TRUE marginal slope (oracle)
local delta   = 0.6
local tau     = 1.0
local sigma   = 1.0

* Honest tolerances (observed at this seed: naive bias +0.136, IIW err +0.005, SE 0.0028)
local tol_a       = 0.02      // recovery tolerance (~7x the recovery SE)
local naive_min_a = 0.05      // naive must miss by at least this

scalar Asetup_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 8675309
    set obs `Na'
    gen long id = _n
    gen double Z = runiform(-1, 1)
    gen double s_i = `beta1' + `delta' * Z
    gen double a_i = `beta0' + `tau' * Z
    gen double rate_i = `rho' * exp(`gamma' * Z)

    * Recurrent visit times: pure Poisson process (first event is natural entry)
    expand `Kmax'
    bysort id: gen int k = _n
    gen double gap = -ln(runiform()) / rate_i
    bysort id (k): gen double vtime = sum(gap)
    keep if vtime <= `Tmax'
    gen double months = vtime
    sort id months
    bysort id: gen int nv = _N
    drop if nv < 2
    drop nv

    gen double y = a_i + s_i * months + rnormal(0, `sigma')

    * Naive pooled GEE of y on time (independence, cluster id)
    glm y months, family(gaussian) link(identity) vce(cluster id)
    scalar A_naive = _b[months]

    * IIW-weighted recovery: visit model on Z, then marginal y-on-time
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(Z) wtype(iivw) nolog replace
    iivw_fit y, model(gee) timespec(linear) nolog replace
    scalar A_iiw = _b[months]
    scalar Asetup_ok = 1
}
if _rc == 0 & Asetup_ok == 1 {
    display as result "  PASS: scenario A DGP + estimation ran"
    local ++pass_count
}
else {
    display as error "  FAIL: scenario A DGP + estimation (error `=_rc')"
    local ++fail_count
}

* A1: naive estimator must MISS the truth (proves the scenario bites)
local ++test_count
capture noisily {
    assert Asetup_ok == 1
    assert abs(A_naive - `beta1') > `naive_min_a'
}
if _rc == 0 {
    display as result "  PASS: A1 naive slope misses truth (naive=" %6.4f A_naive ", truth=`beta1')"
    local ++pass_count
}
else {
    display as error "  FAIL: A1 naive slope did not miss (naive=" %6.4f A_naive ")"
    local ++fail_count
}

* A2: IIW must RECOVER the true marginal slope within tolerance
local ++test_count
capture noisily {
    assert Asetup_ok == 1
    assert abs(A_iiw - `beta1') < `tol_a'
}
if _rc == 0 {
    display as result "  PASS: A2 IIW recovers slope (iiw=" %6.4f A_iiw ", truth=`beta1', |err|<`tol_a')"
    local ++pass_count
}
else {
    display as error "  FAIL: A2 IIW did not recover (iiw=" %6.4f A_iiw ", truth=`beta1')"
    local ++fail_count
}

**# Scenario B: marginal treatment-effect recovery (FIPTIW)

* DGP parameters
local Nb      = 25000
local Kmaxb   = 80
local Tmaxb   = 10
local rhob    = 1.3
local gammab  = 0.6      // visit log-HR on Z
local gammac  = 0.3      // visit log-HR on C (links visits to treatment)
local beta0b  = 5
local beta1b  = 0.3
local deltab  = 0.4
local theta   = -0.8     // TRUE marginal treatment effect (oracle)
local phi     = 0.7      // confounding C -> y
local lam0    = -0.2
local lam1    = 0.6      // confounding C -> treatment (moderate => good positivity)
local taub    = 0.8
local sigmab  = 1.0

* Honest tolerances (observed at this seed: naive +0.408, IIW-only +0.405, FIPTIW +0.030, SE 0.026)
local tol_b       = 0.10     // recovery tolerance (~4x the recovery SE)
local naive_min_b = 0.20     // naive AND iiw-only must miss by at least this

scalar Bsetup_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 271828
    set obs `Nb'
    gen long id = _n
    gen double Z = runiform(-1, 1)
    gen double C = rnormal()
    gen byte T = runiform() < invlogit(`lam0' + `lam1' * C)     // confounded treatment
    gen double s_i = `beta1b' + `deltab' * Z
    gen double a_i = `beta0b' + `taub' * Z + `phi' * C
    gen double rate_i = `rhob' * exp(`gammab' * Z + `gammac' * C)

    expand `Kmaxb'
    bysort id: gen int k = _n
    gen double gap = -ln(runiform()) / rate_i
    bysort id (k): gen double vtime = sum(gap)
    keep if vtime <= `Tmaxb'
    gen double months = vtime
    sort id months
    bysort id: gen int nv = _N
    drop if nv < 2
    drop nv

    gen double y = a_i + `theta' * T + s_i * months + rnormal(0, `sigmab')

    * Naive: y on T + time, unweighted, no confounder adjustment
    glm y T months, family(gaussian) link(identity) vce(cluster id)
    scalar B_naive = _b[T]

    * IIW only: corrects informative visits but NOT confounding -> should still miss
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(Z C) wtype(iivw) nolog replace
    iivw_fit y T, model(gee) timespec(linear) nolog replace
    scalar B_iiw = _b[T]

    * FIPTIW: visit model (Z C) + treatment model (C) -> recovers theta
    * No weight truncation: aggressive trimming attenuates IPTW toward null and
    * masks recovery; moderate confounding keeps positivity good without it.
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(Z C) treat(T) treat_cov(C) ///
        wtype(fiptiw) nolog replace
    iivw_fit y T, model(gee) timespec(linear) nolog replace
    scalar B_fiptiw = _b[T]
    scalar Bsetup_ok = 1
}
if _rc == 0 & Bsetup_ok == 1 {
    display as result "  PASS: scenario B DGP + estimation ran"
    local ++pass_count
}
else {
    display as error "  FAIL: scenario B DGP + estimation (error `=_rc')"
    local ++fail_count
}

* B1: naive estimator must MISS the truth (confounding bias)
local ++test_count
capture noisily {
    assert Bsetup_ok == 1
    assert abs(B_naive - `theta') > `naive_min_b'
}
if _rc == 0 {
    display as result "  PASS: B1 naive misses truth (naive=" %6.4f B_naive ", truth=`theta')"
    local ++pass_count
}
else {
    display as error "  FAIL: B1 naive did not miss (naive=" %6.4f B_naive ")"
    local ++fail_count
}

* B2: IIW-only must ALSO miss (proves IPTW is required, not just visit weighting)
local ++test_count
capture noisily {
    assert Bsetup_ok == 1
    assert abs(B_iiw - `theta') > `naive_min_b'
}
if _rc == 0 {
    display as result "  PASS: B2 IIW-only still misses (iiw=" %6.4f B_iiw ", truth=`theta')"
    local ++pass_count
}
else {
    display as error "  FAIL: B2 IIW-only unexpectedly recovered (iiw=" %6.4f B_iiw ")"
    local ++fail_count
}

* B3: FIPTIW must RECOVER the true marginal treatment effect within tolerance
local ++test_count
capture noisily {
    assert Bsetup_ok == 1
    assert abs(B_fiptiw - `theta') < `tol_b'
}
if _rc == 0 {
    display as result "  PASS: B3 FIPTIW recovers theta (fiptiw=" %6.4f B_fiptiw ", truth=`theta', |err|<`tol_b')"
    local ++pass_count
}
else {
    display as error "  FAIL: B3 FIPTIW did not recover (fiptiw=" %6.4f B_fiptiw ", truth=`theta')"
    local ++fail_count
}

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_iivw_recovery tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: validation_iivw_recovery tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close
