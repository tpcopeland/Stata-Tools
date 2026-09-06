* Deterministic hostile-input contracts for iivw. Seed: 303104.
clear all
version 16.0
set seed 303104
set varabbrev off
capture log close _all
tempfile test_log
log using "`test_log'", replace text nomsg
* Resolve, sandbox and install the checkout under test, then PROVE it is the
* copy the assertions will exercise. This suite used to derive its path with
* subinstr(...,"/qa","",1) and merely `adopath ++' it. PLUS/SSC precede an
* appended path, so an older installed iivw_weight or iivw_exogtest could
* satisfy every hostile assertion while the checkout under audit was never
* called -- an adversarial suite green against the wrong implementation.
* (audit IIVW-14)
do "`c(pwd)'/_iivw_qa_common.do"
iivw_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"
local sandbox "`r(sandbox)'"

* Two independent statements that the checkout under audit is what resolves.
* The sandbox tree is created fresh by iivw_qa_bootstrap and the only thing
* ever installed into it is `pkg_dir', so containment alone settles provenance;
* the header line is compared as well so a stale file left in the tree by some
* future change would still be caught.
foreach _hcmd in iivw_weight iivw_fit iivw_exogtest iivw_balance iivw_diagnose {
    quietly findfile `_hcmd'.ado
    local _hpath "`r(fn)'"
    if strpos("`_hpath'", "`sandbox'") != 1 {
        display as error "test_iivw_hostile: `_hcmd' resolved outside the sandbox"
        display as error "  resolved `_hpath'"
        display as error "  sandbox  `sandbox'"
        exit 601
    }
    tempname _hf
    file open `_hf' using "`_hpath'", read text
    file read `_hf' _hline1
    file close `_hf'
    file open `_hf' using "`pkg_dir'/`_hcmd'.ado", read text
    file read `_hf' _hline2
    file close `_hf'
    if `"`macval(_hline1)'"' != `"`macval(_hline2)'"' {
        display as error "test_iivw_hostile: resolved `_hcmd' is not the checkout copy"
        display as error `"  resolved header: `macval(_hline1)'"'
        display as error `"  checkout header: `macval(_hline2)'"'
        exit 601
    }
}

local test_count = 0
local pass_count = 0
local fail_count = 0
local ++test_count
capture noisily {
    clear
    input long id double time byte sentinel
    1 1 61
    end
    capture noisily iivw_weight, id(id) time(time) visit_cov(not_a_variable)
    assert _rc != 0
    assert sentinel == 61
}
if _rc == 0 local ++pass_count
else local ++fail_count
local ++test_count
capture noisily {
    clear
    set obs 0
    generate long id = .
    generate double time = .
    generate byte y = .
    capture noisily iivw_exogtest y, id(id) time(time)
    assert _rc != 0
    assert _N == 0
}
if _rc == 0 local ++pass_count
else local ++fail_count
capture log close _all
iivw_qa_summary, name(test_iivw_hostile) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count')
