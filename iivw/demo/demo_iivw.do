/*  demo_iivw.do - Demo output for iivw

    Produces:
      1. Console output (FIPTIW diagnostic workflow) -> .log -> .md via logdoc
      2. psdash treatment-propensity and final-weight diagnostic graphs -> .png
      3. Excel tables (unweighted/FIPTIW/artifact-adjusted models) -> .xlsx
      4. Excel table (categorical visit-wave interaction labels) -> .xlsx
      5. Direct reporting exports from iivw_balance/iivw_exogtest/iivw_diagnose -> .xlsx sheets

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
local export_xlsx "`pkg_dir'/iivw_reporting_exports.xlsx"
local psdash_dashboard "`pkg_dir'/iivw_psdash_dashboard.png"
local psdash_final_weights "`pkg_dir'/iivw_psdash_final_weights.png"
capture mkdir "`pkg_dir'"
capture erase "`pkg_dir'/console_output.log"
capture erase "`pkg_dir'/console_output.md"
capture erase "`pkg_dir'/console_output.html"
capture erase "`pkg_dir'/console_output.png"
capture erase "`psdash_dashboard'"
capture erase "`psdash_final_weights'"
capture erase "`xlsx'"
capture erase "`export_xlsx'"
capture erase "`pkg_dir'/iivw_balance.csv"
capture erase "`pkg_dir'/iivw_diagnostics.csv"

**# Install packages from local source
capture ado uninstall iivw
quietly net install iivw, from("`repo_dir'/iivw") replace
capture ado uninstall psdash
quietly net install psdash, from("`repo_dir'/psdash") replace
capture ado uninstall tabtools
quietly net install tabtools, from("`repo_dir'/tabtools") replace
capture ado uninstall tc_schemes
quietly net install tc_schemes, from("`repo_dir'/tc_schemes") replace
set scheme plotplainblind

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
summarize _iivw_weight _iivw_iw _iivw_ps _iivw_tw

* # Step 3: psdash treatment-propensity diagnostics from iivw metadata
psdash combined, saving("`psdash_dashboard'")
psdash weights, iivwcomponent(final) detail graph ///
    saving("`psdash_final_weights'")
display as text "psdash dashboard export: " as result "`psdash_dashboard'"
display as text "psdash final-weight export: " as result "`psdash_final_weights'"
capture graph close _all

* # Step 4: visit-intensity leverage diagnostics
iivw_balance, nolog ///
    xlsx("`export_xlsx'") sheet("Balance") replace
display as text "Balance export: " as result "xlsx() sheet Balance"

* # Step 5: weighted and artifact-adjusted outcome models
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

* # Step 6: exogeneity check and diagnostic decomposition
iivw_exogtest sdmt relapse, ///
    id(id) time(years) ///
    adjust(age female edss0 sdmt0 dur naive) ///
    by(tx) efron nolog ///
    xlsx("`export_xlsx'") sheet("Exogeneity") ///
    title("SDMT visit-timing exogeneity diagnostic") ///
    footnote("Outcome-dependent visits; artifact adjustment is a sensitivity range.") ///
    decimals(3)
display as text "Exogeneity export: " as result "xlsx() sheet `r(sheet)' decimals " ///
    as result %2.0f r(decimals)

local exo "exogenous"
if r(endogenous_flag) local exo "endogenous"

iivw_diagnose years, ///
    unweighted(M_unweighted) weighted(M_fiptiw) adjusted(M_adjusted) ///
    estimand(marginal) exogeneity(`exo') ///
    excel("`export_xlsx'") sheet("Diagnostics") replace
display as text "Diagnostic export: " as result "excel() sheet Diagnostics"

* # Step 7: categorical visit-wave interactions for regtab
preserve
keep if testno <= 4
bysort id: gen byte _nvis_wave = _N
keep if _nvis_wave >= 2
drop _nvis_wave
gen byte visit_wave = testno
label variable visit_wave "Visit wave"
label define visit_wave_demo 1 "Baseline" 2 "Month 6" ///
    3 "Month 12" 4 "Month 18", replace
label values visit_wave visit_wave_demo

iivw_weight, ///
    id(id) time(visit_wave) ///
    visit_cov(tx age female edss0 sdmt0 dur naive relapse) ///
    treat(tx) ///
    treat_cov(age female edss0 sdmt0 dur naive) ///
    stabcov(tx) ///
    truncate(1 99) efron replace nolog

collect clear
iivw_fit sdmt tx age female edss0 dur naive sdmt0 relapse, ///
    model(gee) timespec(categorical) timebasecat(1) ///
    categorical(tx) interaction(tx) replace nolog collect

local cat_time "`e(iivw_time_cat_vars)'"
local cat_ix "`e(iivw_ix_vars)'"
regtab, title("Treatment by visit wave") stats(n) relabel
display as text "Generated categorical-time terms: " as result "`cat_time'"
display as text "Generated treatment-by-wave terms: " as result "`cat_ix'"
foreach v of local cat_ix {
    local ixlbl : variable label `v'
    display as text "  `v': " as result `"`ixlbl'"'
}
restore

log close demo

**# Graph export verification
confirm file "`psdash_dashboard'"
confirm file "`psdash_final_weights'"

**# Direct reporting export verification
confirm file "`export_xlsx'"

preserve
quietly import excel using "`export_xlsx'", sheet("Balance") clear allstring
quietly count
assert r(N) > 0
assert C[2] == "Means"
assert F[2] == "Balance"
assert B[3] == "Covariate"
quietly count if B == "Age at treatment start"
assert r(N) == 1
restore

preserve
quietly import excel using "`export_xlsx'", sheet("Exogeneity") clear allstring
assert A[1] == "SDMT visit-timing exogeneity diagnostic"
assert C[3] == "HR"
assert D[3] == "95% CI"
assert E[3] == "p-value"
quietly count if B == "Observed SDMT score (lag 1)"
assert r(N) >= 1
quietly count if B == "Joint test (all lagged predictors)"
assert r(N) == 1
restore

preserve
quietly import excel using "`export_xlsx'", sheet("Diagnostics") clear allstring
quietly count
assert r(N) > 0
assert C[2] == "Model estimates"
assert B[3] == "Quantity"
quietly count if B == "Sampling gap"
assert r(N) == 1
restore

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

**# Excel table: categorical visit-wave interactions
preserve
keep if testno <= 4
bysort id: gen byte _nvis_wave = _N
keep if _nvis_wave >= 2
drop _nvis_wave
gen byte visit_wave = testno
label variable visit_wave "Visit wave"
label define visit_wave_demo 1 "Baseline" 2 "Month 6" ///
    3 "Month 12" 4 "Month 18", replace
label values visit_wave visit_wave_demo

iivw_weight, ///
    id(id) time(visit_wave) ///
    visit_cov(tx age female edss0 sdmt0 dur naive relapse) ///
    treat(tx) ///
    treat_cov(age female edss0 sdmt0 dur naive) ///
    stabcov(tx) ///
    truncate(1 99) efron replace nolog

collect clear
iivw_fit sdmt tx age female edss0 dur naive sdmt0 relapse, ///
    model(gee) timespec(categorical) timebasecat(1) ///
    categorical(tx) interaction(tx) replace nolog collect

regtab, xlsx("`xlsx'") sheet("Visit waves") ///
    title("Treatment by visit wave") ///
    stats(n) relabel

capture confirm file "`xlsx'"
if _rc exit _rc
quietly import excel using "`xlsx'", sheet("Visit waves") clear allstring
local found_wave_label = 0
ds
foreach v of varlist `r(varlist)' {
    quietly count if strpos(`v', "NTZ-like x Visit wave: Month 6") > 0
    if r(N) > 0 local found_wave_label = 1
}
assert `found_wave_label' == 1
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
