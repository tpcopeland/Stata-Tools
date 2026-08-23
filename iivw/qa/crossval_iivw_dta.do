clear all
set more off
set varabbrev off
version 16.0

* Cross-validation using a same-run double-precision .dta exchange with
* survival::coxph and geepack::geeglm.  Seed 20260823 is set before all draws.
* The MR package named in the dispatch is not method-equivalent: it consumes
* genetic-summary associations, while iivw fits visit-intensity and outcome
* models on longitudinal panels.  Do not replace this oracle with mr_ivw().

do "`c(pwd)'/_iivw_qa_common.do"

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
iivw_qa_bootstrap, pkgdir("`pkg_dir'")

local test_count = 0
local pass_count = 0
local fail_count = 0

* Build a non-degenerate tied-time panel and hand the exact double inputs to R.
set seed 20260823
set obs 320
gen long id = ceil(_n / 4)
gen double time = mod(_n - 1, 4) + 1
gen double x = rnormal() + 0.15 * time
gen double y = 1 + 0.7 * x + 0.2 * time + rnormal(0, 0.35)
sort id time

tempfile r_input r_output
save "`r_input'", replace

local r_script "`qa_dir'/crossval_iivw_dta.R"
capture confirm file "`r_script'"
if _rc {
    display as error "missing R companion: `r_script'"
    display "RESULT: crossval_iivw_dta tests=0 pass=0 fail=0 skip=0"
    exit 601
}

* `r_output' is a new tempfile, so its existence proves this invocation wrote
* an oracle rather than reusing a stale reference artifact.
shell Rscript "`r_script'" "`r_input'" "`r_output'"
capture confirm file "`r_output'"
if _rc {
    display as error "R .dta oracle did not produce its output"
    display "RESULT: crossval_iivw_dta tests=0 pass=0 fail=0 skip=0"
    exit 601
}

iivw_weight, id(id) time(time) visit_cov(x) baseline(event) ///
    endatlastvisit efron nolog
iivw_fit y x, model(gee) family(gaussian) timespec(linear) ///
    vce(fixed) nolog
local stata_x = _b[x]
local stata_time = _b[time]
local stata_x_se = _se[x]
local stata_time_se = _se[time]

preserve
use "`r_output'", clear
foreach metric in estimate se {
    quietly count if missing(`metric')
    assert r(N) == 0
}
quietly count if term == "x"
assert r(N) == 1
quietly count if term == "time"
assert r(N) == 1
quietly summarize estimate if term == "x", meanonly
local r_x = r(mean)
quietly summarize estimate if term == "time", meanonly
local r_time = r(mean)
quietly summarize se if term == "x", meanonly
local r_x_se = r(mean)
quietly summarize se if term == "time", meanonly
local r_time_se = r(mean)
restore

* Point estimates are the same independence-GEE estimating equations: Class P
* TOL_PARITY_OUTCOME = 1e-5.  Sandwich SE implementations differ in finite
* sample scaling, so the registered external crossval bound is 5 percent.
foreach item in x time {
    local ++test_count
    capture noisily assert !missing(`stata_`item'', `r_`item'') & ///
        abs(`stata_`item'' - `r_`item'') < 1e-5
    if _rc == 0 local ++pass_count
    else local ++fail_count

    local ++test_count
    capture noisily assert !missing(`stata_`item'_se', `r_`item'_se') & ///
        abs(`stata_`item'_se' - `r_`item'_se') / `r_`item'_se' < 0.05
    if _rc == 0 local ++pass_count
    else local ++fail_count
}

iivw_qa_summary, name(crossval_iivw_dta) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count')
