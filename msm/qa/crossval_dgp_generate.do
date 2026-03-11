* crossval_dgp_generate.do
* Generate shared DGP datasets for cross-language validation
* Exports to CSV so R and Python can analyze the same data
*
* DGP 1: Time-varying treatment + confounder feedback (N=2000, T=8)
*   True causal log-OR = ln(0.70) = -0.357
* DGP 2: Point-treatment (N=3000) for teffects comparison
*   True ATE = 2.0

version 16.0
set more off
set varabbrev off

local qa_dir "/home/tpcopeland/Stata-Tools/msm/qa"
local data_dir "`qa_dir'/crossval_data"

display "CROSS-VALIDATION DGP GENERATOR"
display "Date: $S_DATE $S_TIME"
display ""

* =========================================================================
* DGP 1: Time-varying treatment with confounder feedback
*
*   L_0 ~ Normal(0, 1)
*   V ~ Bernoulli(0.5) [baseline, time-fixed]
*   For t = 0..7:
*     if t>0: L_t = 0.5*L_{t-1} + 0.8*A_{t-1} + N(0, 0.5)
*     A_t ~ Bernoulli(expit(-1 + 0.5*L_t + 0.3*A_{t-1} + 0.2*V))
*     Y_t ~ Bernoulli(expit(-4 + ln(0.7)*A_t + 0.5*L_t + 0.3*V + 0.05*t))
*
*   Treatment-confounder feedback: A_{t-1} -> L_t -> A_t
*   creates confounding that naive regression on L cannot handle
* =========================================================================
display "DGP 1: Time-varying treatment (N=2000, T=8)"

local N1 = 2000
local T1 = 8
local true_logor = ln(0.70)

clear
set seed 54321
local N_total = `N1' * `T1'
set obs `N_total'

gen long id = ceil(_n / `T1')
bysort id: gen int period = _n - 1

* Baseline confounder (time-fixed)
gen byte V = .
bysort id: replace V = (runiform() < 0.5) if _n == 1
bysort id (period): replace V = V[1]

* Time-varying confounder and treatment/outcome
gen double L = .
gen byte treatment = .
gen byte outcome = .

sort id period
quietly {
    * First period (t=0)
    by id: replace L = rnormal(0, 1) if period == 0
    by id: replace treatment = (runiform() < invlogit(-1 + 0.5*L + 0.2*V)) if period == 0
    by id: replace outcome = (runiform() < invlogit(-4 + `true_logor'*treatment + 0.5*L + 0.3*V)) if period == 0

    * Subsequent periods with feedback
    forvalues p = 1/`=`T1'-1' {
        by id: replace L = 0.5*L[_n-1] + 0.8*treatment[_n-1] + rnormal(0, 0.5) if period == `p'
        by id: replace treatment = (runiform() < invlogit(-1 + 0.5*L + 0.3*treatment[_n-1] + 0.2*V)) if period == `p'
        by id: replace outcome = (runiform() < invlogit(-4 + `true_logor'*treatment + 0.5*L + 0.3*V + 0.05*`p')) if period == `p'
    }
}

* Create lagged treatment (needed for cross-validation scripts)
sort id period
by id: gen byte lag_treatment = treatment[_n-1]

* Summary
display "  Observations: " _N
display "  Individuals:  " `N1'
display "  Periods:      " `T1'
display "  True log-OR:  " %7.4f `true_logor' " (OR = 0.70)"
tabulate treatment outcome

* Save Stata format
save "`data_dir'/dgp1_panel.dta", replace

* Export CSV for R and Python
export delimited using "`data_dir'/dgp1_panel.csv", replace
display "  Saved: dgp1_panel.dta and dgp1_panel.csv"
display ""

* =========================================================================
* DGP 2: Point-treatment for teffects comparison
*
*   X1 ~ Normal(0, 1), X2 ~ Bernoulli(0.4)
*   A ~ Bernoulli(expit(-0.5 + 0.6*X1 + 0.4*X2))
*   Y = 5 + 2.0*A + 1.5*X1 + 1.0*X2 + N(0, 2)
*
*   True ATE = 2.0 (exactly)
* =========================================================================
display "DGP 2: Point-treatment (N=3000)"

clear
set seed 12345
set obs 3000

gen long id = _n
gen double X1 = rnormal(0, 1)
gen byte X2 = (runiform() < 0.4)

* Treatment assignment (confounded)
gen double ps_true = invlogit(-0.5 + 0.6*X1 + 0.4*X2)
gen byte treatment = (runiform() < ps_true)

* Outcome (linear, ATE = 2.0 exactly)
gen double Y = 5 + 2.0*treatment + 1.5*X1 + 1.0*X2 + rnormal(0, 2)

display "  Observations: " _N
display "  True ATE:     2.000"
tabulate treatment

save "`data_dir'/dgp2_point.dta", replace
export delimited using "`data_dir'/dgp2_point.csv", replace
display "  Saved: dgp2_point.dta and dgp2_point.csv"
display ""

* =========================================================================
* DGP 3: True counterfactual simulation
*   Same DGP as DGP 1 but we generate both potential outcome worlds
*   to compute the TRUE marginal causal effect
*
*   We generate 3 copies:
*     (a) Observed world (same as DGP 1, same seed)
*     (b) Always-treated world: set A_t = 1 for all t
*     (c) Never-treated world: set A_t = 0 for all t
*
*   The true marginal causal OR = odds(Y=1|always) / odds(Y=1|never)
*   averaged across periods
* =========================================================================
display "DGP 3: True counterfactual simulation (N=10000, T=8)"

local N3 = 10000
local T3 = 8

* --- Always treated world ---
clear
set seed 54321
local N_total = `N3' * `T3'
set obs `N_total'

gen long id = ceil(_n / `T3')
bysort id: gen int period = _n - 1

gen byte V = .
bysort id: replace V = (runiform() < 0.5) if _n == 1
bysort id (period): replace V = V[1]

gen double L = .
gen byte Y_always = .

sort id period
quietly {
    * Synchronize random draws: use same rnormal() seeds for L and V
    * but set treatment to 1 always
    by id: replace L = rnormal(0, 1) if period == 0
    * A = 1 always, so L_{t+1} depends on A=1
    by id: replace Y_always = (runiform() < invlogit(-4 + `true_logor'*1 + 0.5*L + 0.3*V)) if period == 0

    forvalues p = 1/`=`T3'-1' {
        * L evolves with A=1: L_t = 0.5*L_{t-1} + 0.8*1 + noise
        by id: replace L = 0.5*L[_n-1] + 0.8*1 + rnormal(0, 0.5) if period == `p'
        by id: replace Y_always = (runiform() < invlogit(-4 + `true_logor'*1 + 0.5*L + 0.3*V + 0.05*`p')) if period == `p'
    }
}

tempfile always_world
collapse (mean) risk_always = Y_always, by(period)
save `always_world'

* --- Never treated world ---
clear
set seed 54321
set obs `N_total'

gen long id = ceil(_n / `T3')
bysort id: gen int period = _n - 1

gen byte V = .
bysort id: replace V = (runiform() < 0.5) if _n == 1
bysort id (period): replace V = V[1]

gen double L = .
gen byte Y_never = .

sort id period
quietly {
    by id: replace L = rnormal(0, 1) if period == 0
    by id: replace Y_never = (runiform() < invlogit(-4 + `true_logor'*0 + 0.5*L + 0.3*V)) if period == 0

    forvalues p = 1/`=`T3'-1' {
        * L evolves with A=0: L_t = 0.5*L_{t-1} + 0.8*0 + noise
        by id: replace L = 0.5*L[_n-1] + 0.8*0 + rnormal(0, 0.5) if period == `p'
        by id: replace Y_never = (runiform() < invlogit(-4 + `true_logor'*0 + 0.5*L + 0.3*V + 0.05*`p')) if period == `p'
    }
}

tempfile never_world
collapse (mean) risk_never = Y_never, by(period)
save `never_world'

* Merge and compute true causal contrasts
use `always_world', clear
merge 1:1 period using `never_world', nogenerate

gen double true_rd = risk_always - risk_never
gen double true_or = (risk_always / (1 - risk_always)) / (risk_never / (1 - risk_never))
gen double true_log_or = ln(true_or)

display ""
display "  True counterfactual risks by period:"
list period risk_always risk_never true_rd true_or true_log_or, noobs separator(0)

* Pooled across periods
quietly summarize true_log_or
local pooled_true_logor = r(mean)
quietly summarize true_rd
local pooled_true_rd = r(mean)
display ""
display "  Pooled true log-OR (mean across periods): " %7.4f `pooled_true_logor'
display "  Pooled true RD (mean across periods):     " %7.4f `pooled_true_rd'

save "`data_dir'/dgp3_true_counterfactual.dta", replace
export delimited using "`data_dir'/dgp3_true_counterfactual.csv", replace
display "  Saved: dgp3_true_counterfactual.dta and dgp3_true_counterfactual.csv"

display ""
display "DGP GENERATION COMPLETE"
display "Date: $S_DATE $S_TIME"
