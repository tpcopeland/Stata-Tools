*! test_fixture_entry.do -- delayed-entry refusal regression
version 16.0
clear all
set processors 1
set varabbrev off
capture log close _all
log using "test_fixture_entry.log", text replace
args source
if "`source'"=="" local source = regexr("`c(pwd)'", "/qa$", "")
adopath ++ "`source'"
quietly do "_qa_fx_a2.do"
quietly do "_qa_state.do"
quietly do "_qa_hostile.do"
* Load outside the state probe; cold-loader settings have their own probe.
quietly run "`source'/cstat_surv.ado"
local tests=0
local pass=0
local fail=0
foreach va in on off {
    local ++tests
    capture noisily {
        qa_fx_a2_lifetable, clear tier(micro)
        quietly stset t, failure(d) id(id)
        quietly stcox x1, nolog
        quietly cstat_surv
        assert !missing(e(c)) & e(N_comparable)==179
        * expect: REFUSED
        qa_fx_a2_lifetable, clear tier(micro) perturb(late_entry)
        assert !missing(r(perturb_n_late_entry)) & r(perturb_n_late_entry)>0
        quietly stset t, failure(d) enter(time t0) id(id)
        quietly stcox x1, nolog
        set varabbrev `va'
        tempfile errorlog
        log using "`errorlog'.log", text replace name(entry_error)
        summarize t
        qa_state_snapshot, tag(entry) rreturn predict(xb)
        capture noisily cstat_surv
        local rc=_rc
        capture noisily qa_state_compare, tag(entry)
        local fp_rc=_rc
        log close entry_error
        mata: st_local("named",strofreal(any(strpos(strlower(cat(st_local("errorlog")+".log")),"does not support delayed entry"))))
        display "ENTRY CONTRACT va=`va' rc=`rc' fingerprint_rc=`fp_rc' named=`named'"
        assert `rc'==498 & `fp_rc'==0 & `named'==1
    }
    if _rc local ++fail
    else local ++pass
}
**# Positive entry outside the fitted sample is not a refusal
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a2_lifetable, clear tier(micro) perturb(late_entry)
    quietly stset t, failure(d) enter(time t0) id(id)
    quietly stcox x1 if t0==0, nolog
    quietly cstat_surv
    assert !missing(e(c),e(N_comparable)) & e(N_comparable)>0
    assert e(N)==18
}
if _rc local ++fail
else local ++pass
**# Canonical F covers the legacy badopt route, with its legal control
local ++tests
capture noisily {
    qa_fx_a2_lifetable, clear tier(micro)
    quietly stset t, failure(d) id(id)
    quietly stcox x2, nolog
    quietly cstat_surv
    assert !missing(e(c),e(se))
    quietly stcox x2, nolog
    qa_state_snapshot, tag(badopt) predict(xb)
    capture noisily cstat_surv, badopt
    local rc=_rc
    qa_state_compare, tag(badopt)
    assert `rc'==198
}
if _rc local ++fail
else local ++pass

display "RESULT: test_fixture_entry tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 9
