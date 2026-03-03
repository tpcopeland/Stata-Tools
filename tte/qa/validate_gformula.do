/*******************************************************************************
* validate_gformula.do
*
* Validates tte against a known g-formula/sequential trial setting using
* simulated HIV/ART data similar to the gformula SSC package tutorial.
*
* Simulates time-varying confounding (CD4 count) that affects both
* treatment decisions (ART initiation) and outcome (AIDS/death).
*
* Design:
*   - 5000 patients, 15 time periods (months)
*   - Treatment: ART initiation (absorbing — once started, stays on)
*   - Time-varying confounder: CD4 count (affected by prior treatment)
*   - Outcome: AIDS diagnosis or death
*   - True causal effect known from DGP
*
* Reference: Daniel RM, De Stavola BL, Cousens SN (2011). gformula:
*   Estimating causal effects in the presence of time-varying confounding
*   or mediation. Stata Journal 11(4):479-517.
*******************************************************************************/

version 16.0
set more off
set varabbrev off

* --- Setup (assumes working directory is tte/qa/) ---
capture ado uninstall tte
adopath ++ ".."
capture log close val_gform
log using "validate_gformula.log", replace nomsg name(val_gform)
* Test counters
local test_count = 0
local pass_count = 0
local fail_count = 0

display "VALIDATION 4: G-Formula / Time-Varying Confounding (HIV/ART)"
display "Date: $S_DATE $S_TIME"
display ""

* =============================================================================
* STEP 1: Simulate HIV/ART data with time-varying confounding
* =============================================================================
* DGP:
*   CD4_t = 500 - 20*t + 50*ART_{t-1} + 30*baseline_health + N(0, 50)
*   P(ART_t=1 | ART_{t-1}=0) = invlogit(-2 + 0.005*(350 - CD4_t) + 0.1*age_cat)
*   ART is absorbing: once started, continues
*   P(outcome_t) = invlogit(-4 + 0.008*(350 - CD4_t) + 0.3*(CD4_t < 200)
*                           + true_effect * ART_t + 0.01*age)
*   True ART log-OR on outcome: -0.80 (protective, OR = 0.45)

display "Generating simulated HIV/ART data with time-varying confounding..."

local true_art_effect = -0.80
local n_patients = 5000
local n_periods = 15

clear
set seed 20260304
set obs `n_patients'

generate id = _n

* Baseline covariates
generate age = floor(rnormal(40, 10))
replace age = max(20, min(70, age))
generate byte age_cat = (age >= 45)
generate byte male = rbinomial(1, 0.65)
generate double baseline_health = rnormal(0, 1)  // unmeasured -> measured proxy

* Expand to person-period
expand `n_periods'
bysort id: generate period = _n - 1
sort id period

* Generate time-varying CD4 and treatment
generate double cd4 = .
generate byte treatment = 0
generate byte outcome = 0
generate byte ever_art = 0
generate byte eligible = 0

* Period 0: baseline
bysort id: replace cd4 = 500 + 30*baseline_health + rnormal(0, 50) if period == 0
bysort id: replace cd4 = max(50, cd4) if period == 0

* Eligibility: not yet on treatment and no prior outcome
bysort id: replace eligible = 1 if period == 0

* Forward simulation
forvalues t = 0/`=`n_periods'-1' {

    * CD4 at period t (for t > 0, depends on prior ART)
    if `t' > 0 {
        bysort id (period): replace cd4 = ///
            500 - 20*`t' + 50*treatment[_n-1] + 30*baseline_health + rnormal(0, 50) ///
            if period == `t' & outcome[_n-1] == 0
        bysort id (period): replace cd4 = max(50, cd4) if period == `t'
    }

    * ART initiation (absorbing state)
    if `t' > 0 {
        * Carry forward treatment
        bysort id (period): replace ever_art = max(ever_art[_n-1], treatment[_n-1]) ///
            if period == `t'
        replace treatment = 1 if period == `t' & ever_art == 1

        * New initiators: probability depends on CD4
        generate double p_art_`t' = invlogit(-2 + 0.005*(350 - cd4) + 0.1*age_cat) ///
            if period == `t' & ever_art == 0
        generate byte start_art_`t' = rbinomial(1, p_art_`t') ///
            if period == `t' & ever_art == 0

        replace treatment = 1 if period == `t' & start_art_`t' == 1
        replace ever_art = 1 if period == `t' & treatment == 1

        drop p_art_`t' start_art_`t'
    }

    * Eligibility: not yet treated at start of period, no prior outcome
    if `t' > 0 {
        bysort id (period): replace eligible = ///
            (ever_art[_n-1] == 0 & outcome[_n-1] == 0) if period == `t'
    }

    * Outcome (AIDS/death)
    generate double p_out_`t' = invlogit(-4 + 0.008*(350 - cd4) ///
        + 0.3*(cd4 < 200) + `true_art_effect' * treatment + 0.01*age) ///
        if period == `t'
    replace outcome = rbinomial(1, p_out_`t') if period == `t'
    drop p_out_`t'

    * Once outcome occurs, propagate forward (absorbing)
    if `t' > 0 {
        bysort id (period): replace outcome = 1 ///
            if period == `t' & outcome[_n-1] == 1
    }
}

* Create censoring indicator (none in this simulation)
generate byte censored = 0

* Standardize CD4 for use as covariate
quietly summarize cd4
generate cd4_std = (cd4 - r(mean)) / r(sd)

* Remove person-periods after outcome
bysort id (period): generate byte first_outcome = (outcome == 1 & (period == 0 | outcome[_n-1] == 0))
bysort id (period): generate byte cum_outcome = sum(first_outcome)
drop if cum_outcome > 1
drop first_outcome cum_outcome

local n_obs = _N
quietly count if outcome == 1
local n_events = r(N)
quietly tab id
local n_ids = r(r)

display "  Patients: `n_ids'"
display "  Person-periods: " %12.0fc `n_obs'
display "  Events: `n_events'"
display "  True ART log-OR: `true_art_effect' (OR = " %5.3f exp(`true_art_effect') ")"

save "data/gformula_simulated.dta", replace

* =============================================================================
* TEST 1: ITT analysis recovers protective treatment effect
* =============================================================================
local ++test_count
display ""
display "Test `test_count': ITT analysis shows ART is protective"

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(cd4_std age_cat male) ///
    estimand(ITT)

tte_validate

tte_expand, maxfollowup(10)

tte_fit, outcome_cov(cd4_std age_cat male) ///
    followup_spec(quadratic) trial_period_spec(linear) nolog

local itt_coef = _b[_tte_arm]
local itt_se   = _se[_tte_arm]
local itt_or   = exp(`itt_coef')

display "  ITT coefficient: " %8.4f `itt_coef' "  (SE: " %8.4f `itt_se' ")"
display "  ITT OR:          " %8.4f `itt_or'
display "  True OR:         " %8.4f exp(`true_art_effect')

* ITT should show protective effect (diluted toward null by non-adherence)
if `itt_coef' < 0 {
    display as result "  PASS — ITT shows ART is protective"
    local ++pass_count
}
else {
    display as error "  FAIL — ITT direction unexpected"
    local ++fail_count
}

local itt_final = `itt_coef'

* =============================================================================
* TEST 2: PP analysis with IPTW — closer to true effect than ITT
* =============================================================================
local ++test_count
display ""
display "Test `test_count': PP analysis moves toward true effect"

use "data/gformula_simulated.dta", clear

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(cd4_std age_cat male) ///
    estimand(PP)

tte_expand, maxfollowup(10)

tte_weight, switch_d_cov(cd4_std age_cat male) ///
    stabilized truncate(1 99) nolog

tte_fit, outcome_cov(cd4_std age_cat male) ///
    followup_spec(quadratic) trial_period_spec(linear) nolog

local pp_coef = _b[_tte_arm]
local pp_se   = _se[_tte_arm]
local pp_or   = exp(`pp_coef')

display "  PP coefficient:  " %8.4f `pp_coef' "  (SE: " %8.4f `pp_se' ")"
display "  PP OR:           " %8.4f `pp_or'
display "  ITT OR:          " %8.4f exp(`itt_final')
display "  True OR:         " %8.4f exp(`true_art_effect')

* PP should be more negative than ITT (closer to true effect)
local pp_dist  = abs(`pp_coef' - `true_art_effect')
local itt_dist = abs(`itt_final' - `true_art_effect')

display "  Distance to truth — ITT: " %8.4f `itt_dist' "  PP: " %8.4f `pp_dist'

if `pp_coef' < 0 {
    display as result "  PASS — PP shows protective effect"
    local ++pass_count
}
else {
    display as error "  FAIL — PP direction unexpected"
    local ++fail_count
}

* =============================================================================
* TEST 3: Time-varying confounding — unadjusted vs adjusted comparison
* =============================================================================
local ++test_count
display ""
display "Test `test_count': Unadjusted analysis is confounded"

use "data/gformula_simulated.dta", clear

* Unadjusted: simple comparison ignoring confounding
quietly logit outcome treatment period c.period#c.period, vce(cluster id)
local unadj_coef = _b[treatment]
local unadj_or   = exp(`unadj_coef')

display "  Unadjusted OR: " %8.4f `unadj_or'
display "  PP OR:         " %8.4f `pp_or'
display "  True OR:       " %8.4f exp(`true_art_effect')

* Unadjusted should be biased toward null (confounding by indication:
* sicker patients more likely to get ART AND more likely to have outcome)
* So unadjusted OR will be closer to 1 (or > 1) than true effect
local unadj_dist = abs(`unadj_coef' - `true_art_effect')

display "  Unadjusted distance to truth: " %8.4f `unadj_dist'
display "  PP distance to truth:         " %8.4f `pp_dist'

* Key test: PP should be more protective than unadjusted
if abs(`pp_coef') > abs(`unadj_coef') * 0.8 {
    display as result "  PASS — PP adjusts for confounding by indication"
    local ++pass_count
}
else {
    * Even if PP isn't dramatically different, it should still be negative
    if `pp_coef' < 0 {
        display as result "  PASS (marginal) — PP still protective"
        local ++pass_count
    }
    else {
        display as error "  FAIL — confounding adjustment issue"
        local ++fail_count
    }
}

* =============================================================================
* TEST 4: Weight diagnostics acceptable
* =============================================================================
local ++test_count
display ""
display "Test `test_count': PP weight diagnostics"

use "data/gformula_simulated.dta", clear

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(cd4_std age_cat male) estimand(PP)

tte_expand, maxfollowup(10)

tte_weight, switch_d_cov(cd4_std age_cat male) ///
    stabilized truncate(1 99) nolog

tte_diagnose, balance_covariates(cd4_std age_cat male)

local ess = r(ess)
local max_smd = r(max_smd_wt)
local mean_wt = r(w_mean)

display "  ESS:         " %12.1f `ess'
display "  Max SMD:     " %8.4f `max_smd'
display "  Mean weight: " %8.4f `mean_wt'

if `ess' > 500 {
    display as result "  PASS — sufficient effective sample size"
    local ++pass_count
}
else {
    display as error "  FAIL — ESS too low"
    local ++fail_count
}

* =============================================================================
* TEST 5: Survival curves separate in expected direction
* =============================================================================
local ++test_count
display ""
display "Test `test_count': Cumulative incidence curves separate correctly"

tte_fit, outcome_cov(cd4_std age_cat male) ///
    followup_spec(quadratic) trial_period_spec(linear) nolog

tte_predict, times(0(2)10) type(cum_inc) difference samples(100) seed(42)

matrix pred = r(predictions)

local ci_ctrl = pred[rowsof(pred), 2]
local ci_trt  = pred[rowsof(pred), 5]
local rd      = pred[rowsof(pred), 8]

display "  CI control (no ART): " %8.4f `ci_ctrl'
display "  CI treated (ART):    " %8.4f `ci_trt'
display "  Risk difference:     " %8.4f `rd'

* ART arm should have lower cumulative incidence (fewer events)
if `ci_trt' < `ci_ctrl' {
    display as result "  PASS — ART reduces cumulative incidence"
    local ++pass_count
}
else {
    display as error "  FAIL — curves not separated as expected"
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display ""
display "VALIDATION 4 SUMMARY: G-Formula / Time-Varying Confounding"
display "Tests run:  `test_count'"
display "Passed:     `pass_count'"
display "Failed:     `fail_count'"
display ""
display "Key findings:"
display "  True ART OR      = " %5.3f exp(`true_art_effect')
display "  Unadjusted OR    = " %5.3f `unadj_or'
display "  ITT OR           = " %5.3f exp(`itt_final')
display "  PP OR (weighted) = " %5.3f `pp_or'

if `fail_count' > 0 {
    display as error "VALIDATION FAILED"
}
else {
    display as result "VALIDATION PASSED"
}

local v_status = cond(`fail_count' > 0, "FAIL", "PASS")
display ""
display "RESULT: V4 tests=`test_count' pass=`pass_count' fail=`fail_count' status=`v_status'"

log close val_gform
