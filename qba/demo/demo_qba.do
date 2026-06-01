/*  demo_qba.do - Demo output for qba

    Produces:
      1. Console output (package overview)                 -> console_overview.log -> .md
      2. Console output (fixed single-bias analyses)        -> console_single_bias.log -> .md
      3. Console output (model-based confounding analyses)  -> console_model_integration.log -> .md
      4. Console output (probabilistic single-bias analyses)-> console_probabilistic.log -> .md
      5. Console output (multi-bias analysis)               -> console_multi_bias.log -> .md
      6. Graph (three-parameter tornado plot)               -> tornado_plot.png
      7. Graph (multi-bias Monte Carlo distribution)        -> distribution_plot.png
      8. Graph (misclassification tipping-point plot)       -> tipping_plot.png

    Scenario: case-control study of pesticide exposure and cancer
      Exposed cases     = 136,  unexposed cases     = 297
      Exposed controls  = 1432, unexposed controls  = 6738
      Observed OR       = 2.15
*/

version 16.0
local _demo_varabbrev = c(varabbrev)
local _demo_scheme "`c(scheme)'"
capture log close _all
set varabbrev off
set linesize 120

capture noisily {

**# Paths
local cwd = subinstr("`c(pwd)'", "\", "/", .)
local pkg_dir ""
local repo_dir ""
if fileexists("`cwd'/qba/qba.pkg") {
    local repo_dir "`cwd'"
    local pkg_dir "`cwd'/qba"
}
else if fileexists("`cwd'/qba.pkg") {
    local pkg_dir "`cwd'"
    local repo_dir = substr("`cwd'", 1, length("`cwd'") - 4)
}
else {
    display as error "demo_qba.do must be run from the repository root or qba package directory"
    exit 601
}

local demo_dir "`pkg_dir'/demo"
capture mkdir "`demo_dir'"

foreach f in console_overview console_single_bias console_model_integration ///
    console_probabilistic console_multi_bias {
    capture erase "`demo_dir'/`f'.log"
    capture erase "`demo_dir'/`f'.md"
}
foreach f in console_single.smcl console_multi.smcl console_single.png ///
    console_multi.png mc_misclassification.dta mc_selection.dta ///
    mc_confound.dta mc_multi_bias.dta {
    capture erase "`demo_dir'/`f'"
}

local dep_repo "`repo_dir'"
if !fileexists("`dep_repo'/tc_schemes/tc_schemes.pkg") {
    * Fall back to a sibling repository under the same parent directory
    local parent = substr("`repo_dir'", 1, strrpos("`repo_dir'", "/") - 1)
    local sibs : dir "`parent'" dirs "*"
    foreach sib of local sibs {
        if fileexists("`parent'/`sib'/tc_schemes/tc_schemes.pkg") {
            local dep_repo "`parent'/`sib'"
            continue, break
        }
    }
}
if !fileexists("`dep_repo'/tc_schemes/tc_schemes.pkg") {
    display as error "tc_schemes package not found next to `repo_dir' or in a sibling repository"
    exit 601
}
if !fileexists("`dep_repo'/logdoc/logdoc.pkg") {
    display as error "logdoc package not found next to `repo_dir' or in a sibling repository"
    exit 601
}

**# Install local package build
capture ado uninstall qba
quietly net install qba, from("`pkg_dir'") replace
discard

capture ado uninstall tc_schemes
quietly net install tc_schemes, from("`dep_repo'/tc_schemes") replace
set scheme plotplainblind

**# Study constants
local a 136
local b 297
local c 1432
local d 6738
local observed_or 2.15
local reps 5000

**# 1. Package overview
log using "`demo_dir'/console_overview.log", replace text name(overview) nomsg

* # Package overview

qba

display as text ""
display as text "Demo scenario: pesticide exposure and cancer case-control study"
display as text "  Exposed cases:      " as result %9.0fc 136
display as text "  Unexposed cases:    " as result %9.0fc 297
display as text "  Exposed controls:   " as result %9.0fc 1432
display as text "  Unexposed controls: " as result %9.0fc 6738
display as text "  Observed OR:        " as result %9.2f 2.15

log close overview

**# 2. Fixed single-bias analyses
log using "`demo_dir'/console_single_bias.log", replace text name(single) nomsg

* # Fixed-parameter single-bias analyses

* ## Nondifferential exposure misclassification

qba_misclass, a(136) b(297) c(1432) d(6738) ///
    seca(.85) spca(.95)

* ## Differential exposure misclassification

qba_misclass, a(136) b(297) c(1432) d(6738) ///
    seca(.90) spca(.96) secb(.82) spcb(.94)

* ## Outcome misclassification on the RR scale

qba_misclass, a(136) b(297) c(1432) d(6738) ///
    seca(.92) spca(.98) type(outcome) measure(RR)

* ## Selection bias

qba_selection, a(136) b(297) c(1432) d(6738) ///
    sela(.90) selb(.85) selc(.70) seld(.80)

* ## Unmeasured confounding with E-value

qba_confound, estimate(2.15) measure(OR) ///
    p1(.40) p0(.20) rrcd(2.0) evalue ci_bound(1.30)

log close single

**# 3. Model-based confounding analyses
log using "`demo_dir'/console_model_integration.log", replace text name(model) nomsg

* # Model-based confounding correction

quietly {
    clear
    set seed 20260226
    set obs 1200
    gen double age = rnormal(58, 11)
    label variable age "Age (years)"
    gen byte female = runiform() < .48
    label variable female "Female"
    gen double bmi = rnormal(27, 4.5)
    label variable bmi "Body mass index"
    gen double exposure_pr = invlogit(-3.2 + .035 * age + .32 * female + .045 * bmi)
    gen byte exposure = runiform() < exposure_pr
    label variable exposure "Pesticide exposure"
    gen double disease_pr = invlogit(-4.1 + .72 * exposure + .025 * age + .22 * female + .035 * bmi)
    gen byte disease = runiform() < disease_pr
    label variable disease "Cancer"
    gen double biomarker = 42 + 7.5 * exposure + .18 * age - 2.2 * female + .35 * bmi + rnormal(0, 8)
    label variable biomarker "Inflammatory biomarker"
    drop exposure_pr disease_pr
}

quietly logistic disease exposure age female bmi

* ## Logistic model estimate

qba_confound, from_model coef(exposure) ///
    p1(.45) p0(.20) rrcd(2.1) evalue

quietly regress biomarker exposure age female bmi

* ## Linear model coefficient

qba_confound, from_model coef(exposure) ///
    p1(.35) p0(.10) confeffect(4.5)

log close model

**# 4. Probabilistic single-bias analyses
log using "`demo_dir'/console_probabilistic.log", replace text name(prob) nomsg

* # Probabilistic single-bias analyses

* ## Misclassification with trapezoidal Se/Sp distributions

qba_misclass, a(136) b(297) c(1432) d(6738) ///
    seca(.85) spca(.95) reps(5000) ///
    dist_se("trapezoidal .75 .82 .88 .95") ///
    dist_sp("trapezoidal .90 .93 .97 1.0") ///
    seed(20260226)

* ## Selection bias with four selection-probability distributions

qba_selection, a(136) b(297) c(1432) d(6738) ///
    sela(.90) selb(.85) selc(.70) seld(.80) reps(5000) ///
    dist_sela("trapezoidal .82 .87 .95 1.0") ///
    dist_selb("trapezoidal .75 .82 .88 .95") ///
    dist_selc("trapezoidal .58 .66 .74 .82") ///
    dist_seld("trapezoidal .68 .74 .84 .90") ///
    seed(20260227)

* ## Unmeasured confounding with Beta and trapezoidal distributions

qba_confound, estimate(2.15) measure(OR) ///
    p1(.40) p0(.20) rrcd(2.0) reps(5000) ///
    dist_p1("beta 12 18") dist_p0("beta 5 20") ///
    dist_rr("trapezoidal 1.3 1.7 2.3 3.2") ///
    evalue ci_bound(1.30) seed(20260228)

log close prob

**# 5. Multi-bias analysis
log using "`demo_dir'/console_multi_bias.log", replace text name(multi) nomsg

* # Multi-bias Monte Carlo analysis

qba_multi, a(136) b(297) c(1432) d(6738) reps(5000) ///
    seca(.85) spca(.95) ///
    dist_se("trapezoidal .75 .82 .88 .95") ///
    dist_sp("trapezoidal .90 .93 .97 1.0") ///
    sela(.90) selb(.85) selc(.70) seld(.80) ///
    dist_sela("trapezoidal .82 .87 .95 1.0") ///
    dist_selb("trapezoidal .75 .82 .88 .95") ///
    dist_selc("trapezoidal .58 .66 .74 .82") ///
    dist_seld("trapezoidal .68 .74 .84 .90") ///
    p1(.40) p0(.20) rrcd(2.0) ///
    dist_p1("beta 12 18") dist_p0("beta 5 20") ///
    dist_rr("trapezoidal 1.3 1.7 2.3 3.2") ///
    seed(20260229)

log close multi

**# Saved Monte Carlo verification
qba_misclass, a(`a') b(`b') c(`c') d(`d') ///
    seca(.85) spca(.95) reps(`reps') ///
    dist_se("trapezoidal .75 .82 .88 .95") ///
    dist_sp("trapezoidal .90 .93 .97 1.0") ///
    seed(20260226) saving("`demo_dir'/mc_misclassification.dta", replace)
local mis_reps = r(reps)
preserve
quietly use "`demo_dir'/mc_misclassification.dta", clear
assert _N == `mis_reps'
confirm numeric variable corrected_or
quietly summarize corrected_or
display as text "Verified saved misclassification MC dataset: " ///
    as result %8.0fc r(N) as text " rows; mean corrected OR = " ///
    as result %6.3f r(mean)
restore

qba_selection, a(`a') b(`b') c(`c') d(`d') ///
    sela(.90) selb(.85) selc(.70) seld(.80) reps(`reps') ///
    dist_sela("trapezoidal .82 .87 .95 1.0") ///
    dist_selb("trapezoidal .75 .82 .88 .95") ///
    dist_selc("trapezoidal .58 .66 .74 .82") ///
    dist_seld("trapezoidal .68 .74 .84 .90") ///
    seed(20260227) saving("`demo_dir'/mc_selection.dta", replace)
local sel_reps = r(reps)
preserve
quietly use "`demo_dir'/mc_selection.dta", clear
assert _N == `sel_reps'
confirm numeric variable corrected_or
quietly summarize corrected_or
display as text "Verified saved selection MC dataset:        " ///
    as result %8.0fc r(N) as text " rows; mean corrected OR = " ///
    as result %6.3f r(mean)
restore

qba_confound, estimate(`observed_or') measure(OR) ///
    p1(.40) p0(.20) rrcd(2.0) reps(`reps') ///
    dist_p1("beta 12 18") dist_p0("beta 5 20") ///
    dist_rr("trapezoidal 1.3 1.7 2.3 3.2") ///
    evalue ci_bound(1.30) seed(20260228) ///
    saving("`demo_dir'/mc_confound.dta", replace)
local conf_reps = r(reps)
preserve
quietly use "`demo_dir'/mc_confound.dta", clear
assert _N == `conf_reps'
confirm numeric variable corrected_or
quietly summarize corrected_or
display as text "Verified saved confounding MC dataset:      " ///
    as result %8.0fc r(N) as text " rows; mean corrected OR = " ///
    as result %6.3f r(mean)
restore

qba_multi, a(`a') b(`b') c(`c') d(`d') reps(`reps') ///
    seca(.85) spca(.95) ///
    dist_se("trapezoidal .75 .82 .88 .95") ///
    dist_sp("trapezoidal .90 .93 .97 1.0") ///
    sela(.90) selb(.85) selc(.70) seld(.80) ///
    dist_sela("trapezoidal .82 .87 .95 1.0") ///
    dist_selb("trapezoidal .75 .82 .88 .95") ///
    dist_selc("trapezoidal .58 .66 .74 .82") ///
    dist_seld("trapezoidal .68 .74 .84 .90") ///
    p1(.40) p0(.20) rrcd(2.0) ///
    dist_p1("beta 12 18") dist_p0("beta 5 20") ///
    dist_rr("trapezoidal 1.3 1.7 2.3 3.2") ///
    seed(20260229) saving("`demo_dir'/mc_multi_bias.dta", replace)
local multi_reps = r(reps)
preserve
quietly use "`demo_dir'/mc_multi_bias.dta", clear
assert _N == `multi_reps'
confirm numeric variable corrected_or
confirm numeric variable a_corr
confirm numeric variable d_corr
quietly summarize corrected_or
display as text "Verified saved multi-bias MC dataset:       " ///
    as result %8.0fc r(N) as text " rows; mean corrected OR = " ///
    as result %6.3f r(mean)
restore

**# 6. Graph outputs
qba_plot, tornado a(`a') b(`b') c(`c') d(`d') ///
    param1(se) range1(.70 .98) ///
    param2(sp) range2(.90 1.00) ///
    param3(rrcd) range3(1.2 3.5) ///
    base_p1(.40) base_p0(.20) base_rrcd(2.0) ///
    steps(35) title("Sensitivity of Corrected OR to Bias Parameters") ///
    saving("`demo_dir'/tornado_plot.png") replace
capture graph close _all

qba_plot, distribution using("`demo_dir'/mc_multi_bias.dta") ///
    observed(`observed_or') ///
    title("Distribution of Multi-Bias Corrected OR") ///
    saving("`demo_dir'/distribution_plot.png") replace
capture graph close _all

qba_plot, tipping a(`a') b(`b') c(`c') d(`d') ///
    param1(se) range1(.65 .98) ///
    param2(sp) range2(.85 1.00) ///
    steps(30) title("Misclassification Tipping Point: Corrected OR") ///
    saving("`demo_dir'/tipping_plot.png") replace
capture graph close _all

foreach f in mc_misclassification.dta mc_selection.dta mc_confound.dta ///
    mc_multi_bias.dta {
    capture erase "`demo_dir'/`f'"
}

**# Convert console logs to markdown
capture ado uninstall logdoc
quietly net install logdoc, from("`dep_repo'/logdoc") replace

foreach f in console_overview console_single_bias console_model_integration ///
    console_probabilistic console_multi_bias {
    logdoc using "`demo_dir'/`f'.log", ///
        output("`demo_dir'/`f'.md") format(md) replace quiet
}

clear
}
local _demo_rc = _rc

**# Cleanup
capture log close _all
capture graph close _all
foreach f in mc_misclassification.dta mc_selection.dta mc_confound.dta ///
    mc_multi_bias.dta {
    capture erase "`demo_dir'/`f'"
}
capture ado uninstall qba
set scheme `_demo_scheme'
set varabbrev `_demo_varabbrev'
if `_demo_rc' exit `_demo_rc'
