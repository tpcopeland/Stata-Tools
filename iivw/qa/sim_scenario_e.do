clear all
version 17.0
set varabbrev off
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

*Scenario E is a DOCUMENTED FAILURE MODE, not a recovery scenario. The artifact
*is outcome-dependent (headroom multiplier), so it is not separable from the
*outcome trajectory, and test_number is nearly collinear with follow-up time.
*Observed qa-mode run (50 reps, N=200), truth: marginal 0.10, contrast 0.50:
*                        marginal bias / cov      contrast bias / cov
*   Unweighted              +0.269 / 0.00           -0.169 / 0.12
*   IIW                     +0.219 / 0.00           -0.143 / 0.30
*   FIPTIW                  +0.215 / 0.00           -0.126 / 0.46
*   FIPTIW + test count     -0.340 / 0.00           -0.224 / 0.00
*No estimator recovers, and adjusting for the (time-collinear) test count drives
*the marginal slope to the WRONG SIGN. That is the breakdown this scenario
*exists to demonstrate. The gates below therefore assert (a) the stress bites,
*(b) the artifact-share diagnostic flags it, and (c) no estimator blows up past
*a documented envelope. They are deliberately NOT recovery gates -- writing one
*here would encode a claim the method does not make.
local min_naive_bias  = 0.15
local max_naive_cov   = 0.50
local max_bias_env    = 0.50
local min_share_mean  = 0.50
}
**# Programs
{
*Install iivw from the local package directory (qa runs from iivw/qa/)
local pkg_dir "`c(pwd)'/.."
* Sysdir sandbox (Q3): keep this suite's net install out of the user's real
* ado tree even when the suite is run standalone, outside run_all.
do "`c(pwd)'/_iivw_qa_common.do"
iivw_qa_sandbox, pkgdir("`pkg_dir'")

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

*Assertion helper. Counters are globals so the program can bump the caller's
*totals from inside the gate block.
global SIM_TESTS = 0
global SIM_PASS  = 0
global SIM_FAIL  = 0

capture program drop _sim_assert
program define _sim_assert
    syntax anything(name=ok), MSG(string)
    global SIM_TESTS = ${SIM_TESTS} + 1
    if `ok' {
        display as result "  PASS: `msg'"
        global SIM_PASS = ${SIM_PASS} + 1
    }
    else {
        display as error "  FAIL: `msg'"
        global SIM_FAIL = ${SIM_FAIL} + 1
    }
end

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
        capture iivw_weight, endatlastvisit baseline(event) id(id) time(ftime) ///
            visit_cov(u_i conf_tv) wtype(iivw) ///
            truncfinal(1 99) nolog replace
        if _rc == 0 {
            capture iivw_fit y_obs treatment ftime tx_time conf_ti, vce(fixed) ///
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
        capture iivw_weight, endatlastvisit baseline(event) id(id) time(ftime) ///
            visit_cov(u_i conf_tv) ///
            treat(treatment) treat_cov(conf_ti u_i) ///
            truncfinal(1 99) nolog replace
        if _rc == 0 {
            capture iivw_fit y_obs treatment ftime tx_time conf_ti, vce(fixed) ///
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
        capture iivw_weight, endatlastvisit baseline(event) id(id) time(ftime) ///
            visit_cov(u_i conf_tv) ///
            treat(treatment) treat_cov(conf_ti u_i) ///
            truncfinal(1 99) nolog replace
        if _rc == 0 {
            gen double log_test_number = log(test_number + 1)
            capture iivw_fit y_obs treatment ftime tx_time log_test_number conf_ti, vce(fixed) ///
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

**## Convergence
foreach est in "Unweighted" "IIW" "FIPTIW" "FIPTIW + test count" {
    foreach estimand in "marginal" "contrast" {
        quietly count if estimator == "`est'" & estimand == "`estimand'"
        local n_conv = r(N)
        local ok = (`n_conv' >= `min_success')
        _sim_assert `ok', msg("Scenario E `est' `estimand': `n_conv'/`n_sims' reps converged (need `min_success')")
    }
}

preserve
    collapse (mean) mean_beta=beta mean_se=se mean_coverage=coverage ///
        (sd) sd_beta=beta, by(estimator estimand)
    gen double truth = cond(estimand == "marginal", ///
        `true_marginal', `true_contrast')
    gen double bias = mean_beta - truth
    gen double mc_se = sd_beta / sqrt(`n_sims')
    format mean_beta bias mean_se sd_beta mc_se %8.4f
    format mean_coverage %6.3f

    display _n "Scenario E (`mode' mode): N=`n_subjects', reps=`n_sims'"
    display "  Artifact coef ~ N(`artifact_mean', `artifact_sd'^2), truncated at 0"
    display "  Artifact saturates at test `artifact_cap'; headroom ceiling=`y_ceiling'"
    display "  Truth: marginal slope=`true_marginal', contrast slope=`true_contrast'"

    list estimator estimand mean_beta bias sd_beta mc_se mean_coverage, noobs clean

    **## Stress gates (see header: E is a documented failure mode, not a recovery scenario)
    *The outcome-dependent artifact must actually bite the naive estimator,
    *otherwise the scenario proves nothing about the decomposition's limits.
    quietly summarize bias if estimator == "Unweighted" & estimand == "marginal", meanonly
    local bias_unw_marg = r(mean)
    quietly summarize mean_coverage if estimator == "Unweighted" & estimand == "marginal", meanonly
    local cov_unw_marg = r(mean)

    local s_unw_marg = string(abs(`bias_unw_marg'), "%6.3f")
    local s_cov_marg = string(`cov_unw_marg', "%5.3f")

    local ok = !missing(`bias_unw_marg') & abs(`bias_unw_marg') > `min_naive_bias'
    _sim_assert `ok', msg("Scenario E: outcome-dependent artifact biases the naive marginal slope (|bias|=`s_unw_marg' > `min_naive_bias')")

    local ok = !missing(`cov_unw_marg') & `cov_unw_marg' < `max_naive_cov'
    _sim_assert `ok', msg("Scenario E: naive marginal coverage collapses (`s_cov_marg' < `max_naive_cov')")

    *No estimator may blow up past the documented envelope. This catches a
    *behavioural regression without pretending any of them recover the truth.
    quietly count if abs(bias) > `max_bias_env'
    local n_blowup = r(N)
    local ok = (`n_blowup' == 0)
    _sim_assert `ok', msg("Scenario E: all estimator/estimand |bias| within documented envelope `max_bias_env' (`n_blowup' outside)")
restore

**## Artifact-share diagnostic
quietly count if estimator == "FIPTIW + test count" & ///
    estimand == "marginal" & !missing(artifact_share)
local n_share = r(N)
local ok = (`n_share' >= `min_success')
_sim_assert `ok', msg("Scenario E: artifact-share diagnostic available in `n_share'/`n_sims' reps (need `min_success')")
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

local s_pct   = string(`pct_in_range', "%5.1f")
local s_share = string(`mean_share', "%6.3f")

*artifact_share is a proportion: every replication must report it inside [0,1].
local ok = (`pct_in_range' == 100)
_sim_assert `ok', msg("Scenario E: artifact_share within [0,1] in every rep (`s_pct'%)")

*The diagnostic must actually flag the heavy artifact this DGP injects.
local ok = !missing(`mean_share') & `mean_share' > `min_share_mean'
_sim_assert `ok', msg("Scenario E: artifact-share diagnostic flags a dominant artifact (mean=`s_share' > `min_share_mean')")

erase "sim_results_e.dta"

capture program drop _sim_generate_e
capture program drop _sim_assert

**# Summary
display as result "RESULT: sim_scenario_e tests=${SIM_TESTS} pass=${SIM_PASS} fail=${SIM_FAIL}"
if ${SIM_FAIL} > 0 {
    display as error "SOME SIMULATION GATES FAILED"
    macro drop SIM_TESTS SIM_PASS SIM_FAIL
    exit 1
}
display as result "ALL SIMULATION GATES PASSED"
macro drop SIM_TESTS SIM_PASS SIM_FAIL
}
