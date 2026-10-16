* test_iivw_quiet_output.do
* Console output contract: the commands print their own results, warnings and
* errors, and nothing of their internal machinery. Before 1.0.0 a bare
* -iivw_weight, nolog- printed "(60 observations created)", a run of
* "(N real changes made)", the internal -stset- settings with temporary
* variable names, the visit Cox and treatment logit tables, tempfile
* "saved as .dta format" lines and a -merge- result table; -iivw_balance-
* printed observation counts from its interval rebuild; -iivw_exogtest-
* printed its -stset- settings; shard fits and -iivw_bspool- printed the
* replicate dataset label and "(results ... are active now)".
* budget: 9
*
*   T1  IIW weight, nolog: no noise, no model tables; result block present
*   T2  FIPTIW + stabcov, nolog: no noise; model labels kept, tables hidden
*   T3  default log mode: nuisance fits shown, no internal st header or noise
*   T4  iivw_balance and iivw_exogtest (nolog and log): no noise
*   T5  iivw_fit (fixed, bootstrap shards) and iivw_bspool: no noise
*   T6  warnings stay visible inside the quieted blocks (Breslow tie note)
*   T7  errors stay visible inside the quieted blocks (failed visit model)
*   T8  an omitted (collinear) visit or treatment covariate is still named
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_quiet_output.do [case#]

clear all
set varabbrev off
version 16.0

capture log close _all
tempfile test_log
log using "`test_log'", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed ""

local qa_dir "`c(pwd)'"
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap

iivw_qa_selector `1'
local run_only = r(run_only)

tempfile _stub
local work "`_stub'_quiet"

* The README Quick Start panel.
capture program drop _qo_panel
program define _qo_panel
    version 16.0
    syntax [, TIED]
    clear
    set seed 20260417
    quietly set obs 240
    quietly gen long id = ceil(_n/4)
    quietly bysort id: gen byte visit = _n
    if "`tied'" == "" {
        quietly gen double time = 3 * (visit - 1) + runiform() * .05
    }
    else {
        quietly gen double time = 3 * (visit - 1) + floor(runiform() * 2)
    }
    quietly replace time = 0 if visit == 1
    quietly gen double x = rnormal()
    quietly bysort id: replace x = x[1]
    quietly gen byte treated = runiform() < invlogit(.4 + .5 * x)
    quietly bysort id: replace treated = treated[1]
    quietly gen double y = 1 + .1 * time + x + rnormal()
end

* Count the log lines holding any noise string; also report the first one.
* mode(nolog) adds the model-table and iteration-log strings.
capture program drop _qo_scan
program define _qo_scan, rclass
    version 16.0
    syntax , LOG(string) [NOLOGMODE]
    mata: _qo_lines = cat(st_local("log"))
    local pats `""real change" "observations created" "observations deleted" "missing values generated" "Survival-time data settings" "saved as .dta" "Not matched" "from master" "are active now" "(bootstrap: " "Failure _d:" "Analysis time _t:" "Enter on or after:" "Number of obs" "'
    if "`nologmode'" != "" {
        local pats `"`pats' "Cox regression" "Logistic regression" "Iteration 0" "Haz. ratio""'
    }
    local n_bad = 0
    local first ""
    foreach p of local pats {
        mata: st_local("hit", strofreal(sum(strpos(_qo_lines, st_local("p")) :> 0)))
        if `hit' > 0 {
            * "Number of obs" is legitimate in the outcome-model glm header;
            * it is noise only as the merge result table's column title.
            if "`p'" == "Number of obs" {
                mata: st_local("hit", strofreal(sum(ustrregexm(_qo_lines, "^ +Result +Number of obs"))))
                if `hit' == 0 continue
            }
            local n_bad = `n_bad' + `hit'
            if "`first'" == "" local first "`p'"
        }
    }
    mata: mata drop _qo_lines
    return scalar n_bad = `n_bad'
    return local first `"`first'"'
end

capture program drop _qo_has
program define _qo_has, rclass
    version 16.0
    syntax , LOG(string) PAT(string)
    mata: st_local("hit", strofreal(sum(strpos(cat(st_local("log")), st_local("pat")) :> 0)))
    return scalar hit = `hit'
end


local ++test_count
if `run_only' == 0 | `run_only' == 1 {
capture noisily {
    _qo_panel
    capture log close qo
    quietly log using "`work'_1.log", text replace name(qo)
    iivw_weight, id(id) time(time) visit_cov(x) lagvars(y) maxfu(12) nolog
    quietly log close qo
    _qo_scan, log("`work'_1.log") nologmode
    if r(n_bad) > 0 display as error "noise: `r(first)'"
    assert r(n_bad) == 0
    _qo_has, log("`work'_1.log") pat("Weight distribution:")
    assert r(hit) == 1
    _qo_has, log("`work'_1.log") pat("Visit model: stcox x y_lag1")
    assert r(hit) == 1
    confirm numeric variable _iivw_weight
    display as result "T1 PASS: IIW nolog output is the result block only"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T1"
    display as error "T1 FAIL"
}
}

local ++test_count
if `run_only' == 0 | `run_only' == 2 {
capture noisily {
    _qo_panel
    capture log close qo
    quietly log using "`work'_2.log", text replace name(qo)
    iivw_weight, id(id) time(time) visit_cov(x) lagvars(y) maxfu(12) ///
        treat(treated) treat_cov(x) stabcov(treated) nolog
    quietly log close qo
    _qo_scan, log("`work'_2.log") nologmode
    if r(n_bad) > 0 display as error "noise: `r(first)'"
    assert r(n_bad) == 0
    _qo_has, log("`work'_2.log") pat("Stabilization model: stcox treated")
    assert r(hit) == 1
    _qo_has, log("`work'_2.log") pat("Treatment model: logit treated x")
    assert r(hit) == 1
    confirm numeric variable _iivw_tw
    display as result "T2 PASS: FIPTIW nolog keeps model labels, hides tables"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T2"
    display as error "T2 FAIL"
}
}

local ++test_count
if `run_only' == 0 | `run_only' == 3 {
capture noisily {
    _qo_panel
    capture log close qo
    quietly log using "`work'_3.log", text replace name(qo)
    iivw_weight, id(id) time(time) visit_cov(x) lagvars(y) maxfu(12) ///
        treat(treated) treat_cov(x) stabcov(treated)
    quietly log close qo
    _qo_scan, log("`work'_3.log")
    if r(n_bad) > 0 display as error "noise: `r(first)'"
    assert r(n_bad) == 0
    * Positive control: without nolog the nuisance fits are displayed.
    _qo_has, log("`work'_3.log") pat("Cox regression")
    assert r(hit) == 2
    _qo_has, log("`work'_3.log") pat("Logistic regression")
    assert r(hit) == 1
    _qo_has, log("`work'_3.log") pat("Iteration 0")
    assert r(hit) >= 3
    display as result "T3 PASS: log mode shows the fits and nothing internal"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T3"
    display as error "T3 FAIL"
}
}

local ++test_count
if `run_only' == 0 | `run_only' == 4 {
capture noisily {
    _qo_panel
    quietly iivw_weight, id(id) time(time) visit_cov(x) lagvars(y) maxfu(12) nolog
    capture log close qo
    quietly log using "`work'_4.log", text replace name(qo)
    iivw_balance
    iivw_balance, agrefit nolog
    iivw_exogtest y, id(id) time(time) maxfu(12) adjust(x) by(treated) replace nolog
    quietly log close qo
    _qo_scan, log("`work'_4.log") nologmode
    if r(n_bad) > 0 display as error "noise: `r(first)'"
    assert r(n_bad) == 0
    _qo_has, log("`work'_4.log") pat("Max |target SMD|")
    assert r(hit) >= 1
    _qo_has, log("`work'_4.log") pat("Joint test p-value")
    assert r(hit) == 2
    * Log mode of iivw_exogtest shows its fits, without the internal st header.
    capture log close qo
    quietly log using "`work'_4b.log", text replace name(qo)
    iivw_exogtest y, id(id) time(time) maxfu(12) adjust(x) replace
    quietly log close qo
    _qo_scan, log("`work'_4b.log")
    if r(n_bad) > 0 display as error "noise: `r(first)'"
    assert r(n_bad) == 0
    _qo_has, log("`work'_4b.log") pat("Cox regression")
    assert r(hit) == 1
    display as result "T4 PASS: balance and exogeneity diagnostics are clean"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T4"
    display as error "T4 FAIL"
}
}

local ++test_count
if `run_only' == 0 | `run_only' == 5 {
capture noisily {
    _qo_panel
    quietly iivw_weight, id(id) time(time) visit_cov(x) maxfu(12) nolog
    capture log close qo
    quietly log using "`work'_5.log", text replace name(qo)
    iivw_fit y x, vce(fixed) nolog
    iivw_fit y x, citype(percentile) vce(bootstrap, reps(20) seed(7)) ///
        rngstream(1) saving("`work'_sh1", replace) nolog allowfailedreps
    iivw_fit y x, citype(percentile) vce(bootstrap, reps(20) seed(7)) ///
        rngstream(2) saving("`work'_sh2", replace) nolog allowfailedreps
    iivw_bspool using "`work'_sh1 `work'_sh2", reps(40)
    quietly log close qo
    * The outcome glm table of a fixed-weight fit is the command's result and
    * is not scanned for model tables (no nologmode).
    _qo_scan, log("`work'_5.log")
    if r(n_bad) > 0 display as error "noise: `r(first)'"
    assert r(n_bad) == 0
    _qo_has, log("`work'_5.log") pat("pooled percentile interval")
    assert r(hit) == 1
    assert e(N_reps) == 40
    display as result "T5 PASS: fits, shard writes and pooling are clean"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T5"
    display as error "T5 FAIL"
}
}

local ++test_count
if `run_only' == 0 | `run_only' == 6 {
capture noisily {
    _qo_panel, tied
    capture log close qo
    quietly log using "`work'_6.log", text replace name(qo)
    iivw_weight, id(id) time(time) visit_cov(x) maxfu(12) breslow nolog
    quietly log close qo
    _qo_has, log("`work'_6.log") pat("visit times are heavily tied")
    assert r(hit) == 1
    _qo_scan, log("`work'_6.log") nologmode
    assert r(n_bad) == 0
    display as result "T6 PASS: the Breslow tie warning is still printed"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T6"
    display as error "T6 FAIL"
}
}

local ++test_count
if `run_only' == 0 | `run_only' == 7 {
capture noisily {
    * A covariate missing on every follow-up row leaves the visit model
    * nothing to fit; the refusal raised inside the quieted block must still
    * reach the console.
    _qo_panel
    quietly gen double xmiss = cond(visit == 1, x, .)
    capture log close qo
    quietly log using "`work'_7.log", text replace name(qo)
    capture noisily iivw_weight, id(id) time(time) visit_cov(xmiss) maxfu(12) nolog
    local rc = _rc
    quietly log close qo
    assert `rc' != 0
    _qo_has, log("`work'_7.log") pat("visit intensity model failed; no weights created")
    assert r(hit) == 1
    capture confirm variable _iivw_weight
    assert _rc != 0
    display as result "T7 PASS: a failed visit model is reported (rc `rc')"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T7"
    display as error "T7 FAIL"
}
}

local ++test_count
if `run_only' == 0 | `run_only' == 8 {
capture noisily {
    * Under nolog the fits are quiet, which also hides Stata's own
    * "omitted because of collinearity" note; iivw_weight must name the
    * omitted term itself, for the visit and the treatment model.
    _qo_panel
    quietly gen double x2 = 2 * x
    capture log close qo
    quietly log using "`work'_8.log", text replace name(qo)
    iivw_weight, id(id) time(time) visit_cov(x x2) maxfu(12) ///
        treat(treated) treat_cov(x x2) nolog
    quietly log close qo
    _qo_has, log("`work'_8.log") pat("note: the visit-intensity model omitted")
    assert r(hit) == 1
    _qo_has, log("`work'_8.log") pat("note: the treatment model omitted")
    assert r(hit) == 1
    _qo_has, log("`work'_8.log") pat("x2")
    assert r(hit) >= 3
    _qo_scan, log("`work'_8.log") nologmode
    assert r(n_bad) == 0
    * Negative control: no note when nothing is omitted.
    capture log close qo
    quietly log using "`work'_8b.log", text replace name(qo)
    iivw_weight, id(id) time(time) visit_cov(x) maxfu(12) ///
        treat(treated) treat_cov(x) replace nolog
    quietly log close qo
    _qo_has, log("`work'_8b.log") pat("model omitted")
    assert r(hit) == 0
    display as result "T8 PASS: omitted nuisance-model terms are named under nolog"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T8"
    display as error "T8 FAIL"
}
}

**# Summary

iivw_qa_summary, name(test_iivw_quiet_output) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') runonly(`run_only') ///
    failedtests("`failed'")
