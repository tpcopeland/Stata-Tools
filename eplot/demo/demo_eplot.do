/*  demo_eplot.do - Generate screenshots for eplot

    Produces 2 output types:
      1. Graph (coefficient plot from regression) -> .png
      2. Graph (forest plot from data) -> .png
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "eplot/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload command ---
capture program drop eplot
capture program drop _eplot_parse_mode
capture program drop _eplot_estimates
capture program drop _eplot_data
capture program drop _eplot_matrix
capture program drop _eplot_draw
quietly run eplot/eplot.ado

* --- 1. Coefficient plot from regression ---
sysuse auto, clear
regress price mpg weight length foreign
eplot ., drop(_cons) ///
    title("Price Determinants") ///
    scheme(plotplainblind)
graph export "`pkg_dir'/coefficient_plot.png", replace width(1200)
capture graph close _all

* --- 2. Forest plot from data ---
clear
input str20 study double(es lci uci weight)
"Smith 2020"    -0.16  -0.36  0.03  15.2
"Jones 2021"    -0.33  -0.54 -0.12  18.4
"Brown 2022"    -0.09  -0.25  0.06  22.1
"Davis 2022"    -0.28  -0.51 -0.05  14.6
"Wilson 2023"   -0.39  -0.65 -0.12  12.8
"Taylor 2024"   -0.21  -0.38 -0.04  17.0
"Overall"       -0.24  -0.34 -0.13   .
end
gen byte type = cond(study == "Overall", 5, 1)

eplot es lci uci, labels(study) weights(weight) type(type) ///
    title("Treatment Effect Meta-Analysis") ///
    scheme(plotplainblind)
graph export "`pkg_dir'/forest_plot.png", replace width(1200)
capture graph close _all

* --- Cleanup ---
clear
