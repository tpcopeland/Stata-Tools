/*  demo_iivw.do - Generate screenshots for iivw v1.0.5

    Produces 3 output types:
      1. Console output (FIPTIW workflow: weighting + outcome model) -> .smcl
      2. Excel table (IIW vs FIPTIW comparison via collect + regtab) -> .xlsx
      3. HTML documentation (logdoc rendering of console output) -> .html

    Run from the Stata-Tools repository root:
      stata-mp -b do iivw/demo/demo_iivw.do
*/

version 16.0
set more off
set varabbrev off
set linesize 250

**# Paths
local repo_dir = regexr("`c(pwd)'", "/+$", "")
local pkg_dir "iivw/demo"
capture mkdir "`pkg_dir'"

**# Graph scheme
capture set scheme plotplainblind

**# Install packages from local source
capture ado uninstall iivw
quietly net install iivw, from("`repo_dir'/iivw") replace
capture ado uninstall tabtools
quietly net install tabtools, from("`repo_dir'/tabtools") replace

**# Generate synthetic longitudinal data
* 200 patients, 3-8 visits each, irregular timing
* Sicker patients visit more often (informative visit process)
clear
set seed 20260226

* Create patient-level data
quietly set obs 200
gen long patid = _n
gen byte drug = runiform() < 0.45
gen double age = 40 + 20 * runiform()
gen byte female = runiform() < 0.55
gen double severity_bl = rnormal(4, 1.5)
replace severity_bl = max(0, min(10, severity_bl))

* Assign number of visits (sicker patients get more)
gen int n_visits = 3 + floor(severity_bl / 2) + floor(2 * runiform())
replace n_visits = min(n_visits, 10)

* Expand to panel
expand n_visits
bysort patid: gen int visit_n = _n

* Visit timing: irregular, based on severity
bysort patid: gen double months = 0 if _n == 1
bysort patid: replace months = months[_n-1] + ///
    max(0.5, 6 / (1 + 0.3 * severity_bl) + rnormal(0, 1)) if _n > 1
replace months = round(months, 0.1)

* Time-varying severity (evolves over time, treatment slows progression)
gen double severity = severity_bl + 0.05 * months ///
    - 0.8 * drug + rnormal(0, 0.5)
replace severity = max(0, min(10, severity))

* Binary relapse indicator (higher severity -> more likely)
gen byte relapse = runiform() < invlogit(-2 + 0.3 * severity)

* Outcome: cognitive score (higher is better, treatment helps)
gen double score = 50 - 0.1 * months + 2 * drug ///
    - 1.5 * severity + 0.5 * female + rnormal(0, 3)

label variable patid "Patient ID"
label variable drug "Treatment (0=control, 1=treated)"
label variable age "Age at baseline"
label variable female "Female sex"
label variable severity_bl "Baseline severity (0-10)"
label variable months "Months since baseline"
label variable severity "Current severity (time-varying)"
label variable relapse "Recent relapse (0/1)"
label variable score "Cognitive score (outcome)"

* 3-level treatment for categorical demonstration
gen byte treatment = cond(drug == 0, 0, cond(severity_bl < 5, 1, 2))
label define treat_lbl 0 "Placebo" 1 "Low dose" 2 "High dose", replace
label values treatment treat_lbl
label variable treatment "Treatment arm"

**# Console output: Full FIPTIW workflow
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg

* # Package overview
noisily iivw

* # Step 1: Compute FIPTIW weights
noisily iivw_weight, id(patid) time(months) ///
    visit_cov(severity relapse) ///
    treat(drug) treat_cov(age female severity_bl) ///
    truncate(1 99) nolog

* # Step 2: Inspect weight distribution
noisily summarize _iivw_weight, detail

* # Step 3: Fit weighted outcome model (GEE)
noisily iivw_fit score drug age female severity_bl, ///
    model(gee) timespec(linear) nolog

log close demo

**# Excel table: IIW vs FIPTIW comparison
collect clear

* Model 1: IIW only
iivw_weight, id(patid) time(months) ///
    visit_cov(severity relapse) truncate(1 99) replace nolog
collect: iivw_fit score drug age female severity_bl, ///
    model(gee) timespec(linear) nolog

* Model 2: FIPTIW
iivw_weight, id(patid) time(months) ///
    visit_cov(severity relapse) ///
    treat(drug) treat_cov(age female severity_bl) ///
    truncate(1 99) replace nolog
collect: iivw_fit score drug age female severity_bl, ///
    model(gee) timespec(linear) nolog

* Model 3: FIPTIW with treatment-time interaction (ns(3))
iivw_weight, id(patid) time(months) ///
    visit_cov(severity relapse) ///
    treat(drug) treat_cov(age female severity_bl) ///
    truncate(1 99) replace nolog
collect: iivw_fit score drug age female severity_bl, ///
    model(gee) timespec(ns(3)) interaction(drug) nolog

* Model 4: FIPTIW with categorical treatment
iivw_weight, id(patid) time(months) ///
    visit_cov(severity relapse) ///
    treat(drug) treat_cov(age female severity_bl) ///
    truncate(1 99) replace nolog
collect: iivw_fit score treatment age female severity_bl, ///
    model(gee) timespec(ns(3)) categorical(treatment) interaction(treatment) replace nolog

* Export formatted table
regtab, xlsx(`pkg_dir'/iivw_results.xlsx) sheet(Comparison) ///
    models(IIW \ FIPTIW \ FIPTIW-IX \ FIPTIW-CAT) ///
    title(IIW vs FIPTIW: Cognitive Score) stats(n) noint

**# Render HTML documentation with logdoc
capture ado uninstall logdoc
quietly net install logdoc, from("`repo_dir'/logdoc") replace

logdoc using "`pkg_dir'/console_output.smcl", ///
    output("`pkg_dir'/console_output.html") ///
    title("iivw: Inverse Intensity of Visit Weighting") ///
    date("May 2026") ///
    highlight tables ///
    replace quiet

**# Cleanup
clear
