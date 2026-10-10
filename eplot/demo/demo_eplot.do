/*  demo_eplot.do - Generate screenshots for eplot

    Produces 10 graphs:
      1. Multi-model coefficient comparison     -> multi_model.png
      2. Forest plot with values annotation      -> forest_values.png
      3. Grouped coefficient plot                -> grouped_coefplot.png
      4. Lancet style preset                     -> lancet_style.png
      5. Significance coloring                   -> sigcolors.png
      6. Matrix mode                             -> matrix_mode.png
      7. Single-model values demo                -> coef_values.png
      8. Meta-analysis with heterogeneity        -> meta_heterogeneity.png
      9. Time-ratio forest plot by sex and age   -> time_ratio_forest.png
     10. Two panels with shared axis styling     -> panel_consistency.png

    Run from the Stata-Tools repository root; graphs use the white_tableau
    scheme from the sibling tc_schemes package.
*/

version 16.0
set more off
set varabbrev off
set linesize 120

**# Paths
if !fileexists("eplot/eplot.ado") {
    display as error "Could not locate eplot.ado relative to `c(pwd)'"
    exit 601
}
local pkg_dir "eplot/demo"
capture mkdir "`pkg_dir'"

**# Install local packages and set the graph scheme
capture ado uninstall eplot
quietly net install eplot, from("`c(pwd)'/eplot") replace
which eplot
capture ado uninstall tc_schemes
quietly net install tc_schemes, from("`c(pwd)'/tc_schemes") replace

* Resolve the scheme and assert it took effect; a missing scheme must stop the
* demo rather than fall back silently to the default scheme.
capture findfile scheme-white_tableau.scheme
if _rc {
    display as error "scheme white_tableau not found after tc_schemes install"
    exit 601
}
set scheme white_tableau
if "`c(scheme)'" != "white_tableau" {
    display as error "scheme white_tableau did not take effect (c(scheme) = `c(scheme)')"
    exit 198
}

**# 1. Multi-model coefficient comparison

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

**# 2. Forest plot with values annotation and subgroups

* vsize(small) draws the values at the row-label size.

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
    values vformat(%4.2f) vsize(small) nonull ///
    effect("Hazard Ratio (95% CI)") ///
    title("Treatment Effect on Organ-Specific Outcomes")

graph export "`pkg_dir'/forest_values.png", replace width(1400)
capture graph close _all

**# 3. Grouped coefficient plot

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

**# 4. Lancet style preset

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

**# 5. Significance coloring

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

**# 6. Matrix mode

* The matrix already holds odds ratios, so the null line belongs at 1.

matrix R = (1.82, 1.21, 2.74 \ 0.73, 0.54, 0.99 \ 1.45, 1.08, 1.95 \ 1.12, 0.78, 1.61)
matrix rownames R = "Drug_A" "Drug_B" "Drug_C" "Drug_D"

eplot, matrix(R) null(1) ///
    effect("Odds Ratio (95% CI)") ///
    coeflabels(Drug_A = "Drug A (experimental)" ///
               Drug_B = "Drug B (standard)" ///
               Drug_C = "Drug C (combination)" ///
               Drug_D = "Drug D (low-dose)") ///
    cicap ///
    title("Treatment Odds Ratios from Matrix Input")

graph export "`pkg_dir'/matrix_mode.png", replace width(1400)
capture graph close _all

**# 7. Single-model coefficient plot with values annotation

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

**# 8. Meta-analysis with heterogeneity and prediction intervals

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

**# 9. Time-ratio forest plot by sex and age group

* Synthetic subgroup results from an accelerated failure time model: time ratios
* for time to first cardiovascular event, SNRI versus SSRI new users. A time
* ratio above 1 means the event came later under SNRI. Men aged 80+ had too few
* events to fit the model, so that row is type 2 and prints "Not estimated".
* The dashed extra line marks the overall time ratio and is labelled at the top.
clear
input str20 group double(tr lci uci) byte type
"Men"                .     .     .   0
"  18-39"         1.21  1.04  1.41   1
"  40-59"         1.09  0.97  1.22   1
"  60-79"         1.03  0.94  1.13   1
"  80+"              .     .     .   2
""                   .     .     .   6
"Women"              .     .     .   0
"  18-39"         1.34  1.16  1.55   1
"  40-59"         1.12  1.01  1.24   1
"  60-79"         0.97  0.88  1.07   1
"  80+"           0.88  0.73  1.06   1
""                   .     .     .   6
"All participants" 1.08  1.03  1.13  5
end

eplot tr lci uci, labels(group) type(type) logscale ///
    values vformat(%4.2f) vsize(small) vcolor(black) ///
    effect("Time ratio (log scale)") vtitle("Time ratio (95% CI)") ///
    xlabel(0.7 "0.7" 0.8 "0.8" 1 "1.0" 1.25 "1.25" 1.5 "1.5") ///
    xscale(lcolor(black) lwidth(medthin) fextend) ///
    xline(1.08, lcolor(gs8) lpattern(dash) label("Overall 1.08")) ///
    favors("Favors SSRI" "Favors SNRI", ends arrows) ///
    title("Time to first cardiovascular event, SNRI vs SSRI") ///
    subtitle("Accelerated failure time model by sex and age group (synthetic data)")

graph export "`pkg_dir'/time_ratio_forest.png", replace width(1400)
capture graph close _all

**# 10. Two panels with shared axis styling

* Two outcomes reported side by side should look like one figure: the same
* ticks, axis line, text sizes, and favors labels. Keeping the shared options in
* one local guarantees the panels cannot drift apart. A user xlabel() also drops
* the scheme grid, so neither panel carries grid lines the other lacks. Each
* panel still computes its own axis range from its data, so choose ticks that lie
* within the data of every panel.
local shared `"logscale xlabel(0.7 "0.7" 1 "1.0" 1.4 "1.4") xscale(lcolor(black) lwidth(medthin) fextend) values vformat(%4.2f) vsize(small) vcolor(black) labsize(small) effect("Hazard ratio") vtitle("HR (95% CI)") vmissing("Too few events") favors("Favors SNRI" "Favors SSRI", below arrows)"'

clear
input str16 subgroup double(hr lci uci) byte type
"Age < 60"     0.84  0.72  0.98  1
"Age 60+"      0.93  0.83  1.04  1
"Women"        0.86  0.76  0.97  1
"Men"          0.94  0.81  1.09  1
"Diabetes"     0.97  0.67  1.41  1
"No diabetes"  0.91  0.83  1.00  1
"Overall"      0.89  0.82  0.97  5
end

eplot hr lci uci, labels(subgroup) type(type) `shared' ///
    title("A. Cardiovascular event", size(medium)) ///
    name(panel_cv, replace) nodraw

clear
input str16 subgroup double(hr lci uci) byte type
"Age < 60"     1.18  0.88  1.58  1
"Age 60+"      1.31  1.05  1.63  1
"Women"        1.27  1.01  1.60  1
"Men"          1.10  0.69  1.75  1
"Diabetes"        .     .     .  2
"No diabetes"  1.24  1.03  1.49  1
"Overall"      1.25  1.06  1.47  5
end

eplot hr lci uci, labels(subgroup) type(type) `shared' ///
    title("B. Gastrointestinal bleeding", size(medium)) ///
    name(panel_gi, replace) nodraw

graph combine panel_cv panel_gi, cols(2) xsize(12) ysize(5) ///
    title("Subgroup hazard ratios, SNRI vs SSRI (synthetic data)")

graph export "`pkg_dir'/panel_consistency.png", replace width(1800)
capture graph close _all
capture graph drop panel_cv panel_gi

**# Cleanup
estimates drop _all
clear
