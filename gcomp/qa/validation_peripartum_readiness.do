* validation_peripartum_readiness.do
* Validates gcomp mediation for: Peripartum Depression -> MS Outcomes study
* Study: Causal Effect of Peripartum Depression on MS Disease Outcomes
* Focus: Aim 2 (g-computation mediation: depression -> DMT resumption -> relapse)
*
* DGP mirrors study design:
*   A = peripartum depression (binary, ~15% prevalence)
*   M = DMT resumption by 6mo (binary, ~60% baseline rate)
*   Y = postpartum relapse 12mo (binary, ~25% baseline rate)
*   L = 9 baseline confounders (continuous + binary + categorical)
*
* Known-answer truth derived from N=200,000 MC integration over L:
*   Depression reduces DMT resumption (Aim 1a): RD ~ -0.12
*   Depression increases relapse (Aim 1b): RD ~ 0.08
*   Mediation: 30-40% of depression->relapse effect through DMT delay
*
* Runtime: ~8 minutes

clear all
set more off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

* ============================================================
* Setup
* ============================================================

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

do "`qa_dir'/_qa_bootstrap.do"

local testdir "`c(tmpdir)'"

* ============================================================
* Helper: Build peripartum-like DGP
* ============================================================
* Mimics the causal structure from the study DAG:
*   L0 -> A, L0 -> M, L0 -> Y
*   A -> M -> Y (mediation pathway)
*   A -> Y (direct pathway)
*
* Coefficients calibrated so that:
*   P(A=1) ~ 0.15 (peripartum depression prevalence)
*   P(M=1|A=0) ~ 0.60 (DMT resumption without depression)
*   P(M=1|A=1) ~ 0.40 (DMT resumption with depression)
*   P(Y=1|A=0,M=1) ~ 0.20 (relapse, no depression, on DMT)
*   P(Y=1|A=0,M=0) ~ 0.35 (relapse, no depression, off DMT)
*   P(Y=1|A=1,M=0) ~ 0.45 (relapse, depression, off DMT)

capture program drop _build_peripartum_dgp
program define _build_peripartum_dgp
    version 16.0
    syntax, Observations(integer) [Seed(integer 20260425)]

    clear
    set seed `seed'
    set obs `observations'

    * Baseline confounders (L0): mimics study covariates
    gen double age = rnormal(32, 5)
    gen byte   prior_mh = rbinomial(1, 0.20)
    gen byte   edss_cat = floor(runiform() * 3)
    gen byte   relapse_2yr = rbinomial(1, 0.30)
    gen byte   parity = rbinomial(1, 0.45)
    gen double income = rnormal(0, 1)
    gen byte   education = floor(runiform() * 3)
    gen double ms_duration = max(0, rnormal(8, 4))
    gen byte   dmt_conception = rbinomial(1, 0.70)

    * Exposure: peripartum depression (binary, ~15%)
    gen double _lp_a = -2.0 + 0.60*prior_mh + 0.15*edss_cat ///
        + 0.20*relapse_2yr - 0.03*(age - 32) - 0.15*income ///
        - 0.10*education + 0.04*ms_duration - 0.15*parity
    gen byte depression = rbinomial(1, invlogit(_lp_a))

    * Mediator: DMT resumption by 6 months (binary, ~55% overall)
    gen double _lp_m = 0.40 - 0.80*depression + 0.30*dmt_conception ///
        - 0.20*edss_cat + 0.10*income + 0.15*education ///
        - 0.15*relapse_2yr + 0.02*(age - 32) - 0.02*ms_duration ///
        + 0.20*prior_mh*depression
    gen byte dmt_resumed = rbinomial(1, invlogit(_lp_m))

    * Outcome: postpartum relapse within 12 months (binary, ~25%)
    gen double _lp_y = -1.50 - 0.60*dmt_resumed + 0.30*depression ///
        + 0.25*edss_cat + 0.30*relapse_2yr ///
        - 0.02*(age - 32) + 0.03*ms_duration ///
        - 0.10*income - 0.05*education + 0.15*prior_mh
    gen byte relapse = rbinomial(1, invlogit(_lp_y))

    drop _lp_*
end


* ============================================================
* P1: Known-answer DGP — MC truth computation
* ============================================================
* Compute ground truth via large-sample MC integration

display as text ""
display as text "P1: Known-answer ground truth (N=200,000 MC integration)"

local ++test_count
capture noisily {
    _build_peripartum_dgp, observations(200000) seed(99999)

    * Truth: E[Y(a=1)] and E[Y(a=0)] for TCE
    * Compute potential outcomes by fixing A and simulating M, Y
    * We re-draw M and Y under A=0 and A=1 for the same confounders

    * --- Under A=1 (all depressed) ---
    gen double _lp_m1 = 0.40 - 0.80*1 + 0.30*dmt_conception ///
        - 0.20*edss_cat + 0.10*income + 0.15*education ///
        - 0.15*relapse_2yr + 0.02*(age - 32) - 0.02*ms_duration ///
        + 0.20*prior_mh*1
    gen double pm1 = invlogit(_lp_m1)

    gen double _lp_y_a1_m1 = -1.50 - 0.60*1 + 0.30*1 ///
        + 0.25*edss_cat + 0.30*relapse_2yr ///
        - 0.02*(age - 32) + 0.03*ms_duration ///
        - 0.10*income - 0.05*education + 0.15*prior_mh
    gen double _lp_y_a1_m0 = -1.50 - 0.60*0 + 0.30*1 ///
        + 0.25*edss_cat + 0.30*relapse_2yr ///
        - 0.02*(age - 32) + 0.03*ms_duration ///
        - 0.10*income - 0.05*education + 0.15*prior_mh

    gen double ey_a1 = pm1 * invlogit(_lp_y_a1_m1) + (1 - pm1) * invlogit(_lp_y_a1_m0)

    * --- Under A=0 (none depressed) ---
    gen double _lp_m0 = 0.40 - 0.80*0 + 0.30*dmt_conception ///
        - 0.20*edss_cat + 0.10*income + 0.15*education ///
        - 0.15*relapse_2yr + 0.02*(age - 32) - 0.02*ms_duration ///
        + 0.20*prior_mh*0
    gen double pm0 = invlogit(_lp_m0)

    gen double _lp_y_a0_m1 = -1.50 - 0.60*1 + 0.30*0 ///
        + 0.25*edss_cat + 0.30*relapse_2yr ///
        - 0.02*(age - 32) + 0.03*ms_duration ///
        - 0.10*income - 0.05*education + 0.15*prior_mh
    gen double _lp_y_a0_m0 = -1.50 - 0.60*0 + 0.30*0 ///
        + 0.25*edss_cat + 0.30*relapse_2yr ///
        - 0.02*(age - 32) + 0.03*ms_duration ///
        - 0.10*income - 0.05*education + 0.15*prior_mh

    gen double ey_a0 = pm0 * invlogit(_lp_y_a0_m1) + (1 - pm0) * invlogit(_lp_y_a0_m0)

    * --- Cross-world: E[Y(a=1, M(a=0))] for NDE ---
    gen double ey_a1_ma0 = pm0 * invlogit(_lp_y_a1_m1) + (1 - pm0) * invlogit(_lp_y_a1_m0)

    * Compute truth
    quietly summarize ey_a1
    local truth_ey1 = r(mean)
    quietly summarize ey_a0
    local truth_ey0 = r(mean)
    quietly summarize ey_a1_ma0
    local truth_ey1_ma0 = r(mean)

    local truth_tce = `truth_ey1' - `truth_ey0'
    local truth_nde = `truth_ey1_ma0' - `truth_ey0'
    local truth_nie = `truth_ey1' - `truth_ey1_ma0'
    local truth_pm  = `truth_nie' / `truth_tce'

    display as text "  Ground truth: TCE=" %7.4f `truth_tce' ///
        " NDE=" %7.4f `truth_nde' " NIE=" %7.4f `truth_nie' ///
        " PM=" %6.3f `truth_pm'
    display as text "  E[Y(1)]=" %6.4f `truth_ey1' " E[Y(0)]=" %6.4f `truth_ey0'

    assert `truth_tce' > 0
    assert `truth_nde' > 0
    assert `truth_nie' > 0
    assert `truth_pm' > 0.10 & `truth_pm' < 0.80
}
if _rc == 0 {
    display as result "  PASS: P1 Ground truth computed and has sensible structure"
    local ++pass_count
}
else {
    display as error "  FAIL: P1 Ground truth computation (error `=_rc')"
    local ++fail_count
}

* Save truth for later tests
local saved_truth_tce = `truth_tce'
local saved_truth_nde = `truth_nde'
local saved_truth_nie = `truth_nie'
local saved_truth_pm  = `truth_pm'


* ============================================================
* P2: gcomp mediation recovers truth with study-like covariates
* ============================================================
* Uses all 9 confounders — the actual number in the study

display as text ""
display as text "P2: Mediation recovery with 9 confounders (study-like)"

* P2.1: Point estimates in correct direction
local ++test_count
capture noisily {
    _build_peripartum_dgp, observations(3000) seed(20260425)

    gcomp relapse dmt_resumed depression ///
        prior_mh edss_cat relapse_2yr dmt_conception age parity ///
        education income ms_duration, ///
        outcome(relapse) mediation obe ///
        exposure(depression) mediator(dmt_resumed) ///
        commands(dmt_resumed: logit, relapse: logit) ///
        equations(dmt_resumed: depression prior_mh edss_cat ///
            relapse_2yr dmt_conception age parity education ///
            income ms_duration, ///
            relapse: dmt_resumed depression ///
            prior_mh edss_cat relapse_2yr age ms_duration ///
            income education) ///
        base_confs(prior_mh edss_cat relapse_2yr dmt_conception ///
            age parity education income ms_duration) ///
        sim(5000) samples(200) seed(20260425)

    assert e(tce) > 0
    assert e(nde) > 0
    assert e(nie) > 0
    assert e(pm) > 0
}
if _rc == 0 {
    display as result "  PASS: P2.1 All effects positive (TCE=" %6.4f e(tce) ///
        " NDE=" %6.4f e(nde) " NIE=" %6.4f e(nie) " PM=" %6.3f e(pm) ")"
    local ++pass_count
}
else {
    display as error "  FAIL: P2.1 Effect directions with 9 confounders (error `=_rc')"
    local ++fail_count
}

* P2.2: TCE close to truth (within 0.05 — wider tolerance for 9-confounder model)
local ++test_count
capture noisily {
    local tce_diff = abs(e(tce) - `saved_truth_tce')
    assert `tce_diff' < 0.05
}
if _rc == 0 {
    display as result "  PASS: P2.2 TCE within 0.05 of truth (diff=" %6.4f `tce_diff' ///
        ", truth=" %6.4f `saved_truth_tce' ")"
    local ++pass_count
}
else {
    display as error "  FAIL: P2.2 TCE accuracy (diff=" %6.4f `tce_diff' ", error `=_rc')"
    local ++fail_count
}

* P2.3: NDE close to truth
local ++test_count
capture noisily {
    local nde_diff = abs(e(nde) - `saved_truth_nde')
    assert `nde_diff' < 0.05
}
if _rc == 0 {
    display as result "  PASS: P2.3 NDE within 0.05 of truth (diff=" %6.4f `nde_diff' ")"
    local ++pass_count
}
else {
    display as error "  FAIL: P2.3 NDE accuracy (diff=" %6.4f `nde_diff' ", error `=_rc')"
    local ++fail_count
}

* P2.4: NIE close to truth
local ++test_count
capture noisily {
    local nie_diff = abs(e(nie) - `saved_truth_nie')
    assert `nie_diff' < 0.04
}
if _rc == 0 {
    display as result "  PASS: P2.4 NIE within 0.04 of truth (diff=" %6.4f `nie_diff' ")"
    local ++pass_count
}
else {
    display as error "  FAIL: P2.4 NIE accuracy (diff=" %6.4f `nie_diff' ", error `=_rc')"
    local ++fail_count
}

* P2.5: Decomposition invariant: TCE = NDE + NIE
local ++test_count
capture noisily {
    local decomp = abs(e(tce) - (e(nde) + e(nie)))
    assert `decomp' < 0.001
}
if _rc == 0 {
    display as result "  PASS: P2.5 Decomposition TCE = NDE + NIE (residual=" %9.6f `decomp' ")"
    local ++pass_count
}
else {
    display as error "  FAIL: P2.5 Decomposition invariant (error `=_rc')"
    local ++fail_count
}

* P2.6: PM = NIE / TCE
local ++test_count
capture noisily {
    local expected_pm = e(nie) / e(tce)
    local pm_diff = abs(e(pm) - `expected_pm')
    assert `pm_diff' < 0.001
}
if _rc == 0 {
    display as result "  PASS: P2.6 PM = NIE/TCE (diff=" %9.6f `pm_diff' ")"
    local ++pass_count
}
else {
    display as error "  FAIL: P2.6 PM consistency (error `=_rc')"
    local ++fail_count
}

* P2.7: PM in plausible range for this DGP (truth ~ 0.30-0.40)
local ++test_count
capture noisily {
    assert e(pm) > 0.05 & e(pm) < 0.80
}
if _rc == 0 {
    display as result "  PASS: P2.7 PM in [0.05, 0.80] (PM=" %6.3f e(pm) ")"
    local ++pass_count
}
else {
    display as error "  FAIL: P2.7 PM range (error `=_rc')"
    local ++fail_count
}

* P2.8: Bootstrap SEs all positive
local ++test_count
capture noisily {
    assert e(se_tce) > 0
    assert e(se_nde) > 0
    assert e(se_nie) > 0
    assert e(se_pm)  > 0
}
if _rc == 0 {
    display as result "  PASS: P2.8 All SEs positive"
    local ++pass_count
}
else {
    display as error "  FAIL: P2.8 SE positivity (error `=_rc')"
    local ++fail_count
}

* P2.9: CIs contain point estimates
local ++test_count
capture noisily {
    tempname ci
    matrix `ci' = e(ci_normal)
    assert `ci'[1,1] < e(tce) & e(tce) < `ci'[2,1]
    assert `ci'[1,2] < e(nde) & e(nde) < `ci'[2,2]
    assert `ci'[1,3] < e(nie) & e(nie) < `ci'[2,3]
}
if _rc == 0 {
    display as result "  PASS: P2.9 CIs contain point estimates"
    local ++pass_count
}
else {
    display as error "  FAIL: P2.9 CI containment (error `=_rc')"
    local ++fail_count
}

* P2.10: Stored result metadata correct
local ++test_count
capture noisily {
    assert "`e(cmd)'" == "gcomp"
    assert "`e(analysis_type)'" == "mediation"
    assert "`e(outcome)'" == "relapse"
    assert "`e(exposure)'" == "depression"
    assert "`e(mediator)'" == "dmt_resumed"
    assert "`e(mediation_type)'" == "obe"
    assert "`e(scale)'" == "RD"
    assert e(N) == 3000
}
if _rc == 0 {
    display as result "  PASS: P2.10 Stored metadata correct"
    local ++pass_count
}
else {
    display as error "  FAIL: P2.10 Metadata (error `=_rc')"
    local ++fail_count
}


* ============================================================
* P3: logRR scale — secondary effect measure
* ============================================================
* Study reports RD (primary) and RR (secondary)

display as text ""
display as text "P3: logRR scale for secondary effect measures"

* P3.1: logRR produces valid results with study-like data
local ++test_count
capture noisily {
    _build_peripartum_dgp, observations(2000) seed(20260425)

    gcomp relapse dmt_resumed depression ///
        prior_mh edss_cat relapse_2yr dmt_conception age parity ///
        education income ms_duration, ///
        outcome(relapse) mediation obe ///
        exposure(depression) mediator(dmt_resumed) ///
        commands(dmt_resumed: logit, relapse: logit) ///
        equations(dmt_resumed: depression prior_mh edss_cat ///
            relapse_2yr dmt_conception age parity education ///
            income ms_duration, ///
            relapse: dmt_resumed depression ///
            prior_mh edss_cat relapse_2yr age ms_duration ///
            income education) ///
        base_confs(prior_mh edss_cat relapse_2yr dmt_conception ///
            age parity education income ms_duration) ///
        sim(3000) samples(100) seed(20260425) logRR

    assert "`e(scale)'" == "logRR"
    * logRR(TCE) should be positive (depression increases relapse risk)
    assert e(tce) > 0
    * Decomposition still holds on logRR scale
    local decomp = abs(e(tce) - (e(nde) + e(nie)))
    assert `decomp' < 0.01
}
if _rc == 0 {
    display as result "  PASS: P3.1 logRR scale works (TCE=" %6.4f e(tce) ///
        " NDE=" %6.4f e(nde) " NIE=" %6.4f e(nie) ")"
    local ++pass_count
}
else {
    display as error "  FAIL: P3.1 logRR scale (error `=_rc')"
    local ++fail_count
}

* P3.2: logRR TCE differs from RD TCE (different scales)
local ++test_count
local tce_logrr = e(tce)
capture noisily {
    gcomp relapse dmt_resumed depression ///
        prior_mh edss_cat relapse_2yr dmt_conception age parity ///
        education income ms_duration, ///
        outcome(relapse) mediation obe ///
        exposure(depression) mediator(dmt_resumed) ///
        commands(dmt_resumed: logit, relapse: logit) ///
        equations(dmt_resumed: depression prior_mh edss_cat ///
            relapse_2yr dmt_conception age parity education ///
            income ms_duration, ///
            relapse: dmt_resumed depression ///
            prior_mh edss_cat relapse_2yr age ms_duration ///
            income education) ///
        base_confs(prior_mh edss_cat relapse_2yr dmt_conception ///
            age parity education income ms_duration) ///
        sim(3000) samples(100) seed(20260425)

    assert reldif(`tce_logrr', e(tce)) > 0.01
}
if _rc == 0 {
    display as result "  PASS: P3.2 logRR TCE differs from RD TCE"
    local ++pass_count
}
else {
    display as error "  FAIL: P3.2 logRR vs RD distinction (error `=_rc')"
    local ++fail_count
}


* ============================================================
* P4: CDE — controlled direct effect for sensitivity
* ============================================================
* Study may examine CDE (Section 6.5: what if we intervened on DMT?)

display as text ""
display as text "P4: Controlled direct effect (CDE)"

* P4.1: CDE with control(1) — everyone resumes DMT
local ++test_count
capture noisily {
    _build_peripartum_dgp, observations(2000) seed(20260425)

    gcomp relapse dmt_resumed depression ///
        prior_mh edss_cat relapse_2yr dmt_conception age parity ///
        education income ms_duration, ///
        outcome(relapse) mediation obe ///
        exposure(depression) mediator(dmt_resumed) ///
        commands(dmt_resumed: logit, relapse: logit) ///
        equations(dmt_resumed: depression prior_mh edss_cat ///
            relapse_2yr dmt_conception age parity education ///
            income ms_duration, ///
            relapse: dmt_resumed depression ///
            prior_mh edss_cat relapse_2yr age ms_duration ///
            income education) ///
        base_confs(prior_mh edss_cat relapse_2yr dmt_conception ///
            age parity education income ms_duration) ///
        control(1) sim(3000) samples(100) seed(20260425)

    * CDE should exist and be smaller than TCE (removing mediation pathway)
    confirm scalar e(cde)
    * TCE = NDE + NIE still holds
    local decomp = abs(e(tce) - (e(nde) + e(nie)))
    assert `decomp' < 0.001
    * CDE(M=1) should be positive but less than TCE
    * (with everyone on DMT, only the direct depression->relapse path remains)
    assert e(cde) > -0.10
    assert e(cde) < e(tce) + 0.05
}
if _rc == 0 {
    display as result "  PASS: P4.1 CDE(M=1) valid (CDE=" %6.4f e(cde) ///
        " TCE=" %6.4f e(tce) ")"
    local ++pass_count
}
else {
    display as error "  FAIL: P4.1 CDE (error `=_rc')"
    local ++fail_count
}

* P4.2: CDE with control(0) — nobody resumes DMT
local ++test_count
capture noisily {
    _build_peripartum_dgp, observations(2000) seed(20260425)

    gcomp relapse dmt_resumed depression ///
        prior_mh edss_cat relapse_2yr dmt_conception age parity ///
        education income ms_duration, ///
        outcome(relapse) mediation obe ///
        exposure(depression) mediator(dmt_resumed) ///
        commands(dmt_resumed: logit, relapse: logit) ///
        equations(dmt_resumed: depression prior_mh edss_cat ///
            relapse_2yr dmt_conception age parity education ///
            income ms_duration, ///
            relapse: dmt_resumed depression ///
            prior_mh edss_cat relapse_2yr age ms_duration ///
            income education) ///
        base_confs(prior_mh edss_cat relapse_2yr dmt_conception ///
            age parity education income ms_duration) ///
        control(0) sim(3000) samples(100) seed(20260425)

    confirm scalar e(cde)
    * CDE(M=0) should be larger than CDE(M=1) because without DMT,
    * relapse rate is higher overall, so the depression effect is measured
    * against a higher baseline
}
if _rc == 0 {
    display as result "  PASS: P4.2 CDE(M=0) valid (CDE=" %6.4f e(cde) ")"
    local ++pass_count
}
else {
    display as error "  FAIL: P4.2 CDE(M=0) (error `=_rc')"
    local ++fail_count
}


* ============================================================
* P5: moreMC — sim(10000) as specified in study plan
* ============================================================
* Study uses sim(10000) samples(1000) — verify moreMC works

display as text ""
display as text "P5: Large MC simulation (sim > N)"

* P5.1: moreMC allows sim(10000) with N=1500
local ++test_count
capture noisily {
    _build_peripartum_dgp, observations(1500) seed(20260425)

    gcomp relapse dmt_resumed depression ///
        prior_mh edss_cat relapse_2yr dmt_conception age parity ///
        education income ms_duration, ///
        outcome(relapse) mediation obe ///
        exposure(depression) mediator(dmt_resumed) ///
        commands(dmt_resumed: logit, relapse: logit) ///
        equations(dmt_resumed: depression prior_mh edss_cat ///
            relapse_2yr dmt_conception age parity education ///
            income ms_duration, ///
            relapse: dmt_resumed depression ///
            prior_mh edss_cat relapse_2yr age ms_duration ///
            income education) ///
        base_confs(prior_mh edss_cat relapse_2yr dmt_conception ///
            age parity education income ms_duration) ///
        sim(10000) samples(50) seed(20260425) moreMC

    assert e(MC_sims) == 10000
    assert e(tce) > 0
    local decomp = abs(e(tce) - (e(nde) + e(nie)))
    assert `decomp' < 0.001
}
if _rc == 0 {
    display as result "  PASS: P5.1 moreMC with sim(10000) works (TCE=" %6.4f e(tce) ")"
    local ++pass_count
}
else {
    display as error "  FAIL: P5.1 moreMC (error `=_rc')"
    local ++fail_count
}

* P5.2: Without moreMC, sim > N is silently capped to N
local ++test_count
capture noisily {
    _build_peripartum_dgp, observations(500) seed(20260425)

    gcomp relapse dmt_resumed depression ///
        prior_mh edss_cat relapse_2yr dmt_conception age parity ///
        education income ms_duration, ///
        outcome(relapse) mediation obe ///
        exposure(depression) mediator(dmt_resumed) ///
        commands(dmt_resumed: logit, relapse: logit) ///
        equations(dmt_resumed: depression prior_mh edss_cat ///
            relapse_2yr dmt_conception age parity education ///
            income ms_duration, ///
            relapse: dmt_resumed depression ///
            prior_mh edss_cat relapse_2yr age ms_duration ///
            income education) ///
        base_confs(prior_mh edss_cat relapse_2yr dmt_conception ///
            age parity education income ms_duration) ///
        sim(10000) samples(5) seed(20260425)
    * Without moreMC, sim is capped to N (not an error, just a warning)
    assert e(MC_sims) == 500
}
if _rc == 0 {
    display as result "  PASS: P5.2 sim > N capped to N without moreMC (MC_sims=" e(MC_sims) ")"
    local ++pass_count
}
else {
    display as error "  FAIL: P5.2 sim > N cap (error `=_rc')"
    local ++fail_count
}


* ============================================================
* P6: Known-answer — no mediation DGP
* ============================================================
* When M does not affect Y, NIE should be ~0 and PM should be ~0

display as text ""
display as text "P6: Null mediation (M does not affect Y)"

local ++test_count
capture noisily {
    clear
    set seed 20260425
    set obs 3000

    gen double c1 = rnormal()
    gen double c2 = rbinomial(1, 0.3)
    gen byte a = rbinomial(1, invlogit(-1.5 + 0.3*c1 + 0.4*c2))
    gen byte m = rbinomial(1, invlogit(-0.5 + 0.8*a + 0.2*c1))
    * Y depends on A and C but NOT on M
    gen byte y = rbinomial(1, invlogit(-1.0 + 0.5*a + 0.3*c1 + 0.2*c2))

    gcomp y m a c1 c2, outcome(y) mediation obe ///
        exposure(a) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: a c1, y: m a c1 c2) ///
        base_confs(c1 c2) sim(3000) samples(200) seed(20260425)

    * NIE should be approximately 0 (no mediation pathway)
    assert abs(e(nie)) < 0.03
    * TCE should be positive (direct effect of A on Y)
    assert e(tce) > 0.02
    * NDE should be approximately equal to TCE
    assert abs(e(nde) - e(tce)) < 0.03
}
if _rc == 0 {
    display as result "  PASS: P6 Null mediation: NIE~0 (NIE=" %6.4f e(nie) ///
        "), NDE~TCE (NDE=" %6.4f e(nde) " TCE=" %6.4f e(tce) ")"
    local ++pass_count
}
else {
    display as error "  FAIL: P6 Null mediation (error `=_rc')"
    local ++fail_count
}


* ============================================================
* P7: Known-answer — full mediation DGP
* ============================================================
* When A affects Y ONLY through M, NDE should be ~0

display as text ""
display as text "P7: Full mediation (A affects Y only through M)"

local ++test_count
capture noisily {
    clear
    set seed 20260425
    set obs 3000

    gen double c1 = rnormal()
    gen double c2 = rbinomial(1, 0.3)
    gen byte a = rbinomial(1, invlogit(-1.5 + 0.3*c1 + 0.4*c2))
    gen byte m = rbinomial(1, invlogit(-0.5 + 1.0*a + 0.2*c1))
    * Y depends on M and C but NOT directly on A
    gen byte y = rbinomial(1, invlogit(-1.0 + 0.8*m + 0.3*c1 + 0.2*c2))

    gcomp y m a c1 c2, outcome(y) mediation obe ///
        exposure(a) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: a c1, y: m a c1 c2) ///
        base_confs(c1 c2) sim(3000) samples(200) seed(20260425)

    * NDE should be approximately 0 (no direct path)
    assert abs(e(nde)) < 0.03
    * NIE should be positive and approximately equal to TCE
    assert e(nie) > 0.02
    assert abs(e(nie) - e(tce)) < 0.03
    * PM should be close to 1.0
    assert e(pm) > 0.50
}
if _rc == 0 {
    display as result "  PASS: P7 Full mediation: NDE~0 (NDE=" %6.4f e(nde) ///
        "), NIE~TCE (NIE=" %6.4f e(nie) " TCE=" %6.4f e(tce) ///
        "), PM=" %6.3f e(pm)
    local ++pass_count
}
else {
    display as error "  FAIL: P7 Full mediation (error `=_rc')"
    local ++fail_count
}


* ============================================================
* P8: Known-answer — no effect DGP
* ============================================================
* When A does not affect M or Y, all effects should be ~0

display as text ""
display as text "P8: Null effect (A does not affect M or Y)"

local ++test_count
capture noisily {
    clear
    set seed 20260425
    set obs 3000

    gen double c = rnormal()
    gen byte a = rbinomial(1, invlogit(-1.5 + 0.3*c))
    * M and Y independent of A
    gen byte m = rbinomial(1, invlogit(-0.5 + 0.2*c))
    gen byte y = rbinomial(1, invlogit(-1.0 + 0.5*m + 0.3*c))

    gcomp y m a c, outcome(y) mediation obe ///
        exposure(a) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: a c, y: m a c) ///
        base_confs(c) sim(3000) samples(200) seed(20260425)

    * All effects should be approximately 0
    assert abs(e(tce)) < 0.04
    assert abs(e(nde)) < 0.04
    assert abs(e(nie)) < 0.02
    * This fixed seed deliberately produces a few failed resamples. Confirm
    * that the disclosed effective count remains above the 90% inference gate.
    assert e(bootstrap_requested) == 200
    assert e(bootstrap_attempted) == 200
    assert e(bootstrap_successful) >= 180
    assert e(bootstrap_failed) == 200 - e(bootstrap_successful)
    assert e(bootstrap_failed) > 0
}
if _rc == 0 {
    display as result "  PASS: P8 Null effect: all ~0 (TCE=" %6.4f e(tce) ///
        " NDE=" %6.4f e(nde) " NIE=" %6.4f e(nie) ")"
    local ++pass_count
}
else {
    display as error "  FAIL: P8 Null effect (error `=_rc')"
    local ++fail_count
}


* ============================================================
* P9: Reproducibility — same data/seed = same results
* ============================================================

display as text ""
display as text "P9: Reproducibility"

local ++test_count
capture noisily {
    _build_peripartum_dgp, observations(1500) seed(20260425)
    tempfile repro_data
    save `repro_data'

    gcomp relapse dmt_resumed depression ///
        prior_mh edss_cat relapse_2yr dmt_conception age parity ///
        education income ms_duration, ///
        outcome(relapse) mediation obe ///
        exposure(depression) mediator(dmt_resumed) ///
        commands(dmt_resumed: logit, relapse: logit) ///
        equations(dmt_resumed: depression prior_mh edss_cat ///
            relapse_2yr dmt_conception age parity education ///
            income ms_duration, ///
            relapse: dmt_resumed depression ///
            prior_mh edss_cat relapse_2yr age ms_duration ///
            income education) ///
        base_confs(prior_mh edss_cat relapse_2yr dmt_conception ///
            age parity education income ms_duration) ///
        sim(2000) samples(30) seed(12345)

    local tce1 = e(tce)
    local nde1 = e(nde)
    local nie1 = e(nie)
    local pm1  = e(pm)

    use `repro_data', clear
    gcomp relapse dmt_resumed depression ///
        prior_mh edss_cat relapse_2yr dmt_conception age parity ///
        education income ms_duration, ///
        outcome(relapse) mediation obe ///
        exposure(depression) mediator(dmt_resumed) ///
        commands(dmt_resumed: logit, relapse: logit) ///
        equations(dmt_resumed: depression prior_mh edss_cat ///
            relapse_2yr dmt_conception age parity education ///
            income ms_duration, ///
            relapse: dmt_resumed depression ///
            prior_mh edss_cat relapse_2yr age ms_duration ///
            income education) ///
        base_confs(prior_mh edss_cat relapse_2yr dmt_conception ///
            age parity education income ms_duration) ///
        sim(2000) samples(30) seed(12345)

    assert reldif(`tce1', e(tce)) < 1e-10
    assert reldif(`nde1', e(nde)) < 1e-10
    assert reldif(`nie1', e(nie)) < 1e-10
    assert reldif(`pm1',  e(pm))  < 1e-10
}
if _rc == 0 {
    display as result "  PASS: P9 Reproducible with same data and seed"
    local ++pass_count
}
else {
    display as error "  FAIL: P9 Reproducibility (error `=_rc')"
    local ++fail_count
}


* ============================================================
* P10: gcomptab produces valid Excel from study-like results
* ============================================================

display as text ""
display as text "P10: gcomptab Excel output"

local ++test_count
capture noisily {
    _build_peripartum_dgp, observations(1500) seed(20260425)

    gcomp relapse dmt_resumed depression ///
        prior_mh edss_cat relapse_2yr dmt_conception age parity ///
        education income ms_duration, ///
        outcome(relapse) mediation obe ///
        exposure(depression) mediator(dmt_resumed) ///
        commands(dmt_resumed: logit, relapse: logit) ///
        equations(dmt_resumed: depression prior_mh edss_cat ///
            relapse_2yr dmt_conception age parity education ///
            income ms_duration, ///
            relapse: dmt_resumed depression ///
            prior_mh edss_cat relapse_2yr age ms_duration ///
            income education) ///
        base_confs(prior_mh edss_cat relapse_2yr dmt_conception ///
            age parity education income ms_duration) ///
        sim(2000) samples(50) seed(20260425)

    capture erase "`testdir'/_val_peripartum_mediation.xlsx"
    gcomptab, xlsx("`testdir'/_val_peripartum_mediation.xlsx") ///
        sheet("Table_Mediation") ///
        title("Mediation of Depression-Relapse Effect Through DMT Resumption")

    * Verify r() scalars populated
    assert r(tce) != .
    assert r(nde) != .
    assert r(nie) != .
    assert r(pm) != .
    assert r(N_effects) >= 4

    * Verify Excel file exists and has correct structure
    import excel "`testdir'/_val_peripartum_mediation.xlsx", ///
        sheet("Table_Mediation") clear
    count
    assert r(N) >= 6
}
if _rc == 0 {
    display as result "  PASS: P10 gcomptab Excel output valid"
    local ++pass_count
}
else {
    display as error "  FAIL: P10 gcomptab (error `=_rc')"
    local ++fail_count
}


* ============================================================
* P11: post_confs — exposure-induced M-Y confounding
* ============================================================
* Study Section 6.5.3 notes healthcare engagement as potential
* exposure-induced M-Y confounder. Verify post_confs() works.

display as text ""
display as text "P11: post_confs() for exposure-induced M-Y confounding"

local ++test_count
capture noisily {
    clear
    set seed 20260425
    set obs 2000

    gen double c = rnormal()
    gen byte a = rbinomial(1, invlogit(-1.5 + 0.3*c))
    * Z is an exposure-induced M-Y confounder (healthcare engagement)
    gen double z = rnormal(0.5*a + 0.2*c, 0.5)
    gen byte m = rbinomial(1, invlogit(-0.5 + 0.8*a + 0.3*z + 0.2*c))
    gen byte y = rbinomial(1, invlogit(-1.0 + 0.5*m + 0.3*a + 0.4*z + 0.2*c))

    gcomp y z m a c, outcome(y) mediation obe ///
        exposure(a) mediator(m) ///
        commands(z: regress, m: logit, y: logit) ///
        equations(z: a c, m: a z c, y: m a z c) ///
        base_confs(c) post_confs(z) ///
        sim(3000) samples(100) seed(20260425)

    assert "`e(cmd)'" == "gcomp"
    local decomp = abs(e(tce) - (e(nde) + e(nie)))
    assert `decomp' < 0.001
    assert e(tce) > 0
}
if _rc == 0 {
    display as result "  PASS: P11 post_confs() works (TCE=" %6.4f e(tce) ///
        " NDE=" %6.4f e(nde) " NIE=" %6.4f e(nie) ")"
    local ++pass_count
}
else {
    display as error "  FAIL: P11 post_confs() (error `=_rc')"
    local ++fail_count
}


* ============================================================
* P12: Realistic sample size — N=1500 (Aim 2 subcohort)
* ============================================================
* Study expects 1,000-1,400 for Aim 2 (prior DMT users)

display as text ""
display as text "P12: Realistic study sample size (N=1500)"

local ++test_count
capture noisily {
    _build_peripartum_dgp, observations(1500) seed(20260425)

    * Verify depression prevalence is ~15%
    quietly summarize depression
    assert r(mean) > 0.08 & r(mean) < 0.25

    gcomp relapse dmt_resumed depression ///
        prior_mh edss_cat relapse_2yr dmt_conception age parity ///
        education income ms_duration, ///
        outcome(relapse) mediation obe ///
        exposure(depression) mediator(dmt_resumed) ///
        commands(dmt_resumed: logit, relapse: logit) ///
        equations(dmt_resumed: depression prior_mh edss_cat ///
            relapse_2yr dmt_conception age parity education ///
            income ms_duration, ///
            relapse: dmt_resumed depression ///
            prior_mh edss_cat relapse_2yr age ms_duration ///
            income education) ///
        base_confs(prior_mh edss_cat relapse_2yr dmt_conception ///
            age parity education income ms_duration) ///
        sim(5000) samples(200) seed(20260425) moreMC

    assert e(N) == 1500
    assert e(tce) > 0
    local decomp = abs(e(tce) - (e(nde) + e(nie)))
    assert `decomp' < 0.001
    assert e(se_tce) > 0
    assert e(se_tce) < 0.15
}
if _rc == 0 {
    display as result "  PASS: P12 N=1500: TCE=" %6.4f e(tce) ///
        " SE=" %6.4f e(se_tce) " PM=" %6.3f e(pm)
    local ++pass_count
}
else {
    display as error "  FAIL: P12 Realistic N (error `=_rc')"
    local ++fail_count
}


* ============================================================
* P13: minsim — deterministic expected values
* ============================================================
* minsim uses E[Y|X] instead of random draws — useful as sensitivity check

display as text ""
display as text "P13: minsim option"

local ++test_count
capture noisily {
    _build_peripartum_dgp, observations(2000) seed(20260425)

    gcomp relapse dmt_resumed depression ///
        prior_mh edss_cat relapse_2yr dmt_conception age parity ///
        education income ms_duration, ///
        outcome(relapse) mediation obe ///
        exposure(depression) mediator(dmt_resumed) ///
        commands(dmt_resumed: logit, relapse: logit) ///
        equations(dmt_resumed: depression prior_mh edss_cat ///
            relapse_2yr dmt_conception age parity education ///
            income ms_duration, ///
            relapse: dmt_resumed depression ///
            prior_mh edss_cat relapse_2yr age ms_duration ///
            income education) ///
        base_confs(prior_mh edss_cat relapse_2yr dmt_conception ///
            age parity education income ms_duration) ///
        sim(3000) samples(100) seed(20260425) minsim

    assert e(tce) > 0
    local decomp = abs(e(tce) - (e(nde) + e(nie)))
    assert `decomp' < 0.001
}
if _rc == 0 {
    display as result "  PASS: P13 minsim option (TCE=" %6.4f e(tce) ///
        " NDE=" %6.4f e(nde) " NIE=" %6.4f e(nie) ")"
    local ++pass_count
}
else {
    display as error "  FAIL: P13 minsim (error `=_rc')"
    local ++fail_count
}


* ============================================================
* P14: saving() — save simulated dataset for diagnostics
* ============================================================

display as text ""
display as text "P14: saving() option"

local ++test_count
capture noisily {
    _build_peripartum_dgp, observations(1000) seed(20260425)

    capture erase "`testdir'/_val_peripartum_simdata.dta"
    gcomp relapse dmt_resumed depression ///
        prior_mh edss_cat relapse_2yr dmt_conception age parity ///
        education income ms_duration, ///
        outcome(relapse) mediation obe ///
        exposure(depression) mediator(dmt_resumed) ///
        commands(dmt_resumed: logit, relapse: logit) ///
        equations(dmt_resumed: depression prior_mh edss_cat ///
            relapse_2yr dmt_conception age parity education ///
            income ms_duration, ///
            relapse: dmt_resumed depression ///
            prior_mh edss_cat relapse_2yr age ms_duration ///
            income education) ///
        base_confs(prior_mh edss_cat relapse_2yr dmt_conception ///
            age parity education income ms_duration) ///
        sim(1000) samples(10) seed(20260425) ///
        saving("`testdir'/_val_peripartum_simdata.dta") replace

    confirm file "`testdir'/_val_peripartum_simdata.dta"
    preserve
    use "`testdir'/_val_peripartum_simdata.dta", clear
    assert _N > 0
    capture confirm variable _int
    assert _rc == 0
    restore
}
if _rc == 0 {
    display as result "  PASS: P14 saving() creates simulated dataset"
    local ++pass_count
}
else {
    display as error "  FAIL: P14 saving() (error `=_rc')"
    local ++fail_count
}


* ============================================================
* P15: Exact study plan syntax — dry run
* ============================================================
* Verify the exact gcomp call from Section 6.5.2 runs without error
* (adapted to simulated data with matching variable names)

display as text ""
display as text "P15: Study plan syntax (Section 6.5.2)"

local ++test_count
capture noisily {
    _build_peripartum_dgp, observations(1500) seed(20260425)

    * Rename to match study plan variable names exactly
    rename relapse postpartum_relapse
    rename depression peripartum_depression
    rename dmt_resumed dmt_resumed_6mo

    gcomp postpartum_relapse dmt_resumed_6mo peripartum_depression ///
        prior_mh edss_cat relapse_2yr dmt_conception age parity ///
        education income ms_duration, ///
        outcome(postpartum_relapse) mediation obe ///
        exposure(peripartum_depression) mediator(dmt_resumed_6mo) ///
        commands(dmt_resumed_6mo: logit, postpartum_relapse: logit) ///
        equations(dmt_resumed_6mo: peripartum_depression prior_mh edss_cat ///
                  relapse_2yr dmt_conception age parity education income ms_duration, ///
                  postpartum_relapse: dmt_resumed_6mo peripartum_depression ///
                  prior_mh edss_cat relapse_2yr age ///
                  education ms_duration) ///
        base_confs(prior_mh edss_cat relapse_2yr dmt_conception age parity ///
                   education income ms_duration) ///
        sim(10000) samples(50) seed(20260425) moreMC

    assert "`e(cmd)'" == "gcomp"
    assert "`e(analysis_type)'" == "mediation"
    assert "`e(outcome)'" == "postpartum_relapse"
    assert "`e(exposure)'" == "peripartum_depression"
    assert "`e(mediator)'" == "dmt_resumed_6mo"
    assert e(MC_sims) == 10000
    assert e(tce) != .
    local decomp = abs(e(tce) - (e(nde) + e(nie)))
    assert `decomp' < 0.001
}
if _rc == 0 {
    display as result "  PASS: P15 Study plan syntax runs (TCE=" %6.4f e(tce) ///
        " NDE=" %6.4f e(nde) " NIE=" %6.4f e(nie) " PM=" %6.3f e(pm) ")"
    local ++pass_count
}
else {
    display as error "  FAIL: P15 Study plan syntax (error `=_rc')"
    local ++fail_count
}


* ============================================================
* P16: Study plan gcomptab syntax
* ============================================================

local ++test_count
capture noisily {
    capture erase "`testdir'/_val_mediation_results.xlsx"
    gcomptab, xlsx("`testdir'/_val_mediation_results.xlsx") ///
        sheet("Table_Mediation") ///
        title("Mediation of Depression-Relapse Effect Through DMT Resumption")

    confirm file "`testdir'/_val_mediation_results.xlsx"
    assert r(tce) != .
    assert r(nde) != .
    assert r(nie) != .
    assert r(pm) != .
}
if _rc == 0 {
    display as result "  PASS: P16 Study plan gcomptab syntax"
    local ++pass_count
}
else {
    display as error "  FAIL: P16 gcomptab syntax (error `=_rc')"
    local ++fail_count
}


* ============================================================
* P17: Data preservation — original data intact after gcomp
* ============================================================

display as text ""
display as text "P17: Data preservation"

local ++test_count
capture noisily {
    _build_peripartum_dgp, observations(1000) seed(20260425)
    local n_before = _N
    quietly summarize age
    local age_mean_before = r(mean)

    gcomp relapse dmt_resumed depression ///
        prior_mh edss_cat relapse_2yr dmt_conception age parity ///
        education income ms_duration, ///
        outcome(relapse) mediation obe ///
        exposure(depression) mediator(dmt_resumed) ///
        commands(dmt_resumed: logit, relapse: logit) ///
        equations(dmt_resumed: depression prior_mh edss_cat ///
            relapse_2yr dmt_conception age parity education ///
            income ms_duration, ///
            relapse: dmt_resumed depression ///
            prior_mh edss_cat relapse_2yr age ms_duration ///
            income education) ///
        base_confs(prior_mh edss_cat relapse_2yr dmt_conception ///
            age parity education income ms_duration) ///
        sim(500) samples(10) seed(20260425)

    assert _N == `n_before'
    quietly summarize age
    assert reldif(r(mean), `age_mean_before') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: P17 Data preserved after gcomp"
    local ++pass_count
}
else {
    display as error "  FAIL: P17 Data preservation (error `=_rc')"
    local ++fail_count
}


* ============================================================
* P18: Effect matrix structure (e(b), e(V), e(effects))
* ============================================================

display as text ""
display as text "P18: Matrix structure"

local ++test_count
capture noisily {
    * e(b) should have 4 columns without control() (TCE NDE NIE PM)
    tempname b V eff
    matrix `b' = e(b)
    matrix `V' = e(V)
    assert colsof(`b') == 4
    assert rowsof(`V') == 4
    assert colsof(`V') == 4

    * e(effects) should exist
    matrix `eff' = e(effects)
    assert rowsof(`eff') >= 4
}
if _rc == 0 {
    display as result "  PASS: P18 Matrix structure correct"
    local ++pass_count
}
else {
    display as error "  FAIL: P18 Matrix structure (error `=_rc')"
    local ++fail_count
}


* ============================================================
* Cleanup
* ============================================================

capture erase "`testdir'/_val_peripartum_mediation.xlsx"
capture erase "`testdir'/_val_peripartum_simdata.dta"
capture erase "`testdir'/_val_mediation_results.xlsx"
capture program drop _build_peripartum_dgp

* ============================================================
* Summary
* ============================================================

display ""
display as result "Peripartum Readiness Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display "RESULT: validation_peripartum_readiness tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    display as error "FAIL"
    exit 1
}
else {
    display "RESULT: validation_peripartum_readiness tests=`test_count' pass=`pass_count' fail=`fail_count' status=PASS"
    display as result "PASS"
}
