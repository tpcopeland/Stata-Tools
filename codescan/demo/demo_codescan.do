/*  demo_codescan.do - Generate screenshots for codescan package

    Produces three output types:
      1. Console output (basic row-level scan) -> .smcl -> .png
      2. Console output (collapse with time window + date summaries) -> .smcl -> .png
      3. Console output (prefix mode for procedure codes) -> .smcl -> .png
*/

version 16.0
set varabbrev off

* --- Paths (work from demo/ or repo root) ---
local here = c(pwd)
capture confirm file "demo_codescan.do"
if _rc == 0 {
    * Running from demo/ directory
    local pkg_dir "`here'"
    local pkg_root = subinstr("`here'", "/demo", "", 1)
}
else {
    * Running from repo root
    local pkg_dir "`here'/codescan/demo"
    local pkg_root "`here'/codescan"
}
capture mkdir "`pkg_dir'"

* --- Load and reload command ---
capture program drop codescan
quietly run "`pkg_root'/codescan.ado"

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

* Procedure code variables for prefix mode demo
local proc_pool `""FNA10" "FNA20" "FNA30" "FNB10" "FNB20" "FNC10" "JAB10" "JAB20" "JAC10" "JAD10" "JFB30" "JFB40" "JFH10" "XF001" "XF002" "ZZA00""'
local n_procs : word count `proc_pool'

forvalues j = 1/5 {
    gen str5 proc`j' = ""
    quietly {
        forvalues i = 1/`=_N' {
            if runiform() < 0.3 {
                local pick = ceil(runiform() * `n_procs')
                replace proc`j' = `"`:word `pick' of `proc_pool''"' in `i'
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

* --- 3. Console output: prefix mode for procedure codes ---
* Reload data (collapse destroyed it)
clear
set seed 20260226
set obs 2000
gen long patient_id = ceil(_n / 5)
gen double visit_dt = mdy(1, 1, 2020) + floor(runiform() * 1826)
format visit_dt %td
gen double index_date = mdy(7, 1, 2022)
format index_date %td

local proc_pool `""FNA10" "FNA20" "FNA30" "FNB10" "FNB20" "FNC10" "JAB10" "JAB20" "JAC10" "JAD10" "JFB30" "JFB40" "JFH10" "XF001" "XF002" "ZZA00""'
local n_procs : word count `proc_pool'
forvalues j = 1/5 {
    gen str5 proc`j' = ""
    quietly {
        forvalues i = 1/`=_N' {
            if runiform() < 0.3 {
                local pick = ceil(runiform() * `n_procs')
                replace proc`j' = `"`:word `pick' of `proc_pool''"' in `i'
            }
        }
    }
}

log using "`pkg_dir'/console_prefix.smcl", replace smcl name(demo3) nomsg
noisily codescan proc1-proc5, id(patient_id) date(visit_dt) refdate(index_date) ///
    define(knee "FNA|FNB|FNC" | colectomy "JFB|JFH" | mammo "XF001|XF002") ///
    mode(prefix) lookback(365) lookforward(365) collapse ///
    label(knee "Knee Surgery" \ colectomy "Colectomy" \ mammo "Mammography") ///
    noisily
log close demo3

* --- Cleanup ---
clear
