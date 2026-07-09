clear all
version 17.0
set varabbrev off
set linesize 250
set more off
*IIVW Simulation Scenarios A, B, C
*Tim Copeland
*#Notes
/*
Three simulation scenarios from the IIVW manuscript (Section 4, Table 2):
  A: Pure sampling bias (informative visits, no artifact)
  B: Pure measurement artifact (protocol-driven visits, artifact present)
  C: Both mechanisms (informative visits + artifact)

DGP. N subjects, binary treatment confounded by conf_ti (observed,
included in the outcome model) and u_i (latent, NOT in the outcome
model). u_i drives visit frequency in A and C and enters the outcome,
creating confounding bias that standard regression cannot remove.
IIW addresses visit-frequency overrepresentation; u_i enters the visit
model through conf_tv as a proxy. FIPTIW adds IPTW for treatment
confounding; treat_cov includes conf_ti and u_i. Scenario B has
protocol-driven visits with no u_i dependence; artifact adds
1.5 * log(test_n + 1) to each measurement.

Usage:
  do iivw/qa/sim_scenarios_abc.do              QA gate (fewer reps)
  do iivw/qa/sim_scenarios_abc.do manuscript   Full 1000 replications
  do iivw/qa/sim_scenarios_abc.do A            Single scenario, QA mode
*/
**#Globals
{
args mode
if "`mode'" == "" local mode "qa"
if !inlist("`mode'", "qa", "manuscript", "A", "B", "C") {
    display as error "mode must be qa, manuscript, A, B, or C"
    exit 198
}

local run_A = inlist("`mode'", "qa", "manuscript", "A")
local run_B = inlist("`mode'", "qa", "manuscript", "B")
local run_C = inlist("`mode'", "qa", "manuscript", "C")

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
local true_beta    = 0.5
local max_visits   = 15
local artifact_mag = 1.5
local min_success  = floor(0.80 * `n_sims')

*Gate tolerances, set from observed qa-mode runs (50 reps, N=200), not guessed:
*                    A       B       C
*   Unweighted   0.340   0.481   0.439   (coverage 0.52 / 0.18 / 0.34)
*   IIW          0.304   0.477   0.382
*   FIPTIW       0.021   0.089   0.082   (coverage 0.98 / 0.98 / 0.94)
*   FIPTIW+test      -   0.105   0.083
*The Monte Carlo SE of each mean is sd_beta/sqrt(reps) ~ 0.02, so FIPTIW's
*residual under an artifact (B, C) is a systematic 4-5 SE effect, not noise.
*These are therefore BOUNDED recovery gates: the naive estimator must miss, the
*weighted estimator must remove most of that bias, and the confirmed residual
*must stay inside the envelope. IIW alone is deliberately NOT gated on recovery:
*it targets visit-process bias, not the treatment confounding induced by latent
*u_i, so it is expected to remain biased here (0.30-0.48 above).
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
*totals from inside the scenario loop.
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
capture program drop _sim_generate
program define _sim_generate
    args sim_n scenario n_sub max_vis true_b art_mag

    clear
    set obs `n_sub'
    gen long id = _n
    set seed `=20260518 + `sim_n''

    gen double conf_ti = rnormal(0, 1)
    gen double u_i = rnormal(0, 1)
    gen byte treatment = (runiform() < invlogit(-0.3 + 0.4 * conf_ti + 0.5 * u_i))
    bysort id: replace treatment = treatment[1]

    expand `max_vis'
    bysort id: gen int visit_n = _n
    bysort id (visit_n): replace conf_ti = conf_ti[1]
    bysort id (visit_n): replace treatment = treatment[1]
    bysort id (visit_n): replace u_i = u_i[1]

    gen double months = (visit_n - 1) * 2.5 + runiform()
    replace months = 0 if visit_n == 1
    gen double conf_tv = 0.5 * u_i + rnormal(0, 0.7)

    if "`scenario'" == "A" | "`scenario'" == "C" {
        gen double lp = -1.2 + 0.6 * treatment + 0.7 * u_i + 0.3 * conf_tv
        gen double visit_prob = invlogit(lp)
        gen byte keep_visit = (runiform() < visit_prob) | visit_n == 1
    }
    else {
        gen double visit_prob = invlogit(-0.5 + 0.6 * treatment)
        gen byte keep_visit = (runiform() < visit_prob) | visit_n == 1
    }
    keep if keep_visit == 1
    capture drop lp visit_prob keep_visit

    bysort id (months): gen int test_number = _n

    gen double y_true = 10 + `true_b' * treatment ///
        + 0.3 * conf_ti + 0.2 * conf_tv ///
        + 0.8 * u_i ///
        + 0.05 * months + rnormal(0, 1)

    if "`scenario'" == "B" | "`scenario'" == "C" {
        gen double artifact = `art_mag' * log(test_number + 1)
        gen double y_obs = y_true + artifact
    }
    else {
        gen double y_obs = y_true
        gen double artifact = 0
    }

    bysort id: gen int n_obs = _N
    drop if n_obs < 2
    drop n_obs
end
}
**#Simulation
{
foreach scenario in A B C {

    if "`scenario'" == "A" & !`run_A' continue
    if "`scenario'" == "B" & !`run_B' continue
    if "`scenario'" == "C" & !`run_C' continue

    local has_artifact = ("`scenario'" == "B" | "`scenario'" == "C")

    display _n as result "Scenario `scenario'"

    capture postclose results
    postfile results int(sim) str25(estimator) double(beta se coverage) ///
        using "sim_results_abc_`scenario'.dta", replace

    forvalues s = 1/`n_sims' {
        if mod(`s', 100) == 0 display "  Replication `s' / `n_sims'"
        quietly {
            _sim_generate `s' `scenario' `n_subjects' `max_visits' ///
                `true_beta' `artifact_mag'

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
            if `has_artifact' {
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
    }
    postclose results

    use "sim_results_abc_`scenario'.dta", clear

    **## Convergence
    foreach est in "Unweighted" "IIW" "FIPTIW" {
        quietly count if estimator == "`est'"
        local n_conv = r(N)
        local ok = (`n_conv' >= `min_success')
        _sim_assert `ok', msg("Scenario `scenario' `est': `n_conv'/`n_sims' reps converged (need `min_success')")
    }
    if `has_artifact' {
        quietly count if estimator == "FIPTIW + test count"
        local n_conv = r(N)
        local ok = (`n_conv' >= `min_success')
        _sim_assert `ok', msg("Scenario `scenario' FIPTIW + test count: `n_conv'/`n_sims' reps converged (need `min_success')")
    }

    collapse (mean) mean_beta=beta mean_se=se mean_coverage=coverage ///
        (sd) sd_beta=beta, by(estimator)
    gen double bias = mean_beta - `true_beta'
    gen double mc_se = sd_beta / sqrt(`n_sims')
    format mean_beta bias mean_se sd_beta mc_se %8.4f
    format mean_coverage %6.3f

    display _n "Scenario `scenario': N=`n_subjects', reps=`n_sims', true beta=`true_beta'"
    if "`scenario'" == "A" display "  DGP: Informative visits, no artifact"
    if "`scenario'" == "B" display "  DGP: Protocol-driven visits, artifact = `artifact_mag' * log(n + 1)"
    if "`scenario'" == "C" display "  DGP: Informative visits + artifact"

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

    *The scenario must bite: an unadjusted GEE has to miss the truth, otherwise
    *nothing downstream proves the estimator fixed anything.
    local ok = !missing(`bias_unw') & abs(`bias_unw') > `min_naive_bias'
    _sim_assert `ok', msg("Scenario `scenario': unweighted GEE misses truth (|bias|=`=string(abs(`bias_unw'),"%6.3f")' > `min_naive_bias')")

    local ok = !missing(`cov_unw') & `cov_unw' < `max_naive_cov'
    _sim_assert `ok', msg("Scenario `scenario': unweighted coverage degraded (`=string(`cov_unw',"%5.3f")' < `max_naive_cov')")

    *FIPTIW targets both mechanisms and must land inside the confirmed envelope.
    local ok = !missing(`bias_fip') & abs(`bias_fip') < `max_fiptiw_bias'
    _sim_assert `ok', msg("Scenario `scenario': FIPTIW recovers truth (|bias|=`=string(abs(`bias_fip'),"%6.3f")' < `max_fiptiw_bias')")

    local ok = !missing(`bias_fip') & !missing(`bias_unw') & abs(`bias_fip') < `max_bias_share' * abs(`bias_unw')
    _sim_assert `ok', msg("Scenario `scenario': FIPTIW removes >`=100*(1-`max_bias_share')'% of naive bias (`=string(100*abs(`bias_fip')/abs(`bias_unw'),"%4.1f")'% remains)")

    local ok = !missing(`cov_fip') & !missing(`cov_unw') & (`cov_fip' - `cov_unw') > `min_cov_gap'
    _sim_assert `ok', msg("Scenario `scenario': FIPTIW coverage beats unweighted by >`min_cov_gap' (`=string(`cov_fip'-`cov_unw',"%5.3f")')")

    *IIW alone cannot remove treatment confounding, but weighting must never make
    *the point estimate materially worse than doing nothing.
    local ok = !missing(`bias_iiw') & !missing(`bias_unw') & abs(`bias_iiw') <= abs(`bias_unw') + `iiw_slack'
    _sim_assert `ok', msg("Scenario `scenario': IIW no worse than unweighted (|bias| `=string(abs(`bias_iiw'),"%6.3f")' <= `=string(abs(`bias_unw'),"%6.3f")' + `iiw_slack')")

    if `has_artifact' {
        quietly summarize bias if estimator == "FIPTIW + test count", meanonly
        local bias_fiptc = r(mean)
        local ok = !missing(`bias_fiptc') & abs(`bias_fiptc') < `max_fiptiw_bias'
        _sim_assert `ok', msg("Scenario `scenario': FIPTIW + test count recovers truth (|bias|=`=string(abs(`bias_fiptc'),"%6.3f")' < `max_fiptiw_bias')")
    }

    erase "sim_results_abc_`scenario'.dta"
}

capture program drop _sim_generate
capture program drop _sim_assert

**# Summary
display _n as text "Scenarios run at reps=`n_sims', N=`n_subjects'"
display as result "RESULT: sim_scenarios_abc tests=${SIM_TESTS} pass=${SIM_PASS} fail=${SIM_FAIL}"
if ${SIM_FAIL} > 0 {
    display as error "SOME SIMULATION GATES FAILED"
    macro drop SIM_TESTS SIM_PASS SIM_FAIL
    exit 1
}
display as result "ALL SIMULATION GATES PASSED"
macro drop SIM_TESTS SIM_PASS SIM_FAIL
}
