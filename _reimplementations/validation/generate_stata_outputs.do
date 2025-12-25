/*******************************************************************************
* generate_stata_outputs.do
*
* Purpose: Generate Stata tvtools outputs for validation against R and Python
*
* This script runs tvexpose, tvevent, and tvmerge on the test data and exports
* the results to CSV format for comparison with R and Python implementations.
*******************************************************************************/

version 16.0
set more off
set varabbrev off

global DATA_IN "/home/tpcopeland/Stata-Tools/_testing/data"
global OUT_DIR "/home/tpcopeland/Stata-Tools/_reimplementations/validation/stata_outputs"

* Create output directory
capture mkdir "${OUT_DIR}"

* Install tvtools from local repository
capture net uninstall tvtools
net install tvtools, from("/home/tpcopeland/Stata-Tools/tvtools") replace

display as text _n "{hline 70}"
display as text "GENERATING STATA TVTOOLS VALIDATION OUTPUTS"
display as text "{hline 70}"

* =============================================================================
* VALIDATION TEST 1: Basic tvexpose
* =============================================================================
display as text _n "Test 1: Basic tvexpose..."

use "${DATA_IN}/cohort.dta", clear
tempfile cohort_temp
save `cohort_temp'

tvexpose using "${DATA_IN}/hrt.dta", ///
    id(id) start(rx_start) stop(rx_stop) exposure(hrt_type) ///
    entry(study_entry) exit(study_exit) reference(0) ///
    generate(tv_hrt) replace

* Export to CSV
export delimited using "${OUT_DIR}/test1_basic_tvexpose.csv", replace
display as text "  Saved: test1_basic_tvexpose.csv (`r(N)' obs)"

* =============================================================================
* VALIDATION TEST 2: tvexpose with evertreated
* =============================================================================
display as text _n "Test 2: tvexpose with evertreated..."

use `cohort_temp', clear

tvexpose using "${DATA_IN}/hrt.dta", ///
    id(id) start(rx_start) stop(rx_stop) exposure(hrt_type) ///
    entry(study_entry) exit(study_exit) reference(0) ///
    evertreated generate(ever_hrt) replace

export delimited using "${OUT_DIR}/test2_evertreated.csv", replace
display as text "  Saved: test2_evertreated.csv (`r(N)' obs)"

* =============================================================================
* VALIDATION TEST 3: tvexpose with currentformer
* =============================================================================
display as text _n "Test 3: tvexpose with currentformer..."

use `cohort_temp', clear

tvexpose using "${DATA_IN}/hrt.dta", ///
    id(id) start(rx_start) stop(rx_stop) exposure(hrt_type) ///
    entry(study_entry) exit(study_exit) reference(0) ///
    currentformer generate(cf_hrt) replace

export delimited using "${OUT_DIR}/test3_currentformer.csv", replace
display as text "  Saved: test3_currentformer.csv (`r(N)' obs)"

* =============================================================================
* VALIDATION TEST 4: tvexpose with lag
* =============================================================================
display as text _n "Test 4: tvexpose with lag..."

use `cohort_temp', clear

tvexpose using "${DATA_IN}/hrt.dta", ///
    id(id) start(rx_start) stop(rx_stop) exposure(hrt_type) ///
    entry(study_entry) exit(study_exit) reference(0) ///
    lag(30) generate(lag_hrt) replace

export delimited using "${OUT_DIR}/test4_lag.csv", replace
display as text "  Saved: test4_lag.csv (`r(N)' obs)"

* =============================================================================
* VALIDATION TEST 5: tvexpose with washout
* =============================================================================
display as text _n "Test 5: tvexpose with washout..."

use `cohort_temp', clear

tvexpose using "${DATA_IN}/hrt.dta", ///
    id(id) start(rx_start) stop(rx_stop) exposure(hrt_type) ///
    entry(study_entry) exit(study_exit) reference(0) ///
    washout(30) generate(washout_hrt) replace

export delimited using "${OUT_DIR}/test5_washout.csv", replace
display as text "  Saved: test5_washout.csv (`r(N)' obs)"

* =============================================================================
* VALIDATION TEST 6: tvexpose with continuousunit (cumulative time)
* =============================================================================
display as text _n "Test 6: tvexpose with continuousunit..."

use `cohort_temp', clear

tvexpose using "${DATA_IN}/hrt.dta", ///
    id(id) start(rx_start) stop(rx_stop) exposure(hrt_type) ///
    entry(study_entry) exit(study_exit) reference(0) ///
    continuousunit(years) generate(cumul_hrt) replace

export delimited using "${OUT_DIR}/test6_continuousunit.csv", replace
display as text "  Saved: test6_continuousunit.csv (`r(N)' obs)"

* =============================================================================
* VALIDATION TEST 7: tvevent single
* =============================================================================
display as text _n "Test 7: tvevent single..."

* First create interval data
use `cohort_temp', clear
tvexpose using "${DATA_IN}/hrt.dta", ///
    id(id) start(rx_start) stop(rx_stop) exposure(hrt_type) ///
    entry(study_entry) exit(study_exit) reference(0) ///
    generate(tv_hrt) replace
tempfile intervals_temp
save `intervals_temp'

* Load cohort as events data (edss4_dt is the event)
use `cohort_temp', clear
keep id edss4_dt

* Apply tvevent - using file is the intervals, master is events
* Use startvar/stopvar since tvexpose uses rx_start/rx_stop by default
tvevent using `intervals_temp', id(id) date(edss4_dt) type(single) generate(outcome) ///
    startvar(rx_start) stopvar(rx_stop)

export delimited using "${OUT_DIR}/test7_tvevent_single.csv", replace
display as text "  Saved: test7_tvevent_single.csv (`r(N)' obs)"

* =============================================================================
* VALIDATION TEST 8: tvmerge two datasets
* =============================================================================
display as text _n "Test 8: tvmerge two datasets..."

* Create first exposure
use `cohort_temp', clear
tvexpose using "${DATA_IN}/hrt.dta", ///
    id(id) start(rx_start) stop(rx_stop) exposure(hrt_type) ///
    entry(study_entry) exit(study_exit) reference(0) ///
    generate(hrt_exp) replace
* Rename to standard start/stop
rename rx_start start
rename rx_stop stop
save "${OUT_DIR}/hrt_exp_temp.dta", replace

* Create second exposure
use `cohort_temp', clear
tvexpose using "${DATA_IN}/dmt.dta", ///
    id(id) start(dmt_start) stop(dmt_stop) exposure(dmt) ///
    entry(study_entry) exit(study_exit) reference(0) ///
    generate(dmt_exp) replace
* Rename to standard start/stop
rename dmt_start start
rename dmt_stop stop
save "${OUT_DIR}/dmt_exp_temp.dta", replace

* Merge them
tvmerge "${OUT_DIR}/hrt_exp_temp.dta" "${OUT_DIR}/dmt_exp_temp.dta", ///
    id(id) start(start start) stop(stop stop) exposure(hrt_exp dmt_exp) force

export delimited using "${OUT_DIR}/test8_tvmerge.csv", replace
display as text "  Saved: test8_tvmerge.csv (`r(N)' obs)"

* Clean up temp files
capture erase "${OUT_DIR}/hrt_exp_temp.dta"
capture erase "${OUT_DIR}/dmt_exp_temp.dta"

* =============================================================================
* VALIDATION TEST 9: Person-time conservation check
* =============================================================================
display as text _n "Test 9: Person-time summary..."

use `cohort_temp', clear
tvexpose using "${DATA_IN}/hrt.dta", ///
    id(id) start(rx_start) stop(rx_stop) exposure(hrt_type) ///
    entry(study_entry) exit(study_exit) reference(0) ///
    generate(tv_hrt) replace

* Calculate person-time per category (use rx_stop/rx_start)
gen person_days = rx_stop - rx_start + 1
collapse (sum) person_days, by(tv_hrt)
export delimited using "${OUT_DIR}/test9_persontime.csv", replace
display as text "  Saved: test9_persontime.csv"

* =============================================================================
* Summary
* =============================================================================
display as text _n "{hline 70}"
display as text "STATA VALIDATION OUTPUTS COMPLETE"
display as text "Output directory: ${OUT_DIR}"
display as text "{hline 70}"

* List generated files
local files: dir "${OUT_DIR}" files "*.csv"
foreach f of local files {
    display as text "  `f'"
}
