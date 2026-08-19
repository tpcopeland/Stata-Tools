/*  demo_diagtab.do - Standalone diagtab clinical demo

    Produces:
      1. Excel workbook with single-cutoff, prevalence-adjusted, and
         multi-cutoff diagnostic-accuracy tables -> demo_diagtab.xlsx
*/

version 17.0
local _demo_varabbrev = c(varabbrev)
set varabbrev off
set linesize 120

local pkg_dir "`c(pwd)'/diagtab"
local demo_dir "`pkg_dir'/demo"
capture mkdir "`demo_dir'"

capture ado uninstall diagtab
quietly net install diagtab, from("`pkg_dir'") replace

**# Build a reproducible clinical prediction example
webuse lbw, clear
quietly logit low age lwt smoke
quietly predict double phat

capture erase "`demo_dir'/demo_diagtab.xlsx"

**# Single cutoff and ROC AUC
diagtab phat low, cutoff(0.30) auc ///
    xlsx("`demo_dir'/demo_diagtab.xlsx") sheet("Diagnostic") ///
    title("Low birth weight prediction") theme(nejm)

**# Predictive values at an external prevalence
diagtab phat low, cutoff(0.30) prevalence(0.07) ///
    xlsx("`demo_dir'/demo_diagtab.xlsx") sheet("Prevalence") ///
    title("Predictive values at 7% prevalence")

**# Threshold comparison
diagtab phat low, cutoffs(0.20 0.30 0.40 0.50) ///
    xlsx("`demo_dir'/demo_diagtab.xlsx") sheet("Cutoffs") ///
    title("Diagnostic accuracy across cutoffs")

**# Verify the reader-facing workbook
preserve
quietly import excel using "`demo_dir'/demo_diagtab.xlsx", ///
    sheet("Diagnostic") clear allstring
assert _N >= 10
count if A == "Low birth weight prediction"
assert r(N) == 1
count if B == "Sensitivity"
assert r(N) == 1
restore

set varabbrev `_demo_varabbrev'
