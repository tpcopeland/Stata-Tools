*! build_edss_fixture.do  1.0.0  2026/07/13
*! Deterministically generate qa/data/edss_long.dta (MIT licensed)

version 16.0
args output
if `"`output'"' == "" local output "../data/edss_long.dta"

clear
set obs 1000
gen int id = _n
gen byte n_visits = 3 + mod(id, 7)
expand n_visits
bysort id: gen byte visit_number = _n
gen int edss_dt = td(01jan2010) + id + 180 * visit_number + ///
    mod(id * visit_number, 31)
gen double edss = 1.5 + 0.5 * mod(id + visit_number, 8) + ///
    0.5 * (visit_number > 4)
replace edss = min(edss, 10)
format edss_dt %td
label variable id "Patient ID"
label variable edss_dt "EDSS assessment date"
label variable edss "EDSS score"
keep id edss_dt edss
sort id edss_dt edss
compress
save `"`output'"', replace
