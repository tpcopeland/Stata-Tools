/*  demo_codescan.do - Generate screenshots for codescan package

    Produces two output types:
      1. Console output (basic row-level scan) -> .smcl -> .png
      2. Console output (collapse with time window + date summaries) -> .smcl -> .png
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "codescan/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload command ---
capture program drop codescan
capture program drop _codescan_prefix_scan
quietly run codescan/codescan.ado

* --- Setup: synthetic wide-format diagnosis data ---
clear
set seed 20260226
set obs 2000

* Patient IDs with multiple visits per patient
gen long patient_id = ceil(_n / 5)
label variable patient_id "Patient ID"

* Visit dates spanning 2020-2024
gen double visit_dt = mdy(1, 1, 2020) + floor(runiform() * 1826)
format visit_dt %td
label variable visit_dt "Visit date"

* Index date: mid-2022 for each patient
gen double index_date = mdy(7, 1, 2022)
format index_date %td
label variable index_date "Index date"

* Wide-format diagnosis codes (dx1-dx10)
* Assign realistic ICD-10 codes with known prevalences
local icd_pool `""E110" "E119" "E66" "E660" "I10" "I119" "I13" "I25" "I63" "I64" "J44" "J45" "N18" "K70" "M81" "G35" "C50" "F32" "Z96" "R10""'
local n_codes : word count `icd_pool'

forvalues j = 1/10 {
    gen str5 dx`j' = ""
    quietly {
        * ~60% of slots filled, rest empty
        forvalues i = 1/`=_N' {
            if runiform() < 0.6 {
                local pick = ceil(runiform() * `n_codes')
                replace dx`j' = `"`:word `pick' of `icd_pool''"' in `i'
            }
        }
    }
}

* --- 1. Console output: basic row-level scan ---
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo1) nomsg
noisily codescan dx1-dx10, ///
    define(dm2 "E11" | obesity "E66" | htn "I1[0-3]" | cvd "I[2-6]" | copd "J44") ///
    label(dm2 "Type 2 Diabetes" \ obesity "Obesity" \ htn "Hypertension" ///
          \ cvd "Cardiovascular Disease" \ copd "COPD") ///
    noisily
log close demo1

* --- 2. Console output: collapse with time window + date summaries ---
log using "`pkg_dir'/console_collapse.smcl", replace smcl name(demo2) nomsg
noisily codescan dx1-dx10, id(patient_id) date(visit_dt) refdate(index_date) ///
    define(dm2 "E11" | obesity "E66" | htn "I1[0-3]" | cvd "I[2-6]" | copd "J44") ///
    lookback(1825) inclusive collapse earliestdate latestdate countdate ///
    label(dm2 "Type 2 Diabetes" \ obesity "Obesity" \ htn "Hypertension" ///
          \ cvd "Cardiovascular Disease" \ copd "COPD") ///
    replace noisily
log close demo2

* --- Cleanup ---
clear
