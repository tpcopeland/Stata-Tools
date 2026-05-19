clear all
version 17.0
set varabbrev off, perm
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
local max_abs_bias = 3
}
**#Programs
{
*Install iivw from the local package directory (qa runs from iivw/qa/)
local pkg_dir "`c(pwd)'/.."
capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

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

    foreach est in "Unweighted" "IIW" "FIPTIW" {
        quietly count if estimator == "`est'"
        if r(N) < `min_success' {
            display as error "Scenario `scenario' `est': " r(N) ///
                " reps (need `min_success')"
            exit 9
        }
    }
    if `has_artifact' {
        quietly count if estimator == "FIPTIW + test count"
        if r(N) < `min_success' {
            display as error "Scenario `scenario' FIPTIW+test: " r(N) ///
                " reps (need `min_success')"
            exit 9
        }
    }

    collapse (mean) mean_beta=beta mean_se=se mean_coverage=coverage ///
        (sd) sd_beta=beta, by(estimator)
    gen double bias = mean_beta - `true_beta'
    format mean_beta bias mean_se sd_beta %8.4f
    format mean_coverage %6.3f

    display _n "Scenario `scenario': N=`n_subjects', reps=`n_sims', true beta=`true_beta'"
    if "`scenario'" == "A" display "  DGP: Informative visits, no artifact"
    if "`scenario'" == "B" display "  DGP: Protocol-driven visits, artifact = `artifact_mag' * log(n + 1)"
    if "`scenario'" == "C" display "  DGP: Informative visits + artifact"

    list estimator mean_beta bias sd_beta mean_coverage, noobs clean

    quietly count if abs(bias) > `max_abs_bias'
    if r(N) > 0 {
        display as error "Scenario `scenario': |bias| > `max_abs_bias'"
        exit 9
    }
    erase "sim_results_abc_`scenario'.dta"
}

capture program drop _sim_generate
display _n as result "RESULT: sim_scenarios_abc reps=`n_sims'"
}
