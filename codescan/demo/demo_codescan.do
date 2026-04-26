/*  demo_codescan.do - Generate screenshots for codescan

    Produces 5 output types:
      1. Console output (codescan_describe: code inventory)  -> .smcl
      2. Console output (codescan: inline define, row-level)  -> .smcl
      3. Console output (Charlson scoring with hierarchy)     -> .smcl
      4. Graph (prevalence bar chart)                         -> .png
      5. Excel (summary + cooccurrence workbook)              -> .xlsx
*/

version 16.0
set more off
set varabbrev off
set linesize 250

* --- Paths ---
local pkg_dir "codescan/demo"
capture mkdir "`pkg_dir'"

* --- Install package from local source ---
capture ado uninstall codescan
quietly net install codescan, from("`c(pwd)'/codescan") replace

**# Synthetic Administrative Data
* 500 patients, 3 encounters each, wide-format ICD-10 diagnosis + procedure codes
clear
set seed 20260226
set obs 1500
gen long pid = ceil(_n / 3)
bysort pid: gen byte enc = _n

* Index date: surgery date for each patient (constant within patient)
gen double index_dt = mdy(1,1,2020) + int(runiform() * 730) if enc == 1
bysort pid (enc): replace index_dt = index_dt[1]
format index_dt %td

* Visit dates: spread around index date
gen double visit_dt = index_dt - 365 + int(runiform() * 730) if enc == 1
replace visit_dt = index_dt - 180 + int(runiform() * 540) if enc == 2
replace visit_dt = index_dt + int(runiform() * 365) if enc == 3
format visit_dt %td

* Age and sex (baseline)
gen double age = 45 + int(runiform() * 40) if enc == 1
bysort pid (enc): replace age = age[1]
gen byte female = rbinomial(1, 0.52) if enc == 1
bysort pid (enc): replace female = female[1]

* ICD-10 diagnosis pools — realistic chapter distribution
local dx_E "E110 E119 E102 E103 E114 E100 E109 E030"
local dx_I "I10 I110 I120 I131 I50 I21 I252 I70 I71 I48"
local dx_C "C50 C61 C34 C18 C78 C79 C80 C81 C85"
local dx_J "J44 J45 J47"
local dx_G "G30 G311 G81 G820"
local dx_M "M05 M06 M32"
local dx_B "B18 B20 B21"
local dx_N "N18 N19 N250"
local dx_K "K700 K703 K721 K765 K25"
local dx_F "F10 F32 F33 F20"
local dx_D "D65 D66 D500 D509"
local dx_R "R634 R001"
local dx_Z "Z00 Z96 Z87"

local all_dx `dx_E' `dx_I' `dx_C' `dx_J' `dx_G' `dx_M' `dx_B' `dx_N' `dx_K' `dx_F' `dx_D' `dx_R' `dx_Z'
local n_codes : word count `all_dx'

* Populate 4 wide-format diagnosis slots
forvalues v = 1/4 {
    gen str6 dx`v' = ""
    forvalues i = 1/`=_N' {
        if runiform() < 0.55 + 0.1 * (`v' == 1) {
            local pick = 1 + int(runiform() * `n_codes')
            local code : word `pick' of `all_dx'
            quietly replace dx`v' = "`code'" in `i'
        }
    }
}

* One procedure variable
local procs "XF001 XF002 JFB10 JFH20 ABC99"
local n_procs : word count `procs'
gen str6 proc1 = ""
forvalues i = 1/`=_N' {
    if runiform() < 0.30 {
        local pick = 1 + int(runiform() * `n_procs')
        local code : word `pick' of `procs'
        quietly replace proc1 = "`code'" in `i'
    }
}

label variable pid      "Patient ID"
label variable visit_dt "Encounter date"
label variable index_dt "Index (surgery) date"
label variable age      "Age at baseline"
label variable female   "Female sex"

save "`pkg_dir'/_admin_demo.dta", replace

**# 1. Code Inventory (codescan_describe)
log using "`pkg_dir'/console_describe.smcl", replace smcl name(describe) nomsg

noisily codescan_describe dx1 dx2 dx3 dx4, top(15)

log close describe

**# 2. Inline Define — Row-Level Scan
use "`pkg_dir'/_admin_demo.dta", clear

log using "`pkg_dir'/console_rowlevel.smcl", replace smcl name(rowlevel) nomsg

noisily codescan dx1 dx2 dx3 dx4, ///
    define(dm "E1[01]" | htn "I1[0-35]" | chf "I50" | copd "J4[0-7]" | ///
           cancer "C[0-7]" ~ "C77|C78|C79|C80" | metastatic "C7[789]|C80") ///
    label(dm "Diabetes" \ htn "Hypertension" \ chf "Heart failure" \ ///
          copd "COPD" \ cancer "Cancer (non-met)" \ metastatic "Metastatic cancer") ///
    detail noisily

log close rowlevel

**# 3. Charlson Scoring — Full Clinical Workflow
use "`pkg_dir'/_admin_demo.dta", clear

log using "`pkg_dir'/console_charlson.smcl", replace smcl name(charlson) nomsg

noisily codescan dx1 dx2 dx3 dx4, ///
    codefile(charlson_icd10_example.csv) ///
    id(pid) date(visit_dt) refdate(index_dt) ///
    lookback(365) inclusive ///
    collapse alldates countrows ///
    score(charlson) ///
    hierarchy(dm_comp > dm_uncomp \ liver_severe > liver_mild \ metastatic > cancer) ///
    cooccurrence detail noisily

noisily summarize _score, detail

log close charlson

**# 4. Prevalence Bar Chart
use "`pkg_dir'/_admin_demo.dta", clear

codescan dx1 dx2 dx3 dx4, ///
    codefile(charlson_icd10_example.csv) ///
    id(pid) collapse ///
    score(charlson) ///
    hierarchy(dm_comp > dm_uncomp \ liver_severe > liver_mild \ metastatic > cancer) ///
    graph

graph export "`pkg_dir'/prevalence_chart.png", replace width(1200)
capture graph close _all

**# 5. Excel Export — Summary + Co-occurrence
use "`pkg_dir'/_admin_demo.dta", clear

codescan dx1 dx2 dx3 dx4, ///
    codefile(charlson_icd10_example.csv) ///
    id(pid) collapse ///
    score(charlson) ///
    hierarchy(dm_comp > dm_uncomp \ liver_severe > liver_mild \ metastatic > cancer) ///
    cooccurrence ///
    export("`pkg_dir'/codescan_results.xlsx") ///
    format(%9.2f)

**# Cleanup
capture erase "`pkg_dir'/_admin_demo.dta"
clear
