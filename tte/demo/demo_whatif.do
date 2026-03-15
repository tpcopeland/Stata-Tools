/*  demo_whatif.do — What If Programs 17.2 and 17.3

    Replicates the NHEFS smoking cessation survival analysis from:
      Hernan MA, Robins JM. Causal Inference: What If. 2020.
      Chapter 17: Causal survival analysis.
      Code: github.com/eleanormurray/causalinferencebook_stata

    Program 17.2: Unweighted pooled logistic hazards model
    Program 17.3: IP-weighted pooled logistic with standardized
                  survival curves

    Data: NHEFS (1,629 smokers from NHANES I, 1971-1975)
      Treatment: quit smoking between baseline and 1982
      Outcome:   all-cause mortality, January 1983 - December 1992
      Follow-up: 120 person-months

    Companion scripts:
      demo_whatif_trialemulation.R  — R TrialEmulation
      demo_whatif_emulate.R         — R emulate

    Produces:
      - survival_curves_crude.png       (Program 17.2)
      - survival_curves_ipweighted.png  (Program 17.3, Figure 17.6)
      - protocol.xlsx
      - console_output.smcl
      - comparison.csv
*/

version 16.0
set more off
set varabbrev off

local pkg_dir "tte/demo"
local out_dir "`pkg_dir'/whatif"
capture mkdir "`out_dir'"

* --- Load tte for protocol table only ---
foreach cmd in tte_protocol {
    capture program drop `cmd'
    quietly run tte/`cmd'.ado
}

log using "`out_dir'/console_output.smcl", replace smcl name(whatif) nomsg

noisily display as text ""
noisily display as text "WHAT IF REPLICATION: NHEFS Smoking Cessation & Survival"
noisily display as text "Hernan MA, Robins JM. Causal Inference: What If. 2020."
noisily display as text "Programs 17.2 and 17.3"


* =====================================================================
* TARGET TRIAL PROTOCOL
* =====================================================================

noisily display as text ""
noisily tte_protocol, ///
    eligibility("Cigarette smokers aged 25-74 in NHANES I (1971-1975) with complete confounder data (N=1,629)") ///
    treatment("Quit smoking (A=1) vs. continue smoking (A=0), sustained from baseline through 1982") ///
    assignment("At baseline, based on observed smoking cessation behavior") ///
    followup_start("January 1983 (after treatment assessment window)") ///
    outcome("All-cause mortality through December 1992 (120 months)") ///
    causal_contrast("Per-protocol effect of sustained smoking cessation") ///
    analysis("IP-weighted pooled logistic hazards model; stabilized weights; robust SE clustered by individual") ///
    export("`out_dir'/protocol.xlsx") format(excel) replace


* =====================================================================
* DATA PREPARATION: Person-month dataset (Program 17.2 setup)
* =====================================================================

use tte/qa/data/nhefs.dta, clear

drop if missing(qsmk, death, age, sex, race, wt71, smokeintensity, ///
    smokeyrs, exercise, active, education)

noisily display as text ""
noisily display as text "DATA"
noisily display as text "  Subjects:      " _N
noisily display as text "  Treatment:     quit smoking (qsmk)"

quietly count if death == 1
noisily display as text "  Deaths:        " r(N) " (" %4.1f 100*r(N)/_N "%)"

* Survival time in months (January 1983 = month 0)
generate survtime = 120 if death == 0
replace survtime = (yrdth - 83) * 12 + modth if death == 1

* Expand to person-month
generate time = 0
expand survtime if time == 0
bysort seqn: replace time = _n - 1

* Event in the last observed month for decedents
generate event = 0
replace event = 1 if time == survtime - 1 & death == 1

generate timesq = time * time

noisily display as text "  Person-months: " %9.0fc _N

tempfile nhefs_surv
save `nhefs_surv'


* =====================================================================
* PROGRAM 17.2: Unweighted pooled logistic hazards model
* =====================================================================
* Parametric estimation of survival curves. No confounding adjustment.
* The model includes treatment x time interactions so each arm gets
* its own hazard trajectory.

noisily display as text ""
noisily display as text "PROGRAM 17.2: Unweighted (crude) pooled logistic"

logistic event i.qsmk i.qsmk#c.time i.qsmk#c.time#c.time ///
    c.time c.time#c.time

local crude_coef = _b[1.qsmk]
local crude_or   = exp(`crude_coef')
noisily display as text "  Crude OR for qsmk: " as result %6.4f `crude_or'

* Standardized survival curves (crude)
drop if time != 0
expand 120 if time == 0
bysort seqn: replace time = _n - 1

expand 2, generate(interv)
replace qsmk = interv

predict pevent_k, pr
generate psurv_k = 1 - pevent_k
keep seqn time qsmk interv psurv_k

sort seqn interv time
generate _t = time + 1
generate double psurv = psurv_k if _t == 1
bysort seqn interv: replace psurv = psurv_k * psurv[_t - 1] if _t > 1

noisily display as text ""
noisily display as text "  10-year survival (crude, month 119):"
quietly summarize psurv if interv == 0 & time == 119
local surv_crude_0 = r(mean)
noisily display as text "    Continue smoking: " as result %6.4f r(mean)
quietly summarize psurv if interv == 1 & time == 119
local surv_crude_1 = r(mean)
noisily display as text "    Quit smoking:     " as result %6.4f r(mean)
noisily display as text "    Difference:       " as result %6.4f `surv_crude_1' - `surv_crude_0'

* Plot crude survival
expand 2 if time == 0, generate(newtime)
replace psurv = 1 if newtime == 1
generate time2 = 0 if newtime == 1
replace time2 = time + 1 if newtime == 0
separate psurv, by(interv)

twoway (line psurv0 time2, sort lcolor(navy) lwidth(medthick)) ///
    (line psurv1 time2, sort lcolor(cranberry) lwidth(medthick)) ///
    if interv > -1, ///
    ylabel(0.6(0.1)1.0) xlabel(0(12)120) ///
    ytitle("Survival probability") ///
    xtitle("Months of follow-up") ///
    legend(label(1 "Continue smoking (A=0)") ///
           label(2 "Quit smoking (A=1)") rows(1)) ///
    title("Crude survival curves (Program 17.2)") ///
    scheme(plotplainblind)
graph export "`out_dir'/survival_curves_crude.png", replace width(1200)
capture graph close _all


* =====================================================================
* PROGRAM 17.3: IP-weighted pooled logistic hazards model
* =====================================================================
* Stabilized IP weights adjust for confounding. The outcome model
* has NO covariates — confounding is handled entirely by the weights.
* This is the standard MSM approach from What If Chapter 12.

noisily display as text ""
noisily display as text "PROGRAM 17.3: IP-weighted pooled logistic"

use `nhefs_surv', clear

* --- Stabilized IP weights ---
* Denominator: P(A=1 | L) — exact textbook propensity score model
*   logit qsmk sex race c.age##c.age ib(last).education
*     c.smokeintensity##c.smokeintensity c.smokeyrs##c.smokeyrs
*     ib(last).exercise ib(last).active c.wt71##c.wt71
quietly logit qsmk sex race c.age##c.age ib(last).education ///
    c.smokeintensity##c.smokeintensity ///
    c.smokeyrs##c.smokeyrs ///
    ib(last).exercise ib(last).active ///
    c.wt71##c.wt71 if time == 0
quietly predict p_qsmk, pr

* Numerator: P(A=1) — marginal prevalence
quietly logit qsmk if time == 0
quietly predict num, pr

* Stabilized weights: f(A) / f(A|L)
generate double sw = num / p_qsmk if qsmk == 1
replace sw = (1 - num) / (1 - p_qsmk) if qsmk == 0

noisily display as text "  Stabilized IP weights:"
noisily summarize sw

* --- IP-weighted hazards model ---
* Treatment x time interactions, NO outcome covariates
noisily display as text ""
noisily display as text "  IP-weighted pooled logistic model:"

logit event i.qsmk i.qsmk#c.time i.qsmk#c.time#c.time ///
    c.time c.time#c.time [pweight=sw], cluster(seqn)

local ipw_coef = _b[1.qsmk]
local ipw_se   = _se[1.qsmk]
local ipw_or   = exp(`ipw_coef')

noisily display as text ""
noisily display as text "  Treatment coefficient: " as result %8.4f `ipw_coef'
noisily display as text "  Robust SE:             " as result %8.4f `ipw_se'
noisily display as text "  OR:                    " as result %8.4f `ipw_or'

* --- Standardized survival curves ---
drop if time != 0
expand 120 if time == 0
bysort seqn: replace time = _n - 1

expand 2, generate(interv)
replace qsmk = interv

predict pevent_k, pr
generate psurv_k = 1 - pevent_k
keep seqn time qsmk interv psurv_k

sort seqn interv time
generate _t = time + 1
generate double psurv = psurv_k if _t == 1
bysort seqn interv: replace psurv = psurv_k * psurv[_t - 1] if _t > 1

* 10-year standardized survival
noisily display as text ""
noisily display as text "  10-year standardized survival (month 119):"
quietly summarize psurv if interv == 0 & time == 119
local surv_ipw_0 = r(mean)
noisily display as text "    Continue smoking (A=0): " as result %6.4f r(mean)
quietly summarize psurv if interv == 1 & time == 119
local surv_ipw_1 = r(mean)
noisily display as text "    Quit smoking (A=1):     " as result %6.4f r(mean)
local surv_diff = `surv_ipw_1' - `surv_ipw_0'
noisily display as text "    Survival difference:    " as result %6.4f `surv_diff'
noisily display as text ""
noisily display as text "  Interpretation: positive difference means quitting"
noisily display as text "  smoking increases 10-year survival probability."

* --- Plot IP-weighted survival curves (Figure 17.6) ---
expand 2 if time == 0, generate(newtime)
replace psurv = 1 if newtime == 1
generate time2 = 0 if newtime == 1
replace time2 = time + 1 if newtime == 0
separate psurv, by(interv)

twoway (line psurv0 time2, sort lcolor(navy) lwidth(medthick)) ///
    (line psurv1 time2, sort lcolor(cranberry) lwidth(medthick)) ///
    if interv > -1, ///
    ylabel(0.6(0.1)1.0) xlabel(0(12)120) ///
    ytitle("Survival probability") ///
    xtitle("Months of follow-up") ///
    legend(label(1 "Continue smoking (A=0)") ///
           label(2 "Quit smoking (A=1)") rows(1)) ///
    title("IP-weighted survival curves (What If Figure 17.6)") ///
    scheme(plotplainblind)
graph export "`out_dir'/survival_curves_ipweighted.png", replace width(1200)
capture graph close _all


* =====================================================================
* SUMMARY
* =====================================================================

noisily display as text ""
noisily display as text _dup(69) "="
noisily display as text "SUMMARY"
noisily display as text _dup(69) "-"
noisily display as text %35s "" %12s "Coefficient" %10s "OR"
noisily display as text _dup(57) "-"
noisily display as text %35s "Program 17.2 (crude)" ///
    as result %12.4f `crude_coef' %10.4f `crude_or'
noisily display as text %35s "Program 17.3 (IP-weighted)" ///
    as result %12.4f `ipw_coef' %10.4f `ipw_or'
noisily display as text _dup(57) "-"
noisily display as text ""
noisily display as text %35s "" %12s "Continue" %10s "Quit" %12s "Diff"
noisily display as text _dup(69) "-"
noisily display as text %35s "10-yr survival (crude)" ///
    as result %12.4f `surv_crude_0' %10.4f `surv_crude_1' ///
    %12.4f `surv_crude_1' - `surv_crude_0'
noisily display as text %35s "10-yr survival (IP-weighted)" ///
    as result %12.4f `surv_ipw_0' %10.4f `surv_ipw_1' ///
    %12.4f `surv_diff'
noisily display as text _dup(69) "="

* --- Save comparison CSV ---
tempname comp
postfile `comp' str35 method coef or surv0 surv1 using ///
    "`out_dir'/comparison.dta", replace
post `comp' ("Program_17.2_crude") ///
    (`crude_coef') (`crude_or') (`surv_crude_0') (`surv_crude_1')
post `comp' ("Program_17.3_IPweighted") ///
    (`ipw_coef') (`ipw_or') (`surv_ipw_0') (`surv_ipw_1')
postclose `comp'

use "`out_dir'/comparison.dta", clear
export delimited using "`out_dir'/comparison.csv", replace

log close whatif
capture graph close _all
clear
