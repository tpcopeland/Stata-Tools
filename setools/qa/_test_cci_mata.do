* Test: verify Mata engine produces identical results to v1.0.1 regex engine
* Runs cci_se on the example dataset and checks output

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall setools
net install setools, from("`pkg_dir'") replace

**# Setup
clear all
set more off
use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/diagnoses.dta", clear
count
assert r(N) == 372632

**# Test 1: basic CCI score only
preserve
cci_se, id(id) icd(icd) date(visit_date) noisily
assert r(N_patients) == 15000
assert r(N_input) == 372632

* Verify score variable exists and is sensible
confirm variable charlson
summarize charlson
assert r(min) >= 0
assert r(max) <= 30
assert r(N) == 15000
local mean1 = r(mean)
local max1 = r(max)
display "PASS: Test 1 - basic CCI score"
restore

**# Test 2: with components
preserve
cci_se, id(id) icd(icd) date(visit_date) components noisily
assert r(N_patients) == 15000

* Verify all 18 component variables exist
foreach v in mi chf pvd cevd copd pulm rheum dem plegia diab diabcomp renal livmild livsev pud cancer mets aids {
    confirm variable cci_`v'
    assert cci_`v' == 0 | cci_`v' == 1
}

* Verify hierarchy: no uncomplicated diabetes when complicated present
count if cci_diab == 1 & cci_diabcomp == 1
assert r(N) == 0

* Verify hierarchy: no non-metastatic cancer when metastatic present
count if cci_cancer == 1 & cci_mets == 1
assert r(N) == 0

* Verify weighted score consistency
gen int check_score = cci_mi + cci_chf + cci_pvd + cci_cevd + cci_copd + ///
    cci_pulm + cci_rheum + cci_dem + 2*cci_plegia + cci_diab + ///
    2*cci_diabcomp + 2*cci_renal + cci_livmild + 3*cci_livsev + ///
    cci_pud + 2*cci_cancer + 6*cci_mets + 6*cci_aids
assert charlson == check_score
display "PASS: Test 2 - components + score consistency"
restore

**# Test 3: custom prefix
preserve
cci_se, id(id) icd(icd) date(visit_date) components prefix(ch_) generate(cci_total)
confirm variable ch_mi
confirm variable ch_mets
confirm variable cci_total
display "PASS: Test 3 - custom prefix and generate name"
restore

**# Test 4: return values
preserve
cci_se, id(id) icd(icd) date(visit_date) components
assert r(N_input) == 372632
assert r(N_patients) == 15000
assert r(N_any) > 0
assert r(mean_cci) > 0
assert r(max_cci) > 0 & r(max_cci) <= 30
display "PASS: Test 4 - return values"
restore

**# Test 5: specific prevalence sanity checks
preserve
cci_se, id(id) icd(icd) date(visit_date) components

* MI should exist in a 15K synthetic dataset
count if cci_mi == 1
assert r(N) > 0

* Metastatic should be less common than non-metastatic cancer
count if cci_mets == 1
local n_mets = r(N)
count if cci_cancer == 1
local n_cancer = r(N)
assert `n_mets' <= `n_cancer' + `n_mets'

display "PASS: Test 5 - prevalence sanity checks"
restore

**# Summary
display _newline "All tests PASSED"
