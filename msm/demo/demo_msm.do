/*  demo_msm.do - Demo output for msm 2.0.0 (estimator core + companions)

    Produces:
      1. Console output (prepare, weight, longitudinal diagnostics)
         -> console_pipeline.log -> console_pipeline.md via logdoc
      2. Console output (fit, tables, prediction, E-value)
         -> console_results.log -> console_results.md via logdoc
      3. Graph: counterfactual cumulative incidence (twoway on the
         msm_predict frame)                          -> survival_plot.png
      4. Graph: risk difference by period (eplot)    -> rd_forest.png
      5. Graph: analysis-weight distribution (psdash) -> weight_plot.png
      6. Graph: Love plot of the denominator covariates (psdash)
                                                     -> balance_plot.png
      7. Excel: outcome model (regtab) and risk differences (effecttab)
                                                     -> msm_tables.xlsx

    Run from the repository root (stata-mp -b do msm/demo/demo_msm.do), from
    msm/, or from msm/demo/. Packages are installed into a throwaway PLUS and
    PERSONAL directory; the user's ado tree is never touched.
*/

version 16.0
capture log close _all
set more off
set varabbrev off
set linesize 120

**# Paths
* The package root is msm/; companions are its siblings. Only a TRAILING
* "/demo" is stripped, so a working directory such as projects/demos/repo/... is
* left intact (1.4.x stripped the first "/demo" anywhere in the path).
local here "`c(pwd)'"
if regexm("`here'", "/demo$") & fileexists("`here'/demo_msm.do") {
    local pkg_root = regexr("`here'", "/demo$", "")
}
else if fileexists("`here'/msm/demo/demo_msm.do") {
    local pkg_root "`here'/msm"
}
else if fileexists("`here'/demo/demo_msm.do") {
    local pkg_root "`here'"
}
else {
    display as error "run demo_msm.do from the repository root, msm/, or msm/demo/"
    exit 601
}
local demo_dir "`pkg_root'/demo"
local repo_root = regexr("`pkg_root'", "/msm$", "")
foreach p in msm tabtools psdash eplot qba tc_schemes logdoc {
    capture confirm file "`repo_root'/`p'/`p'.pkg"
    if _rc {
        display as error "package directory `repo_root'/`p' not found"
        exit 601
    }
}

**# Isolated install
tempfile sandbox
local plus "`sandbox'_plus"
local personal "`sandbox'_personal"
capture mkdir "`plus'"
capture mkdir "`personal'"
sysdir set PLUS "`plus'"
sysdir set PERSONAL "`personal'"
foreach p in msm tabtools psdash eplot qba tc_schemes logdoc {
    quietly net install `p', from("`repo_root'/`p'") replace
}
set scheme white_tableau
assert "`c(scheme)'" == "white_tableau"

use "`pkg_root'/msm_example.dta", clear

**# Console: preparation, weighting, longitudinal diagnostics
log using "`demo_dir'/console_pipeline.log", replace text name(pipeline) nomsg

* # Prepare, weight and diagnose

noisily msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) censor(censored) ///
    covariates(biomarker comorbidity) baseline_covariates(age sex)

noisily msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
    treat_n_cov(age sex) censor_d_cov(biomarker comorbidity age sex) ///
    censor_n_cov(age sex) truncate(1 99) nolog

* ## Per-period weights and overlap (psdash reads the msm contract)

noisily psdash combined

* ## Balance by period and prior treatment, censoring balance, positivity

noisily msm_diagnose, threshold(0.1)

log close pipeline

**## Weight and balance graphs
* Age and sex are stabilized-numerator covariates (treat_n_cov), so the
* weights keep their distribution on purpose; the Love plot shows only the
* denominator covariates that weighting is meant to balance.
psdash weights treatment _msm_ps if _msm_decision_risk, wvar(_msm_weight) ///
    graph graphoptions(title("Stabilized analysis weight (treatment x censoring)"))
quietly graph export "`demo_dir'/weight_plot.png", width(1400) replace
capture graph close _all

label variable biomarker "Biomarker"
label variable comorbidity "Comorbidity"
psdash balance treatment _msm_ps if _msm_decision_risk, ///
    covariates(biomarker comorbidity) wvar(_msm_weight) loveplot ///
    title("Balance of the denominator covariates")
quietly graph export "`demo_dir'/balance_plot.png", width(1400) replace
capture graph close _all

**# Console: outcome model, tables, prediction, E-value
* Write the workbook from inside demo/ so the transcripts print a relative path.
quietly cd "`demo_dir'"
local tables_xlsx "msm_tables.xlsx"
capture erase "`tables_xlsx'"
log using "`demo_dir'/console_results.log", replace text name(results) nomsg

* # Fit, tabulate and predict

collect clear
noisily collect: msm_fit, model(logistic) outcome_cov(age sex) ///
    period_spec(quadratic) nolog
noisily regtab, xlsx("`tables_xlsx'") sheet("Outcome model") coef(OR) ///
    title("Weighted pooled logistic MSM")

* ## Standardized cumulative incidence and risk differences

noisily msm_predict, times(1 3 5 7 9) difference samples(1000) ///
    seed(12345) frame(pred, replace)
matrix RD = r(rd)
matrix rownames RD = "Period 1" "Period 3" "Period 5" "Period 7" "Period 9"
noisily effecttab, from(RD) effect("Risk difference") digits(3) ///
    xlsx("`tables_xlsx'") sheet("Risk differences") ///
    title("Always minus never treated")

* ## E-value for unmeasured confounding

noisily qba_confound, from_model coef(treatment) evalue measure(HR)

log close results
quietly cd "`here'"

**# Prediction graphs
eplot if strategy == "rd", frame(pred) values dp(3) xline(0) ///
    title("Risk difference, always minus never treated") ///
    effect("Risk difference (95% MC interval)")
quietly graph export "`demo_dir'/rd_forest.png", width(1400) replace
capture graph close _all

frame pred {
    twoway (rarea ll ul horizon if strategy == "never", pstyle(p1) color(%25) lwidth(none)) ///
        (connected estimate horizon if strategy == "never", pstyle(p1)) ///
        (rarea ll ul horizon if strategy == "always", pstyle(p2) color(%25) lwidth(none)) ///
        (connected estimate horizon if strategy == "always", pstyle(p2)), ///
        legend(order(2 "Never treated" 4 "Always treated") pos(6) rows(1)) ///
        ytitle("Cumulative incidence") xtitle("Period") ///
        title("Counterfactual cumulative incidence") ///
        note("Bands: 95% Monte Carlo intervals, 1,000 draws")
}
quietly graph export "`demo_dir'/survival_plot.png", width(1400) replace
capture graph close _all

**# Convert console logs to markdown via logdoc
foreach f in console_pipeline console_results {
    logdoc using "`demo_dir'/`f'.log", output("`demo_dir'/`f'.md") ///
        format(md) replace quiet
}

capture frame drop pred
clear
