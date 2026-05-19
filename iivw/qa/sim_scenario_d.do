clear all
version 17.0
set varabbrev off, perm
set linesize 250
set more off
*IIVW Simulation Scenario D
*Tim Copeland
*#Notes
/*
Scenario D: heterogeneous and saturating measurement artifact. Sensitivity
analysis extending Scenario C with two complications:
  (a) Individual-specific random learning rates: artifact coefficient
      drawn from N(1.5, 0.5^2), truncated at 0.
  (b) Saturating artifact: no additional increment beyond the 6th test.

Otherwise the DGP matches Scenario C in sim_scenarios_abc.do. Treatment
confounded by conf_ti and u_i, informative visit process, true treatment
effect = 0.5, artifact = coef * log(min(test_n, 6) + 1).

Usage:
  do iivw/qa/sim_scenario_d.do              QA gate (fewer reps)
  do iivw/qa/sim_scenario_d.do manuscript   Full 1000 replications
*/
**#Globals
{
args mode
if "`mode'" == "" local mode "qa"
if !inlist("`mode'", "qa", "manuscript") {
    display as error "mode must be qa or manuscript"
    exit 198
}

global dt 2026_05_19
global working "`c(pwd)'"
cd "$working"

if "`mode'" == "manuscript" {
    local n_sims     = 1000
    local n_subjects = 500
}
else {
    local n_sims     = 50
    local n_subjects = 200
}
local true_beta     = 0.5
local max_visits    = 15
local artifact_mean = 1.5
local artifact_sd   = 0.5
local artifact_cap  = 6
local min_success   = floor(0.80 * `n_sims')
local max_abs_bias  = 3
}
**#Programs
{
*Install iivw from the local package directory (qa runs from iivw/qa/)
local pkg_dir "`c(pwd)'/.."
capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

*Simulation DGP
capture program drop _sim_generate_d
program define _sim_generate_d
    args sim_n n_sub max_vis true_b art_mean art_sd art_cap

    clear
    set obs `n_sub'
    gen long id = _n
    set seed `=20260518 + `sim_n''

    gen double conf_ti = rnormal(0, 1)
    gen double u_i = rnormal(0, 1)
    gen byte treatment = (runiform() < invlogit(-0.3 + 0.4 * conf_ti + 0.5 * u_i))
    bysort id: replace treatment = treatment[1]
    gen double artifact_coef = max(0, rnormal(`art_mean', `art_sd'))

    expand `max_vis'
    bysort id: gen int visit_n = _n
    bysort id (visit_n): replace conf_ti = conf_ti[1]
    bysort id (visit_n): replace treatment = treatment[1]
    bysort id (visit_n): replace u_i = u_i[1]
    bysort id (visit_n): replace artifact_coef = artifact_coef[1]

    gen double months = (visit_n - 1) * 2.5 + runiform()
    replace months = 0 if visit_n == 1
    gen double conf_tv = 0.5 * u_i + rnormal(0, 0.7)

    *Informative visit process (matches Scenario C)
    gen double lp = -1.2 + 0.6 * treatment + 0.7 * u_i + 0.3 * conf_tv
    gen double visit_prob = invlogit(lp)
    gen byte keep_visit = (runiform() < visit_prob) | visit_n == 1
    keep if keep_visit == 1
    drop lp visit_prob keep_visit

    bysort id (months): gen int test_number = _n

    gen double y_true = 10 + `true_b' * treatment ///
        + 0.3 * conf_ti + 0.2 * conf_tv ///
        + 0.8 * u_i ///
        + 0.05 * months + rnormal(0, 1)

    *Saturating artifact with heterogeneous learning rates
    gen int test_capped = min(test_number, `art_cap')
    gen double artifact = artifact_coef * log(test_capped + 1)
    gen double y_obs = y_true + artifact

    bysort id: gen int n_obs = _N
    drop if n_obs < 2
    drop n_obs
end
}
**#Simulation
{
display _n as result "Scenario D"

capture postclose results
postfile results int(sim) str25(estimator) double(beta se coverage) ///
    using "sim_results_d.dta", replace

forvalues s = 1/`n_sims' {
    if mod(`s', 100) == 0 display "  Replication `s' / `n_sims'"
    quietly {
        _sim_generate_d `s' `n_subjects' `max_visits' `true_beta' ///
            `artifact_mean' `artifact_sd' `artifact_cap'

        gen double tx_time = treatment * months

        *Unweighted GEE
        capture glm y_obs treatment months tx_time conf_ti, ///
            family(gaussian) link(identity) vce(cluster id)
        if _rc == 0 {
            local b = _b[treatment]
            local se_val = _se[treatment]
            local cov = (`b' - 1.96*`se_val' <= `true_beta') & ///
                (`b' + 1.96*`se_val' >= `true_beta')
            post results (`s') ("Unweighted") (`b') (`se_val') (`cov')
        }

        *IIW-weighted GEE
        capture iivw_weight, id(id) time(months) ///
            visit_cov(u_i conf_tv) wtype(iivw) ///
            truncate(1 99) nolog replace
        if _rc == 0 {
            capture iivw_fit y_obs treatment conf_ti, ///
                model(gee) timespec(linear) interaction(treatment) ///
                nolog replace
            if _rc == 0 {
                local b = _b[treatment]
                local se_val = _se[treatment]
                local cov = (`b' - 1.96*`se_val' <= `true_beta') & ///
                    (`b' + 1.96*`se_val' >= `true_beta')
                post results (`s') ("IIW") (`b') (`se_val') (`cov')
            }
        }

        *FIPTIW-weighted GEE
        capture iivw_weight, id(id) time(months) ///
            visit_cov(u_i conf_tv) ///
            treat(treatment) treat_cov(conf_ti u_i) ///
            truncate(1 99) nolog replace
        if _rc == 0 {
            capture iivw_fit y_obs treatment conf_ti, ///
                model(gee) timespec(linear) interaction(treatment) ///
                nolog replace
            if _rc == 0 {
                local b = _b[treatment]
                local se_val = _se[treatment]
                local cov = (`b' - 1.96*`se_val' <= `true_beta') & ///
                    (`b' + 1.96*`se_val' >= `true_beta')
                post results (`s') ("FIPTIW") (`b') (`se_val') (`cov')
            }
        }

        *FIPTIW + cumulative test count
        capture iivw_weight, id(id) time(months) ///
            visit_cov(u_i conf_tv) ///
            treat(treatment) treat_cov(conf_ti u_i) ///
            truncate(1 99) nolog replace
        if _rc == 0 {
            capture iivw_fit y_obs treatment test_number conf_ti, ///
                model(gee) timespec(linear) interaction(treatment) ///
                nolog replace
            if _rc == 0 {
                local b = _b[treatment]
                local se_val = _se[treatment]
                local cov = (`b' - 1.96*`se_val' <= `true_beta') & ///
                    (`b' + 1.96*`se_val' >= `true_beta')
                post results (`s') ("FIPTIW + test count") ///
                    (`b') (`se_val') (`cov')
            }
        }
    }
}
postclose results

use "sim_results_d.dta", clear
foreach est in "Unweighted" "IIW" "FIPTIW" "FIPTIW + test count" {
    quietly count if estimator == "`est'"
    if r(N) < `min_success' {
        display as error "Scenario D `est': " r(N) ///
            " reps (need `min_success')"
        exit 9
    }
}

collapse (mean) mean_beta=beta mean_se=se mean_coverage=coverage ///
    (sd) sd_beta=beta, by(estimator)
gen double bias = mean_beta - `true_beta'
format mean_beta bias mean_se sd_beta %8.4f
format mean_coverage %6.3f

display _n "Scenario D (`mode' mode): N=`n_subjects', reps=`n_sims', true beta=`true_beta'"
display "  Artifact coef ~ N(`artifact_mean', `artifact_sd'^2), truncated at 0"
display "  Artifact saturates at test `artifact_cap'"

list estimator mean_beta bias sd_beta mean_coverage, noobs clean

quietly count if abs(bias) > `max_abs_bias'
if r(N) > 0 {
    display as error "Scenario D: |bias| > `max_abs_bias'"
    exit 9
}
erase "sim_results_d.dta"

capture program drop _sim_generate_d
display as result "RESULT: sim_scenario_d estimators=4 reps=`n_sims'"
}
