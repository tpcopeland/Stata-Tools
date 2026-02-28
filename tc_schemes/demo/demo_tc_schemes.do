/*  demo_tc_schemes.do - Generate screenshots for tc_schemes

    Produces 3 output types:
      1. Console output (scheme listing) -> .smcl
      2. Graph (plotplainblind scheme) -> .png
      3. Graph (white_tableau scheme) -> .png
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "tc_schemes/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload command ---
capture program drop tc_schemes
quietly run tc_schemes/tc_schemes.ado

* --- 1. Console output: scheme listing ---
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg
noisily tc_schemes, detail
log close demo

* --- Setup data for graph demos ---
sysuse auto, clear

* --- 2. Graph: plotplainblind scheme ---
twoway (scatter price mpg if foreign == 0, mcolor(%60)) ///
       (scatter price mpg if foreign == 1, mcolor(%60)) ///
       (lfit price mpg if foreign == 0) ///
       (lfit price mpg if foreign == 1), ///
    legend(order(1 "Domestic" 2 "Foreign") pos(6) rows(1)) ///
    title("Price vs. Mileage by Origin") ///
    scheme(plotplainblind)
graph export "`pkg_dir'/scheme_plotplainblind.png", replace width(1200)
capture graph close _all

* --- 3. Graph: white_tableau scheme ---
twoway (scatter price mpg if foreign == 0, mcolor(%60)) ///
       (scatter price mpg if foreign == 1, mcolor(%60)) ///
       (lfit price mpg if foreign == 0) ///
       (lfit price mpg if foreign == 1), ///
    legend(order(1 "Domestic" 2 "Foreign") pos(6) rows(1)) ///
    title("Price vs. Mileage by Origin") ///
    scheme(white_tableau)
graph export "`pkg_dir'/scheme_white_tableau.png", replace width(1200)
capture graph close _all

* --- Cleanup ---
clear
