* test_iivw_v194_regressions.do
* Regression coverage for export path safety, quote round-tripping, and
* temporary-frame cleanup on failed reporting exports.

clear all
set varabbrev off
version 16.0

capture log close _all
tempfile test_log
log using "`test_log'", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
* Sysdir sandbox + path resolution (Q3/Q8): the sandbox keeps this suite's
* net install out of the USER's real ado tree even when run standalone, and
* the "/qa" suffix is stripped by length, not by first-occurrence subinstr()
* (which mangles any path whose ancestors contain "qa").
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_sandbox
local pkg_dir  "`r(pkg_dir)'"
local repo_dir "`r(repo_dir)'"

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace
discard

capture program drop _iivw_v194_balance_panel
program define _iivw_v194_balance_panel
    version 16.0
    clear
    set obs 40
    gen long id = ceil(_n / 4)
    bysort id: gen byte time = _n
    gen double z = id / 10 + time / 20
    gen double _iivw_weight = cond(mod(_n, 3) == 0, 1.5, 0.75)
    char _dta[_iivw_weighted] "1"
    char _dta[_iivw_id] "id"
    char _dta[_iivw_time] "time"
    char _dta[_iivw_weighttype] "iivw"
    char _dta[_iivw_weight_var] "_iivw_weight"
    * A real IIW/FIPTIW run always creates the visit component. iivw_balance
    * diagnoses that component by default, so a fixture without it is not a
    * contract the package can produce.
    capture confirm variable _iivw_iw
    if _rc gen double _iivw_iw = _iivw_weight
    char _dta[_iivw_iw_var] "_iivw_iw"
    char _dta[_iivw_prefix] "_iivw_"
    char _dta[_iivw_visit_covars] "z"
    * Sign the hand-built contract, as iivw_weight would at its commit point.
    * From 2.0.0 the stale-weight guard fails CLOSED, so an unsigned contract is
    * an error rather than a skipped check. See iivw_qa_sign_contract.
    iivw_qa_sign_contract
end

capture program drop _iivw_v194_post
program define _iivw_v194_post, eclass
    version 16.0
    args name b se
    tempname B V
    matrix `B' = (`b')
    matrix colnames `B' = x
    matrix `V' = (`se'^2)
    matrix rownames `V' = x
    matrix colnames `V' = x
    ereturn post `B' `V', obs(100)
    ereturn local cmd "regress"
    estimates store `name'
end

**# T1: embedded quotes survive the public-command/helper boundary

local ++test_count
capture noisily {
    _iivw_v194_balance_panel
    local expected = "Cohort " + char(34) + "A" + char(34) + " summary"
    local book "`c(tmpdir)'/iivw_v194_quotes.xlsx"
    capture erase "`book'"
    iivw_balance, xlsx("`book'") sheet(Balance) replace ///
        title(`"Cohort "A" summary"')
    preserve
    import excel using "`book'", sheet(Balance) cellrange(A1:A1) clear allstring
    assert A[1] == `"`expected'"'
    restore
    erase "`book'"
}
if _rc == 0 {
    display as result "  PASS: embedded quotes round-trip through export"
    local ++pass_count
}
else {
    display as error "  FAIL: embedded quote export (error `=_rc')"
    local ++fail_count
}

**# T2: unsafe xlsx() shell metacharacters are rejected before open

local ++test_count
capture noisily {
    _iivw_v194_balance_panel
    local marker "`c(tmpdir)'/iivw_v194_must_not_exist"
    capture erase "`marker'"
    local bad = "`c(tmpdir)'/bad" + char(36) + ///
        "(touch " + "`marker'" + ").xlsx"
    capture noisily iivw_balance, xlsx(`"`bad'"') open
    assert _rc == 198
    capture confirm file "`marker'"
    assert _rc == 601
}
if _rc == 0 {
    display as result "  PASS: unsafe xlsx path rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: unsafe xlsx path guard (error `=_rc')"
    local ++fail_count
}

**# T3: balance export failure drops its temporary frame

local ++test_count
capture noisily {
    _iivw_v194_balance_panel
    frame dir
    local frames_before "`r(frames)'"
    local book "`c(tmpdir)'/iivw_v194_balance_fail.xlsx"
    capture erase "`book'"
    capture noisily iivw_balance, xlsx("`book'") theme(not_a_theme)
    assert _rc == 198
    frame dir
    assert "`r(frames)'" == "`frames_before'"
    capture erase "`book'"
}
if _rc == 0 {
    display as result "  PASS: balance export failure cleans temporary frame"
    local ++pass_count
}
else {
    display as error "  FAIL: balance export frame cleanup (error `=_rc')"
    local ++fail_count
}

**# T4: diagnose export failure cleans its frame and restores active e()

local ++test_count
capture noisily {
    clear
    _iivw_v194_post M_unw 0.40 0.08
    _iivw_v194_post M_wgt 0.30 0.09
    _iivw_v194_post M_adj 0.10 0.10
    estimates restore M_wgt
    local cmd_before "`e(cmd)'"
    matrix b_before = e(b)
    frame dir
    local frames_before "`r(frames)'"
    local book "`c(tmpdir)'/iivw_v194_diagnose_fail.xlsx"
    capture erase "`book'"
    capture noisily iivw_diagnose x, unweighted(M_unw) ///
        weighted(M_wgt) adjusted(M_adj) xlsx("`book'") ///
        theme(not_a_theme)
    assert _rc == 198
    frame dir
    assert "`r(frames)'" == "`frames_before'"
    assert "`e(cmd)'" == "`cmd_before'"
    matrix b_after = e(b)
    assert mreldif(b_before, b_after) < 1e-12
    capture erase "`book'"
}
if _rc == 0 {
    display as result "  PASS: diagnose export failure preserves state"
    local ++pass_count
}
else {
    display as error "  FAIL: diagnose export cleanup/state (error `=_rc')"
    local ++fail_count
}

**# Summary

capture log close _all
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_iivw_v194_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_iivw_v194_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
