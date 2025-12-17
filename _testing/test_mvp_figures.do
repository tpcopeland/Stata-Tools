/*******************************************************************************
* test_mvp_figures.do
*
* Purpose: Generate MVP (Missing Value Patterns) graphs with all option
*          combinations for visual inspection
*
* Prerequisites:
*   - mvp.ado must be installed
*   - Test data in _testing/data/
*
* Output:
*   - Multiple PNG files in _testing/figures/mvp/ for visual inspection
*
* Author: Timothy P Copeland
* Date: 2025-12-16
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* PATH CONFIGURATION
* =============================================================================
if "`c(os)'" == "MacOSX" {
    global STATA_TOOLS_PATH "/Users/tcopeland/Documents/GitHub/Stata-Tools"
}
else if "`c(os)'" == "Unix" {
    global STATA_TOOLS_PATH "/home/ubuntu/Stata-Tools"
}
else {
    global STATA_TOOLS_PATH "`c(pwd)'/.."
}

global TESTING_DIR "${STATA_TOOLS_PATH}/_testing"
global DATA_DIR "${TESTING_DIR}/data"
global FIGURES_DIR "${TESTING_DIR}/figures/mvp"

* Create figures directory
capture mkdir "${TESTING_DIR}/figures"
capture mkdir "${FIGURES_DIR}"

* Install package
capture net uninstall mvp
quietly net install mvp, from("${STATA_TOOLS_PATH}/mvp")

display as text _n "{hline 70}"
display as text "MVP FIGURE GENERATION FOR VISUAL INSPECTION"
display as text "{hline 70}"
display as text "Output directory: ${FIGURES_DIR}"
display as text "{hline 70}"

* =============================================================================
* SYNTHETIC DATASET WITH CONTROLLED MISSINGNESS
* =============================================================================
display as text _n "Creating synthetic dataset with controlled missingness..."
clear
set obs 500
set seed 12345

* Create ID and stratification variables
gen id = _n
gen female = runiform() > 0.5
label define female 0 "Male" 1 "Female"
label values female female

gen age_group = 1 + int(3*runiform())
label define age_grp 1 "Young" 2 "Middle" 3 "Old"
label values age_group age_grp

* Variables with different missingness patterns
gen var1 = rnormal()           // No missing
gen var2 = rnormal()
replace var2 = . if runiform() < 0.05   // 5% missing

gen var3 = rnormal()
replace var3 = . if runiform() < 0.15   // 15% missing

gen var4 = rnormal()
replace var4 = . if runiform() < 0.25   // 25% missing

gen var5 = rnormal()
replace var5 = . if runiform() < 0.35   // 35% missing

gen var6 = rnormal()
replace var6 = . if runiform() < 0.10   // 10% missing

* Correlated missingness (var7 missing when var3 is missing)
gen var7 = rnormal()
replace var7 = . if var3 == .
replace var7 = . if runiform() < 0.05   // Additional 5%

* Label variables
label var var1 "Complete variable"
label var var2 "Low missingness (5%)"
label var var3 "Moderate missingness (15%)"
label var var4 "High missingness (25%)"
label var var5 "Very high missingness (35%)"
label var var6 "Some missingness (10%)"
label var var7 "Correlated missingness"

save "${DATA_DIR}/synth_missing.dta", replace

* =============================================================================
* FIGURE 1: Bar chart - default horizontal
* =============================================================================
display as text _n "Figure 1: Bar chart - default horizontal..."

mvp var2 var3 var4 var5 var6 var7, graph(bar) gname(mvp_fig01)

graph export "${FIGURES_DIR}/01_bar_horizontal.png", as(png) replace
graph close _all

* =============================================================================
* FIGURE 2: Bar chart - vertical
* =============================================================================
display as text "Figure 2: Bar chart - vertical..."

mvp var2 var3 var4 var5 var6 var7, graph(bar) vertical gname(mvp_fig02)

graph export "${FIGURES_DIR}/02_bar_vertical.png", as(png) replace
graph close _all

* =============================================================================
* FIGURE 3: Bar chart - sorted by missingness
* =============================================================================
display as text "Figure 3: Bar chart - sorted..."

mvp var2 var3 var4 var5 var6 var7, graph(bar) sort gname(mvp_fig03)

graph export "${FIGURES_DIR}/03_bar_sorted.png", as(png) replace
graph close _all

* =============================================================================
* FIGURE 4: Bar chart - custom color
* =============================================================================
display as text "Figure 4: Bar chart - custom color..."

mvp var2 var3 var4 var5 var6 var7, graph(bar) barcolor(maroon) ///
    title("Missing Data by Variable") subtitle("Custom maroon color") ///
    gname(mvp_fig04)

graph export "${FIGURES_DIR}/04_bar_custom_color.png", as(png) replace
graph close _all

* =============================================================================
* FIGURE 5: Bar chart - with scheme
* =============================================================================
display as text "Figure 5: Bar chart - s1mono scheme..."

mvp var2 var3 var4 var5 var6 var7, graph(bar) scheme(s1mono) ///
    title("Missing Data Rates") gname(mvp_fig05)

graph export "${FIGURES_DIR}/05_bar_s1mono.png", as(png) replace
graph close _all

* =============================================================================
* FIGURE 6: Pattern plot - default
* =============================================================================
display as text "Figure 6: Pattern plot - default..."

mvp var2 var3 var4 var5 var6 var7, graph(patterns) gname(mvp_fig06)

graph export "${FIGURES_DIR}/06_patterns_default.png", as(png) replace
graph close _all

* =============================================================================
* FIGURE 7: Pattern plot - top 10
* =============================================================================
display as text "Figure 7: Pattern plot - top 10..."

mvp var2 var3 var4 var5 var6 var7, graph(patterns) top(10) ///
    title("Top 10 Missing Patterns") gname(mvp_fig07)

graph export "${FIGURES_DIR}/07_patterns_top10.png", as(png) replace
graph close _all

* =============================================================================
* FIGURE 8: Matrix plot - default
* =============================================================================
display as text "Figure 8: Matrix plot - default..."

mvp var2 var3 var4 var5 var6 var7, graph(matrix) gname(mvp_fig08)

graph export "${FIGURES_DIR}/08_matrix_default.png", as(png) replace
graph close _all

* =============================================================================
* FIGURE 9: Matrix plot - sampled and sorted
* =============================================================================
display as text "Figure 9: Matrix plot - sampled and sorted..."

mvp var2 var3 var4 var5 var6 var7, graph(matrix, sample(100) sort) ///
    title("Missing Data Matrix (100 obs sample)") gname(mvp_fig09)

graph export "${FIGURES_DIR}/09_matrix_sampled.png", as(png) replace
graph close _all

* =============================================================================
* FIGURE 10: Matrix plot - custom colors
* =============================================================================
display as text "Figure 10: Matrix plot - custom colors..."

mvp var2 var3 var4 var5 var6 var7, graph(matrix) ///
    misscolor(red) obscolor(green*0.3) ///
    title("Missing Data Matrix") subtitle("Red=missing, Green=observed") ///
    gname(mvp_fig10)

graph export "${FIGURES_DIR}/10_matrix_colors.png", as(png) replace
graph close _all

* =============================================================================
* FIGURE 11: Correlation plot - default
* =============================================================================
display as text "Figure 11: Correlation plot - default..."

mvp var2 var3 var4 var5 var6 var7, graph(correlation) gname(mvp_fig11)

graph export "${FIGURES_DIR}/11_correlation_default.png", as(png) replace
graph close _all

* =============================================================================
* FIGURE 12: Correlation plot - with text labels
* =============================================================================
display as text "Figure 12: Correlation plot - with text labels..."

mvp var2 var3 var4 var5 var6 var7, graph(correlation) textlabels ///
    title("Missingness Correlation Matrix") gname(mvp_fig12)

graph export "${FIGURES_DIR}/12_correlation_textlabels.png", as(png) replace
graph close _all

* =============================================================================
* FIGURE 13: Correlation plot - grayscale colorramp
* =============================================================================
display as text "Figure 13: Correlation plot - grayscale..."

mvp var2 var3 var4 var5 var6 var7, graph(correlation) colorramp(grayscale) ///
    title("Missingness Correlations (Grayscale)") gname(mvp_fig13)

graph export "${FIGURES_DIR}/13_correlation_grayscale.png", as(png) replace
graph close _all

* =============================================================================
* FIGURE 14: Bar chart - stratified by gender (gby)
* =============================================================================
display as text "Figure 14: Bar chart - stratified by gby(female)..."

mvp var2 var3 var4 var5 var6 var7, graph(bar) gby(female) ///
    title("Missing Data by Variable and Gender") gname(mvp_fig14)

graph export "${FIGURES_DIR}/14_bar_gby_female.png", as(png) replace
graph close _all

* =============================================================================
* FIGURE 15: Bar chart - overlay by gender (over)
* =============================================================================
display as text "Figure 15: Bar chart - overlay with over(female)..."

mvp var2 var3 var4 var5 var6 var7, graph(bar) over(female) ///
    title("Missing Data by Variable") subtitle("By gender") ///
    gname(mvp_fig15)

graph export "${FIGURES_DIR}/15_bar_over_female.png", as(png) replace
graph close _all

* =============================================================================
* FIGURE 16: Bar chart - stacked
* =============================================================================
display as text "Figure 16: Bar chart - stacked..."

mvp var2 var3 var4 var5 var6 var7, graph(bar) stacked ///
    title("Stacked Missing Data") gname(mvp_fig16)

graph export "${FIGURES_DIR}/16_bar_stacked.png", as(png) replace
graph close _all

* =============================================================================
* FIGURE 17: Pattern plot - stratified by age group
* =============================================================================
display as text "Figure 17: Pattern plot - gby(age_group)..."

mvp var2 var3 var4 var5, graph(patterns) gby(age_group) top(5) ///
    title("Missing Patterns by Age Group") gname(mvp_fig17)

graph export "${FIGURES_DIR}/17_patterns_gby_age.png", as(png) replace
graph close _all

* =============================================================================
* FIGURE 18: Bar chart - sorted vertical with custom title
* =============================================================================
display as text "Figure 18: Bar chart - comprehensive options..."

mvp var2 var3 var4 var5 var6 var7, ///
    graph(bar) sort vertical barcolor(navy) ///
    title("Missing Data Analysis") ///
    subtitle("Sorted by missingness rate") ///
    scheme(s1color) gname(mvp_fig18)

graph export "${FIGURES_DIR}/18_bar_comprehensive.png", as(png) replace
graph close _all

* =============================================================================
* FIGURE 19: Using sysuse auto data
* =============================================================================
display as text "Figure 19: Using sysuse auto data..."

sysuse auto, clear

mvp, graph(bar) sort ///
    title("Missing Data in Auto Dataset") gname(mvp_fig19)

graph export "${FIGURES_DIR}/19_auto_bar.png", as(png) replace
graph close _all

* =============================================================================
* FIGURE 20: Auto data - correlation
* =============================================================================
display as text "Figure 20: Auto data - correlation plot..."

sysuse auto, clear

capture noisily mvp, graph(correlation) textlabels ///
    title("Missingness Correlations") subtitle("Auto dataset") ///
    gname(mvp_fig20)
if _rc == 0 {
    graph export "${FIGURES_DIR}/20_auto_correlation.png", as(png) replace
}
else {
    display as text "  Note: Correlation graph skipped (only 1 variable with missing data)"
}

graph close _all

* =============================================================================
* CLEANUP
* =============================================================================
display as text _n "{hline 70}"
display as text "FIGURE GENERATION COMPLETE"
display as text "{hline 70}"
display as text "Generated 20 figures in: ${FIGURES_DIR}"
display as text ""
display as text "Figures:"
display as text "  01_bar_horizontal.png      - Bar chart horizontal (default)"
display as text "  02_bar_vertical.png        - Bar chart vertical"
display as text "  03_bar_sorted.png          - Bar chart sorted by missingness"
display as text "  04_bar_custom_color.png    - Bar chart with custom color"
display as text "  05_bar_s1mono.png          - Bar chart with s1mono scheme"
display as text "  06_patterns_default.png    - Pattern plot default"
display as text "  07_patterns_top10.png      - Pattern plot top 10"
display as text "  08_matrix_default.png      - Matrix plot default"
display as text "  09_matrix_sampled.png      - Matrix plot sampled"
display as text "  10_matrix_colors.png       - Matrix plot custom colors"
display as text "  11_correlation_default.png - Correlation plot default"
display as text "  12_correlation_textlabels.png - Correlation with labels"
display as text "  13_correlation_grayscale.png  - Correlation grayscale"
display as text "  14_bar_gby_female.png      - Bar chart stratified by gender"
display as text "  15_bar_over_female.png     - Bar chart overlay by gender"
display as text "  16_bar_stacked.png         - Bar chart stacked"
display as text "  17_patterns_gby_age.png    - Patterns by age group"
display as text "  18_bar_comprehensive.png   - Bar with all options"
display as text "  19_auto_bar.png            - Auto dataset bar"
display as text "  20_auto_correlation.png    - Auto dataset correlation"
display as text "{hline 70}"

display as text _n "Figure generation completed: `c(current_date)' `c(current_time)'"
