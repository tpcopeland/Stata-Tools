clear all
set varabbrev off
version 16.0

* validation_iivw_recovery_extended.do
* ----------------------------------------------------------------------------
* Extended known-truth parameter-recovery battery for iivw. Each scenario
* writes its own data-generating process (DGP), so the true parameter is an
* exact analytic oracle -- the strongest correctness check for an estimator.
* Complements validation_iivw_recovery.do (scenarios A/B): this file drives
* one distinct estimator/option code path per scenario and asserts recovery of
* a value built into the data.
*
* Every scenario first confirms a NAIVE estimator MISSES the truth (proving the
* scenario actually exercises what the weighting is meant to fix), then asserts
* the iivw estimate RECOVERS it. Tolerances are set from the Monte-Carlo error
* observed at the shipped seed/N (a throwaway "watch it work" run), NOT from
* whatever makes the test pass. Where a residual is a real, asymptotic property
* of the method (not MC noise), the scenario ships a BOUNDED gate that documents
* the offset instead of a false tight-recovery claim.
*
* Handles confirmed from source (grep '(ereturn|return) scalar' / _b[]):
*   slope       -> _b[months]         (timespec(linear))
*   level        -> _b[_cons]          (timespec(none))
*   quadratic    -> _b[_iivw_time_sq]  (timespec(quadratic))
*   cubic        -> _b[_iivw_time_cu]  (timespec(cubic))
*   treatment    -> _b[T]
*
* Code paths exercised: IIW linear/none/quadratic/cubic, stabcov, entry,
* nobaseevent, lagvars, truncate, unweighted; IPTW (gaussian/poisson/LPM);
* FIPTIW; model(mixed); a non-informative negative control; a strong-gamma
* positivity-stress case.
* ----------------------------------------------------------------------------

capture log close
log using "validation_iivw_recovery_extended.log", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

* Bootstrap: derive package root from qa/ working directory (relocatable)
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

* Compact pass/fail reporter (keeps the counter bookkeeping in one place)
capture program drop _rc_result
program define _rc_result
    gettoken rc 0 : 0
    local msg = `0'
    if `rc' == 0 {
        display as result "  PASS: `msg'"
    }
    else {
        display as error "  FAIL: `msg' (rc=`rc')"
    }
end

**# S1: IIW marginal LEVEL recovery, timespec(none) -- BOUNDED
* y has no time trend; the subject level a_i = mu + 1.2*Z with E[Z]=0, so the
* population marginal mean is exactly mu=5. Informative visits (rate rises with
* Z) over-sample high-level subjects, so the naive mean is biased upward. IIW
* corrects most of it, but the baseline-visit-weight-1 convention leaves high-
* intensity subjects slightly more total weight -- an asymptotic offset (residual
* ~4.7x the recovery SE, does NOT shrink with N), so the intercept is not a tight
* IIW target. Ship a BOUNDED gate: naive misses, IIW removes the bulk of the
* bias, and lands within a documented tolerance. (The IIW estimand of interest
* is the trajectory/slope; those recover tightly in the scenarios below.)
scalar s1_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 101
    set obs 25000
    gen long id = _n
    gen double Z = runiform(-1, 1)
    gen double a_i = 5 + 1.2*Z
    gen double rate_i = 3.0*exp(0.6*Z)
    expand 120
    bysort id: gen int k = _n
    gen double gap = -ln(runiform())/rate_i
    bysort id (k): gen double vtime = sum(gap)
    keep if vtime <= 12
    gen double months = vtime
    sort id months
    bysort id: gen int nv = _N
    drop if nv < 2
    drop nv
    gen double y = a_i + rnormal(0, 1)
    quietly summarize y, meanonly
    scalar s1_naive = r(mean)
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(Z) wtype(iivw) nolog replace
    iivw_fit y, timespec(none) nolog replace
    scalar s1_est = _b[_cons]
    scalar s1_ok = 1
}
local rc = _rc
if `rc' == 0 & s1_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "S1 setup (IIW level, timespec none)"

local ++test_count
capture noisily {
    assert s1_ok == 1
    * naive misses (observed naive bias ~ +0.24)
    assert abs(s1_naive - 5) > 0.12
    * IIW removes >= 80% of the naive bias (observed ~91%)
    scalar s1_frac = (abs(s1_naive-5) - abs(s1_est-5)) / abs(s1_naive-5)
    assert s1_frac >= 0.80
    * and lands within a documented bound (observed residual ~0.022)
    assert abs(s1_est - 5) < 0.05
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "S1 bounded level recovery (naive=" + string(s1_naive,"%6.4f") + " est=" + string(s1_est,"%6.4f") + ")"

**# S2: IIW slope recovery with stabilized weights, stabcov(S)
* Heterogeneous slope s_i = 0.5 + 0.6*Z (population marginal slope = 0.5). Visit
* intensity depends on Z (drives the naive bias) AND an independent baseline S
* that is NOT in the outcome. Stabilizing by S (stabcov(S)) leaves Z fully in the
* denominator so the Z-oversampling is corrected, while the S term cancels; the
* estimand is unchanged and variance is lower. Truth = 0.5, handle _b[months].
scalar s2_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 202
    set obs 20000
    gen long id = _n
    gen double Z = runiform(-1, 1)
    gen double S = runiform(-1, 1)
    gen double s_i = 0.5 + 0.6*Z
    gen double a_i = 10 + 1.0*Z
    gen double rate_i = 1.5*exp(0.7*Z + 0.8*S)
    expand 80
    bysort id: gen int k = _n
    gen double gap = -ln(runiform())/rate_i
    bysort id (k): gen double vtime = sum(gap)
    keep if vtime <= 10
    gen double months = vtime
    sort id months
    bysort id: gen int nv = _N
    drop if nv < 2
    drop nv
    gen double y = a_i + s_i*months + rnormal(0, 1)
    glm y months, family(gaussian) link(identity) vce(cluster id)
    scalar s2_naive = _b[months]
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(Z S) stabcov(S) wtype(iivw) nolog replace
    iivw_fit y, timespec(linear) nolog replace
    scalar s2_est = _b[months]
    scalar s2_ok = 1
}
local rc = _rc
if `rc' == 0 & s2_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "S2 setup (IIW stabcov)"

local ++test_count
capture noisily {
    assert s2_ok == 1
    assert abs(s2_naive - 0.5) > 0.08                    // naive bias ~ +0.14
    assert abs(s2_est - 0.5) < 0.03                      // residual ~0.008 (~2.4x SE)
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "S2 stabilized IIW recovers slope (est=" + string(s2_est,"%6.4f") + ")"

**# S3: non-informative visits negative control (gamma=0)
* When the visit rate does not depend on Z, there is nothing to correct: the
* weights are ~1 and BOTH the naive and IIW estimators recover the true slope.
* Guards against an IIW that would distort an already-unbiased analysis.
scalar s3_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 303
    set obs 15000
    gen long id = _n
    gen double Z = runiform(-1, 1)
    gen double s_i = 0.5 + 0.6*Z
    gen double a_i = 10 + 1.0*Z
    gen double rate_i = 1.5                               // gamma=0: non-informative
    expand 60
    bysort id: gen int k = _n
    gen double gap = -ln(runiform())/rate_i
    bysort id (k): gen double vtime = sum(gap)
    keep if vtime <= 10
    gen double months = vtime
    sort id months
    bysort id: gen int nv = _N
    drop if nv < 2
    drop nv
    gen double y = a_i + s_i*months + rnormal(0, 1)
    glm y months, family(gaussian) link(identity) vce(cluster id)
    scalar s3_naive = _b[months]
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(Z) wtype(iivw) nolog replace
    scalar s3_wcv = r(sd_weight)/r(mean_weight)
    scalar s3_wmax = r(max_weight)
    iivw_fit y, timespec(linear) nolog replace
    scalar s3_est = _b[months]
    scalar s3_ok = 1
}
local rc = _rc
if `rc' == 0 & s3_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "S3 setup (non-informative control)"

local ++test_count
capture noisily {
    assert s3_ok == 1
    assert abs(s3_naive - 0.5) < 0.02                    // naive already unbiased
    assert abs(s3_est - 0.5) < 0.02                      // IIW leaves it unbiased
    assert s3_wcv < 0.02                                 // weights ~ constant (obs 0.0016)
    assert s3_wmax < 1.10                                 // no leverage (obs 1.003)
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "S3 non-informative: naive & IIW both recover, weights~1"

**# S4: IIW quadratic-coefficient recovery, timespec(quadratic)
* Quadratic coef s2_i = 0.30 + 0.40*Z (population marginal = 0.30). Informative
* visits bias the naive quadratic term. Truth = 0.30, handle _b[_iivw_time_sq].
scalar s4_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 404
    set obs 15000
    gen long id = _n
    gen double Z = runiform(-1, 1)
    gen double s2_i = 0.30 + 0.40*Z
    gen double a_i = 10 + 1.0*Z
    gen double rate_i = 1.5*exp(0.7*Z)
    expand 60
    bysort id: gen int k = _n
    gen double gap = -ln(runiform())/rate_i
    bysort id (k): gen double vtime = sum(gap)
    keep if vtime <= 10
    gen double months = vtime
    sort id months
    bysort id: gen int nv = _N
    drop if nv < 2
    drop nv
    gen double y = a_i + 0.5*months + s2_i*months^2 + rnormal(0, 1)
    gen double months2 = months^2
    glm y months months2, family(gaussian) link(identity) vce(cluster id)
    scalar s4_naive = _b[months2]
    drop months2
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(Z) wtype(iivw) nolog replace
    iivw_fit y, timespec(quadratic) nolog replace
    scalar s4_est = _b[_iivw_time_sq]
    scalar s4_ok = 1
}
local rc = _rc
if `rc' == 0 & s4_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "S4 setup (IIW quadratic)"

local ++test_count
capture noisily {
    assert s4_ok == 1
    assert abs(s4_naive - 0.30) > 0.04                   // naive bias ~ +0.09
    assert abs(s4_est - 0.30) < 0.03                     // residual ~0.014 (~3.3x SE)
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "S4 IIW recovers quadratic coef (est=" + string(s4_est,"%6.4f") + ")"

**# S5: IIW slope recovery with staggered entry(), delayed-entry counting process
* Subjects enter at entry0 in (0,0.5); first visit follows entry. The AG risk set
* starts at entry. Truth = 0.5, handle _b[months].
scalar s5_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 505
    set obs 15000
    gen long id = _n
    gen double Z = runiform(-1, 1)
    gen double s_i = 0.5 + 0.6*Z
    gen double a_i = 10 + 1.0*Z
    gen double rate_i = 1.5*exp(0.7*Z)
    gen double entry0 = runiform(0, 0.5)
    expand 60
    bysort id: gen int k = _n
    gen double gap = -ln(runiform())/rate_i
    bysort id (k): gen double vtime = entry0 + sum(gap)
    keep if vtime <= 10
    gen double months = vtime
    sort id months
    bysort id: gen int nv = _N
    drop if nv < 2
    drop nv
    gen double y = a_i + s_i*months + rnormal(0, 1)
    glm y months, family(gaussian) link(identity) vce(cluster id)
    scalar s5_naive = _b[months]
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(Z) entry(entry0) wtype(iivw) nolog replace
    iivw_fit y, timespec(linear) nolog replace
    scalar s5_est = _b[months]
    scalar s5_ok = 1
}
local rc = _rc
if `rc' == 0 & s5_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "S5 setup (IIW entry)"

local ++test_count
capture noisily {
    assert s5_ok == 1
    assert abs(s5_naive - 0.5) > 0.08                    // naive bias ~ +0.13
    assert abs(s5_est - 0.5) < 0.025                     // residual ~0.0015
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "S5 IIW+entry recovers slope (est=" + string(s5_est,"%6.4f") + ")"

**# S6: IIW slope recovery with nobaseevent (baseline visit = study entry)
* Under nobaseevent the first visit defines risk onset rather than a modeled
* event; follow-up visits are the events. Truth = 0.5, handle _b[months].
scalar s6_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 606
    set obs 15000
    gen long id = _n
    gen double Z = runiform(-1, 1)
    gen double s_i = 0.5 + 0.6*Z
    gen double a_i = 10 + 1.0*Z
    gen double rate_i = 1.5*exp(0.7*Z)
    expand 60
    bysort id: gen int k = _n
    gen double gap = -ln(runiform())/rate_i
    bysort id (k): gen double vtime = sum(gap)
    keep if vtime <= 10
    gen double months = vtime
    sort id months
    bysort id: gen int nv = _N
    drop if nv < 2
    drop nv
    gen double y = a_i + s_i*months + rnormal(0, 1)
    glm y months, family(gaussian) link(identity) vce(cluster id)
    scalar s6_naive = _b[months]
    iivw_weight, endatlastvisit id(id) time(months) visit_cov(Z) wtype(iivw) nolog replace
    iivw_fit y, timespec(linear) nolog replace
    scalar s6_est = _b[months]
    scalar s6_ok = 1
}
local rc = _rc
if `rc' == 0 & s6_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "S6 setup (IIW nobaseevent)"

local ++test_count
capture noisily {
    assert s6_ok == 1
    assert abs(s6_naive - 0.5) > 0.08                    // naive bias ~ +0.13
    assert abs(s6_est - 0.5) < 0.025                     // residual ~0.0007
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "S6 IIW+nobaseevent recovers slope (est=" + string(s6_est,"%6.4f") + ")"

**# S7: IIW slope recovery with lagvars() (lagged tv covariate in visit model)
* A time-varying nuisance covariate W enters the visit model lagged one visit.
* Z is the true bias driver; W_lag1 is noise. Exercises the lag-construction +
* visit-model path. Truth = 0.5, handle _b[months].
scalar s7_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 707
    set obs 15000
    gen long id = _n
    gen double Z = runiform(-1, 1)
    gen double s_i = 0.5 + 0.6*Z
    gen double a_i = 10 + 1.0*Z
    gen double rate_i = 1.5*exp(0.7*Z)
    expand 60
    bysort id: gen int k = _n
    gen double gap = -ln(runiform())/rate_i
    bysort id (k): gen double vtime = sum(gap)
    keep if vtime <= 10
    gen double months = vtime
    sort id months
    bysort id: gen int nv = _N
    drop if nv < 2
    drop nv
    gen double W = rnormal()
    gen double y = a_i + s_i*months + rnormal(0, 1)
    glm y months, family(gaussian) link(identity) vce(cluster id)
    scalar s7_naive = _b[months]
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(Z) lagvars(W) wtype(iivw) nolog replace
    iivw_fit y, timespec(linear) nolog replace
    scalar s7_est = _b[months]
    scalar s7_ok = 1
}
local rc = _rc
if `rc' == 0 & s7_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "S7 setup (IIW lagvars)"

local ++test_count
capture noisily {
    assert s7_ok == 1
    assert abs(s7_naive - 0.5) > 0.08                    // naive bias ~ +0.14
    assert abs(s7_est - 0.5) < 0.03                      // residual ~0.007 (~2x SE)
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "S7 IIW+lagvars recovers slope (est=" + string(s7_est,"%6.4f") + ")"

**# S8: pure IPTW treatment-effect recovery, timespec(none), constant visits
* Confounder C drives treatment T and outcome. True marginal effect theta=-0.8
* (additive, collapsible). Naive y~T is confounded; IPTW recovers. Handle _b[T].
scalar s8_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 808
    set obs 15000
    gen long id = _n
    gen double C = rnormal()
    gen byte T = runiform() < invlogit(-0.2 + 0.7*C)
    gen double a_i = 5 + 0.5*rnormal()
    gen double rate_i = 1.5
    expand 60
    bysort id: gen int k = _n
    gen double gap = -ln(runiform())/rate_i
    bysort id (k): gen double vtime = sum(gap)
    keep if vtime <= 10
    gen double months = vtime
    sort id months
    bysort id: gen int nv = _N
    drop if nv < 2
    drop nv
    gen double y = a_i - 0.8*T + 0.9*C + rnormal(0, 1)
    glm y T, family(gaussian) link(identity) vce(cluster id)
    scalar s8_naive = _b[T]
    iivw_weight, id(id) time(months) treat(T) treat_cov(C) wtype(iptw) nolog replace
    iivw_fit y T, timespec(none) nolog replace
    scalar s8_est = _b[T]
    scalar s8_ok = 1
}
local rc = _rc
if `rc' == 0 & s8_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "S8 setup (pure IPTW)"

local ++test_count
capture noisily {
    assert s8_ok == 1
    assert abs(s8_naive - (-0.8)) > 0.30                 // confounding bias ~0.53
    assert abs(s8_est - (-0.8)) < 0.08                   // residual ~0.022 (~1x SE)
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "S8 IPTW recovers treatment effect (est=" + string(s8_est,"%6.4f") + ")"

**# S9: IPTW treatment-effect recovery with a linear time trend
* Same confounding as S8 plus a shared 0.4*months trend. Truth theta=-0.8,
* handle _b[T], timespec(linear).
scalar s9_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 909
    set obs 15000
    gen long id = _n
    gen double C = rnormal()
    gen byte T = runiform() < invlogit(-0.2 + 0.7*C)
    gen double a_i = 5 + 0.5*rnormal()
    gen double rate_i = 1.5
    expand 60
    bysort id: gen int k = _n
    gen double gap = -ln(runiform())/rate_i
    bysort id (k): gen double vtime = sum(gap)
    keep if vtime <= 10
    gen double months = vtime
    sort id months
    bysort id: gen int nv = _N
    drop if nv < 2
    drop nv
    gen double y = a_i - 0.8*T + 0.9*C + 0.4*months + rnormal(0, 1)
    glm y T months, family(gaussian) link(identity) vce(cluster id)
    scalar s9_naive = _b[T]
    iivw_weight, id(id) time(months) treat(T) treat_cov(C) wtype(iptw) nolog replace
    iivw_fit y T, timespec(linear) nolog replace
    scalar s9_est = _b[T]
    scalar s9_ok = 1
}
local rc = _rc
if `rc' == 0 & s9_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "S9 setup (IPTW + linear time)"

local ++test_count
capture noisily {
    assert s9_ok == 1
    assert abs(s9_naive - (-0.8)) > 0.30                 // confounding bias ~0.56
    assert abs(s9_est - (-0.8)) < 0.08                   // residual ~0.025 (~1.2x SE)
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "S9 IPTW+time recovers treatment effect (est=" + string(s9_est,"%6.4f") + ")"

**# S10: FIPTIW recovery, continuous outcome + time trend
* Visits informative via Z and C; treatment confounded by C. Only IIW+IPTW
* together (FIPTIW) recovers theta=-0.8. Handle _b[T], timespec(linear).
scalar s10_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 1010
    set obs 20000
    gen long id = _n
    gen double Z = runiform(-1, 1)
    gen double C = rnormal()
    gen byte T = runiform() < invlogit(-0.2 + 0.6*C)
    gen double s_i = 0.3 + 0.4*Z
    gen double a_i = 5 + 0.8*Z + 0.7*C
    gen double rate_i = 1.3*exp(0.6*Z + 0.3*C)
    expand 80
    bysort id: gen int k = _n
    gen double gap = -ln(runiform())/rate_i
    bysort id (k): gen double vtime = sum(gap)
    keep if vtime <= 10
    gen double months = vtime
    sort id months
    bysort id: gen int nv = _N
    drop if nv < 2
    drop nv
    gen double y = a_i - 0.8*T + s_i*months + rnormal(0, 1)
    glm y T months, family(gaussian) link(identity) vce(cluster id)
    scalar s10_naive = _b[T]
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(Z C) treat(T) treat_cov(C) ///
        wtype(fiptiw) nolog replace
    iivw_fit y T, timespec(linear) nolog replace
    scalar s10_est = _b[T]
    scalar s10_ok = 1
}
local rc = _rc
if `rc' == 0 & s10_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "S10 setup (FIPTIW)"

local ++test_count
capture noisily {
    assert s10_ok == 1
    assert abs(s10_naive - (-0.8)) > 0.20                // combined bias ~0.35
    assert abs(s10_est - (-0.8)) < 0.10                  // residual ~0.020 (~0.7x SE)
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "S10 FIPTIW recovers treatment effect (est=" + string(s10_est,"%6.4f") + ")"

**# S11: IPTW Poisson log-link marginal log-rate-ratio recovery
* Count outcome with a homogeneous multiplicative treatment effect (log-RR=0.5).
* The rate ratio is collapsible, so IPTW-weighted Poisson recovers the marginal
* log-RR exactly. Confounder C biases the naive log-RR. Handle _b[T].
scalar s11_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 1111
    set obs 15000
    gen long id = _n
    gen double C = rnormal()
    gen byte T = runiform() < invlogit(-0.2 + 0.7*C)
    gen double a_i = 0.2 + 0.3*rnormal()
    gen double rate_i = 1.5
    expand 60
    bysort id: gen int k = _n
    gen double gap = -ln(runiform())/rate_i
    bysort id (k): gen double vtime = sum(gap)
    keep if vtime <= 10
    gen double months = vtime
    sort id months
    bysort id: gen int nv = _N
    drop if nv < 2
    drop nv
    gen double mu = exp(a_i + 0.5*T + 0.4*C)
    gen int ycount = rpoisson(mu)
    glm ycount T, family(poisson) link(log) vce(cluster id)
    scalar s11_naive = _b[T]
    iivw_weight, id(id) time(months) treat(T) treat_cov(C) wtype(iptw) nolog replace
    iivw_fit ycount T, family(poisson) link(log) timespec(none) nolog replace
    scalar s11_est = _b[T]
    scalar s11_ok = 1
}
local rc = _rc
if `rc' == 0 & s11_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "S11 setup (IPTW poisson log-RR)"

local ++test_count
capture noisily {
    assert s11_ok == 1
    assert abs(s11_naive - 0.5) > 0.15                   // confounding bias ~0.26
    assert abs(s11_est - 0.5) < 0.05                     // residual ~0.009 (~0.8x SE)
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "S11 IPTW poisson recovers log-RR (est=" + string(s11_est,"%6.4f") + ")"

**# S12: weighted model(mixed) fixed-effect slope -- BOUNDED (fenced path)
* iivw_fit fences weighted model(mixed): IIVW weights enter mixed through a single
* observation-level [pw=] that Stata does not rescale across levels, so the fixed
* slope is only partially weight-corrected by design (the package documents this
* and steers to model(gee) as primary). Ship a BOUNDED gate: mixed removes a
* substantial share of the naive bias and beats naive, but is NOT claimed to
* recover tightly. (model(gee) recovers this same DGP tightly -- see recovery
* scenario A.) Observed: mixed removes ~66% of the bias.
scalar s12_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 1212
    set obs 15000
    gen long id = _n
    gen double Z = runiform(-1, 1)
    gen double s_i = 0.5 + 0.6*Z
    gen double a_i = 10 + 1.0*Z
    gen double rate_i = 1.5*exp(0.7*Z)
    expand 60
    bysort id: gen int k = _n
    gen double gap = -ln(runiform())/rate_i
    bysort id (k): gen double vtime = sum(gap)
    keep if vtime <= 10
    gen double months = vtime
    sort id months
    bysort id: gen int nv = _N
    drop if nv < 2
    drop nv
    gen double y = a_i + s_i*months + rnormal(0, 1)
    glm y months, family(gaussian) link(identity) vce(cluster id)
    scalar s12_naive = _b[months]
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(Z) wtype(iivw) nolog replace
    iivw_fit y, model(mixed) timespec(linear) nolog replace
    scalar s12_est = _b[months]
    scalar s12_ok = 1
}
local rc = _rc
if `rc' == 0 & s12_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "S12 setup (weighted mixed, fenced)"

local ++test_count
capture noisily {
    assert s12_ok == 1
    assert abs(s12_naive - 0.5) > 0.10                   // naive bias ~ +0.14
    * mixed removes >= 45% of the bias and beats naive (observed ~66%)
    scalar s12_frac = (abs(s12_naive-0.5) - abs(s12_est-0.5)) / abs(s12_naive-0.5)
    assert s12_frac >= 0.45
    assert abs(s12_est - 0.5) < abs(s12_naive - 0.5)
    assert abs(s12_est - 0.5) < 0.08                     // documented bound (obs ~0.048)
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "S12 weighted mixed bounded partial recovery (est=" + string(s12_est,"%6.4f") + ")"

**# S13: truncation invariance under benign (mild) weights
* Mild informativeness (gamma=0.3) so truncate(1 99) removes essentially nothing;
* recovery of the true slope 0.5 is preserved. (Aggressive truncation on strong
* weights would attenuate toward the null -- deliberately avoided here.)
scalar s13_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 1313
    set obs 15000
    gen long id = _n
    gen double Z = runiform(-1, 1)
    gen double s_i = 0.5 + 0.6*Z
    gen double a_i = 10 + 1.0*Z
    gen double rate_i = 1.5*exp(0.3*Z)
    expand 60
    bysort id: gen int k = _n
    gen double gap = -ln(runiform())/rate_i
    bysort id (k): gen double vtime = sum(gap)
    keep if vtime <= 10
    gen double months = vtime
    sort id months
    bysort id: gen int nv = _N
    drop if nv < 2
    drop nv
    gen double y = a_i + s_i*months + rnormal(0, 1)
    glm y months, family(gaussian) link(identity) vce(cluster id)
    scalar s13_naive = _b[months]
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(Z) wtype(iivw) truncate(1 99) nolog replace
    iivw_fit y, timespec(linear) nolog replace
    scalar s13_est = _b[months]
    scalar s13_ok = 1
}
local rc = _rc
if `rc' == 0 & s13_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "S13 setup (truncate invariance)"

local ++test_count
capture noisily {
    assert s13_ok == 1
    assert abs(s13_naive - 0.5) > 0.03                   // mild naive bias ~0.06
    assert abs(s13_est - 0.5) < 0.025                    // residual ~0.003
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "S13 truncated IIW still recovers slope (est=" + string(s13_est,"%6.4f") + ")"

**# S14: unweighted path equals naive; weighted recovers
* iivw_fit ..., unweighted must reproduce the plain naive GLM (it ignores the
* weights), while the default weighted fit recovers the true slope 0.5. Confirms
* the weighting is what does the correction, not the fit machinery.
scalar s14_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 1414
    set obs 15000
    gen long id = _n
    gen double Z = runiform(-1, 1)
    gen double s_i = 0.5 + 0.6*Z
    gen double a_i = 10 + 1.0*Z
    gen double rate_i = 1.5*exp(0.7*Z)
    expand 60
    bysort id: gen int k = _n
    gen double gap = -ln(runiform())/rate_i
    bysort id (k): gen double vtime = sum(gap)
    keep if vtime <= 10
    gen double months = vtime
    sort id months
    bysort id: gen int nv = _N
    drop if nv < 2
    drop nv
    gen double y = a_i + s_i*months + rnormal(0, 1)
    glm y months, family(gaussian) link(identity) vce(cluster id)
    scalar s14_naive = _b[months]
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(Z) wtype(iivw) nolog replace
    iivw_fit y, timespec(linear) unweighted nolog replace
    scalar s14_unw = _b[months]
    iivw_fit y, timespec(linear) nolog replace
    scalar s14_w = _b[months]
    scalar s14_ok = 1
}
local rc = _rc
if `rc' == 0 & s14_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "S14 setup (unweighted vs weighted)"

local ++test_count
capture noisily {
    assert s14_ok == 1
    assert reldif(s14_unw, s14_naive) < 1e-6             // unweighted == plain GLM
    assert abs(s14_naive - 0.5) > 0.08                   // naive misses (bias ~0.14)
    assert abs(s14_w - 0.5) < 0.025                      // weighted recovers
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "S14 unweighted==naive, weighted recovers (unw=" + string(s14_unw,"%6.4f") + " w=" + string(s14_w,"%6.4f") + ")"

**# S15: strong-gamma positivity stress -- still recovers tightly
* Strong informativeness (gamma=1.5) concentrates weight; recovery of slope 0.5
* still holds at this N. Confirms the estimator is not fragile to heavy but
* supported visit-intensity variation.
scalar s15_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 1515
    set obs 20000
    gen long id = _n
    gen double Z = runiform(-1, 1)
    gen double s_i = 0.5 + 0.6*Z
    gen double a_i = 10 + 1.0*Z
    gen double rate_i = 1.5*exp(1.5*Z)
    expand 80
    bysort id: gen int k = _n
    gen double gap = -ln(runiform())/rate_i
    bysort id (k): gen double vtime = sum(gap)
    keep if vtime <= 10
    gen double months = vtime
    sort id months
    bysort id: gen int nv = _N
    drop if nv < 2
    drop nv
    gen double y = a_i + s_i*months + rnormal(0, 1)
    glm y months, family(gaussian) link(identity) vce(cluster id)
    scalar s15_naive = _b[months]
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(Z) wtype(iivw) nolog replace
    iivw_fit y, timespec(linear) nolog replace
    scalar s15_est = _b[months]
    scalar s15_ok = 1
}
local rc = _rc
if `rc' == 0 & s15_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "S15 setup (strong gamma)"

local ++test_count
capture noisily {
    assert s15_ok == 1
    assert abs(s15_naive - 0.5) > 0.15                   // strong naive bias ~0.26
    assert abs(s15_est - 0.5) < 0.025                    // residual ~0.002
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "S15 strong-gamma IIW recovers slope (est=" + string(s15_est,"%6.4f") + ")"

**# S16: IIW cubic-coefficient recovery, timespec(cubic)
* Cubic coef s3_i = 0.03 + 0.04*Z (population marginal = 0.03). Informative
* visits bias the naive cubic term. Truth = 0.03, handle _b[_iivw_time_cu].
scalar s16_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 1616
    set obs 20000
    gen long id = _n
    gen double Z = runiform(-1, 1)
    gen double s3_i = 0.03 + 0.04*Z
    gen double a_i = 10 + 1.0*Z
    gen double rate_i = 1.5*exp(0.7*Z)
    expand 80
    bysort id: gen int k = _n
    gen double gap = -ln(runiform())/rate_i
    bysort id (k): gen double vtime = sum(gap)
    keep if vtime <= 8
    gen double months = vtime
    sort id months
    bysort id: gen int nv = _N
    drop if nv < 2
    drop nv
    gen double y = a_i + 0.5*months - 0.1*months^2 + s3_i*months^3 + rnormal(0, 1)
    gen double m2 = months^2
    gen double m3 = months^3
    glm y months m2 m3, family(gaussian) link(identity) vce(cluster id)
    scalar s16_naive = _b[m3]
    drop m2 m3
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(Z) wtype(iivw) nolog replace
    iivw_fit y, timespec(cubic) nolog replace
    scalar s16_est = _b[_iivw_time_cu]
    scalar s16_ok = 1
}
local rc = _rc
if `rc' == 0 & s16_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "S16 setup (IIW cubic)"

local ++test_count
capture noisily {
    assert s16_ok == 1
    assert abs(s16_naive - 0.03) > 0.003                 // naive bias ~ +0.008
    assert abs(s16_est - 0.03) < 0.006                   // residual ~0.0006
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "S16 IIW recovers cubic coef (est=" + string(s16_est,"%6.4f") + ")"

**# S18: IPTW binary-outcome LPM marginal risk-difference recovery
* Binary outcome via a linear-probability model; the marginal risk difference is
* collapsible so IPTW + family(gaussian) identity recovers RD=0.15. Confounder C
* biases the naive contrast. Truth = 0.15, handle _b[T].
scalar s18_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 1818
    set obs 20000
    gen long id = _n
    gen double C = runiform(-1, 1)
    gen byte T = runiform() < invlogit(-0.2 + 1.0*C)
    gen double p0_i = 0.35 + 0.15*C
    gen double rate_i = 1.5
    expand 60
    bysort id: gen int k = _n
    gen double gap = -ln(runiform())/rate_i
    bysort id (k): gen double vtime = sum(gap)
    keep if vtime <= 10
    gen double months = vtime
    sort id months
    bysort id: gen int nv = _N
    drop if nv < 2
    drop nv
    gen double prob = p0_i + 0.15*T
    gen byte y = runiform() < prob
    glm y T, family(gaussian) link(identity) vce(cluster id)
    scalar s18_naive = _b[T]
    iivw_weight, id(id) time(months) treat(T) treat_cov(C) wtype(iptw) nolog replace
    iivw_fit y T, family(gaussian) timespec(none) nolog replace
    scalar s18_est = _b[T]
    scalar s18_ok = 1
}
local rc = _rc
if `rc' == 0 & s18_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "S18 setup (IPTW LPM risk difference)"

local ++test_count
capture noisily {
    assert s18_ok == 1
    assert abs(s18_naive - 0.15) > 0.02                  // confounding bias ~0.045
    assert abs(s18_est - 0.15) < 0.02                    // residual ~0.0001
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "S18 IPTW recovers risk difference (est=" + string(s18_est,"%6.4f") + ")"

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_iivw_recovery_extended tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: validation_iivw_recovery_extended tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close
