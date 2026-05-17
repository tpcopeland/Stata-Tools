/*  demo_psdash.do - Demo output for psdash

    Produces:

    Binary treatment (2 groups):
      1. Console output (overlap diagnostics)     -> console_overlap.log -> .md
      2. Console output (balance + weights)        -> console_balance_weights.log -> .md
      3. Console output (support assessment)       -> console_support.log -> .md
      4. Graph (PS overlap density)                -> overlap_density.png
      5. Graph (Love plot)                         -> love_plot.png
      6. Graph (combined dashboard)                -> dashboard.png

    Multi-group treatment (3 groups):
      7. Console output (multi-group overlap)      -> console_mg_overlap.log -> .md
      8. Console output (multi-group balance)      -> console_mg_balance.log -> .md
      9. Console output (multi-group weights)      -> console_mg_weights.log -> .md
     10. Console output (multi-group support)      -> console_mg_support.log -> .md
     11. Graph (multi-group overlap density)       -> mg_overlap_density.png
     12. Graph (multi-group Love plot)             -> mg_love_plot.png
*/

version 16.0
local _demo_varabbrev = c(varabbrev)
capture log close _all
set varabbrev off
set linesize 120

* --- Paths ---
local repo "`c(pwd)'"
local demo_dir "`repo'/psdash/demo"
capture mkdir "`demo_dir'"

* --- Install local package build ---
capture ado uninstall psdash
quietly net install psdash, from("`repo'/psdash") replace

* --- Graph scheme ---
capture ado uninstall tc_schemes
quietly net install tc_schemes, from("`repo'/tc_schemes") replace
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
noisily psdash overlap statin ps, nograph
log close overlap

psdash overlap statin ps, saving("`demo_dir'/overlap_density.png")
capture graph close _all

**# 2. Balance and weight diagnostics
log using "`demo_dir'/console_balance_weights.log", replace text ///
    name(balwt) nomsg
noisily psdash balance statin ps, ///
    covariates(age female bmi sbp cholesterol) wvar(ipw)
noisily psdash weights statin ps, wvar(ipw)
log close balwt

psdash balance statin ps, covariates(age female bmi sbp cholesterol) ///
    wvar(ipw) loveplot saving("`demo_dir'/love_plot.png")
capture graph close _all

**# 3. Support assessment
log using "`demo_dir'/console_support.log", replace text name(support) nomsg
noisily psdash support statin ps, crump nograph
log close support

**# 4. Combined dashboard
psdash combined statin ps, ///
    covariates(age female bmi sbp cholesterol) wvar(ipw) ///
    saving("`demo_dir'/dashboard.png")
capture graph close _all

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
noisily psdash overlap arm, psvars(ps0 ps1 ps2) nograph
log close mg_overlap

psdash overlap arm, psvars(ps0 ps1 ps2) ///
    saving("`demo_dir'/mg_overlap_density.png")
capture graph close _all

**# 6. Multi-group balance
log using "`demo_dir'/console_mg_balance.log", replace text ///
    name(mg_balance) nomsg
noisily psdash balance arm, psvars(ps0 ps1 ps2) ///
    covariates(age female bmi sbp cholesterol creatinine) wvar(gipw)
log close mg_balance

psdash balance arm, psvars(ps0 ps1 ps2) ///
    covariates(age female bmi sbp cholesterol creatinine) wvar(gipw) ///
    loveplot saving("`demo_dir'/mg_love_plot.png")
capture graph close _all

**# 7. Multi-group weights
log using "`demo_dir'/console_mg_weights.log", replace text ///
    name(mg_weights) nomsg
noisily psdash weights arm, psvars(ps0 ps1 ps2) wvar(gipw)
log close mg_weights

**# 8. Multi-group support
log using "`demo_dir'/console_mg_support.log", replace text ///
    name(mg_support) nomsg
noisily psdash support arm, psvars(ps0 ps1 ps2) threshold(0.1) nograph
log close mg_support

**# Convert console logs to markdown via logdoc
capture ado uninstall logdoc
quietly net install logdoc, from("`repo'/logdoc") replace

foreach f in console_overlap console_balance_weights console_support ///
    console_mg_overlap console_mg_balance console_mg_weights ///
    console_mg_support {
    logdoc using "`demo_dir'/`f'.log", ///
        output("`demo_dir'/`f'.md") format(md) replace quiet
}

**# Cleanup
capture log close _all
capture drop _psdash_ps
capture drop _psdash_wt
clear
set varabbrev `_demo_varabbrev'
