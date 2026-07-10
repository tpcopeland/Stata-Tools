/*  demo_finegray.do - Comprehensive demonstration of finegray

    Produces:
      1. Cumulative-incidence curve with confidence band -> .png
      2. CIF estimates -> temporary .dta, verified and removed
*/

version 16.0
clear all
set more off
set varabbrev off
set linesize 120

**# Paths and local installation
local pkg_dir "finegray/demo"
capture mkdir "`pkg_dir'"
capture log close _all

capture ado uninstall finegray
quietly net install finegray, from("`c(pwd)'/finegray") replace

capture ado uninstall tc_schemes
quietly net install tc_schemes, from("`c(pwd)'/tc_schemes") replace
set scheme plotplainblind

**# Estimation features
webuse hypoxia, clear
gen byte status = failtype
gen int site = ceil(_n / 10)
label variable status "Outcome type (0=censored)"
label variable site "Synthetic study site"
stset dftime, failure(dfcens==1) id(stnum)

* # Core model and reporting controls
noisily finegray ifp tumsize pelnode, compete(status) cause(1) ///
    censvalue(0) level(90) iterate(200) tolerance(1e-8) nolog
noisily margins, at(ifp=(0 5 10)) predict(xb)

* # Stratified censoring and cluster-robust inference
noisily finegray ifp tumsize pelnode, compete(status) cause(1) ///
    strata(pelnode) cluster(site) nolog

* # Model-based standard errors and log-SHR coefficients
noisily finegray ifp tumsize pelnode, compete(status) cause(1) ///
    norobust noshr nolog

* # Factor-variable model
noisily finegray i.pelnode ifp tumsize, compete(status) cause(1) ///
    cluster(site) nolog

**# Prediction and diagnostics
quietly finegray i.pelnode ifp tumsize, compete(status) cause(1) ///
    cluster(site) nolog

* # Linear predictor and cumulative incidence
noisily finegray_predict double xb_hat,
noisily finegray_predict double cif_hat, cif
gen double horizon5 = 5
noisily finegray_predict double cif5, cif timevar(horizon5) ci level(90)
noisily finegray_predict double cif5_bs, cif timevar(horizon5) ///
    ci level(90) bootstrap(20) seed(12345)
noisily summarize xb_hat cif_hat cif5 cif5_lci cif5_uci ///
    cif5_bs cif5_bs_lci cif5_bs_uci

* # Prediction on compatible new data
preserve
clear
set obs 4
gen byte pelnode = mod(_n, 2)
gen double ifp = 5 * _n
gen double tumsize = 2 + _n
gen double eval_time = 5
noisily finegray_predict double xb_new, xb
noisily finegray_predict double cif_new, cif timevar(eval_time)
noisily list pelnode ifp tumsize xb_new cif_new, noobs abbreviate(12)
restore

* # Schoenfeld residuals and proportional-hazards tests
noisily finegray_predict double sch, schoenfeld
noisily summarize sch sch_2 sch_3
noisily finegray_phtest
noisily finegray_phtest, time(log) detail

**# Cumulative-incidence curves, tables, bootstrap, and export
quietly finegray i.pelnode ifp tumsize, compete(status) cause(1) ///
    cluster(site) nolog

* # Fixed-horizon CIF for a factor-variable profile
noisily finegray_cif, at(pelnode=1 ifp=20 tumsize=5) ///
    attime(1 3 5 8) ci level(90)

* # Cluster bootstrap with replication diagnostics
noisily finegray_cif, attime(1 5 8) ci bootstrap(20) seed(24680)
noisily display as text "Bootstrap replications requested: " ///
    as result r(bootstrap_requested)
noisily display as text "Bootstrap replications used:      " ///
    as result r(bootstrap_success)
noisily display as text "Bootstrap replications omitted:   " ///
    as result r(bootstrap_requested) - r(bootstrap_success)

* # Custom time grid and numeric-estimate export
preserve
clear
set obs 0
quietly save "`pkg_dir'/_cif_estimates.dta", replace emptyok
restore
noisily finegray_cif, timepoints(1 2 3 4 5 6 7 8) ci nograph ///
    saving("`pkg_dir'/_cif_estimates.dta",replace)
preserve
use "`pkg_dir'/_cif_estimates.dta", clear
assert _N == 8
assert inrange(cif, 0, 1)
assert lci <= cif & cif <= uci
noisily describe
noisily summarize time cif se lci uci
restore
erase "`pkg_dir'/_cif_estimates.dta"

**# Multiple records, delayed entry, and string identifiers
webuse hypoxia, clear
gen byte status = failtype
stset dftime, failure(dfcens==1) id(stnum)

* # Multiple records per subject after stsplit
preserve
stsplit interval, at(2 4 6 8)
noisily finegray ifp tumsize pelnode, compete(status) cause(1) nolog
noisily finegray_cif, attime(1 5 8) ci
noisily finegray_phtest, time(identity)
restore

* # Left-truncated data
gen double entry_time = dftime / 4
stset dftime, failure(dfcens==1) id(stnum) enter(time entry_time)
noisily finegray ifp tumsize pelnode, compete(status) cause(1) nolog
noisily finegray_cif, attime(3 5 8) ci

* # Bootstrap inference with a string id()
webuse hypoxia, clear
gen byte status = failtype
tostring stnum, gen(subject_id)
stset dftime, failure(dfcens==1) id(subject_id)
quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
noisily finegray_cif, attime(1 5 8) ci bootstrap(10) seed(13579)

**# Graph output
webuse hypoxia, clear
gen byte status = failtype
stset dftime, failure(dfcens==1) id(stnum)
quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
finegray_cif, ci ///
    ytitle("Cumulative incidence of cause 1") ///
    xtitle("Analysis time (years)") ///
    title("Fine-Gray cumulative incidence with 95% band") ///
    legend(pos(6))
graph export "`pkg_dir'/finegray_cif.png", replace width(1400)
capture graph close _all

**# Cleanup
capture log close _all
clear
