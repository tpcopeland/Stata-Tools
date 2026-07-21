* test_msm_weight_adversarial.do
* Semantic adversarial QA for msm_weight IPTW/IPCW behavior.

version 16.0
clear all
set more off
set varabbrev off

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local tol = 1e-8
local pass_count = 0
local fail_count = 0
local test_count = 0
local failed_tests ""

capture program drop _wadv_make_panel
program define _wadv_make_panel
    version 16.0

    clear
    set seed 86420
    set obs 900
    gen long id = ceil(_n / 5)
    bysort id: gen int period = _n - 1

    gen byte bl = mod(id, 2)
    gen double L = rnormal() + 0.25 * period + 0.35 * bl
    gen double p_treat = invlogit(-0.65 + 0.40 * bl + 0.35 * L + 0.15 * period)
    gen byte treatment = runiform() < p_treat

    gen double p_outcome = invlogit(-4.4 + 0.45 * treatment + 0.20 * L + 0.10 * period)
    gen byte outcome = runiform() < p_outcome

    gen double p_censor = invlogit(-3.2 + 0.35 * treatment + 0.35 * L + 0.12 * period)
    gen byte censored = runiform() < p_censor

    replace outcome = 1 if id == 5 & period == 1
    replace censored = 0 if id == 5 & period == 1   // event => uncensored (censor-first)
    replace censored = 1 if id == 6 & period == 1
    replace outcome = 0 if id == 6 & period == 1     // censored => no observed event

    replace outcome = 0 if inlist(id, 7, 8)
    replace censored = 0 if inlist(id, 7, 8)

    * Enforce the package's censor-first timing convention: a censored subject
    * has no observed outcome that period, so an outcome==1 & censored==1 tie is
    * contradictory data (rejected by msm_prepare, audit A08). Incidental ties
    * from the independent draws above are resolved here; because censored
    * subjects leave the risk set, this leaves every weighting oracle exact.
    replace outcome = 0 if censored == 1

    drop p_treat p_outcome p_censor
end

display as text ""
display as text "{hline 72}"
display as result "msm_weight adversarial semantic QA"
display as text "{hline 72}"

* --- WADV1: manual treatment probabilities match command IPTW ---
local ++test_count
capture noisily {
    tempfile source observed manual

    _wadv_make_panel
    save `source'

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) covariates(L) baseline_covariates(bl)
    msm_weight, treat_d_cov(L bl) treat_n_cov(bl) nolog

    keep id period _msm_tw_weight
    rename _msm_tw_weight tw_command
    save `observed'

    use `source', clear
    sort id period

    tempvar at_risk cum_out cum_cens lag_treat first
    bysort id (period): gen int `cum_out' = sum(outcome[_n-1]) if _n > 1
    replace `cum_out' = 0 if missing(`cum_out')
    bysort id (period): gen int `cum_cens' = sum(censored[_n-1]) if _n > 1
    replace `cum_cens' = 0 if missing(`cum_cens')
    gen byte `at_risk' = (`cum_out' == 0 & `cum_cens' == 0)
    bysort id (period): gen byte `first' = (_n == 1)
    bysort id (period): gen byte `lag_treat' = treatment[_n-1]

    tempvar denom_pr denom_complete denom0_pr denom0_complete
    gen byte `denom_complete' = `at_risk' & !`first' & ///
        !missing(treatment, `lag_treat', L, bl, period)
    quietly logit treatment `lag_treat' L bl period if `denom_complete', nolog
    predict double `denom_pr' if `denom_complete', pr

    gen byte `denom0_complete' = `at_risk' & `first' & ///
        !missing(treatment, L, bl)
    quietly logit treatment L bl if `denom0_complete', nolog
    predict double `denom0_pr' if `denom0_complete', pr
    replace `denom_pr' = `denom0_pr' if missing(`denom_pr') & ///
        `at_risk' & `first'

    tempvar numer_pr numer_complete numer0_pr numer0_complete
    gen byte `numer_complete' = `at_risk' & !`first' & ///
        !missing(treatment, `lag_treat', bl)
    quietly logit treatment `lag_treat' bl if `numer_complete', nolog
    predict double `numer_pr' if `numer_complete', pr

    gen byte `numer0_complete' = `at_risk' & `first' & ///
        !missing(treatment, bl)
    quietly logit treatment bl if `numer0_complete', nolog
    predict double `numer0_pr' if `numer0_complete', pr
    replace `numer_pr' = `numer0_pr' if missing(`numer_pr') & ///
        `at_risk' & `first'

    replace `denom_pr' = max(`denom_pr', 0.001) if `at_risk' & !missing(`denom_pr')
    replace `denom_pr' = min(`denom_pr', 0.999) if `at_risk' & !missing(`denom_pr')
    replace `numer_pr' = max(`numer_pr', 0.001) if `at_risk' & !missing(`numer_pr')
    replace `numer_pr' = min(`numer_pr', 0.999) if `at_risk' & !missing(`numer_pr')

    tempvar tw_t miss_tw log_tw cum_log_tw cum_miss_tw
    gen double `tw_t' = 1
    replace `tw_t' = `numer_pr' / `denom_pr' if treatment == 1 & ///
        `at_risk' & !missing(`denom_pr', `numer_pr')
    replace `tw_t' = (1 - `numer_pr') / (1 - `denom_pr') if treatment == 0 & ///
        `at_risk' & !missing(`denom_pr', `numer_pr')

    gen byte `miss_tw' = `at_risk' & ///
        (missing(treatment) | missing(`denom_pr') | missing(`numer_pr'))
    gen double `log_tw' = ln(`tw_t') if `at_risk' & !`miss_tw' & ///
        !missing(`tw_t') & `tw_t' > 0
    replace `log_tw' = 0 if !`at_risk'
    bysort id (period): gen byte `cum_miss_tw' = (sum(`miss_tw') > 0)
    bysort id (period): gen double `cum_log_tw' = sum(`log_tw')
    gen double tw_manual = exp(`cum_log_tw')
    replace tw_manual = . if `cum_miss_tw'

    keep id period tw_manual
    save `manual'

    use `observed', clear
    merge 1:1 id period using `manual', nogenerate
    gen double absdiff = abs(tw_command - tw_manual)
    quietly summarize absdiff, meanonly
    assert r(max) < `tol'
}
if _rc == 0 {
    display as result "  PASS WADV1: manual treatment probabilities match command IPTW"
    local ++pass_count
}
else {
    display as error "  FAIL WADV1: treatment probability alignment (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' WADV1"
}

* --- WADV2: manual censoring probabilities match command IPCW and combined weights ---
*
* SCOPE WARNING -- this is a TRANSCRIPTION CHECK, not an oracle.  The "manual"
* computation below is a line-by-line copy of _msm_weight_censor's algorithm,
* down to the 0.001/0.999 truncation bounds.  It asserts that msm's code agrees
* with a hand-copy of msm's code, so it cannot detect a wrong *convention* --
* only an accidental divergence between the two copies.
*
* It demonstrably could not: it passed for the entire life of finding N05, and
* it went red the moment N05 was FIXED, because it still transcribed the broken
* `outcome == 0' conditioning (2026-07-17, A10).  Updated below to the corrected
* censor-first convention -- see validation_msm_dgp_recovery.do D14, which is the
* actual oracle (forward-simulated, independent of msm's implementation).
*
* Do not read a WADV2 pass as evidence that the IPCW is correct.
local ++test_count
capture noisily {
    tempfile source observed manual

    _wadv_make_panel
    save `source'

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) covariates(L) baseline_covariates(bl)
    msm_weight, treat_d_cov(L bl) treat_n_cov(bl) ///
        censor_d_cov(L bl) censor_n_cov(bl) nolog

    keep id period _msm_cw_weight _msm_tw_weight _msm_weight
    rename _msm_cw_weight cw_command
    rename _msm_tw_weight tw_command
    rename _msm_weight weight_command
    save `observed'

    use `source', clear
    sort id period

    tempvar at_risk cum_out cum_cens
    bysort id (period): gen int `cum_out' = sum(outcome[_n-1]) if _n > 1
    replace `cum_out' = 0 if missing(`cum_out')
    bysort id (period): gen int `cum_cens' = sum(censored[_n-1]) if _n > 1
    replace `cum_cens' = 0 if missing(`cum_cens')
    gen byte `at_risk' = (`cum_out' == 0 & `cum_cens' == 0)

    tempvar denom_pr denom_complete numer_pr numer_complete
    gen byte `denom_complete' = `at_risk' & ///
        !missing(censored, treatment, L, bl, period)
    quietly logit censored treatment L bl period if `denom_complete', nolog
    predict double `denom_pr' if `denom_complete', pr

    gen byte `numer_complete' = `at_risk' & ///
        !missing(censored, treatment, bl)
    quietly logit censored treatment bl if `numer_complete', nolog
    predict double `numer_pr' if `numer_complete', pr

    replace `denom_pr' = max(`denom_pr', 0.001) if `at_risk' & ///
        !missing(`denom_pr')
    replace `denom_pr' = min(`denom_pr', 0.999) if `at_risk' & ///
        !missing(`denom_pr')
    replace `numer_pr' = max(`numer_pr', 0.001) if `at_risk' & ///
        !missing(`numer_pr')
    replace `numer_pr' = min(`numer_pr', 0.999) if `at_risk' & ///
        !missing(`numer_pr')

    tempvar cw_t miss_cw log_cw cum_log_cw cum_miss_cw
    gen double `cw_t' = 1
    replace `cw_t' = (1 - `numer_pr') / (1 - `denom_pr') if ///
        `at_risk' & !missing(`denom_pr', `numer_pr')
    gen byte `miss_cw' = `at_risk' & ///
        (missing(censored) | missing(`denom_pr') | missing(`numer_pr'))
    gen double `log_cw' = ln(`cw_t') if !`miss_cw' & ///
        !missing(`cw_t') & `cw_t' > 0
    replace `log_cw' = 0 if !`at_risk'
    bysort id (period): gen byte `cum_miss_cw' = (sum(`miss_cw') > 0)
    bysort id (period): gen double `cum_log_cw' = sum(`log_cw')
    gen double cw_manual = exp(`cum_log_cw')
    replace cw_manual = . if `cum_miss_cw'

    keep id period cw_manual
    save `manual'

    use `observed', clear
    merge 1:1 id period using `manual', nogenerate
    gen double cw_absdiff = abs(cw_command - cw_manual)
    gen double comb_absdiff = abs(weight_command - tw_command * cw_command)
    quietly summarize cw_absdiff, meanonly
    assert r(max) < `tol'
    quietly summarize comb_absdiff, meanonly
    assert r(max) < `tol'
}
if _rc == 0 {
    display as result "  PASS WADV2: manual censoring probabilities match command IPCW"
    local ++pass_count
}
else {
    display as error "  FAIL WADV2: censoring probability semantics (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' WADV2"
}

* --- WADV3: post-outcome and post-censor rows do not affect fitted weights ---
local ++test_count
capture noisily {
    tempfile source reference

    _wadv_make_panel
    save `source'

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) covariates(L) baseline_covariates(bl)
    msm_weight, treat_d_cov(L bl) treat_n_cov(bl) ///
        censor_d_cov(L bl) censor_n_cov(bl) nolog
    keep id period _msm_weight _msm_tw_weight _msm_cw_weight
    rename _msm_weight ref_weight
    rename _msm_tw_weight ref_tw
    rename _msm_cw_weight ref_cw
    save `reference'

    use `source', clear
    tempvar post_out post_cens
    bysort id (period): gen byte `post_out' = (sum(outcome[_n-1]) >= 1) if _n > 1
    replace `post_out' = 0 if missing(`post_out')
    bysort id (period): gen byte `post_cens' = (sum(censored[_n-1]) >= 1) if _n > 1
    replace `post_cens' = 0 if missing(`post_cens')
    replace L = 99 if `post_out' | `post_cens'
    replace treatment = 1 - treatment if `post_out' | `post_cens'
    replace outcome = 1 if `post_out'
    replace censored = 1 if `post_cens'
    * A row that is both post-outcome and post-censor would be set to an
    * outcome==1 & censored==1 tie; resolve by censor-first (audit A08). These
    * are post-risk rows, so their values cannot affect any at-risk weight --
    * which is exactly what this test asserts.
    replace outcome = 0 if censored == 1

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) covariates(L) baseline_covariates(bl)
    msm_weight, treat_d_cov(L bl) treat_n_cov(bl) ///
        censor_d_cov(L bl) censor_n_cov(bl) nolog

    merge 1:1 id period using `reference', nogenerate
    assert reldif(_msm_weight, ref_weight) < `tol'
    assert reldif(_msm_tw_weight, ref_tw) < `tol'
    assert reldif(_msm_cw_weight, ref_cw) < `tol'
}
if _rc == 0 {
    display as result "  PASS WADV3: post-event rows are excluded from weight models"
    local ++pass_count
}
else {
    display as error "  FAIL WADV3: post-event exclusion invariance (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' WADV3"
}

* --- WADV4: missing current treatment refuses a partial weighting ---
local ++test_count
capture noisily {
    _wadv_make_panel
    replace treatment = . if id == 7 & period == 2

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(L) baseline_covariates(bl)
    capture msm_weight, treat_d_cov(L bl) treat_n_cov(bl) nolog
    assert _rc == 459
    capture confirm variable _msm_tw_weight
    assert _rc != 0
    capture confirm variable _msm_weight
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS WADV4: missing treatment refuses partial weights"
    local ++pass_count
}
else {
    display as error "  FAIL WADV4: missing treatment propagation (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' WADV4"
}

* --- WADV5: missing current censoring refuses a partial weighting ---
local ++test_count
capture noisily {
    _wadv_make_panel
    replace censored = . if id == 8 & period == 2

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) covariates(L) baseline_covariates(bl)
    capture msm_weight, treat_d_cov(L bl) treat_n_cov(bl) ///
        censor_d_cov(L bl) censor_n_cov(bl) nolog
    assert _rc == 459
    foreach _v in _msm_cw_weight _msm_tw_weight _msm_weight {
        capture confirm variable `_v'
        assert _rc != 0
    }
}
if _rc == 0 {
    display as result "  PASS WADV5: missing censoring refuses partial weights"
    local ++pass_count
}
else {
    display as error "  FAIL WADV5: missing censoring propagation (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' WADV5"
}

* --- WADV6: truncation returns match exact percentile caps ---
local ++test_count
capture noisily {
    tempfile source untruncated

    _wadv_make_panel
    save `source'

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) covariates(L) baseline_covariates(bl)
    msm_weight, treat_d_cov(L bl) treat_n_cov(bl) ///
        censor_d_cov(L bl) censor_n_cov(bl) nolog

    * Truncation cutoffs are computed on the risk set only (audit A11): the
    * percentiles, the truncated count, and the caps are all defined over
    * _msm_decision_risk, so this oracle mirrors the corrected implementation.
    _pctile _msm_weight if _msm_decision_risk & !missing(_msm_weight), percentiles(10 90)
    local lo = r(r1)
    local hi = r(r2)
    quietly count if _msm_decision_risk & _msm_weight < `lo' & !missing(_msm_weight)
    local n_lo = r(N)
    quietly count if _msm_decision_risk & _msm_weight > `hi' & !missing(_msm_weight)
    local n_hi = r(N)
    local n_expected = `n_lo' + `n_hi'

    keep id period _msm_weight _msm_decision_risk
    rename _msm_weight untruncated_weight
    rename _msm_decision_risk untrunc_risk
    save `untruncated'

    use `source', clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) covariates(L) baseline_covariates(bl)
    msm_weight, treat_d_cov(L bl) treat_n_cov(bl) ///
        censor_d_cov(L bl) censor_n_cov(bl) truncate(10 90) nolog

    assert r(n_truncated) == `n_expected'
    assert abs(r(min_weight) - `lo') < `tol'
    assert abs(r(max_weight) - `hi') < `tol'

    merge 1:1 id period using `untruncated', nogenerate
    * caps apply to risk-set rows only; post-risk rows keep their carry-forward
    gen double expected_weight = untruncated_weight
    replace expected_weight = `lo' if untrunc_risk & expected_weight < `lo' & !missing(expected_weight)
    replace expected_weight = `hi' if untrunc_risk & expected_weight > `hi' & !missing(expected_weight)
    assert reldif(_msm_weight, expected_weight) < `tol' if !missing(expected_weight)
}
if _rc == 0 {
    display as result "  PASS WADV6: truncation counts and caps match percentiles"
    local ++pass_count
}
else {
    display as error "  FAIL WADV6: truncation return/cap correctness (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' WADV6"
}

* --- WADV7: uneven follow-up is accepted when everyone shares baseline ---
local ++test_count
capture noisily {
    _wadv_make_panel
    drop if mod(id, 5) == 0 & period == 4
    drop if mod(id, 7) == 0 & period >= 3

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) covariates(L) baseline_covariates(bl)
    msm_weight, treat_d_cov(L bl) treat_n_cov(bl) ///
        censor_d_cov(L bl) censor_n_cov(bl) nolog

    local weight_var "`r(weight_var)'"
    local treat_d_cov "`r(treat_d_cov)'"
    local treat_n_cov "`r(treat_n_cov)'"
    local censor_d_cov "`r(censor_d_cov)'"
    local censor_n_cov "`r(censor_n_cov)'"

    confirm variable _msm_weight
    quietly count if missing(_msm_weight)
    assert r(N) == 0
    quietly summarize _msm_weight
    assert r(min) > 0
    assert "`weight_var'" == "_msm_weight"
    assert "`treat_d_cov'" == "L bl"
    assert "`treat_n_cov'" == "bl"
    assert "`censor_d_cov'" == "L bl"
    assert "`censor_n_cov'" == "bl"
}
if _rc == 0 {
    display as result "  PASS WADV7: uneven panels with common baseline are weighted"
    local ++pass_count
}
else {
    display as error "  FAIL WADV7: uneven common-baseline panel (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' WADV7"
}

* --- WADV8: representative combined-weight snapshot stays fixed ---
*
* RE-BASELINED 2026-07-17 (finding N05, fixed under A10).  The previous snapshot
* pinned the pre-fix censoring weights, so it pinned WRONG values; it is exactly
* the kind of golden test that turns a defect into a "regression" the moment the
* defect is repaired.  Re-baselining is only defensible because the new values
* were independently established correct -- see validation_msm_dgp_recovery.do
* D14 (forward-sim oracle, two censoring strengths) and the N05 mechanism probe
* (0/5483 event rows frozen, was 1744/1744).  It is NOT defensible on the grounds
* that the suite went green.
*
* Corroboration that the change is scoped to the IPCW and nothing else: every
* _msm_tw_weight value below is UNCHANGED to all 16 digits (0.9974944973378391,
* 0.6359360121111731, 1.2602290650067010).  Only _msm_cw_weight, _msm_weight and
* the truncation/ESS summaries moved.  If a future edit shifts a tw value here,
* it has touched the treatment path and is out of scope for an IPCW change.
local ++test_count
capture noisily {
    _wadv_make_panel

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) covariates(L) baseline_covariates(bl)
    msm_weight, treat_d_cov(L bl) treat_n_cov(bl) ///
        censor_d_cov(L bl) censor_n_cov(bl) truncate(10 90) nolog

    local n_truncated = r(n_truncated)
    local mean_weight = r(mean_weight)
    local min_weight = r(min_weight)
    local max_weight = r(max_weight)
    local ess = r(ess)
    local repairs = r(n_probability_repairs)

    * RE-BASELINED 2026-07-17 (audit A11, Phase 2).  The truncation cutoffs, the
    * truncated count, and the mean/min/max/ESS summaries are now computed on the
    * risk set (_msm_decision_risk) instead of every row, so post-event/post-
    * censor carry-forward rows no longer distort them.  This panel keeps all 5
    * periods per id, so it HAS post-risk rows and these aggregates moved.  The
    * new values are independently established by WADV6 above (percentile oracle
    * over _msm_decision_risk) and by test_msm_phase2.do's A11 invariance test
    * (appended post-risk rows leave every at-risk result bit-for-bit identical),
    * NOT because the suite went green.  Scope check: every _msm_tw_weight value
    * below is unchanged to 16 digits -- A11 touched only the truncation/ESS
    * masking, not the treatment path.
    assert `n_truncated' == 148
    assert abs(`mean_weight' - 0.9519584850978235) < `tol'
    assert abs(`min_weight' - 0.5015873965291691) < `tol'
    assert abs(`max_weight' - 1.5877987839354910) < `tol'
    assert abs(`ess' - 664.5545548970006) < `tol'
    assert `repairs' == 0

    assert abs(_msm_tw_weight - 0.9974944973378391) < `tol' if id == 1 & period == 0
    assert abs(_msm_cw_weight - 0.9884290360399728) < `tol' if id == 1 & period == 0
    assert abs(_msm_weight - 0.9859525244588175) < `tol' if id == 1 & period == 0
    assert abs(_msm_tw_weight - 0.6359360121111731) < `tol' if id == 1 & period == 4
    assert abs(_msm_cw_weight - 1.0782693449893961) < `tol' if id == 1 & period == 4
    assert abs(_msm_weight - 0.6857103072342833) < `tol' if id == 1 & period == 4
    assert abs(_msm_tw_weight - 1.2602290650067010) < `tol' if id == 7 & period == 2
    assert abs(_msm_cw_weight - 0.9839382408073766) < `tol' if id == 7 & period == 2
    assert abs(_msm_weight - 1.2399875692370184) < `tol' if id == 7 & period == 2
    * These two rows sit at the lower truncation cap, which moved with the
    * risk-set-based percentiles (0.5203556059080199 -> 0.5015873965291691).
    assert abs(_msm_weight - 0.5015873965291691) < `tol' if id == 25 & period == 3
    assert abs(_msm_weight - 0.5015873965291691) < `tol' if id == 101 & period == 4
}
if _rc == 0 {
    display as result "  PASS WADV8: representative combined-weight snapshot"
    local ++pass_count
}
else {
    display as error "  FAIL WADV8: representative combined-weight snapshot (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' WADV8"
}

display as text ""
display as text "{hline 72}"
display as text "Tests run: " as result `test_count'
display as text "Passed:    " as result `pass_count'
display as text "Failed:    " as result `fail_count'
display as text "RESULT: test_msm_weight_adversarial tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    display as text "{hline 72}"
    exit 459
}
display as result "All msm_weight adversarial semantic tests passed"
display as text "{hline 72}"
