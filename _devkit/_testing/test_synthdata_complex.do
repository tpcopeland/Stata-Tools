/*******************************************************************************
* test_synthdata_complex.do - Test the new complex synthesis option
*******************************************************************************/

clear
set more off
version 16.0

* Find the repo root
local repo_root "`c(pwd)'"
if regexm("`repo_root'", "^(.*/Stata-Tools)") {
    local repo_root = regexs(1)
}

* Install synthdata
capture net uninstall synthdata
quietly net install synthdata, from("`repo_root'/synthdata")

display as text _n "{hline 60}"
display as text "TESTING COMPLEX SYNTHESIS OPTION"
display as text "{hline 60}"

* Create test data with dates and categorical associations
clear
set obs 500
set seed 123

gen patient_id = _n

* Ordered date sequence
gen admission_date = date("2020-01-01", "YMD") + floor(runiform() * 365)
gen procedure_date = admission_date + ceil(runiform() * 14)
gen discharge_date = procedure_date + ceil(runiform() * 7)
gen followup_date = discharge_date + ceil(runiform() * 46) + 14
format *_date %td

* Associated categoricals
gen region = ceil(runiform() * 5)
gen country = (region - 1) * 3 + ceil(runiform() * 3)

display as text "Original data:"
display as text "  N = " as res _N
count if admission_date > procedure_date
display as text "  Date ordering violations (admit>proc): " as res r(N)
gen combo = region * 100 + country
qui levelsof combo
display as text "  Region-Country combinations: " as res r(r)
drop combo

* Run complex synthesis
display as text _n "Running complex synthesis..."
tempfile orig
qui save `orig'

synthdata, complex n(500) dates(admission_date procedure_date discharge_date followup_date) ///
    seed(456) replace

* Check results
display as text _n "Synthetic data results:"
display as text "  N = " as res _N

qui count if admission_date > procedure_date
display as text "  Date violations (admit>proc): " as res r(N)
qui count if procedure_date > discharge_date
display as text "  Date violations (proc>disch): " as res r(N)
qui count if discharge_date > followup_date
display as text "  Date violations (disch>fu): " as res r(N)

gen combo = region * 100 + country
qui levelsof combo
display as text "  Region-Country combinations: " as res r(r)

display as text _n "{hline 60}"
display as result "Complex synthesis test complete"
display as text "{hline 60}"
