/*  demo_psdash.do - Demo output for psdash

    Produces:

    Binary treatment (2 groups):
      1. Console output (overlap diagnostics)      -> console_overlap.log -> .md
      2. Console output (balance + weights)        -> console_balance_weights.log -> .md
      3. Console output (weight options)           -> console_weight_options.log -> .md
      4. Console output (support assessment)       -> console_support.log -> .md
      5. Console output (stored results)           -> console_return_values.log -> .md
      6. Console output (teffects auto-detection)  -> console_teffects_auto.log -> .md
      7. Graph (PS overlap density)                -> overlap_density.png
      8. Graph (PS overlap histogram)              -> overlap_histogram.png
      9. Graph (Love plot)                         -> love_plot.png
     10. Graph (weight distribution)               -> weight_distribution.png
     11. Graph (support region)                    -> support_region.png
     12. Graph (manual combined dashboard)         -> dashboard.png
     13. Graph (teffects dashboard)                -> dashboard_teffects.png

    v1.3.0 features (binary):
     B1. Console output (detect + machine-readable verdict) -> console_detect_verdict.log -> .md
     B2. Console output (SMD matrix for table1_tc)          -> console_smd_matrix.log -> .md
     B3. Console output (pre/post-trimming comparison)      -> console_trimming_compare.log -> .md
     B4. Graph (multi-strategy Love plot overlay)           -> strategies_loveplot.png
     B5. Graph (per-covariate distributional balance)       -> distribution_balance.png
     B6. Excel (one-call publication report workbook)       -> psdash_report.xlsx
     B7. Excel (single-panel export parity)                 -> weights_table.xlsx

    Multi-group treatment (3 groups):
     14. Console output (multi-group overlap)      -> console_mg_overlap.log -> .md
     15. Console output (multi-group balance)      -> console_mg_balance.log -> .md
     16. Console output (multi-group weights)      -> console_mg_weights.log -> .md
     17. Console output (multi-group support)      -> console_mg_support.log -> .md
     18. Console output (reference group change)   -> console_mg_reference.log -> .md
     19. Graph (multi-group overlap density)       -> mg_overlap_density.png
     20. Graph (multi-group Love plot)             -> mg_love_plot.png
     21. Graph (multi-group dashboard)             -> mg_dashboard.png
*/

version 16.0
local _demo_varabbrev = c(varabbrev)
capture log close _all
set varabbrev off
set linesize 120

* --- Non-mutating install sandbox (RB-16) -----------------------------------
* This demo installs psdash, tc_schemes, and logdoc to exercise them. It must
* NOT replace the packages in the user's real ado directories. Redirect PLUS and
* PERSONAL to a temporary sandbox for the duration of the demo and restore them
* in the cleanup zone, so a documentation demo never mutates the user's Stata
* installation. (The locals are declared here, before the captured block, so the
* cleanup zone can restore them on every exit path.)
local _demo_plus_orig "`c(sysdir_plus)'"
local _demo_personal_orig "`c(sysdir_personal)'"
tempfile _demo_marker
local _demo_sysroot "`_demo_marker'_sysdir"
capture mkdir "`_demo_sysroot'"
capture mkdir "`_demo_sysroot'/plus"
capture mkdir "`_demo_sysroot'/personal"
sysdir set PLUS "`_demo_sysroot'/plus"
sysdir set PERSONAL "`_demo_sysroot'/personal"

capture noisily {

* --- Paths ---
local cwd = subinstr("`c(pwd)'", "\", "/", .)
local pkg_dir ""
if fileexists("`cwd'/psdash.pkg") {
    local pkg_dir "`cwd'"
}
else if fileexists("`cwd'/../psdash.pkg") {
    local pkg_dir = substr("`cwd'", 1, length("`cwd'") - 5)
}
else if fileexists("`cwd'/psdash/psdash.pkg") {
    local pkg_dir "`cwd'/psdash"
}
else {
    display as error "demo_psdash.do must be run from Stata-Tools, psdash, or psdash/demo"
    exit 601
}
local repo = substr("`pkg_dir'", 1, length("`pkg_dir'") - 7)
local demo_dir "`pkg_dir'/demo"
capture mkdir "`demo_dir'"

* --- Install local package build ---
capture ado uninstall psdash
quietly net install psdash, from("`pkg_dir'") replace

* --- Graph scheme ---
local tc_dir "`repo'/tc_schemes"
if !fileexists("`tc_dir'/tc_schemes.pkg") {
    display as error "tc_schemes package not found at `tc_dir'"
    exit 601
}
capture ado uninstall tc_schemes
quietly net install tc_schemes, from("`tc_dir'") replace
set scheme plotplainblind


**# Binary treatment setup
clear
set seed 20260226
set obs 800

gen double age = rnormal(55, 12)
label variable age "Age (years)"
gen byte female = runiform() < 0.48
label variable female "Female sex"
gen double bmi = rnormal(27, 5)
label variable bmi "Body mass index"
gen double sbp = rnormal(135, 22)
label variable sbp "Systolic BP (mmHg)"
gen double cholesterol = rnormal(200, 40)
label variable cholesterol "Total cholesterol"

* Treatment assignment with confounding
gen double lp = -3.5 + 0.04*age + 0.6*female + 0.03*bmi + 0.008*sbp
gen double ps_true = invlogit(lp)
gen byte statin = runiform() < ps_true
label variable statin "Statin use"
label define yn 0 "No" 1 "Yes"
label values statin yn
drop lp ps_true

* Outcome
gen double ldl_change = -15 - 20*statin + 0.3*age + 5*female + 0.5*bmi ///
    + rnormal(0, 10)
label variable ldl_change "LDL change (mg/dL)"

* Estimate propensity score
quietly logit statin age female bmi sbp
predict double ps, pr
gen double ipw = cond(statin==1, 1/ps, 1/(1-ps))

**# 1. Overlap diagnostics
log using "`demo_dir'/console_overlap.log", replace text name(overlap) nomsg
* # Binary overlap diagnostics
noisily psdash overlap statin ps, nograph
log close overlap

psdash overlap statin ps, saving("`demo_dir'/overlap_density.png")
capture graph close _all

psdash overlap statin ps, histogram bins(25) ///
    saving("`demo_dir'/overlap_histogram.png")
capture graph close _all

**# 2. Balance and weight diagnostics
log using "`demo_dir'/console_balance_weights.log", replace text ///
    name(balwt) nomsg
* # Binary balance and IPTW diagnostics
noisily psdash balance statin ps, ///
    covariates(age female bmi sbp cholesterol) wvar(ipw) ks
noisily psdash weights statin ps, wvar(ipw)
log close balwt

psdash balance statin ps, covariates(age female bmi sbp cholesterol) ///
    wvar(ipw) loveplot saving("`demo_dir'/love_plot.png")
capture graph close _all

**# 3. Weight modification options
log using "`demo_dir'/console_weight_options.log", replace text ///
    name(weight_opts) nomsg
* # Detailed and modified weights
noisily psdash weights statin ps, wvar(ipw) detail
noisily psdash weights statin ps, wvar(ipw) trim(99) generate(ipw_trimmed)
noisily psdash weights statin ps, wvar(ipw) stabilize generate(ipw_stabilized)
noisily summarize ipw ipw_trimmed ipw_stabilized
log close weight_opts

psdash weights statin ps, wvar(ipw) graph xlabel(0 2 5 10 15) ///
    saving("`demo_dir'/weight_distribution.png")
capture graph close _all

**# 4. Support assessment
log using "`demo_dir'/console_support.log", replace text name(support) nomsg
* # Common support with generated indicator
noisily psdash support statin ps, crump generate(in_support) nograph
noisily tabulate in_support statin, column
log close support

psdash support statin ps, crump saving("`demo_dir'/support_region.png")
capture graph close _all

**# 5. Stored result example
log using "`demo_dir'/console_return_values.log", replace text ///
    name(return_values) nomsg
* # Stored results for automated checks
noisily psdash balance statin ps, ///
    covariates(age female bmi sbp cholesterol) wvar(ipw)
noisily return list
noisily matrix list r(balance)
log close return_values

**# 6. Manual combined dashboard
psdash combined statin ps, ///
    covariates(age female bmi sbp cholesterol) wvar(ipw) ///
    saving("`demo_dir'/dashboard.png")
capture graph close _all

**# 7. Fully automatic workflow after teffects
log using "`demo_dir'/console_teffects_auto.log", replace text ///
    name(teffects_auto) nomsg
* # Automatic detection after teffects
noisily teffects ipw (ldl_change) (statin age female bmi sbp cholesterol)
noisily psdash combined
log close teffects_auto

psdash combined, saving("`demo_dir'/dashboard_teffects.png")
capture graph close _all

**# B1. Auto-detection inspection + machine-readable verdict (v1.3.0)
log using "`demo_dir'/console_detect_verdict.log", replace text ///
    name(detect_verdict) nomsg
* # Auto-detection report and machine-readable verdict
* ## psdash detect — inspect detection without running panels
noisily psdash detect statin ps, covariates(age female bmi sbp cholesterol)
* ## Returned verdict with configurable thresholds
noisily psdash combined statin ps, ///
    covariates(age female bmi sbp cholesterol) wvar(ipw) ///
    overlapmax(5) essmin(60) nooverlap nosupport
noisily display "verdict = " r(verdict) "  (n_warnings = " r(n_warnings) ")"
noisily display "warnings = " r(warnings)
log close detect_verdict

**# B2. SMD matrix for manuscript Table 1 (v1.3.0)
log using "`demo_dir'/console_smd_matrix.log", replace text ///
    name(smd_matrix) nomsg
* # Balance SMD matrix for table1_tc / puttab
noisily psdash balance statin ps, ///
    covariates(age female bmi sbp cholesterol) wvar(ipw) smdmatrix(smd_table)
noisily matrix list smd_table
log close smd_matrix

**# B3. Pre/post-trimming comparison (v1.3.0)
log using "`demo_dir'/console_trimming_compare.log", replace text ///
    name(trim_compare) nomsg
* # Did trimming help? pre/post-trimming comparison
noisily psdash support statin ps, crump compare ///
    covariates(age female bmi sbp cholesterol) nograph
log close trim_compare

**# B4. Multi-strategy Love plot overlay (v1.3.0)
psdash balance statin ps, covariates(age female bmi sbp cholesterol) ///
    strategies(raw ate att) saving("`demo_dir'/strategies_loveplot.png")
capture graph close _all

**# B5. Per-covariate distributional balance (v1.3.0)
psdash balance statin ps, covariates(age female bmi sbp cholesterol) ///
    wvar(ipw) distribution(age bmi sbp) ///
    saving("`demo_dir'/distribution_balance.png")
capture graph close _all

**# B6/B7. Excel report workbook + single-panel export parity (v1.3.0)
capture erase "`demo_dir'/psdash_report.xlsx"
quietly psdash combined statin ps, ///
    covariates(age female bmi sbp cholesterol) wvar(ipw) ///
    report("`demo_dir'/psdash_report.xlsx")
capture graph close _all
capture erase "`demo_dir'/weights_table.xlsx"
quietly psdash weights statin ps, wvar(ipw) xlsx("`demo_dir'/weights_table.xlsx")

**# Multi-group treatment setup (3 arms)
clear
set seed 20260226
set obs 1200

gen double age = rnormal(55, 12)
label variable age "Age (years)"
gen byte female = runiform() < 0.48
label variable female "Female sex"
gen double bmi = rnormal(27, 5)
label variable bmi "Body mass index"
gen double sbp = rnormal(135, 22)
label variable sbp "Systolic BP (mmHg)"
gen double cholesterol = rnormal(200, 40)
label variable cholesterol "Total cholesterol"
gen double creatinine = rnormal(1.0, 0.3)
label variable creatinine "Serum creatinine"

* 3-arm treatment: 0=placebo, 1=low dose, 2=high dose
* Confounded by age, bmi, sbp
gen double lp1 = -2.0 + 0.03*age + 0.02*bmi + 0.005*sbp
gen double lp2 = -3.5 + 0.05*age + 0.04*bmi + 0.01*sbp
gen double denom = 1 + exp(lp1) + exp(lp2)
gen double pr0 = 1/denom
gen double pr1 = exp(lp1)/denom
gen double pr2 = exp(lp2)/denom
gen double u = runiform()
gen byte arm = cond(u < pr0, 0, cond(u < pr0 + pr1, 1, 2))
label variable arm "Treatment arm"
label define arm_lbl 0 "Placebo" 1 "Low dose" 2 "High dose"
label values arm arm_lbl
drop lp1 lp2 denom pr0 pr1 pr2 u

* Estimate generalized propensity scores via mlogit
quietly mlogit arm age female bmi sbp cholesterol creatinine
predict double ps0 ps1 ps2, pr

* Generalized IPTW
gen double gipw = cond(arm==0, 1/ps0, cond(arm==1, 1/ps1, 1/ps2))
label variable gipw "Generalized IPTW"

**# 5. Multi-group overlap
log using "`demo_dir'/console_mg_overlap.log", replace text ///
    name(mg_overlap) nomsg
* # Multi-group overlap diagnostics
noisily psdash overlap arm, psvars(ps0 ps1 ps2) nograph
log close mg_overlap

psdash overlap arm, psvars(ps0 ps1 ps2) ///
    saving("`demo_dir'/mg_overlap_density.png")
capture graph close _all

**# 6. Multi-group balance
log using "`demo_dir'/console_mg_balance.log", replace text ///
    name(mg_balance) nomsg
* # Multi-group balance diagnostics
noisily psdash balance arm, psvars(ps0 ps1 ps2) ///
    covariates(age female bmi sbp cholesterol creatinine) wvar(gipw) ks
log close mg_balance

psdash balance arm, psvars(ps0 ps1 ps2) ///
    covariates(age female bmi sbp cholesterol creatinine) wvar(gipw) ///
    loveplot saving("`demo_dir'/mg_love_plot.png")
capture graph close _all

**# 7. Multi-group weights
log using "`demo_dir'/console_mg_weights.log", replace text ///
    name(mg_weights) nomsg
* # Multi-group weight diagnostics
noisily psdash weights arm, psvars(ps0 ps1 ps2) wvar(gipw) detail
log close mg_weights

**# 8. Multi-group support
log using "`demo_dir'/console_mg_support.log", replace text ///
    name(mg_support) nomsg
* # Multi-group common support
noisily psdash support arm, psvars(ps0 ps1 ps2) threshold(0.1) ///
    generate(mg_support) nograph
noisily tabulate mg_support arm, column
log close mg_support

**# 9. Multi-group reference group change
log using "`demo_dir'/console_mg_reference.log", replace text ///
    name(mg_reference) nomsg
* # Multi-group balance with reference arm 1
noisily psdash balance arm, psvars(ps0 ps1 ps2) ///
    covariates(age female bmi sbp cholesterol creatinine) ///
    wvar(gipw) reference(1)
log close mg_reference

**# 10. Multi-group combined dashboard
psdash combined arm, psvars(ps0 ps1 ps2) ///
    covariates(age female bmi sbp cholesterol creatinine) wvar(gipw) ///
    saving("`demo_dir'/mg_dashboard.png")
capture graph close _all

**# Convert console logs to markdown via logdoc
local logdoc_dir "`repo'/logdoc"
if !fileexists("`logdoc_dir'/logdoc.pkg") {
    display as error "logdoc package not found at `logdoc_dir'"
    exit 601
}
capture ado uninstall logdoc
quietly net install logdoc, from("`logdoc_dir'") replace

foreach f in console_overlap console_balance_weights console_weight_options ///
    console_support console_return_values console_teffects_auto ///
    console_detect_verdict console_smd_matrix console_trimming_compare ///
    console_mg_overlap console_mg_balance console_mg_weights ///
    console_mg_support console_mg_reference {
    logdoc using "`demo_dir'/`f'.log", ///
        output("`demo_dir'/`f'.md") format(md) replace quiet
}

clear
}
local _demo_rc = _rc

**# Cleanup
capture log close _all
capture graph close _all
capture drop _psdash_ps
capture drop _psdash_wt
* Restore the user's real ado directories and remove the sandbox (RB-16).
capture sysdir set PLUS "`_demo_plus_orig'"
capture sysdir set PERSONAL "`_demo_personal_orig'"
if `"`_demo_sysroot'"' != "" capture shell rm -rf "`_demo_sysroot'"
set varabbrev `_demo_varabbrev'
if `_demo_rc' exit `_demo_rc'
