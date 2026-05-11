clear all
set more off
version 16.0
set varabbrev off

* sim_scenario_d.do — Scenario D: Heterogeneous and saturating artifact
*
* Extends the three primary simulation scenarios (A–C) in the iivw manuscript
* with a sensitivity check: individual-specific random learning rates and a
* saturating practice effect that plateaus after the 6th test.
*
* DGP matches Scenario C (both sampling bias and measurement artifact) except:
*   (a) artifact coefficient is subject-specific: drawn from N(1.5, 0.5^2),
*       truncated at 0 to prevent negative practice effects
*   (b) artifact saturates: no additional increment beyond the 6th test
*
* Usage:
*   do iivw/qa/sim_scenario_d.do
*
* Output:
*   Displays mean beta, bias, and coverage for each of four estimators
*   across 1000 replications.
*
* See: iivw_manuscript_2026_05_11_v08.md, Section 4.7

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

* === Parameters ===
local n_sims     = 1000
local n_subjects = 500
local true_beta  = 0.5
local max_visits = 12
local artifact_mean = 1.5
local artifact_sd   = 0.5
local artifact_cap  = 6

* === Storage ===
tempname results
postfile `results' int(sim) str20(estimator) double(beta se coverage) ///
    using "sim_d_results.dta", replace

* === Simulation loop ===
forvalues s = 1/`n_sims' {
    if mod(`s', 100) == 0 display "  Replication `s' / `n_sims'"
    quietly {
        clear
        set obs `n_subjects'
        gen long id = _n
        set seed `=20260511 + `s''

        * Subject-level attributes
        gen byte treatment = (runiform() < invlogit(-0.5 + 0.3 * rnormal()))
        gen double conf_ti = rnormal(0, 1)
        * Individual artifact coefficient: N(1.5, 0.5^2), truncated at 0
        gen double artifact_coef = max(0, rnormal(`artifact_mean', `artifact_sd'))

        * Expand to panel
        expand `max_visits'
        bysort id: gen int visit_n = _n
        bysort id (visit_n): replace conf_ti = conf_ti[1]
        bysort id (visit_n): replace treatment = treatment[1]
        bysort id (visit_n): replace artifact_coef = artifact_coef[1]

        * Time and time-varying confounder
        gen double months = (visit_n - 1) * 3 + runiform() * 1.5
        replace months = 0 if visit_n == 1
        gen double conf_tv = rnormal(0, 1)

        * Visit process (outcome-dependent, as in Scenario C)
        * Keep visits with probability depending on treatment and confounders
        gen double visit_prob = invlogit(-0.5 + 0.4 * treatment ///
            + 0.3 * conf_ti + 0.2 * conf_tv)
        gen byte keep_visit = (runiform() < visit_prob) | visit_n == 1
        keep if keep_visit == 1

        * Cumulative test number
        bysort id (months): gen int test_number = _n

        * True outcome (linear model, true treatment effect = 0.5)
        gen double y_true = 10 + `true_beta' * treatment ///
            + 0.3 * conf_ti + 0.2 * conf_tv ///
            + 0.05 * months + rnormal(0, 1)

        * Saturating artifact: cap at artifact_cap tests
        gen int test_capped = min(test_number, `artifact_cap')
        gen double artifact = artifact_coef * log(test_capped + 1)

        * Observed outcome = true + artifact
        gen double y_obs = y_true + artifact

        * Ensure at least 2 obs per subject
        bysort id: gen int n_obs = _N
        drop if n_obs < 2

        * --- Estimator 1: Unweighted GEE ---
        gen double tx_time = treatment * months
        capture glm y_obs treatment months tx_time conf_ti, ///
            family(gaussian) link(identity) vce(cluster id)
        if _rc == 0 {
            local b1 = _b[treatment]
            local se1 = _se[treatment]
            local cov1 = (`b1' - 1.96*`se1' <= `true_beta') & ///
                (`b1' + 1.96*`se1' >= `true_beta')
            post `results' (`s') ("Unweighted") (`b1') (`se1') (`cov1')
        }

        * --- Estimator 2: IIW-weighted GEE ---
        capture iivw_weight, id(id) time(months) ///
            visit_cov(conf_ti conf_tv) wtype(iivw) ///
            truncate(1 99) nolog replace
        if _rc == 0 {
            capture iivw_fit y_obs treatment conf_ti, ///
                model(gee) timespec(linear) interaction(treatment) ///
                nolog replace
            if _rc == 0 {
                local b2 = _b[treatment]
                local se2 = _se[treatment]
                local cov2 = (`b2' - 1.96*`se2' <= `true_beta') & ///
                    (`b2' + 1.96*`se2' >= `true_beta')
                post `results' (`s') ("IIW") (`b2') (`se2') (`cov2')
            }
        }

        * --- Estimator 3: FIPTIW-weighted GEE ---
        capture iivw_weight, id(id) time(months) ///
            visit_cov(conf_ti conf_tv) ///
            treat(treatment) treat_cov(conf_ti) ///
            truncate(1 99) nolog replace
        if _rc == 0 {
            capture iivw_fit y_obs treatment conf_ti, ///
                model(gee) timespec(linear) interaction(treatment) ///
                nolog replace
            if _rc == 0 {
                local b3 = _b[treatment]
                local se3 = _se[treatment]
                local cov3 = (`b3' - 1.96*`se3' <= `true_beta') & ///
                    (`b3' + 1.96*`se3' >= `true_beta')
                post `results' (`s') ("FIPTIW") (`b3') (`se3') (`cov3')
            }
        }

        * --- Estimator 4: FIPTIW + test count ---
        capture iivw_weight, id(id) time(months) ///
            visit_cov(conf_ti conf_tv) ///
            treat(treatment) treat_cov(conf_ti) ///
            truncate(1 99) nolog replace
        if _rc == 0 {
            capture iivw_fit y_obs treatment test_number conf_ti, ///
                model(gee) timespec(linear) interaction(treatment) ///
                nolog replace
            if _rc == 0 {
                local b4 = _b[treatment]
                local se4 = _se[treatment]
                local cov4 = (`b4' - 1.96*`se4' <= `true_beta') & ///
                    (`b4' + 1.96*`se4' >= `true_beta')
                post `results' (`s') ("FIPTIW + test count") (`b4') (`se4') (`cov4')
            }
        }
    }
}
postclose `results'

* === Summarize ===
use "sim_d_results.dta", clear
display _n "{hline 72}"
display "Scenario D: Heterogeneous and Saturating Artifact"
display "  N subjects = `n_subjects', N replications = `n_sims'"
display "  True beta = `true_beta'"
display "  Artifact coef ~ N(`artifact_mean', `artifact_sd'^2), truncated at 0"
display "  Artifact saturates at test `artifact_cap'"
display "{hline 72}"

collapse (mean) mean_beta=beta mean_se=se mean_coverage=coverage ///
    (sd) sd_beta=beta, by(estimator)
gen double bias = mean_beta - `true_beta'
format mean_beta bias mean_se sd_beta %8.4f
format mean_coverage %6.3f

list estimator mean_beta bias sd_beta mean_coverage, noobs clean

capture erase "sim_d_results.dta"
