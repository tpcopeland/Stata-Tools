/*  demo_treescan.do - Generate screenshots for treescan

    Produces 2 output types:
      1. Console output (tree scan statistic results) -> .smcl
      2. Excel export (results spreadsheet) -> .xlsx
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "treescan/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload command ---
adopath + "treescan"
capture program drop treescan
capture program drop _treescan_build_tree
capture program drop _treescan_count_nodes
capture program drop _treescan_cut_tree
capture program drop _treescan_display
capture program drop _treescan_col_letter
capture program drop _treescan_build_col_letters
capture program drop _treescan_validate_path
quietly run treescan/treescan.ado
quietly run treescan/_treescan_cut_tree.ado
quietly run treescan/_treescan_excel.ado
quietly mata: mata mlib index

* --- Setup: synthetic pharmacovigilance data ---
clear
set seed 20260226
set obs 2000

* Person IDs
gen double person_id = _n

* Binary exposure (e.g., new drug vs comparator)
gen byte exposed = rbinomial(1, 0.5)

* ATC codes for drug prescriptions - simulate hierarchical codes
* Using a few common ATC groups
local atc_codes "N06AB04 N06AB06 N06AB10 N06AX16 N06AX21 N05BA01 N05BA06 N05CF01 N05CF02 C09AA01 C09AA02 C09AA05 C07AB02 C07AB07 A02BC01 A02BC02 A02BC05 M01AE01 M01AB05"
local natc : word count `atc_codes'

gen str10 atc_code = ""
forvalues i = 1/`=_N' {
    local pick = ceil(runiform() * `natc')
    local code : word `pick' of `atc_codes'
    quietly replace atc_code = "`code'" in `i'
}

* Make exposed group slightly more likely to have certain codes
replace atc_code = "N06AB04" if exposed == 1 & runiform() < 0.05
replace atc_code = "N05BA01" if exposed == 1 & runiform() < 0.03

* --- 1. Console output: tree scan statistic ---
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg
noisily treescan atc_code using treescan/atc_tree.dta, ///
    id(person_id) exposed(exposed) ///
    model(bernoulli) nsim(199) seed(20260226)

log close demo

* --- 2. Excel export: results spreadsheet ---
capture erase "`pkg_dir'/treescan_results.xlsx"
treescan atc_code using treescan/atc_tree.dta, ///
    id(person_id) exposed(exposed) ///
    model(bernoulli) nsim(199) seed(20260226) ///
    xlsx("`pkg_dir'/treescan_results.xlsx") ///
    title("Treescan: ATC Drug Classification (Bernoulli Unconditional)")

* --- Cleanup ---
clear
