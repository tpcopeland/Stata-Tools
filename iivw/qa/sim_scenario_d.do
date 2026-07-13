clear all
version 17.0
set varabbrev off
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

*Gate tolerances, set from an observed qa-mode run (50 reps, N=200), not guessed:
*   Unweighted           bias 0.495  coverage 0.38
*   IIW                  bias 0.427  coverage 0.48
*   FIPTIW               bias 0.107  coverage 0.96
*   FIPTIW + test count  bias 0.131  coverage 0.98
*MC SE of each mean is sd_beta/sqrt(reps) ~ 0.02-0.03, so FIPTIW's ~0.11 residual
*under the heterogeneous saturating artifact is systematic, not noise. Bounded
*recovery gate, as in sim_scenarios_abc.do. IIW alone is not gated on recovery:
*it does not target the treatment confounding induced by latent u_i.
local min_naive_bias  = 0.20
local max_fiptiw_bias = 0.20
local max_bias_share  = 0.40
local max_naive_cov   = 0.80
local min_cov_gap     = 0.25
local iiw_slack       = 0.05
}
**#Programs
{
*Install iivw from the local package directory (qa runs from iivw/qa/)
local pkg_dir "`c(pwd)'/.."
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
        capture iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
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
        capture iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
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
        capture iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
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

**## Convergence
foreach est in "Unweighted" "IIW" "FIPTIW" "FIPTIW + test count" {
    quietly count if estimator == "`est'"
    local n_conv = r(N)
    local ok = (`n_conv' >= `min_success')
    _sim_assert `ok', msg("Scenario D `est': `n_conv'/`n_sims' reps converged (need `min_success')")
}

collapse (mean) mean_beta=beta mean_se=se mean_coverage=coverage ///
    (sd) sd_beta=beta, by(estimator)
gen double bias = mean_beta - `true_beta'
gen double mc_se = sd_beta / sqrt(`n_sims')
format mean_beta bias mean_se sd_beta mc_se %8.4f
format mean_coverage %6.3f

display _n "Scenario D (`mode' mode): N=`n_subjects', reps=`n_sims', true beta=`true_beta'"
display "  Artifact coef ~ N(`artifact_mean', `artifact_sd'^2), truncated at 0"
display "  Artifact saturates at test `artifact_cap'"

list estimator mean_beta bias sd_beta mc_se mean_coverage, noobs clean

**## Correctness gates
quietly summarize bias if estimator == "Unweighted", meanonly
local bias_unw = r(mean)
quietly summarize mean_coverage if estimator == "Unweighted", meanonly
local cov_unw = r(mean)
quietly summarize bias if estimator == "IIW", meanonly
local bias_iiw = r(mean)
quietly summarize bias if estimator == "FIPTIW", meanonly
local bias_fip = r(mean)
quietly summarize mean_coverage if estimator == "FIPTIW", meanonly
local cov_fip = r(mean)
quietly summarize bias if estimator == "FIPTIW + test count", meanonly
local bias_fiptc = r(mean)

*Format once into plain locals: nesting double quotes inside msg() would break
*Stata's option parser.
local s_unw   = string(abs(`bias_unw'), "%6.3f")
local s_iiw   = string(abs(`bias_iiw'), "%6.3f")
local s_fip   = string(abs(`bias_fip'), "%6.3f")
local s_fiptc = string(abs(`bias_fiptc'), "%6.3f")
local s_cunw  = string(`cov_unw', "%5.3f")
local s_gap   = string(`cov_fip' - `cov_unw', "%5.3f")
local s_share = string(100 * abs(`bias_fip') / abs(`bias_unw'), "%4.1f")
local pct_cut = 100 * (1 - `max_bias_share')

*The scenario must bite before any correction can be credited.
local ok = !missing(`bias_unw') & abs(`bias_unw') > `min_naive_bias'
_sim_assert `ok', msg("Scenario D: unweighted GEE misses truth (|bias|=`s_unw' > `min_naive_bias')")

local ok = !missing(`cov_unw') & `cov_unw' < `max_naive_cov'
_sim_assert `ok', msg("Scenario D: unweighted coverage degraded (`s_cunw' < `max_naive_cov')")

local ok = !missing(`bias_fip') & abs(`bias_fip') < `max_fiptiw_bias'
_sim_assert `ok', msg("Scenario D: FIPTIW recovers truth (|bias|=`s_fip' < `max_fiptiw_bias')")

local ok = !missing(`bias_fip') & !missing(`bias_unw') & abs(`bias_fip') < `max_bias_share' * abs(`bias_unw')
_sim_assert `ok', msg("Scenario D: FIPTIW removes >`pct_cut'% of naive bias (`s_share'% remains)")

local ok = !missing(`cov_fip') & !missing(`cov_unw') & (`cov_fip' - `cov_unw') > `min_cov_gap'
_sim_assert `ok', msg("Scenario D: FIPTIW coverage beats unweighted by >`min_cov_gap' (gap=`s_gap')")

local ok = !missing(`bias_fiptc') & abs(`bias_fiptc') < `max_fiptiw_bias'
_sim_assert `ok', msg("Scenario D: FIPTIW + test count recovers truth (|bias|=`s_fiptc' < `max_fiptiw_bias')")

*IIW alone cannot remove treatment confounding, but must not be worse than nothing.
local ok = !missing(`bias_iiw') & !missing(`bias_unw') & abs(`bias_iiw') <= abs(`bias_unw') + `iiw_slack'
_sim_assert `ok', msg("Scenario D: IIW no worse than unweighted (|bias| `s_iiw' <= `s_unw' + `iiw_slack')")

erase "sim_results_d.dta"

capture program drop _sim_generate_d
capture program drop _sim_assert

**# Summary
display as result "RESULT: sim_scenario_d tests=${SIM_TESTS} pass=${SIM_PASS} fail=${SIM_FAIL}"
if ${SIM_FAIL} > 0 {
    display as error "SOME SIMULATION GATES FAILED"
    macro drop SIM_TESTS SIM_PASS SIM_FAIL
    exit 1
}
display as result "ALL SIMULATION GATES PASSED"
macro drop SIM_TESTS SIM_PASS SIM_FAIL
}
