/*  demo_tc_schemes.do - Generate screenshots for tc_schemes

    Produces 14 output types:
      1. Console output (scheme overview) -> .smcl
      2. Console output (detailed listing) -> .smcl
      3-6. Graphs (blindschemes: plotplain, plotplainblind, plottig, plottigblind) -> .png
      7-9. Graphs (schemepack white: tableau, viridis, ptol) -> .png
      10-11. Graphs (schemepack black: tableau, cividis) -> .png
      12. Graph (schemepack gg: hue) -> .png
      13-14. Graphs (schemepack standalone: neon, swift_red) -> .png
*/

version 16.0
set more off
set varabbrev off
set linesize 250

* --- Paths ---
local pkg_dir "tc_schemes/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload command ---
capture program drop tc_schemes
capture program drop _tc_schemes_detail
quietly run tc_schemes/tc_schemes.ado

**# Console Output

* --- Overview listing ---
log using "`pkg_dir'/console_overview.smcl", replace smcl name(overview) nomsg
noisily tc_schemes
log close overview

* --- Detailed listing ---
log using "`pkg_dir'/console_detail.smcl", replace smcl name(detail) nomsg
noisily tc_schemes, detail
log close detail

**# Setup Data
sysuse auto, clear

**# Blindschemes
* Four schemes from Daniel Bischof — clean publication-ready aesthetics

foreach s in plotplain plotplainblind plottig plottigblind {
    twoway (scatter price mpg if foreign == 0, mcolor(%60)) ///
           (scatter price mpg if foreign == 1, mcolor(%60)) ///
           (lfit price mpg if foreign == 0) ///
           (lfit price mpg if foreign == 1), ///
        legend(order(1 "Domestic" 2 "Foreign") pos(6) rows(1)) ///
        title("Price vs. Mileage") subtitle("scheme: `s'") ///
        scheme(`s')
    graph export "`pkg_dir'/scheme_`s'.png", replace width(1200)
    capture graph close _all
}

**# Schemepack — White Background Series
* Clean white background across three palettes: tableau, viridis, ptol

foreach s in white_tableau white_viridis white_ptol {
    twoway (scatter price mpg if foreign == 0, mcolor(%60)) ///
           (scatter price mpg if foreign == 1, mcolor(%60)) ///
           (lfit price mpg if foreign == 0) ///
           (lfit price mpg if foreign == 1), ///
        legend(order(1 "Domestic" 2 "Foreign") pos(6) rows(1)) ///
        title("Price vs. Mileage") subtitle("scheme: `s'") ///
        scheme(`s')
    graph export "`pkg_dir'/scheme_`s'.png", replace width(1200)
    capture graph close _all
}

**# Schemepack — Black Background Series
* Dramatic dark backgrounds: tableau and cividis palettes

foreach s in black_tableau black_cividis {
    twoway (scatter price mpg if foreign == 0, mcolor(%60)) ///
           (scatter price mpg if foreign == 1, mcolor(%60)) ///
           (lfit price mpg if foreign == 0) ///
           (lfit price mpg if foreign == 1), ///
        legend(order(1 "Domestic" 2 "Foreign") pos(6) rows(1)) ///
        title("Price vs. Mileage") subtitle("scheme: `s'") ///
        scheme(`s')
    graph export "`pkg_dir'/scheme_`s'.png", replace width(1200)
    capture graph close _all
}

**# Schemepack — gg (ggplot2-style) Background
* Gray background inspired by R's ggplot2

twoway (scatter price mpg if foreign == 0, mcolor(%60)) ///
       (scatter price mpg if foreign == 1, mcolor(%60)) ///
       (lfit price mpg if foreign == 0) ///
       (lfit price mpg if foreign == 1), ///
    legend(order(1 "Domestic" 2 "Foreign") pos(6) rows(1)) ///
    title("Price vs. Mileage") subtitle("scheme: gg_hue") ///
    scheme(gg_hue)
graph export "`pkg_dir'/scheme_gg_hue.png", replace width(1200)
capture graph close _all

**# Schemepack — Standalone Schemes
* Distinctive individual schemes: neon (dark, vivid) and swift_red (themed)

foreach s in neon swift_red {
    twoway (scatter price mpg if foreign == 0, mcolor(%60)) ///
           (scatter price mpg if foreign == 1, mcolor(%60)) ///
           (lfit price mpg if foreign == 0) ///
           (lfit price mpg if foreign == 1), ///
        legend(order(1 "Domestic" 2 "Foreign") pos(6) rows(1)) ///
        title("Price vs. Mileage") subtitle("scheme: `s'") ///
        scheme(`s')
    graph export "`pkg_dir'/scheme_`s'.png", replace width(1200)
    capture graph close _all
}

**# Cleanup
clear
