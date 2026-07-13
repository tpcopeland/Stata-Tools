clear all
set varabbrev off
version 16.0

* validation_iivw_recovery_extended2.do
* ----------------------------------------------------------------------------
* SECOND extended known-truth recovery battery for iivw. Each scenario writes
* its own data-generating process (DGP), so the true parameter is an exact
* analytic oracle -- the strongest correctness check for an estimator.
*
* This file complements validation_iivw_recovery.do (A/B) and
* validation_iivw_recovery_extended.do (S1-S18) by driving option/command code
* paths those files do NOT reach:
*   N1  interaction(T)        -- treatment x time interaction coefficient
*   N2  categorical()/basecat -- baseline categorical level effects
*   N3  visit_cov(Z1 Z2)      -- two informative visit covariates
*   N4  IPTW negative control -- unconfounded treatment, weights ~ 1
*   N5  IIW + binary LPM      -- collapsible per-month risk-difference slope
*   N6  efron + scheduled     -- informative-observation panel, Efron ties
*   N7  negative slope        -- sign recovery
*   N8  cluster()             -- point-estimate invariance to cluster choice
*   N9  iivw_exogtest         -- endogenous DGP flags, endatlastvisit exogenous does not
*   N10 iivw_balance          -- weighting rebalances covariate; control does not
*   N11 iivw_diagnose         -- DGP-driven bias decomposition (end-to-end)
*   N12 FIPTIW + Poisson      -- collapsible marginal log-rate-ratio
*   N13 truncate() attenuation-- documented bounded trade-off on strong weights
*
* Every estimator scenario confirms a NAIVE estimator MISSES the truth (proving
* the scenario actually exercises what the weighting is meant to fix), then
* asserts the iivw estimate RECOVERS it. Tolerances are set from the Monte-Carlo
* error observed at the shipped seed/N ("watch it work"), NOT from whatever makes
* the test pass. Where a residual is a real property of the method (truncation
* bias), the scenario ships a BOUNDED gate documenting the offset.
*
* Handles confirmed from source (grep '_b\[' / colnames e(b), verified in Stata):
*   slope        -> _b[months]
*   treatment    -> _b[T]
*   T x time      -> _b[_iivw_ix_T_time]      (interaction(T), timespec(linear))
*   grp level j   -> _b[_iivw_cat_grp_j]      (categorical(grp), basecat(1))
* iivw_diagnose r(bias): rows true/bias_unweighted/bias_weighted/bias_adjusted.
* ----------------------------------------------------------------------------

capture log close
* Q6: no disposable log in the package tree. This suite used to write
* validation_iivw_recovery_extended2.log into qa/, which is gitignored but is still ~4 MB of debris carrying the
* local Stata license header, and the release hygiene gate had been taught to
* whitelist exactly these files. The batch invocation
* (`stata-mp -b do <suite>.do') already produces a readable log in the cwd, and
* run_all.log captures everything when the suite runs under the runner, so the
* named log was pure redundancy.
tempfile _suite_log
log using "`_suite_log'", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

* Bootstrap: derive package root from qa/ working directory (relocatable)
local qa_dir "`c(pwd)'"
* Sysdir sandbox + path resolution (Q3/Q8): the sandbox keeps this suite's
* net install out of the USER's real ado tree even when run standalone, and
* the "/qa" suffix is stripped by length, not by first-occurrence subinstr()
* (which mangles any path whose ancestors contain "qa").
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_sandbox
local pkg_dir  "`r(pkg_dir)'"
local repo_dir "`r(repo_dir)'"
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

**# N1: interaction(T) -- treatment x time interaction coefficient
* T is randomized (T _|_ Z), so the T x time coefficient (0.25) is clean even
* naively; but the MAIN time slope (heterogeneous 0.5+0.6*Z) IS biased upward by
* informative visits. IIW must recover the main slope (0.5) AND the interaction
* (0.25) jointly. Handles _b[months] and _b[_iivw_ix_T_time].
scalar n1_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 111
    set obs 20000
    gen long id = _n
    gen double Z = runiform(-1, 1)
    gen byte T = runiform() < 0.5
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
    gen double y = a_i + s_i*months + 0.9*T + 0.25*T*months + rnormal(0, 1)
    gen double tm = T*months
    glm y T months tm, family(gaussian) link(identity) vce(cluster id)
    scalar n1_naive_slope = _b[months]
    drop tm
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(Z) wtype(iivw) nolog replace
    iivw_fit y T, timespec(linear) interaction(T) nolog replace
    scalar n1_slope = _b[months]
    scalar n1_ix = _b[_iivw_ix_T_time]
    scalar n1_ok = 1
}
local rc = _rc
if `rc' == 0 & n1_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "N1 setup (interaction T x time)"

local ++test_count
capture noisily {
    assert n1_ok == 1
    assert abs(n1_naive_slope - 0.5) > 0.08                // naive main slope biased ~0.14
    assert abs(n1_slope - 0.5) < 0.04                      // IIW recovers main slope (obs 0.515)
    assert abs(n1_ix - 0.25) < 0.03                        // IIW recovers interaction (obs 0.248)
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "N1 interaction: slope=" + string(n1_slope,"%6.4f") + " ix=" + string(n1_ix,"%6.4f")

**# N2: categorical()/basecat() -- baseline categorical level effects
* Baseline 3-level group grp (independent of visits) shifts the level by 0.7
* (grp==2) and 1.3 (grp==3) vs grp==1. The heterogeneous time slope (0.5+0.6*Z)
* is biased by informative visits; IIW recovers the slope AND the categorical()
* path returns the built-in level effects. Handles _b[_iivw_cat_grp_2/_3].
scalar n2_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 202
    set obs 30000
    gen long id = _n
    gen double Z = runiform(-1, 1)
    gen byte grp = 1 + int(runiform()*3)
    gen double s_i = 0.5 + 0.6*Z
    gen double a_i = 10 + 1.0*Z + 0.7*(grp==2) + 1.3*(grp==3)
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
    scalar n2_naive_slope = _b[months]
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(Z) wtype(iivw) nolog replace
    iivw_fit y grp, timespec(linear) categorical(grp) basecat(1) nolog replace
    scalar n2_slope = _b[months]
    scalar n2_c2 = _b[_iivw_cat_grp_2]
    scalar n2_c3 = _b[_iivw_cat_grp_3]
    scalar n2_ok = 1
}
local rc = _rc
if `rc' == 0 & n2_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "N2 setup (categorical baseline levels)"

local ++test_count
capture noisily {
    assert n2_ok == 1
    assert abs(n2_naive_slope - 0.5) > 0.08                // naive slope biased
    assert abs(n2_slope - 0.5) < 0.04                      // IIW recovers slope
    assert abs(n2_c2 - 0.7) < 0.06                         // grp==2 level (obs 0.665)
    assert abs(n2_c3 - 1.3) < 0.06                         // grp==3 level (obs 1.288)
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "N2 categorical levels: c2=" + string(n2_c2,"%6.4f") + " c3=" + string(n2_c3,"%6.4f")

**# N3: visit_cov(Z1 Z2) -- two informative visit covariates
* Both Z1 and Z2 drive the visit intensity and the slope; the visit model must
* condition on both to recover the marginal slope 0.5. Handle _b[months].
scalar n3_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 303
    set obs 15000
    gen long id = _n
    gen double Z1 = runiform(-1, 1)
    gen double Z2 = runiform(-1, 1)
    gen double s_i = 0.5 + 0.5*Z1 + 0.4*Z2
    gen double a_i = 10 + Z1 + Z2
    gen double rate_i = 1.5*exp(0.6*Z1 + 0.5*Z2)
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
    scalar n3_naive = _b[months]
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(Z1 Z2) wtype(iivw) nolog replace
    iivw_fit y, timespec(linear) nolog replace
    scalar n3_est = _b[months]
    scalar n3_ok = 1
}
local rc = _rc
if `rc' == 0 & n3_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "N3 setup (two visit covariates)"

local ++test_count
capture noisily {
    assert n3_ok == 1
    assert abs(n3_naive - 0.5) > 0.08                      // naive bias ~0.16
    assert abs(n3_est - 0.5) < 0.03                        // residual ~0.004
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "N3 two-covar IIW recovers slope (est=" + string(n3_est,"%6.4f") + ")"

**# N4: IPTW negative control -- unconfounded treatment, weights ~ 1
* Treatment is randomized (PS independent of C), so C is balanced across T and
* the naive contrast already recovers theta=-0.8. IPTW must LEAVE the unbiased
* estimate alone (weights ~ 1). Guards against IPTW distorting a clean analysis.
scalar n4_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 404
    set obs 15000
    gen long id = _n
    gen double C = rnormal()
    gen byte T = runiform() < 0.5
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
    scalar n4_naive = _b[T]
    iivw_weight, id(id) time(months) treat(T) treat_cov(C) wtype(iptw) nolog replace
    scalar n4_wmax = r(max_weight)
    scalar n4_wcv = r(sd_weight)/r(mean_weight)
    iivw_fit y T, timespec(none) nolog replace
    scalar n4_est = _b[T]
    scalar n4_ok = 1
}
local rc = _rc
if `rc' == 0 & n4_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "N4 setup (IPTW negative control)"

local ++test_count
capture noisily {
    assert n4_ok == 1
    assert abs(n4_naive - (-0.8)) < 0.05                   // naive already unbiased (obs -0.783)
    assert abs(n4_est - (-0.8)) < 0.05                     // IPTW leaves it unbiased (obs -0.814)
    assert n4_wmax < 1.20                                  // no leverage (obs 1.07)
    assert n4_wcv < 0.05                                   // weights ~ constant (obs 0.017)
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "N4 IPTW negative control: naive & IPTW both recover, weights~1"

**# N5: IIW + binary LPM -- collapsible per-month risk-difference slope
* Binary outcome via a linear-probability model; the marginal per-month risk
* difference is collapsible, so IIW + family(gaussian) identity recovers the
* population slope E[s_i]=0.05. Informative visits bias the naive slope up.
scalar n5_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 555
    set obs 25000
    gen long id = _n
    gen double Z = runiform(-1, 1)
    gen double s_i = 0.05 + 0.05*Z
    gen double p0_i = 0.30 + 0.10*Z
    gen double rate_i = 1.5*exp(1.0*Z)
    expand 50
    bysort id: gen int k = _n
    gen double gap = -ln(runiform())/rate_i
    bysort id (k): gen double vtime = sum(gap)
    keep if vtime <= 8
    gen double months = vtime
    sort id months
    bysort id: gen int nv = _N
    drop if nv < 2
    drop nv
    gen double prob = p0_i + s_i*months
    replace prob = 0 if prob < 0
    replace prob = 1 if prob > 1
    gen byte y = runiform() < prob
    glm y months, family(gaussian) link(identity) vce(cluster id)
    scalar n5_naive = _b[months]
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(Z) wtype(iivw) nolog replace
    iivw_fit y, family(gaussian) timespec(linear) nolog replace
    scalar n5_est = _b[months]
    scalar n5_ok = 1
}
local rc = _rc
if `rc' == 0 & n5_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "N5 setup (IIW binary LPM slope)"

local ++test_count
capture noisily {
    assert n5_ok == 1
    assert abs(n5_naive - 0.05) > 0.007                    // naive bias ~0.013
    assert abs(n5_est - 0.05) < 0.008                      // residual ~0.0006
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "N5 IIW LPM recovers RD slope (est=" + string(n5_est,"%6.4f") + ")"

**# N6: efron + scheduled visits -- informative-observation panel, Efron ties
* Distinct DGP: visits are SCHEDULED at integer months 1..10 and each is OBSERVED
* with probability invlogit(1.2*Z) (informative missingness, not a recurrent-event
* intensity). Scheduled times are heavily tied across subjects, exercising the
* efron tie-handling path in the visit (stcox) model. Truth = 0.5, handle _b[months].
scalar n6_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 909
    set obs 6000
    gen long id = _n
    gen double Z = runiform(-1, 1)
    gen double s_i = 0.5 + 0.6*Z
    gen double a_i = 10 + 1.0*Z
    expand 10
    bysort id: gen int months = _n
    gen byte obs_it = runiform() < invlogit(1.2*Z)
    keep if obs_it
    bysort id: gen int nv = _N
    drop if nv < 2
    drop nv obs_it
    gen double y = a_i + s_i*months + rnormal(0, 1)
    glm y months, family(gaussian) link(identity) vce(cluster id)
    scalar n6_naive = _b[months]
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(Z) wtype(iivw) efron nolog replace
    iivw_fit y, timespec(linear) nolog replace
    scalar n6_est = _b[months]
    scalar n6_ok = 1
}
local rc = _rc
if `rc' == 0 & n6_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "N6 setup (efron + scheduled informative observation)"

local ++test_count
capture noisily {
    assert n6_ok == 1
    assert abs(n6_naive - 0.5) > 0.06                      // naive bias ~0.12
    assert abs(n6_est - 0.5) < 0.04                        // residual ~0.017
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "N6 efron IIW recovers slope (est=" + string(n6_est,"%6.4f") + ")"

**# N7: negative slope -- sign recovery
* True marginal slope is NEGATIVE (-0.5). Informative visits bias the naive slope
* toward zero / positive; IIW must recover the correct sign and magnitude.
scalar n7_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 777
    set obs 15000
    gen long id = _n
    gen double Z = runiform(-1, 1)
    gen double s_i = -0.5 + 0.6*Z
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
    scalar n7_naive = _b[months]
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(Z) wtype(iivw) nolog replace
    iivw_fit y, timespec(linear) nolog replace
    scalar n7_est = _b[months]
    scalar n7_ok = 1
}
local rc = _rc
if `rc' == 0 & n7_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "N7 setup (negative slope)"

local ++test_count
capture noisily {
    assert n7_ok == 1
    assert abs(n7_naive - (-0.5)) > 0.08                   // naive bias ~ +0.13
    assert abs(n7_est - (-0.5)) < 0.025                    // residual ~0.0003
    assert n7_est < 0                                       // correct sign
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "N7 IIW recovers negative slope (est=" + string(n7_est,"%6.4f") + ")"

**# N8: cluster() -- point-estimate invariance to cluster choice
* Clustering affects only the robust SE, never the point estimate. iivw_fit with
* a coarser cluster(site) must return the IDENTICAL slope as the default (cluster
* by id) and still recover 0.5. Exercises the cluster() code path.
scalar n8_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 888
    set obs 15000
    gen long id = _n
    gen double Z = runiform(-1, 1)
    gen int site = 1 + mod(id, 50)
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
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(Z) wtype(iivw) nolog replace
    iivw_fit y, timespec(linear) nolog replace
    scalar n8_bdef = _b[months]
    scalar n8_sedef = _se[months]
    iivw_fit y, timespec(linear) cluster(site) nolog replace
    scalar n8_bsite = _b[months]
    scalar n8_sesite = _se[months]
    scalar n8_ok = 1
}
local rc = _rc
if `rc' == 0 & n8_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "N8 setup (cluster invariance)"

local ++test_count
capture noisily {
    assert n8_ok == 1
    assert reldif(n8_bsite, n8_bdef) < 1e-10               // point estimate identical
    assert abs(n8_bdef - 0.5) < 0.025                      // recovers slope
    assert n8_sesite != n8_sedef                           // SE genuinely differs by cluster
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "N8 cluster() point-invariant, recovers (b=" + string(n8_bdef,"%6.4f") + ")"

**# N9: iivw_exogtest -- endogenous DGP flags, endatlastvisit exogenous does not
* Known-answer power/size for the visit-process exogeneity test. In the ENDOGENOUS
* DGP the next-visit gap depends on the lagged outcome (rate rises with past y), so
* the test must flag endogeneity (r(endogenous_flag)==1). In the EXOGENOUS control
* the gap is independent of y and the test must NOT flag (flag==0).
scalar n9_ok = 0
local ++test_count
capture noisily {
    * -- endogenous: past y speeds the next visit
    clear
    set seed 71
    set obs 3000
    gen long id = _n
    gen double a_i = rnormal()
    expand 40
    bysort id: gen int k = _n
    sort id k
    bysort id (k): gen double y = a_i + 0.4*k + rnormal(0, 0.5)
    bysort id (k): gen double ylag = y[_n-1]
    replace ylag = a_i if k == 1
    gen double rate = 1.0*exp(0.9*ylag)
    gen double gap = -ln(runiform())/rate
    bysort id (k): gen double vtime = sum(gap)
    keep if vtime <= 10
    gen double months = vtime
    bysort id: gen int nv = _N
    drop if nv < 2
    iivw_exogtest y, endatlastvisit id(id) time(months) nolog
    scalar n9_endo_flag = r(endogenous_flag)
    scalar n9_endo_p = r(min_p)

    * -- exogenous: gap independent of y
    clear
    set seed 72
    set obs 3000
    gen long id = _n
    gen double a_i = rnormal()
    gen double rate_i = 1.2
    expand 40
    bysort id: gen int k = _n
    gen double gap = -ln(runiform())/rate_i
    bysort id (k): gen double vtime = sum(gap)
    keep if vtime <= 10
    gen double months = vtime
    bysort id (k): gen double y = a_i + 0.4*k + rnormal(0, 0.5)
    bysort id: gen int nv = _N
    drop if nv < 2
    iivw_exogtest y, endatlastvisit id(id) time(months) nolog
    scalar n9_exo_flag = r(endogenous_flag)
    scalar n9_exo_p = r(min_p)
    scalar n9_ok = 1
}
local rc = _rc
if `rc' == 0 & n9_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "N9 setup (exogtest endogenous vs exogenous)"

local ++test_count
capture noisily {
    assert n9_ok == 1
    assert n9_endo_flag == 1                               // endogenous DGP is flagged
    assert n9_endo_p < 0.01                                // strongly significant (obs ~0)
    assert n9_exo_flag == 0                                // exogenous control not flagged
    assert n9_exo_p > 0.05                                 // not significant (obs 0.38)
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "N9 exogtest: endo flag=" + string(n9_endo_flag) + " exo flag=" + string(n9_exo_flag)

**# N10: iivw_balance -- weighting rebalances covariate; control does not
* Informative visits over-sample high-Z subjects, so the UNWEIGHTED person-time
* mean of Z is biased away from its population value 0; IIW weighting pulls the
* WEIGHTED mean back toward 0. A non-informative control (constant rate) leaves
* the covariate balanced with weights ~ 1. Reads the r(balance) matrix
* (col 1 unweighted_mean, col 2 weighted_mean, col 5 abs_smd).
scalar n10_ok = 0
local ++test_count
capture noisily {
    * -- informative visits
    clear
    set seed 73
    set obs 4000
    gen long id = _n
    gen double Z = runiform(-1, 1)
    gen double s_i = 0.5 + 0.6*Z
    gen double a_i = 10 + 1.0*Z
    gen double rate_i = 1.5*exp(1.2*Z)
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
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(Z) wtype(iivw) nolog replace
    iivw_balance Z, nolog
    matrix Binf = r(balance)
    scalar n10_inf_unw = Binf[1,1]
    scalar n10_inf_wt = Binf[1,2]
    scalar n10_inf_smd = r(balance_max_shift)
    scalar n10_inf_tsmd = r(balance_max_tsmd)
    scalar n10_inf_flag_good = ("`r(balance_flag)'" == "good")

    * -- non-informative control
    clear
    set seed 74
    set obs 4000
    gen long id = _n
    gen double Z = runiform(-1, 1)
    gen double s_i = 0.5 + 0.6*Z
    gen double a_i = 10 + 1.0*Z
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
    gen double y = a_i + s_i*months + rnormal(0, 1)
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(Z) wtype(iivw) nolog replace
    iivw_balance Z, nolog
    scalar n10_ni_smd = r(balance_max_shift)
    scalar n10_ok = 1
}
local rc = _rc
if `rc' == 0 & n10_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "N10 setup (balance informative vs control)"

local ++test_count
capture noisily {
    assert n10_ok == 1
    assert abs(n10_inf_unw) > 0.20                         // unweighted Z-mean biased (obs 0.36)
    assert abs(n10_inf_wt) < 0.15                          // weighted Z-mean corrected (obs 0.06)
    assert abs(n10_inf_wt) < abs(n10_inf_unw)              // weighting reduced covariate bias
    assert n10_inf_smd > 0.10                              // informative leverage detected (obs 0.60)
    assert n10_ni_smd < 0.05                               // control: nothing to rebalance

    * C2, the whole point of this DGP. The correction WORKED: it moved the
    * observed-visit mean of Z from 0.36 to 0.06, toward the patient target.
    * The OLD code read that 0.60 movement as |SMD| > 0.10 and reported
    * "Balance flag: poor" and "Informative: 0" -- it told the user to disregard
    * a correction that had done exactly what it was designed to do.
    *
    * Movement is now descriptive. The verdict comes from the gap to the at-risk
    * person-time target, which correct weights close.
    assert abs(n10_inf_tsmd) < 0.10
    assert n10_inf_flag_good == 1
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "N10 balance: unw=" + string(n10_inf_unw,"%6.4f") + " wt=" + string(n10_inf_wt,"%6.4f") + " ctrl_smd=" + string(n10_ni_smd,"%6.4f")

**# N11: iivw_diagnose -- DGP-driven bias decomposition (end-to-end)
* Fit REAL unweighted, weighted, and baseline-adjusted iivw slopes from an
* informative-visit DGP (true slope 0.5), then feed them to iivw_diagnose with
* true(0.5). The unweighted bias must equal the naive miss; the weighted bias
* must be ~0. (Baseline adjustment does NOT fix informative-visit bias, a useful
* known answer -- so bias_adjusted stays large like bias_unweighted.)
scalar n11_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 1212
    set obs 20000
    gen long id = _n
    gen double Z = runiform(-1, 1)
    gen double s_i = 0.5 + 0.6*Z
    gen double a_i = 10 + 1.0*Z
    gen double rate_i = 1.5*exp(0.9*Z)
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
    estimates clear
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(Z) wtype(iivw) nolog replace
    iivw_fit y, timespec(linear) unweighted nolog replace
    scalar n11_unw_slope = _b[months]
    estimates store UNW
    iivw_fit y, timespec(linear) nolog replace
    estimates store WT
    glm y months Z, family(gaussian) link(identity) vce(cluster id)
    estimates store ADJ
    iivw_diagnose months, unweighted(UNW) weighted(WT) adjusted(ADJ) ///
        true(0.5) exogeneity(exogenous)
    matrix Bd = r(bias)
    scalar n11_bias_unw = Bd[2,1]
    scalar n11_bias_wt = Bd[3,1]
    scalar n11_ok = 1
}
local rc = _rc
if `rc' == 0 & n11_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "N11 setup (diagnose DGP-driven decomposition)"

local ++test_count
capture noisily {
    assert n11_ok == 1
    * bias_unweighted equals the actual unweighted miss (internal consistency)
    assert reldif(n11_bias_unw, n11_unw_slope - 0.5) < 1e-6
    assert abs(n11_bias_unw) > 0.10                        // unweighted materially biased (obs 0.17)
    assert abs(n11_bias_wt) < 0.03                         // weighted bias ~0 (obs 0.006)
    assert abs(n11_bias_wt) < abs(n11_bias_unw)            // weighting removes the bias
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "N11 diagnose: bias_unw=" + string(n11_bias_unw,"%6.4f") + " bias_wt=" + string(n11_bias_wt,"%6.4f")

**# N12: FIPTIW + Poisson -- collapsible marginal log-rate-ratio
* Count outcome with a HOMOGENEOUS multiplicative treatment effect (log-RR=0.5,
* collapsible). Visits are informative via Z and C; treatment is confounded by C.
* Only FIPTIW (visit model on Z,C + treatment model on C) recovers the marginal
* log-RR. Extends S11 (IPTW-only Poisson) with the IIW visit component. Handle _b[T].
scalar n12_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 1313
    set obs 20000
    gen long id = _n
    gen double Z = runiform(-1, 1)
    gen double C = rnormal()
    gen byte T = runiform() < invlogit(-0.2 + 0.6*C)
    gen double a_i = 0.2 + 0.3*Z + 0.3*C
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
    gen double mu = exp(a_i + 0.5*T)
    gen int yc = rpoisson(mu)
    glm yc T, family(poisson) link(log) vce(cluster id)
    scalar n12_naive = _b[T]
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(Z C) treat(T) treat_cov(C) ///
        wtype(fiptiw) nolog replace
    iivw_fit yc T, family(poisson) link(log) timespec(none) nolog replace
    scalar n12_est = _b[T]
    scalar n12_ok = 1
}
local rc = _rc
if `rc' == 0 & n12_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "N12 setup (FIPTIW poisson log-RR)"

local ++test_count
capture noisily {
    assert n12_ok == 1
    assert abs(n12_naive - 0.5) > 0.10                     // combined bias ~0.18
    assert abs(n12_est - 0.5) < 0.05                       // residual ~0.005
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "N12 FIPTIW poisson recovers log-RR (est=" + string(n12_est,"%6.4f") + ")"

**# N13: truncate() attenuation -- documented bounded trade-off on strong weights
* Strong informativeness (gamma=1.6) concentrates the weights. The UNTRUNCATED IIW
* recovers the slope 0.5 tightly. Aggressive truncate(5 95) trades variance for
* bias: the truncated estimate moves AWAY from 0.5 (toward the biased naive value)
* -- a real, documented property, NOT a bug. Bounded gate: truncation still beats
* naive by a wide margin, but is measurably more biased than the untruncated fit.
scalar n13_ok = 0
local ++test_count
capture noisily {
    clear
    set seed 1414
    set obs 20000
    gen long id = _n
    gen double Z = runiform(-1, 1)
    gen double s_i = 0.5 + 0.6*Z
    gen double a_i = 10 + 1.0*Z
    gen double rate_i = 1.5*exp(1.6*Z)
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
    scalar n13_naive = _b[months]
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(Z) wtype(iivw) nolog replace
    iivw_fit y, timespec(linear) nolog replace
    scalar n13_full = _b[months]
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(Z) wtype(iivw) truncate(5 95) nolog replace
    iivw_fit y, timespec(linear) nolog replace
    scalar n13_trunc = _b[months]
    scalar n13_ok = 1
}
local rc = _rc
if `rc' == 0 & n13_ok == 1 local ++pass_count
else local ++fail_count
_rc_result `rc' "N13 setup (truncate attenuation)"

local ++test_count
capture noisily {
    assert n13_ok == 1
    assert abs(n13_naive - 0.5) > 0.15                     // strong naive bias ~0.28
    assert abs(n13_full - 0.5) < 0.03                      // untruncated recovers (obs 0.008)
    * aggressive truncation adds bias (moves away from truth)...
    assert abs(n13_trunc - 0.5) > abs(n13_full - 0.5)
    * ...but still corrects the bulk of the naive bias (documented bound)
    assert abs(n13_trunc - 0.5) < 0.5*abs(n13_naive - 0.5)
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
_rc_result `rc' "N13 truncate bounded attenuation (full=" + string(n13_full,"%6.4f") + " trunc=" + string(n13_trunc,"%6.4f") + ")"

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_iivw_recovery_extended2 tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: validation_iivw_recovery_extended2 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close
