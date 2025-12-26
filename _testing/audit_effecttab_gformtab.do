/*******************************************************************************
* audit_effecttab_gformtab.do
*
* Purpose: Expert-level audit of effecttab and gformtab Excel output
*          Creates test files for Python analysis
*
* Author: Claude (Audit)
* Date: 2025-12-21
*******************************************************************************/

clear all
set more off
version 17.0

* Try to detect path from current working directory
    capture confirm file "_testing"
    if _rc == 0 {
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "data"
        if _rc == 0 {
            global STATA_TOOLS_PATH "`c(pwd)'/.."
        }
        else {
            global STATA_TOOLS_PATH "/home/`c(username)'/Stata-Tools"
        }
    }
global TESTING_DIR "${STATA_TOOLS_PATH}/_testing"
global AUDIT_DIR "${TESTING_DIR}/audit_output"

* Create audit output directory
capture mkdir "${AUDIT_DIR}"

* Reinstall package
capture net uninstall regtab
net install regtab, from("${STATA_TOOLS_PATH}/regtab")

display as text _n "{hline 70}"
display as text "EXPERT AUDIT: effecttab and gformtab"
display as text "{hline 70}"

* =============================================================================
* SECTION 1: EFFECTTAB TESTS
* =============================================================================

display as text _n "SECTION 1: Creating effecttab test files for Python analysis"

* Create synthetic data
clear
set seed 12345
set obs 1500

* Covariates
gen age = 25 + int(runiform() * 50)
gen female = runiform() < 0.52
gen education = 1 + int(runiform() * 4)
gen income = 20000 + runiform() * 80000

* Treatment with good overlap
gen ps = invlogit(-1 + 0.01*age + 0.3*female + 0.05*education + 0.00001*income)
gen treatment = runiform() < ps

* Outcomes
gen prob_y = invlogit(-1.5 + 0.5*treatment + 0.005*age - 0.15*female + 0.08*education)
gen outcome = runiform() < prob_y
gen outcome_cont = 100 + 10*treatment + 0.3*age - 5*female + rnormal(0, 15)

* Multi-level treatment
gen treat4 = int(runiform() * 4)
label define treat4_lbl 0 "Placebo" 1 "Low" 2 "Medium" 3 "High"
label values treat4 treat4_lbl

label variable age "Age (years)"
label variable female "Female"
label variable treatment "Treatment"
label variable outcome "Binary outcome"

save "${AUDIT_DIR}/_audit_data.dta", replace

* -----------------------------------------------------------------------------
* Test 1: Basic teffects IPW - single model
* -----------------------------------------------------------------------------
display as text "  Test 1: Basic teffects IPW"
use "${AUDIT_DIR}/_audit_data.dta", clear

collect clear
collect: teffects ipw (outcome) (treatment age female education), ate

effecttab, xlsx("${AUDIT_DIR}/effecttab_01_basic.xlsx") sheet("ATE") ///
    effect("ATE") title("Test 1: Basic IPW Estimate")

display as result "    Created: effecttab_01_basic.xlsx"

* -----------------------------------------------------------------------------
* Test 2: teffects with clean option
* -----------------------------------------------------------------------------
display as text "  Test 2: teffects with clean option"
use "${AUDIT_DIR}/_audit_data.dta", clear

collect clear
collect: teffects ipw (outcome) (treatment age female), ate

effecttab, xlsx("${AUDIT_DIR}/effecttab_02_clean.xlsx") sheet("ATE") ///
    effect("ATE") title("Test 2: With Clean Option") clean

display as result "    Created: effecttab_02_clean.xlsx"

* -----------------------------------------------------------------------------
* Test 3: teffects PO means
* -----------------------------------------------------------------------------
display as text "  Test 3: teffects PO means"
use "${AUDIT_DIR}/_audit_data.dta", clear

collect clear
collect: teffects ipw (outcome) (treatment age female), pomeans

effecttab, xlsx("${AUDIT_DIR}/effecttab_03_pomeans.xlsx") sheet("POMeans") ///
    effect("Pr(Y)") title("Test 3: Potential Outcome Means") clean

display as result "    Created: effecttab_03_pomeans.xlsx"

* -----------------------------------------------------------------------------
* Test 4: Multi-model comparison (IPTW vs AIPW)
* -----------------------------------------------------------------------------
display as text "  Test 4: Multi-model comparison"
use "${AUDIT_DIR}/_audit_data.dta", clear

collect clear
collect: teffects ipw (outcome) (treatment age female), ate
collect: teffects aipw (outcome age female) (treatment age female), ate

effecttab, xlsx("${AUDIT_DIR}/effecttab_04_multimodel.xlsx") sheet("Compare") ///
    models("IPTW \ AIPW") effect("ATE") title("Test 4: IPTW vs AIPW") clean

display as result "    Created: effecttab_04_multimodel.xlsx"

* -----------------------------------------------------------------------------
* Test 5: Margins predictions
* -----------------------------------------------------------------------------
display as text "  Test 5: Margins predictions"
use "${AUDIT_DIR}/_audit_data.dta", clear

logit outcome i.treatment age female education

collect clear
collect: margins treatment

effecttab, xlsx("${AUDIT_DIR}/effecttab_05_margins_pred.xlsx") sheet("Pred") ///
    type(margins) effect("Pr(Y)") title("Test 5: Predicted Probabilities")

display as result "    Created: effecttab_05_margins_pred.xlsx"

* -----------------------------------------------------------------------------
* Test 6: Margins dydx (AME)
* -----------------------------------------------------------------------------
display as text "  Test 6: Margins dydx (AME)"
use "${AUDIT_DIR}/_audit_data.dta", clear

logit outcome i.treatment age female education

collect clear
collect: margins, dydx(treatment age female)

effecttab, xlsx("${AUDIT_DIR}/effecttab_06_margins_ame.xlsx") sheet("AME") ///
    type(margins) effect("AME") title("Test 6: Average Marginal Effects")

display as result "    Created: effecttab_06_margins_ame.xlsx"

* -----------------------------------------------------------------------------
* Test 7: Margins contrasts (risk difference)
* -----------------------------------------------------------------------------
display as text "  Test 7: Margins contrasts"
use "${AUDIT_DIR}/_audit_data.dta", clear

logit outcome i.treatment age female

collect clear
collect: margins r.treatment

effecttab, xlsx("${AUDIT_DIR}/effecttab_07_margins_rd.xlsx") sheet("RD") ///
    type(margins) effect("RD") title("Test 7: Risk Difference")

display as result "    Created: effecttab_07_margins_rd.xlsx"

* -----------------------------------------------------------------------------
* Test 8: Multi-level treatment
* -----------------------------------------------------------------------------
display as text "  Test 8: Multi-level treatment"
use "${AUDIT_DIR}/_audit_data.dta", clear

collect clear
collect: teffects ipw (outcome) (treat4 age female), ate

effecttab, xlsx("${AUDIT_DIR}/effecttab_08_multilevel.xlsx") sheet("Multi") ///
    effect("ATE") title("Test 8: Multi-level Treatment Effects") clean

display as result "    Created: effecttab_08_multilevel.xlsx"

* -----------------------------------------------------------------------------
* Test 9: Continuous outcome (RA)
* -----------------------------------------------------------------------------
display as text "  Test 9: Continuous outcome"
use "${AUDIT_DIR}/_audit_data.dta", clear

collect clear
collect: teffects ra (outcome_cont age female) (treatment), ate

effecttab, xlsx("${AUDIT_DIR}/effecttab_09_continuous.xlsx") sheet("Cont") ///
    effect("ATE") title("Test 9: Continuous Outcome") clean

display as result "    Created: effecttab_09_continuous.xlsx"

* -----------------------------------------------------------------------------
* Test 10: Custom CI separator
* -----------------------------------------------------------------------------
display as text "  Test 10: Custom CI separator"
use "${AUDIT_DIR}/_audit_data.dta", clear

collect clear
collect: teffects ipw (outcome) (treatment age female), ate

effecttab, xlsx("${AUDIT_DIR}/effecttab_10_custom_sep.xlsx") sheet("Custom") ///
    effect("ATE") sep(" to ") title("Test 10: Custom CI Separator")

display as result "    Created: effecttab_10_custom_sep.xlsx"

* =============================================================================
* SECTION 2: GFORMTAB TESTS
* =============================================================================

display as text _n "SECTION 2: Creating gformtab test files for Python analysis"

* Mock gformula program
capture program drop mock_gformula
program define mock_gformula, rclass
    version 16.0
    syntax, tce(real) nde(real) nie(real) pm(real) cde(real) ///
            [se_tce(real 0.05) se_nde(real 0.04) se_nie(real 0.03) ///
             se_pm(real 0.02) se_cde(real 0.04)]

    return scalar tce = `tce'
    return scalar nde = `nde'
    return scalar nie = `nie'
    return scalar pm = `pm'
    return scalar cde = `cde'
    return scalar se_tce = `se_tce'
    return scalar se_nde = `se_nde'
    return scalar se_nie = `se_nie'
    return scalar se_pm = `se_pm'
    return scalar se_cde = `se_cde'

    matrix ci_normal = J(5, 2, .)
    matrix ci_normal[1,1] = `tce' - 1.96*`se_tce'
    matrix ci_normal[1,2] = `tce' + 1.96*`se_tce'
    matrix ci_normal[2,1] = `nde' - 1.96*`se_nde'
    matrix ci_normal[2,2] = `nde' + 1.96*`se_nde'
    matrix ci_normal[3,1] = `nie' - 1.96*`se_nie'
    matrix ci_normal[3,2] = `nie' + 1.96*`se_nie'
    matrix ci_normal[4,1] = `pm' - 1.96*`se_pm'
    matrix ci_normal[4,2] = `pm' + 1.96*`se_pm'
    matrix ci_normal[5,1] = `cde' - 1.96*`se_cde'
    matrix ci_normal[5,2] = `cde' + 1.96*`se_cde'

    matrix ci_percentile = J(5, 2, .)
    forvalues i = 1/5 {
        matrix ci_percentile[`i',1] = ci_normal[`i',1] - 0.02
        matrix ci_percentile[`i',2] = ci_normal[`i',2] + 0.02
    }

    matrix ci_bc = J(5, 2, .)
    forvalues i = 1/5 {
        matrix ci_bc[`i',1] = ci_normal[`i',1] - 0.01
        matrix ci_bc[`i',2] = ci_normal[`i',2] + 0.01
    }

    matrix ci_bca = J(5, 2, .)
    forvalues i = 1/5 {
        matrix ci_bca[`i',1] = ci_normal[`i',1] - 0.015
        matrix ci_bca[`i',2] = ci_normal[`i',2] + 0.015
    }
end

* -----------------------------------------------------------------------------
* Test 1: Basic gformtab
* -----------------------------------------------------------------------------
display as text "  Test 1: Basic gformtab"
mock_gformula, tce(0.150) nde(0.100) nie(0.050) pm(0.333) cde(0.085) ///
    se_tce(0.030) se_nde(0.025) se_nie(0.015) se_pm(0.080) se_cde(0.025)

gformtab, xlsx("${AUDIT_DIR}/gformtab_01_basic.xlsx") sheet("Mediation") ///
    title("Test 1: Basic Mediation Analysis")

display as result "    Created: gformtab_01_basic.xlsx"

* -----------------------------------------------------------------------------
* Test 2: Custom labels
* -----------------------------------------------------------------------------
display as text "  Test 2: Custom labels"
mock_gformula, tce(0.180) nde(0.120) nie(0.060) pm(0.333) cde(0.100)

gformtab, xlsx("${AUDIT_DIR}/gformtab_02_labels.xlsx") sheet("Custom") ///
    labels("Total \ Direct \ Indirect \ % Mediated \ Controlled") ///
    title("Test 2: Custom Labels")

display as result "    Created: gformtab_02_labels.xlsx"

* -----------------------------------------------------------------------------
* Test 3: Percentile CI
* -----------------------------------------------------------------------------
display as text "  Test 3: Percentile CI"
mock_gformula, tce(0.200) nde(0.130) nie(0.070) pm(0.350) cde(0.110)

gformtab, xlsx("${AUDIT_DIR}/gformtab_03_percentile.xlsx") sheet("Pct") ///
    ci(percentile) title("Test 3: Percentile CI")

display as result "    Created: gformtab_03_percentile.xlsx"

* -----------------------------------------------------------------------------
* Test 4: High precision (4 decimals)
* -----------------------------------------------------------------------------
display as text "  Test 4: High precision"
mock_gformula, tce(0.1523) nde(0.1012) nie(0.0511) pm(0.3355) cde(0.0856)

gformtab, xlsx("${AUDIT_DIR}/gformtab_04_precision.xlsx") sheet("Dec4") ///
    decimal(4) title("Test 4: 4 Decimal Precision")

display as result "    Created: gformtab_04_precision.xlsx"

* -----------------------------------------------------------------------------
* Test 5: Negative effects
* -----------------------------------------------------------------------------
display as text "  Test 5: Negative effects"
mock_gformula, tce(-0.120) nde(-0.080) nie(-0.040) pm(0.333) cde(-0.070) ///
    se_tce(0.040) se_nde(0.030) se_nie(0.020) se_pm(0.100) se_cde(0.030)

gformtab, xlsx("${AUDIT_DIR}/gformtab_05_negative.xlsx") sheet("Negative") ///
    title("Test 5: Negative (Protective) Effects")

display as result "    Created: gformtab_05_negative.xlsx"

* -----------------------------------------------------------------------------
* Test 6: Large effects
* -----------------------------------------------------------------------------
display as text "  Test 6: Large effects"
mock_gformula, tce(0.450) nde(0.280) nie(0.170) pm(0.378) cde(0.250) ///
    se_tce(0.080) se_nde(0.060) se_nie(0.050) se_pm(0.100) se_cde(0.060)

gformtab, xlsx("${AUDIT_DIR}/gformtab_06_large.xlsx") sheet("Large") ///
    title("Test 6: Large Effects")

display as result "    Created: gformtab_06_large.xlsx"

* -----------------------------------------------------------------------------
* Test 7: Small effects (near zero)
* -----------------------------------------------------------------------------
display as text "  Test 7: Small effects"
mock_gformula, tce(0.020) nde(0.015) nie(0.005) pm(0.250) cde(0.012) ///
    se_tce(0.030) se_nde(0.025) se_nie(0.015) se_pm(0.150) se_cde(0.025)

gformtab, xlsx("${AUDIT_DIR}/gformtab_07_small.xlsx") sheet("Small") ///
    decimal(4) title("Test 7: Small Effects")

display as result "    Created: gformtab_07_small.xlsx"

* -----------------------------------------------------------------------------
* Test 8: All options combined
* -----------------------------------------------------------------------------
display as text "  Test 8: All options combined"
mock_gformula, tce(0.175) nde(0.115) nie(0.060) pm(0.343) cde(0.095) ///
    se_tce(0.035) se_nde(0.028) se_nie(0.018) se_pm(0.085) se_cde(0.028)

gformtab, xlsx("${AUDIT_DIR}/gformtab_08_full.xlsx") sheet("Complete") ///
    ci(percentile) effect("RD") decimal(4) ///
    labels("Total Causal Effect \ Natural Direct Effect \ Natural Indirect Effect \ Proportion Mediated \ Controlled Direct Effect") ///
    title("Test 8: Complete Analysis with All Options")

display as result "    Created: gformtab_08_full.xlsx"

* Clean up
capture program drop mock_gformula
capture erase "${AUDIT_DIR}/_audit_data.dta"

display as text _n "{hline 70}"
display as text "AUDIT FILES CREATED SUCCESSFULLY"
display as text "Output directory: ${AUDIT_DIR}"
display as text "{hline 70}"
