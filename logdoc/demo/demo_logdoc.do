/*  demo_logdoc.do - Generate screenshots for logdoc package

    Produces 5 output types:
      1. Console output (logdoc conversion commands) -> .smcl -> .png
      2. Light theme HTML document (with embedded graph) -> .html
      3. Dark theme HTML document -> .html
      4. Nodots + date variant HTML -> .html (clean script-style output)
      5. Markdown document with date (with graph reference) -> .md

    MUST be run from the Stata-Dev repo root.
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "logdoc/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload command ---
capture program drop logdoc
quietly run logdoc/logdoc.ado

* ===================================================================
* Step A: Generate a rich SMCL log with varied Stata output
* ===================================================================

sysuse auto, clear

log using "`pkg_dir'/sample_analysis.smcl", replace smcl name(sample) nomsg

* Summary statistics
summarize price mpg weight length, separator(0)

* Regression with table output
regress price mpg weight length i.foreign

* Margins after regression
margins foreign, atmeans

* Tabulation
tabulate foreign rep78

* Residual histogram
quietly regress price mpg weight
predict double resid, residuals
histogram resid, normal scheme(plotplainblind) ///
    title("Residual Distribution") ///
    xtitle("Residuals") ytitle("Density")
graph export "logdoc/demo/residuals.png", replace width(800)
capture graph close _all
drop resid

log close sample

* ===================================================================
* Step B: Convert the SMCL into multiple output variants
* ===================================================================

* --- 1. Console output: show logdoc in action ---
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg

* Light theme with date subtitle
noisily logdoc using "`pkg_dir'/sample_analysis.smcl", ///
    output("`pkg_dir'/sample_light.html") ///
    title("Auto Dataset Analysis") date("March 2026") replace

* Dark theme with date subtitle
noisily logdoc using "`pkg_dir'/sample_analysis.smcl", ///
    output("`pkg_dir'/sample_dark.html") ///
    title("Auto Dataset Analysis") date("March 2026") ///
    theme(dark) replace

* Nodots: strip dot prompts for clean script-style display
noisily logdoc using "`pkg_dir'/sample_analysis.smcl", ///
    output("`pkg_dir'/sample_nodots.html") ///
    title("Auto Dataset Analysis") date("March 2026") ///
    nodots replace

* Markdown output with date in YAML front matter
noisily logdoc using "`pkg_dir'/sample_analysis.smcl", ///
    output("`pkg_dir'/sample.md") ///
    title("Auto Dataset Analysis") date("March 2026") ///
    format(md) replace

log close demo

* --- Cleanup ---
clear
