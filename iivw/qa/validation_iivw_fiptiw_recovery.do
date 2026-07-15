clear all
set more off
version 16.0
set varabbrev off

* validation_iivw_fiptiw_recovery.do - Gate 2B: recommended-path FIPTIW recovery
* Tests: 4
*
* WHAT THIS SUITE IS FOR
* ----------------------
* METHOD_ORACLE_MAP.md #10/#11 and plan Gate 2B: the recommended full-risk-set
* FIPTIW estimator must recover a known treatment effect on a package-
* representable DGP, and the naive/IIW-only/IPTW-only comparators must MISS in
* the arm where their omitted mechanism is the sole source of bias. Until this
* passes, no Phase-3 coverage claim can rest on the FIPTIW point estimator.
*
* The legacy recovery suites (validation_iivw_recovery_extended*.do) use
* `endatlastvisit baseline(event)' (1.x semantics) -- the exact risk-set defect
* the 2.0.0 contract corrects. This suite uses the FULL C_i risk window via
* censor()+baseline(entry), never endatlastvisit.
*
* THE DGP -- COULOMBE-BASED ADAPTATION, NOT a reproduction of Table 3.1
* --------------------------------------------------------------------
* Appendix A of the Phase-3 plan / coulombe-2021-biometrics.notes.md sec.
* "Failure conditions". Coulombe's time-varying monitoring covariate Z_i(t) is
* made SUBJECT-CONSTANT (the declared adaptation) so the package can represent it
* without pretending to observe a covariate changing between visits. Everything
* else -- confounders, gamma frailty, true effect 1, C_i~U(1,2), monitoring
* intensity eta*exp(g1*A+g2*Z) -- is kept. Because Z and A are subject-constant,
* the intensity is constant in t, so exact exponential inter-visit gaps replace
* Coulombe's 0.01 grid.
*
*   K1~N(1,1) K2~Bern(0.55) K3~N(0,1)
*   A ~ Bern(expit(0.5+0.8K1+0.05K2-K3))                    (confounded treatment)
*   Z|A=1~N(2,1)  Z|A=0~N(4, var 4)                         (subject-constant)
*   phi~N(0,var .04)  eta~Gamma(shape 100,scale .01)=mean1,var.01
*   C~U(1,2)  tau=2
*   lambda_i = eta*exp(g1*A + g2*Z)                          (constant in t)
*   Y(t) = alpha(t) + 1*A + 3*(Z-E[Z|A]) + 0.4K1+0.05K2-0.6K3 + eps, eps~N(phi,.01)
*   true marginal treatment effect = 1 ; alpha(t)=3 (primary cell)
*   carrier entry row at t=0 per subject (y=. => excluded from the outcome EE,
*     keeps zero-event subjects in the risk set)
*
* PREREGISTERED COMPARATOR ORDERING (fixed BEFORE the run; plan Appendix A table)
* -----------------------------------------------------------------------------
* Each comparator's blindness is asserted in the arm where its omitted mechanism
* is the SOLE bias, so the demonstration is not muddied by the other mechanism:
*   arm (0,0)  monitoring NON-informative -> only confounding is present:
*       naive MISS, IIW-only MISS (both blind to confounding);
*       IPTW-only RECOVER, FIPTIW RECOVER (both correct confounding).
*   arm (0.6,0.3) strong informative monitoring + confounding:
*       naive MISS, IPTW-only MISS (blind to monitoring);
*       FIPTIW RECOVER (corrects both).
* Only FIPTIW recovers in BOTH arms. This isolates each mechanism cleanly; the
* mid arm (-0.3,0.2) is reported but not gated. IIW-only accidentally recovers in
* the strong arm (the monitoring correction happens to offset confounding there),
* which is exactly why its confounding-blindness is pinned in arm (0,0) instead.
*
* Class M (TOLERANCE_FRAMEWORK.md): PASS iff |mean-1| < MCSE_K*MCSE, MCSE_K=3;
* MCSE=SD/sqrt(R). Bias must not GROW in MCSE units as n rises (250 -> 500).
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do validation_iivw_fiptiw_recovery.do        Run all
*   stata-mp -b do validation_iivw_fiptiw_recovery.do 2      Run only T2

args run_only
do "`c(pwd)'/_iivw_qa_common.do"
iivw_qa_selector "`run_only'"
local run_only = `r(run_only)'

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "validation_iivw_fiptiw_recovery.do must be run from iivw/qa"
    exit 198
}
iivw_qa_sandbox
local pkg_dir "`r(pkg_dir)'"
capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace
capture which iivw_weight
if _rc {
    display as error "iivw_weight not found after net install"
    exit 111
}

* Registered constant (TOLERANCE_FRAMEWORK.md section 3, Class M).
local MCSE_K = 3
* Monte Carlo size. R chosen so 3*MCSE (~0.3-0.4 at these SDs) resolves both the
* confounding bias (~0.9) and the monitoring bias (~2.7) a defect would produce,
* while staying < the ~1 signal FIPTIW must recover to. Pilot at R=20 already
* separated every required cell; R=50 tightens the band. FIXED before the run.
local R = 50

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* =============================================================================
* DGP + estimator programs
* =============================================================================
capture program drop _gen_coulombe
program define _gen_coulombe
    version 16.0
    syntax , N(integer) SEED(integer) G1(real) G2(real) [ALPHA(real 3)]
    clear
    set seed `seed'
    set obs `n'
    gen long id = _n
    gen double K1 = rnormal(1,1)
    gen byte   K2 = runiform() < 0.55
    gen double K3 = rnormal(0,1)
    gen byte   A  = runiform() < invlogit(0.5 + 0.8*K1 + 0.05*K2 - K3)
    gen double Z  = cond(A==1, rnormal(2,1), rnormal(4,2))     // SD 2 => var 4
    gen double EZ = cond(A==1, 2, 4)
    gen double phi = rnormal(0, 0.2)                           // var 0.04
    gen double eta = rgamma(100, 0.01)                         // mean 1, var 0.01
    gen double C   = runiform(1, 2)                            // tau=2
    gen double lam = eta * exp(`g1'*A + `g2'*Z)                // constant in t
    tempfile base
    quietly save `base'
    * monitoring events: exact exponential gaps until C
    quietly expand 150
    bysort id: gen int k = _n
    gen double gap = -ln(runiform()) / lam
    bysort id (k): gen double t = sum(gap)
    bysort id (k): egen double _tmax = max(t)
    quietly count if _tmax < C
    if r(N) > 0 {
        display as error "visit process truncated before C for `r(N)' subjects (raise expand)"
        exit 459
    }
    quietly drop if t > C
    gen double y = `alpha' + 1*A + 3*(Z - EZ) + 0.4*K1 + 0.05*K2 - 0.6*K3 ///
        + rnormal(phi, 0.1)
    gen byte entry = 0
    drop k gap _tmax
    tempfile visits
    quietly save `visits'
    * carrier entry row at t=0 for EVERY subject (y=. -> out of the outcome EE)
    quietly use `base', clear
    gen double t = 0
    gen double y = .
    gen byte entry = 1
    quietly append using `visits'
    sort id t
end

capture program drop _fit4
program define _fit4, rclass
    * one dataset in memory -> naive / IIW-only / IPTW-only / FIPTIW b[A].
    * . if a fit fails, so the caller can drop that replicate.
    capture quietly glm y A if entry==0
    return scalar naive = cond(_rc==0, _b[A], .)

    capture quietly iivw_weight, id(id) time(t) visit_cov(Z) wtype(iivw) ///
        censor(C) baseline(entry) nolog replace
    capture quietly iivw_fit y A, model(gee) timespec(none) vce(fixed) nolog replace
    return scalar iiw = cond(_rc==0, _b[A], .)

    capture quietly iivw_weight, id(id) time(t) treat(A) treat_cov(K1 K2 K3) ///
        wtype(iptw) nolog replace
    capture quietly iivw_fit y A, model(gee) timespec(none) vce(fixed) nolog replace
    return scalar iptw = cond(_rc==0, _b[A], .)

    capture quietly iivw_weight, id(id) time(t) treat(A) treat_cov(K1 K2 K3) ///
        visit_cov(Z) wtype(fiptiw) censor(C) baseline(entry) nolog replace
    return scalar treat_in_visit = r(treat_in_visit)
    capture quietly iivw_fit y A, model(gee) timespec(none) vce(fixed) nolog replace
    return scalar fiptiw = cond(_rc==0, _b[A], .)
end

* =============================================================================
* Run the Monte Carlo once; every test reads from the same result file.
* Cells: arms {(0,0),(-0.3,0.2),(0.6,0.3)} x n {250,500}.
* =============================================================================
tempfile mcres
capture postclose _pf
postfile _pf str8 arm int n double(naive iiw iptw fiptiw) int tiv ///
    using "`mcres'", replace
local arms `" "0 0" "-0.3 0.2" "0.6 0.3" "'
foreach arm of local arms {
    local g1 : word 1 of `arm'
    local g2 : word 2 of `arm'
    foreach n in 250 500 {
        forvalues r = 1/`R' {
            _gen_coulombe, n(`n') seed(`=70000 + `n' + `r'') g1(`g1') g2(`g2')
            _fit4
            post _pf ("`g1',`g2'") (`n') (r(naive)) (r(iiw)) (r(iptw)) ///
                (r(fiptiw)) (r(treat_in_visit))
        }
    }
}
postclose _pf

* --- cell summaries: mean, SD, MCSE, bias for each estimator ---
use "`mcres'", clear
foreach v in naive iiw iptw fiptiw {
    bysort arm n: egen double m_`v'  = mean(`v')
    bysort arm n: egen double sd_`v' = sd(`v')
    bysort arm n: egen int    nok_`v' = count(`v')
}
bysort arm n: egen int tiv_min = min(tiv)
by arm n: keep if _n == 1
* self-calibrating recovery band per estimator/cell
foreach v in naive iiw iptw fiptiw {
    gen double bias_`v' = m_`v' - 1
    gen double mcse_`v' = sd_`v' / sqrt(nok_`v')
    gen double band_`v' = `MCSE_K' * mcse_`v'
    gen byte   rec_`v'  = abs(bias_`v') < band_`v'
}
tempfile cells
save "`cells'"

* Print the whole table for the log (diagnosis).
display as text "{hline 78}"
display as result "FIPTIW recovery -- cell table (true effect = 1, R=`R')"
display as text "{hline 78}"
list arm n bias_naive bias_iiw bias_iptw bias_fiptiw, noobs abbrev(12) sep(2)
list arm n band_fiptiw rec_naive rec_iiw rec_iptw rec_fiptiw tiv_min, noobs abbrev(12) sep(2)

* Convenience: load a cell's values into locals arm_<...>
capture program drop _getcell
program define _getcell
    syntax using/, ARM(string) N(integer)
    preserve
    use "`using'", clear
    quietly keep if arm == "`arm'" & n == `n'
    if _N == 0 {
        restore
        display as error "no cell arm=`arm' n=`n'"
        exit 459
    }
    foreach v in naive iiw iptw fiptiw {
        c_local b_`v'    = bias_`v'[1]
        c_local band_`v' = band_`v'[1]
        c_local rec_`v'  = rec_`v'[1]
    }
    c_local tiv = tiv_min[1]
    restore
end

* =============================================================================
* T1 - FIPTIW recovers in both core arms, at both sample sizes
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 1 {
    capture noisily {
        foreach arm in "0,0" "0.6,0.3" {
            foreach n in 250 500 {
                _getcell using "`cells'", arm("`arm'") n(`n')
                display as text "    FIPTIW arm(`arm') n=`n': bias=" %8.4f `b_fiptiw' ///
                    "  3*MCSE=" %7.4f `band_fiptiw' "  recover=" `rec_fiptiw'
                assert `rec_fiptiw' == 1
            }
        }
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: T1 FIPTIW recovers (|bias|<3MCSE) in both core arms, n=250 and 500"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' T1"
        display as error "FAIL: T1 FIPTIW recovery (error `=_rc')"
    }
}

* =============================================================================
* T2 - FIPTIW bias does not GROW in MCSE units as n rises (250 -> 500)
*      A persistent asymptotic offset stays put or grows in MCSE units while
*      Monte Carlo noise shrinks like 1/sqrt(n). (TOLERANCE_FRAMEWORK Class M.)
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 2 {
    capture noisily {
        foreach arm in "0,0" "0.6,0.3" {
            _getcell using "`cells'", arm("`arm'") n(250)
            local b250 = abs(`b_fiptiw')
            local band250 = `band_fiptiw'
            _getcell using "`cells'", arm("`arm'") n(500)
            local b500 = abs(`b_fiptiw')
            local band500 = `band_fiptiw'
            * in MCSE units: |bias|/MCSE = MCSE_K*|bias|/band
            local z250 = `MCSE_K' * `b250' / `band250'
            local z500 = `MCSE_K' * `b500' / `band500'
            display as text "    arm(`arm'): |bias|/MCSE  n250=" %6.2f `z250' ///
                "  n500=" %6.2f `z500'
            * both must be within the 3-MCSE recovery band, and n=500 must not be
            * a materially worse offset than n=250 (allow 1 MCSE of MC slack).
            assert `z500' < `MCSE_K'
            assert `z500' <= `z250' + 1
        }
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: T2 FIPTIW bias stays within band and does not grow with n"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' T2"
        display as error "FAIL: T2 FIPTIW n-trend (error `=_rc')"
    }
}

* =============================================================================
* T3 - preregistered comparator ordering (the discrimination)
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 3 {
    capture noisily {
        * arm (0,0): monitoring off -> only confounding.
        _getcell using "`cells'", arm("0,0") n(500)
        display as text "    arm(0,0) n=500 recover: naive=`rec_naive' iiw=`rec_iiw'" ///
            " iptw=`rec_iptw' fiptiw=`rec_fiptiw'"
        assert `rec_naive'  == 0     // naive blind to confounding -> MISS
        assert `rec_iiw'    == 0     // IIW-only blind to confounding -> MISS
        assert `rec_iptw'   == 1     // IPTW-only corrects confounding -> RECOVER
        assert `rec_fiptiw' == 1     // FIPTIW -> RECOVER

        * arm (0.6,0.3): strong informative monitoring + confounding.
        _getcell using "`cells'", arm("0.6,0.3") n(500)
        display as text "    arm(0.6,0.3) n=500 recover: naive=`rec_naive' iiw=`rec_iiw'" ///
            " iptw=`rec_iptw' fiptiw=`rec_fiptiw'"
        assert `rec_naive'  == 0     // blind to both -> MISS
        assert `rec_iptw'   == 0     // IPTW-only blind to monitoring -> MISS
        assert `rec_fiptiw' == 1     // FIPTIW corrects both -> RECOVER
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: T3 comparator ordering matches the preregistered table"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' T3"
        display as error "FAIL: T3 comparator ordering (error `=_rc')"
    }
}

* =============================================================================
* T4 - the FIPTIW visit-intensity denominator contains treatment (Coulombe
*      eq. 3.12), on the full C_i risk window; nuisance diagnostics for the log
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 4 {
    capture noisily {
        * every replicate stored r(treat_in_visit); the cell min must be 1.
        _getcell using "`cells'", arm("0.6,0.3") n(500)
        display as text "    min(treat_in_visit) over the strong-arm cell = `tiv'"
        assert `tiv' == 1

        * one representative fit, printed, for diagnosis of the nuisance models.
        _gen_coulombe, n(500) seed(424242) g1(0.6) g2(0.3)
        iivw_weight, id(id) time(t) treat(A) treat_cov(K1 K2 K3) visit_cov(Z) ///
            wtype(fiptiw) censor(C) baseline(entry) nolog replace
        display as text "    visit_covars = `r(visit_covars)'  treat_in_visit = `r(treat_in_visit)'"
        assert "`r(visit_covars)'" == "Z A"
        assert r(treat_in_visit) == 1
        * component weights are finite and the treatment weight is ~mean 1
        quietly summarize _iivw_tw
        display as text "    mean(IPT weight)=" %7.4f r(mean) "  (stabilized ~ 1)"
        assert r(mean) < . & r(mean) > 0
        quietly summarize _iivw_iw
        assert r(mean) < . & r(mean) > 0
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: T4 treatment in the FIPTIW visit denominator, full risk window"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' T4"
        display as error "FAIL: T4 visit-model structure (error `=_rc')"
    }
}

iivw_qa_summary, name(validation_iivw_fiptiw_recovery) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') runonly(`run_only') failedtests("`failed_tests'")

clear
