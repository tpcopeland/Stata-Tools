/*  demo_codescan.do - Demo output for codescan

    Produces, in codescan/demo/:
      1. prevalence_chart.png    - condition prevalence bar chart (patient level)
      2. codescan_results.xlsx   - summary + co-occurrence workbook

    Run from the Stata-Tools repo root, the codescan package directory, or
    codescan/demo/ — the package root is resolved from c(pwd).

    Optional: tc_schemes (plotplainblind). The demo uses it when it is already
    installed and falls back to the current scheme otherwise; it never installs
    or uninstalls it.

    Side effect: this demo (re)installs codescan into your real PLUS directory
    from the local source (ado uninstall + net install) and leaves it there. If
    you had a GitHub/SSC build of codescan installed, you will be on the local
    build after running this. Re-run `net install codescan` from your usual
    source to switch back. (The demo deliberately does not sandbox PLUS, so an
    already-installed tc_schemes stays visible for the graph scheme.)
*/

version 16.0
set varabbrev off
set linesize 120

* Resolve the package root from c(pwd) so the demo runs from either the
* Stata-Tools repo root or from codescan/demo/ itself.
local here "`c(pwd)'"
local src_dir ""
local pkg_dir ""

* Repo root: ./codescan/codescan.ado
capture confirm file "`here'/codescan/codescan.ado"
if _rc == 0 {
    local src_dir "`here'/codescan"
    local pkg_dir "`here'/codescan/demo"
}
* Package dir: ./codescan.ado
if "`src_dir'" == "" {
    capture confirm file "`here'/codescan.ado"
    if _rc == 0 {
        local src_dir "`here'"
        local pkg_dir "`here'/demo"
    }
}
* Demo dir: ../codescan.ado — pkg_dir is where we already are
if "`src_dir'" == "" {
    capture confirm file "`here'/../codescan.ado"
    if _rc == 0 {
        local src_dir "`here'/.."
        local pkg_dir "`here'"
    }
}
if "`src_dir'" == "" {
    display as error "demo_codescan.do: run from the Stata-Tools root, the codescan package dir, or codescan/demo/"
    exit 601
}
capture mkdir "`pkg_dir'"

* --- Install package from local source ---
* NOTE: this mutates the caller's real PLUS (see the side-effect note in the
* header) — it leaves the local build installed after the demo finishes.
capture ado uninstall codescan
quietly net install codescan, from("`src_dir'") replace

* --- Graph scheme ---
* Use tc_schemes when the user already has it; never install or uninstall a
* sibling package on their behalf. Restore the original scheme on exit.
local _orig_scheme "`c(scheme)'"
local _scheme_set = 0
capture findfile scheme-plotplainblind.scheme
if _rc == 0 {
    set scheme plotplainblind
    local _scheme_set = 1
}
else display as text "(note: tc_schemes not installed; using the current scheme `_orig_scheme')"

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

tempfile admin_demo
save "`admin_demo'", replace

* Condition rule set reused across the graph and Excel exports below.
local cs_define dm "E1[01]" | htn "I1[0-35]" | chf "I50" | copd "J4[0-7]" | cancer "C[0-7]" ~ "C77|C78|C79|C80" | metastatic "C7[789]|C80"
local cs_label  dm "Diabetes" \ htn "Hypertension" \ chf "Heart failure" \ copd "COPD" \ cancer "Cancer (non-met)" \ metastatic "Metastatic cancer"

**# 1. Prevalence Bar Chart
use "`admin_demo'", clear

codescan dx1 dx2 dx3 dx4, ///
    define(`cs_define') ///
    label(`cs_label') ///
    id(pid) collapse ///
    graph

graph export "`pkg_dir'/prevalence_chart.png", replace width(1200)
capture graph close _all

**# 2. Excel Export — Summary + Co-occurrence
use "`admin_demo'", clear

codescan dx1 dx2 dx3 dx4, ///
    define(`cs_define') ///
    label(`cs_label') ///
    id(pid) collapse ///
    cooccurrence ///
    export("`pkg_dir'/codescan_results.xlsx", replace) ///
    format(%9.2f)

**# Cleanup
* Runs on every path: the tempfile is dropped by Stata, but the scheme is a
* session setting that must be handed back the way it was found.
if `_scheme_set' set scheme `_orig_scheme'
capture graph close _all
clear
