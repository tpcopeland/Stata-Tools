/*  demo_eplot.do - Generate screenshots for eplot

    Produces 8 graphs:
      1. Multi-model coefficient comparison     -> multi_model.png
      2. Forest plot with values annotation      -> forest_values.png
      3. Grouped coefficient plot                -> grouped_coefplot.png
      4. Lancet style preset                     -> lancet_style.png
      5. Significance coloring                   -> sigcolors.png
      6. Matrix mode                             -> matrix_mode.png
      7. Single-model values demo                -> coef_values.png
      8. Meta-analysis with heterogeneity        -> meta_heterogeneity.png
*/

version 16.0
set more off
set varabbrev off
set linesize 250

* --- Paths ---
if fileexists("eplot/eplot.ado") {
    local cmd_dir "eplot"
    local pkg_dir "eplot/demo"
}
else if fileexists("../eplot.ado") {
    local cmd_dir ".."
    local pkg_dir "."
}
else if fileexists("eplot.ado") {
    local cmd_dir "."
    local pkg_dir "demo"
}
else {
    display as error "Could not locate eplot.ado relative to `c(pwd)'"
    exit 601
}

capture mkdir "`pkg_dir'"

* --- Set default scheme ---
set scheme plotplainblind

* --- Load and reload command ---
capture program drop eplot _eplot_parse_mode _eplot_estimates _eplot_data
capture program drop _eplot_matrix _eplot_apply_coeflabels
capture program drop _eplot_apply_keep _eplot_apply_drop _eplot_apply_rename
capture program drop _eplot_process_groups _eplot_process_headers
quietly run "`cmd_dir'/eplot.ado"

* ============================================================
* 1. Multi-model coefficient comparison
* ============================================================

sysuse auto, clear

* Model 1: Base specification
quietly regress price mpg weight foreign
estimates store base

* Model 2: Add vehicle dimensions
quietly regress price mpg weight length headroom foreign
estimates store extended

* Model 3: Add condition indicators
quietly regress price mpg weight length headroom foreign rep78
estimates store full

eplot base extended full, drop(_cons) ///
    modellabels("Base" "Extended" "Full") ///
    coeflabels(mpg = "Miles per Gallon" ///
               weight = "Vehicle Weight" ///
               length = "Body Length" ///
               headroom = "Headroom" ///
               foreign = "Foreign Make" ///
               rep78 = "Repair Record") ///
    cicap ///
    title("Determinants of Car Price") ///
    subtitle("Three model specifications compared")

graph export "`pkg_dir'/multi_model.png", replace width(1400)
capture graph close _all

* ============================================================
* 2. Forest plot with values annotation and subgroups
* ============================================================

clear
input str24 study double(es lci uci weight) byte type
"Cardiovascular"         .     .     .    .  0
"  Chen 2019"         0.72  0.55  0.94  16.2  1
"  Patel 2020"        0.85  0.71  1.02  22.4  1
"  Yamamoto 2021"     0.68  0.49  0.94  12.8  1
"  Subtotal"          0.76  0.65  0.89   .    3
""                     .     .     .    .  6
"Respiratory"          .     .     .    .  0
"  Garcia 2020"       0.91  0.74  1.12  18.6  1
"  Andersson 2021"    0.79  0.62  1.01  14.9  1
"  Li 2022"           0.83  0.69  1.00  20.1  1
"  Subtotal"          0.84  0.74  0.96   .    3
""                     .     .     .    .  6
"Overall"             0.80  0.72  0.88   .    5
end

eplot es lci uci, labels(study) weights(weight) type(type) ///
    values vformat(%4.2f) nonull ///
    effect("Hazard Ratio (95% CI)") ///
    title("Treatment Effect on Organ-Specific Outcomes")

graph export "`pkg_dir'/forest_values.png", replace width(1400)
capture graph close _all

* ============================================================
* 3. Grouped coefficient plot
* ============================================================

sysuse auto, clear

quietly logit foreign mpg weight length headroom trunk turn

eplot ., drop(_cons) eform ///
    coeflabels(mpg = "Miles per Gallon" ///
               weight = "Vehicle Weight (lbs)" ///
               length = "Body Length (in)" ///
               headroom = "Headroom (in)" ///
               trunk = "Trunk Space (ft³)" ///
               turn = "Turning Circle (ft)") ///
    groups(mpg weight = "Efficiency & Mass" ///
           length headroom trunk = "Dimensions" ///
           turn = "Handling") ///
    cicap mcolor(forest_green) ///
    effect("Odds Ratio") ///
    title("Predictors of Foreign Manufacture")

graph export "`pkg_dir'/grouped_coefplot.png", replace width(1400)
capture graph close _all

* ============================================================
* 4. Lancet style preset
* ============================================================

sysuse auto, clear

quietly logit foreign mpg weight length

eplot ., noconstant eform ///
    style(lancet) ///
    coeflabels(mpg = "Miles per Gallon" ///
               weight = "Vehicle Weight" ///
               length = "Body Length") ///
    title("Lancet Style Preset")

graph export "`pkg_dir'/lancet_style.png", replace width(1400)
capture graph close _all

* ============================================================
* 5. Significance coloring
* ============================================================

sysuse auto, clear

quietly regress price mpg weight length turn headroom foreign

eplot ., noconstant ///
    sigcolors sigcolor(navy) ///
    cicap stars ///
    coeflabels(mpg = "Miles per Gallon" ///
               weight = "Vehicle Weight" ///
               length = "Body Length" ///
               turn = "Turning Circle" ///
               headroom = "Headroom" ///
               foreign = "Foreign Make") ///
    title("Significance-Coded Coefficients")

graph export "`pkg_dir'/sigcolors.png", replace width(1400)
capture graph close _all

* ============================================================
* 6. Matrix mode
* ============================================================

matrix R = (1.82, 1.21, 2.74 \ 0.73, 0.54, 0.99 \ 1.45, 1.08, 1.95 \ 1.12, 0.78, 1.61)
matrix rownames R = "Drug_A" "Drug_B" "Drug_C" "Drug_D"

eplot, matrix(R) eform ///
    effect("Odds Ratio (95% CI)") ///
    coeflabels(Drug_A = "Drug A (experimental)" ///
               Drug_B = "Drug B (standard)" ///
               Drug_C = "Drug C (combination)" ///
               Drug_D = "Drug D (low-dose)") ///
    cicap ///
    title("Treatment Odds Ratios from Matrix Input")

graph export "`pkg_dir'/matrix_mode.png", replace width(1400)
capture graph close _all

* ============================================================
* 7. Single-model coefficient plot with values annotation
* ============================================================

sysuse auto, clear

quietly regress price mpg weight length foreign

eplot ., noconstant ///
    values cicap ///
    coeflabels(mpg = "Miles per Gallon" ///
               weight = "Vehicle Weight" ///
               length = "Body Length" ///
               foreign = "Foreign Make") ///
    effect("Coefficient (95% CI)") ///
    title("Single-Model Coefficients with Values")

graph export "`pkg_dir'/coef_values.png", replace width(1400)
capture graph close _all

* ============================================================
* 8. Meta-analysis with heterogeneity and prediction intervals
* ============================================================

clear
input str20 study double(es lci uci pi_lci pi_uci weight) byte type
"Smith 2018"   -0.42  -0.78  -0.06  -1.15   0.31  12.3  1
"Jones 2019"   -0.31  -0.58  -0.04  -1.04   0.42  16.8  1
"Brown 2020"   -0.18  -0.41   0.05  -0.91   0.55  21.5  1
"Lee 2021"     -0.55  -0.93  -0.17  -1.28   0.18  10.2  1
"Garcia 2022"  -0.27  -0.49  -0.05  -1.00   0.46  19.1  1
"Patel 2023"   -0.09  -0.35   0.17  -0.82   0.64  20.1  1
"Overall"      -0.28  -0.41  -0.15   .       .      .    5
end

eplot es lci uci, labels(study) weights(weight) type(type) ///
    values vformat(%4.2f) ///
    pi(pi_lci pi_uci) ///
    i2("42.1%") tau2("0.021") qstat("8.63, df=5, p=0.125") ///
    effect("Mean Difference (95% CI)") ///
    favors("Favors Treatment" "Favors Control") ///
    title("Meta-Analysis with Prediction Intervals")

graph export "`pkg_dir'/meta_heterogeneity.png", replace width(1400)
capture graph close _all

* --- Cleanup ---
estimates drop _all
clear
