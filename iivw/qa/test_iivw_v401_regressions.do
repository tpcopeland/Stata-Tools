* test_iivw_v401_regressions.do
* Regression coverage for the baseline-event missing-weight and demo-state
* defects found during the 4.0.0 deep review:
*   T1  baseline(event) fails closed when the first fitted weight is missing
*   T2  allowmissingweights preserves that missing first weight
*   T3  the demo reads the documented exogeneity return
*   T4  a failing demo restores caller settings

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
local pkg_dir "`r(pkg_dir)'"

capture program drop _iivw_v401_panel
program define _iivw_v401_panel
    version 16.0
    clear
    set seed 20260830
    set obs 40
    gen long id = _n
    gen double z = rnormal()
    expand 4
    bysort id: gen byte visit = _n
    gen double time = visit
    gen double x = 0.25 * z + 0.30 * visit + rnormal()
    replace x = . if id == 1 & visit == 1
end

**# T1: baseline(event) fails closed on a missing first fitted weight

local ++test_count
capture noisily {
    _iivw_v401_panel
    capture noisily iivw_weight, id(id) time(time) visit_cov(x z) ///
        baseline(event) endatlastvisit wtype(iivw) nolog
    local weight_rc = _rc
    assert `weight_rc' == 416
    capture confirm variable _iivw_weight
    assert _rc == 111
    capture confirm variable _iivw_iw
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: T1 - missing first event weight fails closed"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - missing first event weight (error `=_rc')"
    local ++fail_count
    local failed "`failed' T1"
}

**# T2: explicit opt-in preserves, rather than fabricates, that missing weight

local ++test_count
capture noisily {
    _iivw_v401_panel
    quietly iivw_weight, id(id) time(time) visit_cov(x z) ///
        baseline(event) endatlastvisit wtype(iivw) allowmissingweights nolog
    local n_weighted = r(N_weighted)
    local n_missing_weight = r(n_missing_weight)

    quietly count if missing(_iivw_weight)
    local n_missing_observed = r(N)
    quietly count if id == 1 & visit == 1 & missing(_iivw_weight)
    local first_missing = r(N)

    assert `n_missing_weight' == 1
    assert `n_missing_observed' == 1
    assert `first_missing' == 1
    assert `n_weighted' == _N - 1
}
if _rc == 0 {
    display as result "  PASS: T2 - allowmissingweights preserves missing first weight"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - explicit missing-weight route (error `=_rc')"
    local ++fail_count
    local failed "`failed' T2"
}

**# T3: the demo consumes the return that iivw_exogtest actually publishes

local ++test_count
capture noisily {
    tempname demo_source
    local good_return = 0
    local stale_return = 0
    file open `demo_source' using "`pkg_dir'/demo/demo_iivw.do", read text
    file read `demo_source' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "if r(history_association_flag)") > 0 {
            local ++good_return
        }
        if strpos(`"`line'"', "r(endogenous_flag)") > 0 {
            local ++stale_return
        }
        file read `demo_source' line
    }
    file close `demo_source'
    assert `good_return' == 1
    assert `stale_return' == 0
}
if _rc == 0 {
    display as result "  PASS: T3 - demo reads history_association_flag"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - demo exogeneity return wiring (error `=_rc')"
    local ++fail_count
    local failed "`failed' T3"
}

**# T4: a failing demo restores caller settings before returning the error

local ++test_count
capture noisily {
    local caller_cwd "`c(pwd)'"
    local caller_varabbrev "`c(varabbrev)'"
    local caller_linesize = c(linesize)
    local caller_plus "`c(sysdir_plus)'"
    local caller_personal "`c(sysdir_personal)'"
    tempfile empty_anchor
    local empty_dir "`empty_anchor'_repo"
    mkdir "`empty_dir'"
    mkdir "`empty_dir'/iivw"
    copy "`pkg_dir'/iivw.pkg" "`empty_dir'/iivw/iivw.pkg"

    set varabbrev on
    set linesize 109
    cd "`empty_dir'"
    capture noisily do "`pkg_dir'/demo/demo_iivw.do"
    local demo_rc = _rc
    local after_varabbrev "`c(varabbrev)'"
    local after_linesize = c(linesize)
    local after_plus "`c(sysdir_plus)'"
    local after_personal "`c(sysdir_personal)'"

    capture cd "`caller_cwd'"
    capture sysdir set PLUS "`caller_plus'"
    capture sysdir set PERSONAL "`caller_personal'"
    if "`caller_varabbrev'" == "on" set varabbrev on
    else set varabbrev off
    set linesize `caller_linesize'

    assert `demo_rc' == 601
    assert "`after_varabbrev'" == "on"
    assert `after_linesize' == 109
    assert "`after_plus'" == "`caller_plus'"
    assert "`after_personal'" == "`caller_personal'"
}
if _rc == 0 {
    display as result "  PASS: T4 - failing demo restores caller settings"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - demo failure cleanup (error `=_rc')"
    local ++fail_count
    local failed "`failed' T4"
}

capture log close _all
iivw_qa_summary, name(test_iivw_v401_regressions) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') failedtests("`failed'")
