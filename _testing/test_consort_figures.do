/*******************************************************************************
* test_consort_figures.do
*
* Purpose: Generate CONSORT diagrams with all option combinations for visual
*          inspection. This tests figure export functionality thoroughly.
*
* Prerequisites:
*   - consort.ado must be installed/accessible
*   - Python 3 with matplotlib
*
* Output:
*   - Multiple PNG files in _testing/figures/consort/ for visual inspection
*
* Author: Timothy P Copeland
* Date: 2025-12-16
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* PATH CONFIGURATION
* =============================================================================
if "`c(os)'" == "MacOSX" {
    global STATA_TOOLS_PATH "/Users/tcopeland/Documents/GitHub/Stata-Tools"
}
else if "`c(os)'" == "Unix" {
    global STATA_TOOLS_PATH "/home/ubuntu/Stata-Tools"
}
else {
    global STATA_TOOLS_PATH "`c(pwd)'/.."
}

global TESTING_DIR "${STATA_TOOLS_PATH}/_testing"
global FIGURES_DIR "${TESTING_DIR}/figures/consort"

* Create figures directory
capture mkdir "${TESTING_DIR}/figures"
capture mkdir "${FIGURES_DIR}"

* Install package
capture net uninstall consort
quietly net install consort, from("${STATA_TOOLS_PATH}/consort")

display as text _n "{hline 70}"
display as text "CONSORT FIGURE GENERATION FOR VISUAL INSPECTION"
display as text "{hline 70}"
display as text "Output directory: ${FIGURES_DIR}"
display as text "{hline 70}"

* =============================================================================
* HELPER: Clear consort state
* =============================================================================
capture program drop _clear_consort_state
program define _clear_consort_state
    capture consort clear, quiet
    global CONSORT_FILE ""
    global CONSORT_N ""
    global CONSORT_ACTIVE ""
    global CONSORT_STEPS ""
    global CONSORT_TEMPFILE ""
    global CONSORT_SCRIPT_PATH ""
end

* =============================================================================
* SYNTHETIC DATASET 1: Clinical trial style
* 100 observations with various exclusion criteria
* =============================================================================
display as text _n "Creating synthetic clinical trial dataset..."
clear
set obs 500
set seed 12345

gen id = _n
gen has_baseline_labs = runiform() > 0.1         // 10% missing baseline
gen age = int(18 + 60*runiform())
gen is_child = age < 18                           // Some under 18
gen prior_cancer = runiform() < 0.08              // 8% prior cancer
gen followup_days = int(365*runiform())
gen lost_early = followup_days < 30              // Lost to follow-up
gen has_outcome = runiform() > 0.06              // 6% missing outcome

label data "Synthetic clinical trial: 500 patients"
save "${TESTING_DIR}/data/synth_clinical.dta", replace

* =============================================================================
* SYNTHETIC DATASET 2: Large population study
* 10000 observations for testing with larger numbers
* =============================================================================
display as text "Creating large population dataset..."
clear
set obs 10000
set seed 54321

gen id = _n
gen has_exposure = runiform() > 0.05
gen has_outcome_data = runiform() > 0.03
gen valid_dates = runiform() > 0.02
gen no_duplicates = runiform() > 0.01
gen complete_covariates = runiform() > 0.08

label data "Synthetic population: 10,000 subjects"
save "${TESTING_DIR}/data/synth_population.dta", replace

* =============================================================================
* SYNTHETIC DATASET 3: Small dataset with many exclusions
* =============================================================================
display as text "Creating dataset with many exclusion steps..."
clear
set obs 1000
set seed 11111

gen id = _n
gen step1_pass = runiform() > 0.15
gen step2_pass = runiform() > 0.12
gen step3_pass = runiform() > 0.10
gen step4_pass = runiform() > 0.08
gen step5_pass = runiform() > 0.06
gen step6_pass = runiform() > 0.05

label data "Dataset for testing many exclusion steps"
save "${TESTING_DIR}/data/synth_multistep.dta", replace

* =============================================================================
* FIGURE 1: Basic workflow - default options
* =============================================================================
display as text _n "Figure 1: Basic workflow with default options..."
_clear_consort_state
use "${TESTING_DIR}/data/synth_clinical.dta", clear

consort init, initial("All patients in database 2020-2024")
consort exclude if has_baseline_labs == 0, label("Missing baseline labs")
consort exclude if is_child == 1, label("Age < 18 years")
consort exclude if prior_cancer == 1, label("Prior cancer diagnosis")
consort exclude if lost_early == 1, label("Lost to follow-up < 30 days")
consort exclude if has_outcome == 0, label("Missing outcome data")
consort save, output("${FIGURES_DIR}/01_basic_default.png") final("Final Analytic Cohort")

* =============================================================================
* FIGURE 2: With shading enabled
* =============================================================================
display as text "Figure 2: With shading enabled..."
_clear_consort_state
use "${TESTING_DIR}/data/synth_clinical.dta", clear

consort init, initial("All patients in database 2020-2024")
consort exclude if has_baseline_labs == 0, label("Missing baseline labs")
consort exclude if is_child == 1, label("Age < 18 years")
consort exclude if prior_cancer == 1, label("Prior cancer diagnosis")
consort exclude if lost_early == 1, label("Lost to follow-up < 30 days")
consort exclude if has_outcome == 0, label("Missing outcome data")
consort save, output("${FIGURES_DIR}/02_with_shading.png") final("Final Analytic Cohort") shading

* =============================================================================
* FIGURE 3: High DPI (300) for publication quality
* =============================================================================
display as text "Figure 3: High DPI (300) for publication quality..."
_clear_consort_state
use "${TESTING_DIR}/data/synth_clinical.dta", clear

consort init, initial("All patients in database 2020-2024")
consort exclude if has_baseline_labs == 0, label("Missing baseline labs")
consort exclude if is_child == 1, label("Age < 18 years")
consort exclude if prior_cancer == 1, label("Prior cancer diagnosis")
consort save, output("${FIGURES_DIR}/03_high_dpi_300.png") final("Study Population") dpi(300)

* =============================================================================
* FIGURE 4: Low DPI (100) for quick preview
* =============================================================================
display as text "Figure 4: Low DPI (100) for quick preview..."
_clear_consort_state
use "${TESTING_DIR}/data/synth_clinical.dta", clear

consort init, initial("All patients in database 2020-2024")
consort exclude if has_baseline_labs == 0, label("Missing baseline labs")
consort exclude if is_child == 1, label("Age < 18 years")
consort save, output("${FIGURES_DIR}/04_low_dpi_100.png") dpi(100)

* =============================================================================
* FIGURE 5: Using remaining() for intermediate labels
* =============================================================================
display as text "Figure 5: Using remaining() for intermediate labels..."
_clear_consort_state
use "${TESTING_DIR}/data/synth_clinical.dta", clear

consort init, initial("All patients screened for eligibility")
consort exclude if has_baseline_labs == 0, label("Missing baseline labs") remaining("Patients with lab data")
consort exclude if is_child == 1, label("Age < 18 years") remaining("Adult patients")
consort exclude if prior_cancer == 1, label("Prior cancer diagnosis") remaining("Cancer-free patients")
consort exclude if lost_early == 1, label("Lost to follow-up") remaining("Patients with adequate follow-up")
consort save, output("${FIGURES_DIR}/05_with_remaining_labels.png") final("Final Study Cohort") shading

* =============================================================================
* FIGURE 6: Large population (10000 subjects)
* =============================================================================
display as text "Figure 6: Large population study..."
_clear_consort_state
use "${TESTING_DIR}/data/synth_population.dta", clear

consort init, initial("All subjects in registry 2015-2024")
consort exclude if has_exposure == 0, label("No exposure data")
consort exclude if has_outcome_data == 0, label("No outcome data")
consort exclude if valid_dates == 0, label("Invalid date records")
consort exclude if no_duplicates == 0, label("Duplicate records")
consort exclude if complete_covariates == 0, label("Missing covariates")
consort save, output("${FIGURES_DIR}/06_large_population.png") final("Analysis Population") shading

* =============================================================================
* FIGURE 7: Many exclusion steps (6 steps)
* =============================================================================
display as text "Figure 7: Many exclusion steps..."
_clear_consort_state
use "${TESTING_DIR}/data/synth_multistep.dta", clear

consort init, initial("Source Population")
consort exclude if step1_pass == 0, label("Exclusion criterion 1")
consort exclude if step2_pass == 0, label("Exclusion criterion 2")
consort exclude if step3_pass == 0, label("Exclusion criterion 3")
consort exclude if step4_pass == 0, label("Exclusion criterion 4")
consort exclude if step5_pass == 0, label("Exclusion criterion 5")
consort exclude if step6_pass == 0, label("Exclusion criterion 6")
consort save, output("${FIGURES_DIR}/07_many_steps.png") final("Final Cohort") shading

* =============================================================================
* FIGURE 8: Minimal diagram (single exclusion)
* =============================================================================
display as text "Figure 8: Minimal diagram (single exclusion)..."
_clear_consort_state
sysuse auto, clear

consort init, initial("All vehicles in dataset")
consort exclude if rep78 == ., label("Missing repair record")
consort save, output("${FIGURES_DIR}/08_minimal_single.png") final("Vehicles for analysis")

* =============================================================================
* FIGURE 9: Shading + High DPI combined
* =============================================================================
display as text "Figure 9: Shading + High DPI combined..."
_clear_consort_state
use "${TESTING_DIR}/data/synth_clinical.dta", clear

consort init, initial("Patients in electronic health records")
consort exclude if has_baseline_labs == 0, label("No baseline laboratory values")
consort exclude if is_child == 1, label("Pediatric patients (age < 18)")
consort exclude if prior_cancer == 1, label("History of malignancy")
consort save, output("${FIGURES_DIR}/09_shading_highdpi.png") final("Final Analytic Sample") shading dpi(300)

* =============================================================================
* FIGURE 10: Long text labels
* =============================================================================
display as text "Figure 10: Long text labels..."
_clear_consort_state
use "${TESTING_DIR}/data/synth_clinical.dta", clear

consort init, initial("All patients enrolled in the multicenter prospective cohort study 2020-2024")
consort exclude if has_baseline_labs == 0, label("Missing required baseline laboratory measurements (hemoglobin, creatinine, albumin)")
consort exclude if is_child == 1, label("Age below minimum enrollment criteria of 18 years at index date")
consort exclude if prior_cancer == 1, label("Prior diagnosis of malignant neoplasm within 5 years before enrollment")
consort save, output("${FIGURES_DIR}/10_long_labels.png") final("Patients meeting all inclusion and exclusion criteria") shading

* =============================================================================
* FIGURE 11: Special characters in labels
* =============================================================================
display as text "Figure 11: Special characters in labels..."
_clear_consort_state
sysuse auto, clear

consort init, initial("All vehicles (n=74)")
consort exclude if rep78 == ., label("Missing repair record - excluded")
consort exclude if foreign == 1, label("Non-domestic manufacture")
consort exclude if price > 10000, label("Price > $10,000")
consort save, output("${FIGURES_DIR}/11_special_chars.png") final("Domestic cars <= $10k") shading

* =============================================================================
* FIGURE 12: CSV file option test
* =============================================================================
display as text "Figure 12: Using custom CSV file..."
_clear_consort_state
use "${TESTING_DIR}/data/synth_clinical.dta", clear

consort init, initial("All patients") file("${FIGURES_DIR}/12_custom_csv.csv")
consort exclude if has_baseline_labs == 0, label("Missing labs")
consort exclude if is_child == 1, label("Under 18")
consort save, output("${FIGURES_DIR}/12_custom_csv.png") final("Study sample")

* Display CSV contents
display as text _n "CSV file contents:"
type "${FIGURES_DIR}/12_custom_csv.csv"

* =============================================================================
* CLEANUP
* =============================================================================
display as text _n "{hline 70}"
display as text "FIGURE GENERATION COMPLETE"
display as text "{hline 70}"
display as text "Generated 12 figures in: ${FIGURES_DIR}"
display as text ""
display as text "Figures:"
display as text "  01_basic_default.png       - Basic workflow, default options"
display as text "  02_with_shading.png        - Shading enabled"
display as text "  03_high_dpi_300.png        - High DPI (300)"
display as text "  04_low_dpi_100.png         - Low DPI (100)"
display as text "  05_with_remaining_labels.png - Custom intermediate labels"
display as text "  06_large_population.png    - Large N (10000)"
display as text "  07_many_steps.png          - Many exclusion steps"
display as text "  08_minimal_single.png      - Single exclusion"
display as text "  09_shading_highdpi.png     - Shading + high DPI"
display as text "  10_long_labels.png         - Long text labels"
display as text "  11_special_chars.png       - Special characters"
display as text "  12_custom_csv.png          - Custom CSV file"
display as text "{hline 70}"

* Clean up synthetic datasets (optional - keep for other tests)
* capture erase "${TESTING_DIR}/data/synth_clinical.dta"
* capture erase "${TESTING_DIR}/data/synth_population.dta"
* capture erase "${TESTING_DIR}/data/synth_multistep.dta"

display as text _n "Figure generation completed: `c(current_date)' `c(current_time)'"
