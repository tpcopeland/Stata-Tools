/*  demo_eplot.do - Generate screenshots for eplot v2.0.0

    Produces 3 graphs:
      1. Multi-model coefficient comparison -> multi_model.png
      2. Forest plot with values annotation  -> forest_values.png
      3. Grouped coefficient plot            -> grouped_coefplot.png
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "eplot/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload command ---
capture program drop eplot _eplot_parse_mode _eplot_estimates _eplot_data
capture program drop _eplot_matrix _eplot_apply_coeflabels
capture program drop _eplot_apply_keep _eplot_apply_drop _eplot_apply_rename
capture program drop _eplot_process_groups _eplot_process_headers
quietly run eplot/eplot.ado

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
    subtitle("Three model specifications compared") ///
    scheme(plotplainblind)

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
    title("Treatment Effect on Organ-Specific Outcomes") ///
    note("Diamonds represent pooled estimates. Boxes proportional to study weight.") ///
    scheme(plotplainblind)

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
    title("Predictors of Foreign Manufacture") ///
    scheme(plotplainblind)

graph export "`pkg_dir'/grouped_coefplot.png", replace width(1400)
capture graph close _all

* --- Cleanup ---
estimates drop _all
clear
