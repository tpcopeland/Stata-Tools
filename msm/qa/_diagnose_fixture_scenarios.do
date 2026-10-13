* _diagnose_fixture_scenarios.do
*
* Shared setup for the msm_diagnose 1.4.12 fixture. _make_diagnose_fixture.do
* ran these scenarios under msm 1.4.12 (git HEAD before 2.0.0) and wrote
* data/diagnose_fixture_1412.mmat; test_msm_diagnose_fixture.do runs them under
* the current package and requires the retained returns to be bit-identical.
*
* Usage: do _diagnose_fixture_scenarios.do <pkg_dir>  (defines _dfx_setup)

version 16.0

capture program drop _dfx_setup
program define _dfx_setup
    version 16.0
    syntax , scenario(integer) pkgdir(string)

    use "`pkgdir'/msm_example.dta", clear
    if `scenario' == 1 {
        * Demo specification: IPTW x IPCW, truncation, default covariates.
        quietly msm_prepare, id(id) period(period) treatment(treatment) ///
            outcome(outcome) censor(censored) ///
            covariates(biomarker comorbidity) baseline_covariates(age sex)
        quietly msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
            treat_n_cov(age sex) censor_d_cov(biomarker comorbidity age sex) ///
            censor_n_cov(age sex) truncate(1 99) nolog
        c_local dfx_opts ""
    }
    else if `scenario' == 2 {
        * Explicit covariate order, a strict positivity floor that fires, and
        * post-event rows appended outside the decision risk set.
        quietly {
            bysort id (period): gen byte _ev = sum(outcome)
            by id: gen byte _first_ev = outcome == 1 & _ev == 1
            expand 3 if _first_ev, generate(_dup)
            bysort id (period _dup): replace period = period[_n-1] + 1 if _dup
            replace outcome = 1 if _dup
            drop _ev _first_ev _dup
        }
        quietly msm_prepare, id(id) period(period) treatment(treatment) ///
            outcome(outcome) covariates(biomarker comorbidity) ///
            baseline_covariates(age sex)
        quietly msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
            treat_n_cov(age sex) nolog
        c_local dfx_opts "balance_covariates(sex comorbidity biomarker) positivity(0.2) threshold(0.05)"
    }
    else if `scenario' == 3 {
        * No numerator covariates (every covariate is a balance target),
        * censoring weights, untruncated.
        quietly msm_prepare, id(id) period(period) treatment(treatment) ///
            outcome(outcome) censor(censored) ///
            covariates(biomarker comorbidity) baseline_covariates(age sex)
        quietly msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
            censor_d_cov(biomarker comorbidity) nolog
        c_local dfx_opts "balance_covariates(age biomarker)"
    }
    else {
        display as error "unknown scenario `scenario'"
        exit 198
    }
end
