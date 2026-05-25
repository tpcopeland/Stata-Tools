/*  demo_iivw.do - Demo output for iivw

    Produces:
      1. Console output (FIPTIW diagnostic workflow) -> .log -> .md via logdoc
      2. Excel table (unweighted/FIPTIW/artifact-adjusted models) -> .xlsx

    Run from the Stata-Tools repository root:
      stata-mp -b do iivw/demo/demo_iivw.do
*/

version 16.0
set more off
set varabbrev off
set linesize 120

**# Paths
local repo_dir = regexr("`c(pwd)'", "/+$", "")
local pkg_dir "iivw/demo"
local xlsx "`pkg_dir'/iivw_results.xlsx"
capture mkdir "`pkg_dir'"
capture erase "`pkg_dir'/console_output.log"
capture erase "`pkg_dir'/console_output.md"
capture erase "`pkg_dir'/console_output.html"
capture erase "`pkg_dir'/console_output.png"
capture erase "`xlsx'"

**# Install packages from local source
capture ado uninstall iivw
quietly net install iivw, from("`repo_dir'/iivw") replace
capture ado uninstall tabtools
quietly net install tabtools, from("`repo_dir'/tabtools") replace

**# Generate synthetic longitudinal SDMT-like data
clear
set seed 20260226
quietly set obs 320

gen long id = _n
gen double age = 28 + 24 * runiform()
gen byte female = runiform() < 0.68
gen double edss0 = rnormal(2.2, 0.9)
replace edss0 = max(0, min(6.5, edss0))
gen double sdmt0 = rnormal(53 - 1.7 * edss0 - 0.08 * (age - 40), 6)
gen double dur = max(0.2, exp(rnormal(log(6), 0.45)))
gen byte naive = runiform() < invlogit(0.35 - 0.30 * edss0)
gen double ps_tx = invlogit(-0.40 - 0.05 * (age - 38) + ///
    0.28 * edss0 - 0.45 * naive)
gen byte tx = runiform() < ps_tx
label define tx 0 "RTX-like" 1 "NTZ-like", replace
label values tx tx

gen int n_test = 3 + floor(3 * runiform()) + 3 * tx + (edss0 > 2.7)
replace n_test = min(n_test, 10)
expand n_test
bysort id: gen int testno = _n
bysort id: gen double gap = cond(_n == 1, 0, ///
    max(0.08, 0.72 - 0.28 * tx - 0.035 * (_n - 2) + ///
    0.025 * edss0 + rnormal(0, 0.08)))
bysort id: gen double years = sum(gap)
replace years = round(years, 0.01)

gen double true_sdmt = sdmt0 + 0.16 * years + 0.38 * tx * years - ///
    0.18 * edss0 * years + rnormal(0, 2.4)
gen double practice = 2.7 * log(testno + 1)
gen double sdmt = true_sdmt + practice
gen byte relapse = runiform() < invlogit(-2.1 + 0.30 * edss0 - ///
    0.015 * (sdmt - sdmt0))
gen double tx_years = tx * years

label variable id "Patient ID"
label variable age "Age at treatment start"
label variable female "Female"
label variable edss0 "Baseline EDSS"
label variable sdmt0 "Baseline SDMT"
label variable dur "Disease duration"
label variable naive "Treatment-naive"
label variable tx "Treatment group"
label variable testno "Cumulative SDMT test number"
label variable years "Years since treatment start"
label variable sdmt "Observed SDMT score"
label variable relapse "Recent relapse"
label variable tx_years "Treatment x years"
label variable practice "Synthetic practice effect"

**# Console output
capture log close _all
log using "`pkg_dir'/console_output.log", replace text name(demo) nomsg

* # Package overview
iivw

* # Synthetic SDMT-like panel
quietly egen byte _idtag = tag(id)
count
count if _idtag
tabulate tx if _idtag
summarize years testno sdmt practice
drop _idtag

* # Step 1: unweighted outcome model
iivw_fit sdmt tx years tx_years relapse ///
    age female edss0 dur naive sdmt0, ///
    unweighted id(id) time(years) timespec(none) nolog
estimates store M_unweighted

* # Step 2: FIPTIW weights and leverage diagnostics
iivw_weight, ///
    id(id) time(years) ///
    visit_cov(tx age female edss0 sdmt0 dur naive) ///
    lagvars(sdmt relapse) ///
    treat(tx) ///
    treat_cov(age female edss0 sdmt0 dur naive) ///
    stabcov(tx) ///
    truncate(1 99) efron replace nolog

display as text "FIPTIW effective sample size: " as result %9.1f r(ess) ///
    as text " of " as result %9.0f r(N)
summarize _iivw_weight _iivw_iw _iivw_tw
iivw_balance, nolog

* # Step 3: weighted and artifact-adjusted outcome models
iivw_fit sdmt tx years tx_years relapse ///
    age female edss0 dur naive sdmt0, ///
    model(gee) timespec(none) replace nolog
estimates store M_fiptiw

gen double log_testno = log(testno + 1)
label variable log_testno "log(test number + 1)"

iivw_fit sdmt tx years tx_years relapse ///
    age female edss0 dur naive sdmt0 log_testno, ///
    model(gee) timespec(none) replace nolog
estimates store M_adjusted

* # Step 4: exogeneity check and diagnostic decomposition
iivw_exogtest sdmt relapse, ///
    id(id) time(years) ///
    adjust(age female edss0 sdmt0 dur naive) ///
    by(tx) efron nolog

local exo "exogenous"
if r(endogenous_flag) local exo "endogenous"

iivw_diagnose years, ///
    unweighted(M_unweighted) weighted(M_fiptiw) adjusted(M_adjusted) ///
    estimand(marginal) exogeneity(`exo')

log close demo

**# Excel table: diagnostic model comparison
collect clear
collect: iivw_fit sdmt tx years tx_years relapse ///
    age female edss0 dur naive sdmt0, ///
    unweighted id(id) time(years) timespec(none) replace nolog
collect: iivw_fit sdmt tx years tx_years relapse ///
    age female edss0 dur naive sdmt0, ///
    model(gee) timespec(none) replace nolog
collect: iivw_fit sdmt tx years tx_years relapse ///
    age female edss0 dur naive sdmt0 log_testno, ///
    model(gee) timespec(none) replace nolog

regtab, xlsx("`xlsx'") sheet("Diagnostic") ///
    models("Unweighted \ FIPTIW \ FIPTIW + log(test+1)") ///
    title("IIVW diagnostic model comparison") ///
    stats(n) relabel

capture confirm file "`xlsx'"
if _rc exit _rc
preserve
quietly import excel using "`xlsx'", sheet("Diagnostic") clear allstring
quietly count
assert r(N) > 0
quietly ds
local xlsx_vars `r(varlist)'
local n_xlsx_cols : word count `xlsx_vars'
assert `n_xlsx_cols' >= 2
restore

**# Convert console log to markdown via logdoc
capture ado uninstall logdoc
quietly net install logdoc, from("`repo_dir'/logdoc") replace
logdoc using "`pkg_dir'/console_output.log", ///
    output("`pkg_dir'/console_output.md") ///
    format(md) replace quiet
confirm file "`pkg_dir'/console_output.md"

**# Cleanup
capture log close _all
clear
