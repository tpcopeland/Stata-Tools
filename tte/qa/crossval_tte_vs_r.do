* crossval_tte_vs_r.do — Cross-validation: Stata tte vs R TrialEmulation
*
* Runs 3 TTE configurations on the trial_example dataset and compares
* treatment coefficients, robust SEs, and risk differences at t=10
* against results from R's TrialEmulation package.
*
* Prerequisites: Run the companion R script first to generate benchmarks:
*   cd tte/qa && Rscript 01_r_analysis.R
*
* Produces: crossval_tte_vs_r.xlsx with the comparison table
*
* R TrialEmulation reference (Maringe et al. 2024, arXiv:2402.12083)
*   uses the trial_example dataset (503 patients, 48,400 person-periods).
*
* Known algorithmic differences (NOTE* status expected):
*   1. Weight model: R uses 4 strata (arm x lag_treat), Stata uses 2 (arm)
*   2. Robust SE: R uses sandwich::vcovCL (HC1), Stata uses vce(cluster)
*   3. Spline knots: R uses ns() boundary knots, Stata uses Harrell RCS
*   Risk differences converge despite these differences.
*
* Run: stata-mp -b do crossval_tte_vs_r.do

version 16.0
set varabbrev off
set more off
clear all
set seed 12345

* --- Paths ---
* All files are self-contained within tte/qa/
local pkg_dir "/home/tpcopeland/Stata-Tools/tte"
local qa_dir "`pkg_dir'/qa"
local datadir "`qa_dir'/data"
local rdir    "`qa_dir'/r_results"
local outfile "`qa_dir'/crossval_tte_vs_r.xlsx"

* --- Setup adopath ---
capture ado uninstall tte
adopath ++ "`pkg_dir'"

* --- Verify R results exist ---
capture confirm file "`rdir'/config1_itt_coefs.csv"
if _rc != 0 {
    display as error "R results not found in `rdir'."
    display as error "Run 01_r_analysis.R first."
    exit 601
}

display _newline
display _dup(72) "="
display "Cross-Validation: Stata tte vs R TrialEmulation"
display _dup(72) "="

* --- Load and prepare data ---
import delimited using "`datadir'/trial_example.csv", clear case(preserve)
display "Dataset: " _N " person-periods, " as result "503" as text " patients"

local outcome_covs "catvarA catvarB nvarA nvarB nvarC"
local switch_covs "nvarA nvarB"

tempfile prepared_data
save `prepared_data'

* =====================================================================
* CONFIG 1: ITT, quadratic, no weights
* =====================================================================
display _newline "CONFIG 1: ITT, quadratic time, no weights"

use `prepared_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(`switch_covs') estimand(ITT)
tte_expand
tte_fit, outcome_cov(`outcome_covs') ///
    followup_spec(quadratic) trial_period_spec(quadratic) nolog

local c1_coef = _b[_tte_arm]
local c1_se   = _se[_tte_arm]

tte_predict, times(0(1)30) type(cum_inc) difference samples(100) seed(12345)
matrix c1_pred = r(predictions)
local c1_rd10 = c1_pred[11, 8]

display "  Coef: " %9.6f `c1_coef' "  SE: " %9.6f `c1_se' "  RD(10): " %9.6f `c1_rd10'

* =====================================================================
* CONFIG 2: PP, quadratic, stabilized IPTW
* =====================================================================
display _newline "CONFIG 2: PP, quadratic time, stabilized IPTW"

use `prepared_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(`switch_covs') estimand(PP)
tte_expand
tte_weight, switch_d_cov(`switch_covs') switch_n_cov(`switch_covs') ///
    stabilized nolog
tte_fit, outcome_cov(`outcome_covs') ///
    followup_spec(quadratic) trial_period_spec(quadratic) nolog

local c2_coef = _b[_tte_arm]
local c2_se   = _se[_tte_arm]

tte_predict, times(0(1)30) type(cum_inc) difference samples(100) seed(12345)
matrix c2_pred = r(predictions)
local c2_rd10 = c2_pred[11, 8]

display "  Coef: " %9.6f `c2_coef' "  SE: " %9.6f `c2_se' "  RD(10): " %9.6f `c2_rd10'

* =====================================================================
* CONFIG 3: PP, quadratic, stabilized + truncated (1/99)
* =====================================================================
display _newline "CONFIG 3: PP, quadratic, stabilized + truncated 1/99"

use `prepared_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(`switch_covs') estimand(PP)
tte_expand
tte_weight, switch_d_cov(`switch_covs') switch_n_cov(`switch_covs') ///
    stabilized truncate(1 99) nolog
tte_fit, outcome_cov(`outcome_covs') ///
    followup_spec(quadratic) trial_period_spec(quadratic) nolog

local c3_coef = _b[_tte_arm]
local c3_se   = _se[_tte_arm]

tte_predict, times(0(1)30) type(cum_inc) difference samples(100) seed(12345)
matrix c3_pred = r(predictions)
local c3_rd10 = c3_pred[11, 8]

display "  Coef: " %9.6f `c3_coef' "  SE: " %9.6f `c3_se' "  RD(10): " %9.6f `c3_rd10'

* =====================================================================
* LOAD R RESULTS
* =====================================================================

* Config 1
preserve
import delimited using "`rdir'/config1_itt_coefs.csv", clear
quietly {
    local r1_coef = estimate[2]
    local r1_se   = robust_se[2]
}
restore

preserve
import delimited using "`rdir'/config1_itt_predictions.csv", clear
quietly local r1_rd10 = risk_diff[11]
restore

* Config 2
preserve
import delimited using "`rdir'/config2_pp_coefs.csv", clear
quietly {
    local r2_coef = estimate[2]
    local r2_se   = robust_se[2]
}
restore

preserve
import delimited using "`rdir'/config2_pp_predictions.csv", clear
quietly local r2_rd10 = risk_diff[11]
restore

* Config 3
preserve
import delimited using "`rdir'/config3_pp_trunc_coefs.csv", clear
quietly {
    local r3_coef = estimate[2]
    local r3_se   = robust_se[2]
}
restore

preserve
import delimited using "`rdir'/config3_pp_trunc_predictions.csv", clear
quietly local r3_rd10 = risk_diff[11]
restore

* =====================================================================
* COMPARISON TABLE AND STATUS
* =====================================================================

* Tolerances
local tol1_coef = 0.02
local tol1_se   = 0.01
local tol1_rd   = 0.005
local tol23_coef = 0.15
local tol23_se   = 0.15
local tol23_rd   = 0.05

* Build results dataset (9 rows: 3 configs x 3 metrics)
clear
set obs 9
gen str8 config = ""
gen str20 metric = ""
gen double r_value = .
gen double stata_value = .

local row = 0

foreach cfg in 1 2 3 {
    foreach met in coef se rd10 {
        local ++row
        if "`met'" == "coef" local metric_label "Treatment coef"
        if "`met'" == "se"   local metric_label "Robust SE"
        if "`met'" == "rd10" local metric_label "Risk diff (t=10)"

        if "`cfg'" == "1" local config_label "1-ITT"
        if "`cfg'" == "2" local config_label "2-PP"
        if "`cfg'" == "3" local config_label "3-PP-T"

        local r_val = `r`cfg'_`met''
        local s_val = `c`cfg'_`met''

        quietly replace config = "`config_label'" in `row'
        quietly replace metric = "`metric_label'" in `row'
        quietly replace r_value = `r_val' in `row'
        quietly replace stata_value = `s_val' in `row'
    }
}

gen double diff = abs(r_value - stata_value)

* Determine status
gen str6 status = ""
* Config 1 tolerances (tight)
replace status = "PASS" if config == "1-ITT" & metric == "Treatment coef" & diff <= `tol1_coef'
replace status = "FAIL" if config == "1-ITT" & metric == "Treatment coef" & diff > `tol1_coef'
replace status = "PASS" if config == "1-ITT" & metric == "Robust SE" & diff <= `tol1_se'
replace status = "FAIL" if config == "1-ITT" & metric == "Robust SE" & diff > `tol1_se'
replace status = "PASS" if config == "1-ITT" & metric == "Risk diff (t=10)" & diff <= `tol1_rd'
replace status = "FAIL" if config == "1-ITT" & metric == "Risk diff (t=10)" & diff > `tol1_rd'
* Config 2-3 tolerances (wider, expected diffs)
replace status = "NOTE*" if inlist(config, "2-PP", "3-PP-T") & diff <= `tol23_coef' & metric == "Treatment coef"
replace status = "FAIL"  if inlist(config, "2-PP", "3-PP-T") & diff > `tol23_coef' & metric == "Treatment coef"
replace status = "NOTE*" if inlist(config, "2-PP", "3-PP-T") & diff <= `tol23_se' & metric == "Robust SE"
replace status = "FAIL"  if inlist(config, "2-PP", "3-PP-T") & diff > `tol23_se' & metric == "Robust SE"
replace status = "NOTE*" if inlist(config, "2-PP", "3-PP-T") & diff <= `tol23_rd' & metric == "Risk diff (t=10)"
replace status = "FAIL"  if inlist(config, "2-PP", "3-PP-T") & diff > `tol23_rd' & metric == "Risk diff (t=10)"

* Display
display _newline
display _dup(72) "="
display "CROSS-VALIDATION COMPARISON TABLE"
display _dup(72) "="

display %8s "Config" "  " %20s "Metric" "  " %12s "R Value" "  " %12s "Stata Value" "  " %10s "Diff" "  " %8s "Status"
display _dup(76) "-"

forvalues i = 1/`=_N' {
    display %8s config[`i'] "  " %20s metric[`i'] ///
        "  " %12.6f r_value[`i'] "  " %12.6f stata_value[`i'] ///
        "  " %10.6f diff[`i'] "  " %8s status[`i']
    if mod(`i', 3) == 0 & `i' < _N {
        display _dup(76) "-"
    }
}

* Summary counts
quietly count if status == "PASS"
local n_pass = r(N)
quietly count if status == "NOTE*"
local n_note = r(N)
quietly count if status == "FAIL"
local n_fail = r(N)

display _dup(76) "-"
display "PASS: `n_pass'  NOTE: `n_note'  FAIL: `n_fail'"

if `n_fail' == 0 {
    display as result "OVERALL: ALL COMPARISONS WITHIN TOLERANCE"
}
else {
    display as error "OVERALL: `n_fail' COMPARISON(S) EXCEEDED TOLERANCE"
}

* =====================================================================
* EXPORT TO XLSX
* =====================================================================

capture erase "`outfile'"
quietly {
    putexcel set "`outfile'", sheet("Cross-Validation") replace

    * Title
    putexcel A1 = "Cross-Validation: Stata tte vs R TrialEmulation"
    putexcel A2 = "Dataset: trial_example (503 patients, 48,400 person-periods)"
    putexcel A3 = "Date: `c(current_date)'"

    * Header row
    putexcel A5 = "Config" B5 = "Metric" C5 = "R Value" ///
        D5 = "Stata Value" E5 = "Diff" F5 = "Status"

    * Data rows
    forvalues i = 1/`=_N' {
        local r = `i' + 5
        putexcel A`r' = config[`i']
        putexcel B`r' = metric[`i']
        putexcel C`r' = r_value[`i'], nformat(#0.000000)
        putexcel D`r' = stata_value[`i'], nformat(#0.000000)
        putexcel E`r' = diff[`i'], nformat(#0.000000)
        putexcel F`r' = status[`i']
    }

    * Summary row
    local sr = _N + 7
    putexcel A`sr' = "Summary"
    putexcel B`sr' = "PASS: `n_pass'  NOTE: `n_note'  FAIL: `n_fail'"

    local nr = `sr' + 2
    putexcel A`nr' = "NOTE* = within tolerance; expected diffs due to:"
    local ++nr
    putexcel A`nr' = "  1. Weight model: R 4 strata (arm x lag_treat), Stata 2 strata (arm)"
    local ++nr
    putexcel A`nr' = "  2. Robust SE: R sandwich::vcovCL (HC1), Stata vce(cluster)"
    local ++nr
    putexcel A`nr' = "  3. Risk differences converge despite coefficient differences"

    putexcel save
}

display _newline "Results exported to `outfile'"
