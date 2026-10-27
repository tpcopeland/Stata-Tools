* crossval_stcrprep_lt.do - delayed-entry Fine-Gray: finegray vs stcrprep + stcox
* Package: finegray
*
* WHAT THIS ANSWERS. Under delayed entry, Lambert's stcrprep (SSC) writes the Geskus (2011) weight as two variables: weight_c, the censoring part G(t)/G(X), and weight_t, the entry part H(X)/H(t). The Fine-Gray weight is their PRODUCT. This suite fits finegray's pooled delayed-entry model and a weighted stcox on stcrprep's expanded rows with [pw = weight_c*weight_t], on five simulated left-truncated cohorts, and gates that the coefficients agree. stcrprep shares no code with finegray, so agreement shows that finegray's pooled weight equals the Geskus product weight.
*
* NEGATIVE CONTROL (gated). weight_c alone ignores the entry process. It must NOT reproduce finegray; otherwise the product-weight gate would have no power to detect a dropped entry weight.
*
* STRATIFIED (informational, not gated). stcrprep's byg()/byh() estimate G and H fully within groups (Geskus). finegray's strata()/truncstrata() use ZZF (2011) eq. 6 with the pooled stabilizer, a different weight, so the two are expected to differ by roughly 1e-3 to 1e-2. The difference is reported only.
*
* DGP. The delayed-entry cohort in the Stata Journal companion do-file (seed block `set seed 20260713'): 24,000 drawn, keep entry_time < time, keep the first 4,000; seeds 20260713, 101, 202, 303, 404.
*
* DEPENDENCY. stcrprep is not shipped with Stata and this file does not install it. When it is absent the suite prints a SKIP and exits 0 with skip=10 in its RESULT line. run_all counts any skip as a failure and sandboxes PLUS, which is why this file is not in a run_all lane (see qa/README.md).

clear all
set more off
set varabbrev off
version 16.0

* stcrprep builds G(t) and H(t) with `sts gen', which uses the default storage type; float survivor values would cap agreement near 1e-7, above the gate.
set type double

local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0
local failed_tests ""

local pkgroot "`c(pwd)'"
capture confirm file "`pkgroot'/finegray.pkg"
if _rc {
    capture confirm file "`pkgroot'/../finegray.pkg"
    if _rc {
        display as error "could not locate finegray package root"
        exit 601
    }
    local pkgroot "`pkgroot'/.."
}
local qadir "`pkgroot'/qa"

capture log close _all
log using "`qadir'/crossval_stcrprep_lt.log", replace text name(_cvsplt)

capture ado uninstall finegray
quietly net install finegray, from("`pkgroot'") replace

local seeds 20260713 101 202 303 404
local n_seeds : word count `seeds'

* Both fits maximize the same weighted partial likelihood by Newton-Raphson, so agreement is limited by convergence noise (observed below 1e-14); 1e-8 sits far above that and far below the 1e-3 stratified-weight gap.
local tol 1e-8
* The negative control must miss by more than this (observed 0.07 to 0.12).
local negtol 1e-2

* ---------------------------------------------------------------------------
* stcrprep is an optional comparator: absent -> SKIP, not FAIL.
* ---------------------------------------------------------------------------
capture findfile stcrprep.ado
if _rc {
    local test_count = 2 * `n_seeds'
    local skip_count = 2 * `n_seeds'
    display as error "SKIP: stcrprep is not installed (ssc install stcrprep)."
    display as error "  No comparison was run; this is an unrun check, not a pass."
    display "RESULT: crossval_stcrprep_lt tests=`test_count' pass=`pass_count' fail=`fail_count' skip=`skip_count'"
    log close _cvsplt
    exit 0
}
local _ref_ver "unknown"
tempname _ref_fh
file open `_ref_fh' using "`r(fn)'", read text
file read `_ref_fh' _ref_line
file close `_ref_fh'
if regexm(`"`macval(_ref_line)'"', "version ([0-9.]+)") local _ref_ver = regexs(1)
display "REFERENCE: stcrprep `_ref_ver'"

tempfile cohort
local max_prod = 0
local min_neg = .
local max_strat = 0

display as text _newline "mreldif vs finegray; product gated, weight_c only = negative control"
display as text "    seed       rows    product  weight_c only  stratified"

foreach seed of local seeds {
    * ---- cohort: companion DGP ----
    clear
    set seed `seed'
    quietly set obs 24000
    gen byte z1 = runiform() < 0.5
    gen double z2 = rnormal()
    gen byte g4 = ceil(runiform() * 4)
    gen double ez = exp(0.5*z1 - 0.5*z2)
    gen double p1 = 1 - (1 - 0.5)^ez
    gen byte cause = cond(runiform() < p1, 1, 2)
    gen double v = runiform()
    quietly gen double event_time = -ln(1 - (1 - (1 - v*p1)^(1/ez))/0.5) if cause == 1
    quietly replace event_time = rexponential(1/(0.5*exp(0.5*z1 + 0.5*z2))) if cause == 2
    gen double censor_time = min(rexponential(1/0.15), 6)
    gen double entry_time = rexponential(1/cond(z1 == 1, 1.6, 0.5))
    gen double time = min(event_time, censor_time)
    gen byte status = cond(event_time <= censor_time, cause, 0)
    quietly keep if entry_time < time
    quietly keep in 1/4000
    gen long id = _n
    gen byte any_event = status > 0
    keep id z1 z2 entry_time time status any_event
    quietly save `cohort', replace

    * ---- finegray: pooled and stratified ----
    quietly stset time, failure(any_event == 1) id(id) enter(time entry_time)
    capture quietly finegray z1 z2, compete(status) cause(1) nolog
    local fg_rc = _rc
    if !`fg_rc' matrix b_fg = (_b[z1], _b[z2])
    capture quietly finegray z1 z2, compete(status) cause(1) strata(z1) truncstrata(z1) nolog
    local fgs_rc = _rc
    if !`fgs_rc' matrix b_fgs = (_b[z1], _b[z2])

    * ---- stcrprep pooled: product weight, then weight_c alone ----
    local nrows = .
    use `cohort', clear
    quietly stset time, failure(status == 1 2) id(id) enter(time entry_time)
    capture noisily {
        quietly stcrprep, events(status) keep(z1 z2) trans(1)
        gen byte event = failcode == status
        gen double w = weight_c * weight_t
        local nrows = _N
        quietly stset tstop [pw = w], failure(event == 1) enter(tstart)
        quietly stcox z1 z2, vce(cluster id) nolog
        matrix b_sp = (_b[z1], _b[z2])
        quietly stset tstop [pw = weight_c], failure(event == 1) enter(tstart)
        quietly stcox z1 z2, vce(cluster id) nolog
        matrix b_wc = (_b[z1], _b[z2])
    }
    local sp_rc = _rc

    * ---- stcrprep stratified G and H (informational) ----
    use `cohort', clear
    quietly stset time, failure(status == 1 2) id(id) enter(time entry_time)
    capture noisily {
        quietly stcrprep, events(status) keep(z1 z2) trans(1) byg(z1) byh(z1)
        gen byte event = failcode == status
        gen double w = weight_c * weight_t
        quietly stset tstop [pw = w], failure(event == 1) enter(tstart)
        quietly stcox z1 z2, vce(cluster id) nolog
        matrix b_sps = (_b[z1], _b[z2])
    }
    local sps_rc = _rc

    * ---- gate 1: product weight reproduces finegray ----
    local ++test_count
    local d_prod = .
    local d_neg = .
    if `fg_rc' | `sp_rc' {
        local ++fail_count
        local failed_tests "`failed_tests' prod_`seed'"
        display as error "  FAIL: seed `seed' -- fit rc finegray=`fg_rc' stcrprep/stcox=`sp_rc'"
    }
    else {
        local d_prod = mreldif(b_sp, b_fg)
        local d_neg = mreldif(b_wc, b_fg)
        local max_prod = max(`max_prod', `d_prod')
        if `d_prod' < `tol' local ++pass_count
        else {
            local ++fail_count
            local failed_tests "`failed_tests' prod_`seed'"
            display as error "  FAIL: seed `seed' -- product-weight mreldif `d_prod' >= `tol'"
        }
    }

    * ---- gate 2: weight_c alone must not reproduce finegray ----
    local ++test_count
    if missing(`d_neg') {
        local ++fail_count
        local failed_tests "`failed_tests' negctl_`seed'"
    }
    else {
        local min_neg = min(`min_neg', `d_neg')
        if `d_neg' > `negtol' local ++pass_count
        else {
            local ++fail_count
            local failed_tests "`failed_tests' negctl_`seed'"
            display as error "  FAIL: seed `seed' -- weight_c alone matches finegray (mreldif `d_neg')"
        }
    }

    * ---- stratified comparison: report only ----
    local d_strat = .
    if !`fgs_rc' & !`sps_rc' {
        local d_strat = mreldif(b_sps, b_fgs)
        local max_strat = max(`max_strat', `d_strat')
    }
    display as text %8.0f `seed' " " %10.0fc `nrows' " " %10.2e `d_prod' ///
        " " %14.2e `d_neg' " " %11.2e `d_strat'
}

display as text _newline "Max product-weight mreldif:   " as result %9.2e `max_prod' as text "  (gate < `tol')"
display as text "Min weight_c-only mreldif:    " as result %9.2e `min_neg' as text "  (gate > `negtol')"
display as text "Max stratified mreldif:       " as result %9.2e `max_strat' as text "  (Geskus byg/byh vs ZZF eq. 6)"

* ============================================================================
**# Summary
* ============================================================================
display "RESULT: crossval_stcrprep_lt tests=`test_count' pass=`pass_count' fail=`fail_count' skip=`skip_count'"
if `fail_count' > 0 {
    display as error "FAILED:`failed_tests'"
    log close _cvsplt
    exit 1
}
display as result "ALL CROSS-VALIDATIONS PASSED"
log close _cvsplt
