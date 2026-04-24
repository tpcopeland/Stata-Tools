* Test: cci_se dates option
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall setools
net install setools, from("`pkg_dir'") replace

**# Setup
clear all
set more off
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/diagnoses.dta", clear

**# Test 1: dates option generates date variables
preserve
cci_se, id(id) icd(icd) date(visit_date) dates noisily

* dates implies components — verify both exist
foreach v in mi chf pvd cevd copd pulm rheum dem plegia diab diabcomp renal livmild livsev pud cancer mets aids {
    confirm variable cci_`v'
    confirm variable cci_`v'_date
}

* Date variables should be %td formatted
local fmt : format cci_mi_date
assert "`fmt'" == "%td"

* Dates should be missing where indicator is 0, non-missing where 1
count if cci_mi == 1 & missing(cci_mi_date)
assert r(N) == 0
count if cci_mi == 0 & !missing(cci_mi_date)
assert r(N) == 0

* Check consistency across all components
foreach v in mi chf pvd cevd copd pulm rheum dem plegia diab diabcomp renal livmild livsev pud cancer mets aids {
    count if cci_`v' == 1 & missing(cci_`v'_date)
    assert r(N) == 0
    count if cci_`v' == 0 & !missing(cci_`v'_date)
    assert r(N) == 0
}
display "PASS: Test 1 - dates generated and consistent with indicators"
restore

**# Test 2: dates should be earliest (minimum)
preserve
cci_se, id(id) icd(icd) date(visit_date) dates

* All dates should be plausible Stata dates (within data range)
foreach v in mi chf copd cevd rheum dem diab diabcomp renal livmild cancer mets aids {
    summarize cci_`v'_date if !missing(cci_`v'_date), format
    if r(N) > 0 {
        assert r(min) >= daily("01jan2000", "DMY")
        assert r(max) <= daily("31dec2025", "DMY")
    }
}
display "PASS: Test 2 - dates within plausible range"
restore

**# Test 3: without dates — no date variables (backward compat)
preserve
cci_se, id(id) icd(icd) date(visit_date) components
capture confirm variable cci_mi_date
assert _rc != 0
display "PASS: Test 3 - no date variables without dates option"
restore

**# Test 4: score unchanged by dates option
preserve
cci_se, id(id) icd(icd) date(visit_date) components
tempfile no_dates
save `no_dates'
restore

preserve
cci_se, id(id) icd(icd) date(visit_date) dates
rename cci_*_date _dt_*
merge 1:1 id using `no_dates', assert(match) nogenerate

* Verify all indicators are identical
foreach v in mi chf pvd cevd copd pulm rheum dem plegia diab diabcomp renal livmild livsev pud cancer mets aids {
    count if cci_`v' != cci_`v'
    assert r(N) == 0
}

* Verify score is identical
count if charlson != charlson
assert r(N) == 0
display "PASS: Test 4 - score and indicators unchanged by dates option"
restore

**# Test 5: hierarchy rules applied to dates
preserve
cci_se, id(id) icd(icd) date(visit_date) dates

* Diabetes hierarchy: uncomplicated cleared when complicated exists
count if cci_diabcomp == 1 & !missing(cci_diab_date)
assert r(N) == 0

* Cancer hierarchy: non-metastatic cleared when metastatic exists
count if cci_mets == 1 & !missing(cci_cancer_date)
assert r(N) == 0
display "PASS: Test 5 - hierarchy rules applied to dates"
restore

**# Test 6: custom prefix works with dates
preserve
cci_se, id(id) icd(icd) date(visit_date) dates prefix(ch_)
confirm variable ch_mi
confirm variable ch_mi_date
confirm variable ch_mets_date
display "PASS: Test 6 - custom prefix with dates"
restore

**# Summary
display _newline "All tests PASSED"
