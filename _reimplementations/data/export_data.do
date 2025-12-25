/*******************************************************************************
* export_data.do
*
* Purpose: Export Stata test datasets to CSV format for R and Python testing
*
* Output: CSV files in the csv/ subdirectory
*******************************************************************************/

version 16.0
set more off

global DATA_IN "/home/tpcopeland/Stata-Tools/_testing/data"
global DATA_OUT "/home/tpcopeland/Stata-Tools/_reimplementations/data/csv"

* Core datasets for validation
local core_files "cohort hrt dmt steroids hospitalizations hospitalizations_wide point_events overlapping_exposures edss_long"

* Edge case datasets
local edge_files "edge_single_obs edge_single_exp edge_short_followup edge_short_exp edge_same_type edge_boundary_exp"

* All files to export
local all_files "`core_files' `edge_files'"

display as text _n "{hline 70}"
display as text "Exporting Stata datasets to CSV format"
display as text "{hline 70}"

foreach f of local all_files {
    capture confirm file "${DATA_IN}/`f'.dta"
    if _rc == 0 {
        use "${DATA_IN}/`f'.dta", clear
        export delimited using "${DATA_OUT}/`f'.csv", replace
        quietly describe
        display as text "  Exported `f'.csv (`r(N)' obs, `r(k)' vars)"
    }
    else {
        display as error "  [SKIP] `f'.dta not found"
    }
}

display as text _n "{hline 70}"
display as text "Export complete"
display as text "{hline 70}"
