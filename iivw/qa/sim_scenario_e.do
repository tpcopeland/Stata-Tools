clear all
version 17.0
set varabbrev off, perm
set linesize 250
set more off
*IIVW Simulation Scenario E
*Tim Copeland
*#Notes
/*
Scenario E: outcome-dependent measurement artifact. Sensitivity analysis
extending Scenario D with a headroom interaction:

    artifact = artifact_coef * log(min(test_n, cap) + 1) * headroom_multiplier

The multiplier depends on the latent true outcome, so the measurement
artifact is no longer separable from the outcome trajectory. This stresses
the additive sampling/artifact decomposition used by iivw_diagnose.

Usage:
  do iivw/qa/sim_scenario_e.do              QA gate (fewer reps)
  do iivw/qa/sim_scenario_e.do manuscript   Full 1000 replications
*/
**# Globals
{
args mode
if "`mode'" == "" local mode "qa"
if !inlist("`mode'", "qa", "manuscript") {
    display as error "mode must be qa or manuscript"
    exit 198
}

global dt 2026_05_24
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
local true_marginal = 0.10
local true_contrast = 0.50
local true_treat    = 0.50
local max_visits    = 15
local y_ceiling     = 16
local artifact_mean = 0.6
local artifact_sd   = 0.2
local artifact_cap  = 6
local min_success   = floor(0.80 * `n_sims')
local max_abs_bias  = 3
}
**# Programs
{
*Install iivw from the local package directory (qa runs from iivw/qa/)
local pkg_dir "`c(pwd)'/.."
capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

*Simulation DGP
capture program drop _sim_generate_e
program define _sim_generate_e
    args sim_n n_sub max_vis true_treat true_marg true_cont art_mean ///
        art_sd art_cap y_ceiling

    clear
    set obs `n_sub'
    gen long id = _n
    set seed `=20260524 + `sim_n''

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
    gen double ftime = months / 10
    gen double conf_tv = 0.5 * u_i + rnormal(0, 0.7)

    *Informative visit process (matches Scenario C/D)
    gen double lp = -1.2 + 0.6 * treatment + 0.7 * u_i + 0.3 * conf_tv
    gen double visit_prob = invlogit(lp)
    gen byte keep_visit = (runiform() < visit_prob) | visit_n == 1
    keep if keep_visit == 1
    drop lp visit_prob keep_visit

    bysort id (ftime): gen int test_number = _n
    gen double tx_time = treatment * ftime

    gen double y_true = 10 + `true_treat' * treatment ///
        + `true_marg' * ftime + `true_cont' * tx_time ///
        + 0.3 * conf_ti + 0.2 * conf_tv ///
        + 0.8 * u_i + rnormal(0, 1)

    *Outcome-dependent, saturating artifact with heterogeneous learning rates
    gen int test_capped = min(test_number, `art_cap')
    gen double base_artifact = artifact_coef * log(test_capped + 1)
    gen double headroom = max(0, `y_ceiling' - y_true)
    quietly summarize headroom
    gen double headroom_mult = headroom / r(mean)
    replace headroom_mult = max(0.25, min(1.75, headroom_mult))
    gen double artifact = base_artifact * headroom_mult
    gen double y_obs = y_true + artifact

    bysort id: gen int n_obs = _N
    drop if n_obs < 2
    drop n_obs
end
}
**# Simulation
{
display _n as result "Scenario E"

capture postclose results
postfile results int(sim) str25(estimator) str10(estimand) ///
    double(beta se coverage artifact_share) using "sim_results_e.dta", replace

forvalues s = 1/`n_sims' {
    if mod(`s', 100) == 0 display "  Replication `s' / `n_sims'"
    quietly {
        _sim_generate_e `s' `n_subjects' `max_visits' `true_treat' ///
            `true_marginal' `true_contrast' `artifact_mean' ///
            `artifact_sd' `artifact_cap' `y_ceiling'

        local b_unw_marg = .
        local b_w_marg = .
        local b_adj_marg = .

        *Unweighted GEE
        capture glm y_obs treatment ftime tx_time conf_ti, ///
            family(gaussian) link(identity) vce(cluster id)
        if _rc == 0 {
            local b_unw_marg = _b[ftime]
            local se_val = _se[ftime]
            local cov = (`b_unw_marg' - 1.96*`se_val' <= `true_marginal') & ///
                (`b_unw_marg' + 1.96*`se_val' >= `true_marginal')
            post results (`s') ("Unweighted") ("marginal") ///
                (`b_unw_marg') (`se_val') (`cov') (.)

            local b = _b[tx_time]
            local se_val = _se[tx_time]
            local cov = (`b' - 1.96*`se_val' <= `true_contrast') & ///
                (`b' + 1.96*`se_val' >= `true_contrast')
            post results (`s') ("Unweighted") ("contrast") ///
                (`b') (`se_val') (`cov') (.)
        }

        *IIW-weighted GEE
        capture iivw_weight, id(id) time(ftime) ///
            visit_cov(u_i conf_tv) wtype(iivw) ///
            truncate(1 99) nolog replace
        if _rc == 0 {
            capture iivw_fit y_obs treatment ftime tx_time conf_ti, ///
                model(gee) timespec(none) nolog replace
            if _rc == 0 {
                local b = _b[ftime]
                local se_val = _se[ftime]
                local cov = (`b' - 1.96*`se_val' <= `true_marginal') & ///
                    (`b' + 1.96*`se_val' >= `true_marginal')
                post results (`s') ("IIW") ("marginal") ///
                    (`b') (`se_val') (`cov') (.)

                local b = _b[tx_time]
                local se_val = _se[tx_time]
                local cov = (`b' - 1.96*`se_val' <= `true_contrast') & ///
                    (`b' + 1.96*`se_val' >= `true_contrast')
                post results (`s') ("IIW") ("contrast") ///
                    (`b') (`se_val') (`cov') (.)
            }
        }

        *FIPTIW-weighted GEE
        capture iivw_weight, id(id) time(ftime) ///
            visit_cov(u_i conf_tv) ///
            treat(treatment) treat_cov(conf_ti u_i) ///
            truncate(1 99) nolog replace
        if _rc == 0 {
            capture iivw_fit y_obs treatment ftime tx_time conf_ti, ///
                model(gee) timespec(none) nolog replace
            if _rc == 0 {
                local b_w_marg = _b[ftime]
                local se_val = _se[ftime]
                local cov = (`b_w_marg' - 1.96*`se_val' <= `true_marginal') & ///
                    (`b_w_marg' + 1.96*`se_val' >= `true_marginal')
                post results (`s') ("FIPTIW") ("marginal") ///
                    (`b_w_marg') (`se_val') (`cov') (.)

                local b = _b[tx_time]
                local se_val = _se[tx_time]
                local cov = (`b' - 1.96*`se_val' <= `true_contrast') & ///
                    (`b' + 1.96*`se_val' >= `true_contrast')
                post results (`s') ("FIPTIW") ("contrast") ///
                    (`b') (`se_val') (`cov') (.)
            }
        }

        *FIPTIW + cumulative test count
        capture iivw_weight, id(id) time(ftime) ///
            visit_cov(u_i conf_tv) ///
            treat(treatment) treat_cov(conf_ti u_i) ///
            truncate(1 99) nolog replace
        if _rc == 0 {
            gen double log_test_number = log(test_number + 1)
            capture iivw_fit y_obs treatment ftime tx_time log_test_number conf_ti, ///
                model(gee) timespec(none) nolog replace
            if _rc == 0 {
                local b_adj_marg = _b[ftime]
                local se_val = _se[ftime]
                local cov = (`b_adj_marg' - 1.96*`se_val' <= `true_marginal') & ///
                    (`b_adj_marg' + 1.96*`se_val' >= `true_marginal')

                local share = .
                if abs(`b_unw_marg' - `b_adj_marg') >= 1e-8 {
                    local share = (`b_w_marg' - `b_adj_marg') / ///
                        (`b_unw_marg' - `b_adj_marg')
                }

                post results (`s') ("FIPTIW + test count") ("marginal") ///
                    (`b_adj_marg') (`se_val') (`cov') (`share')

                local b = _b[tx_time]
                local se_val = _se[tx_time]
                local cov = (`b' - 1.96*`se_val' <= `true_contrast') & ///
                    (`b' + 1.96*`se_val' >= `true_contrast')
                post results (`s') ("FIPTIW + test count") ("contrast") ///
                    (`b') (`se_val') (`cov') (.)
            }
        }
    }
}
postclose results

use "sim_results_e.dta", clear
foreach est in "Unweighted" "IIW" "FIPTIW" "FIPTIW + test count" {
    foreach estimand in "marginal" "contrast" {
        quietly count if estimator == "`est'" & estimand == "`estimand'"
        if r(N) < `min_success' {
            display as error "Scenario E `est' `estimand': " r(N) ///
                " reps (need `min_success')"
            exit 9
        }
    }
}

preserve
    collapse (mean) mean_beta=beta mean_se=se mean_coverage=coverage ///
        (sd) sd_beta=beta, by(estimator estimand)
    gen double truth = cond(estimand == "marginal", ///
        `true_marginal', `true_contrast')
    gen double bias = mean_beta - truth
    format mean_beta bias mean_se sd_beta %8.4f
    format mean_coverage %6.3f

    display _n "Scenario E (`mode' mode): N=`n_subjects', reps=`n_sims'"
    display "  Artifact coef ~ N(`artifact_mean', `artifact_sd'^2), truncated at 0"
    display "  Artifact saturates at test `artifact_cap'; headroom ceiling=`y_ceiling'"
    display "  Truth: marginal slope=`true_marginal', contrast slope=`true_contrast'"

    list estimator estimand mean_beta bias sd_beta mean_coverage, noobs clean

    quietly count if abs(bias) > `max_abs_bias'
    if r(N) > 0 {
        display as error "Scenario E: |bias| > `max_abs_bias'"
        exit 9
    }
restore

quietly count if estimator == "FIPTIW + test count" & ///
    estimand == "marginal" & !missing(artifact_share)
if r(N) < `min_success' {
    display as error "Scenario E: insufficient artifact-share diagnostics"
    exit 9
}
gen byte share_in_0_1 = inrange(artifact_share, 0, 1) ///
    if estimator == "FIPTIW + test count" & estimand == "marginal" & ///
    !missing(artifact_share)
quietly summarize artifact_share if estimator == "FIPTIW + test count" & ///
    estimand == "marginal"
local mean_share = r(mean)
quietly summarize share_in_0_1 if estimator == "FIPTIW + test count" & ///
    estimand == "marginal"
local pct_in_range = 100 * r(mean)
display _n as text "Scenario E robustness diagnostic"
display as text "  Mean artifact share: " as result %8.4f `mean_share'
display as text "  Share in [0,1]:      " as result %6.1f `pct_in_range' "%"

erase "sim_results_e.dta"

capture program drop _sim_generate_e
display as result "RESULT: sim_scenario_e estimators=4 estimands=2 reps=`n_sims'"
}
