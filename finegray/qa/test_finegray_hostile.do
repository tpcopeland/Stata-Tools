* Deterministic hostile-input contracts for finegray. Seed: 303102.
clear all
version 16.0
set seed 303102
set varabbrev off
capture log close _all
log using "test_finegray_hostile.log", replace text nomsg
do _finegray_qa_common.do
quietly _finegray_qa_bootstrap
local test_count = 0
local pass_count = 0
local fail_count = 0
* H1: a two-row dataset with NO cause-1 event.  finegray must refuse and must
* leave the caller's data untouched.
*
* FIXED 2026-09-02.  The fixture used to stset WITHOUT id(), so the refusal it
* observed was "finegray requires stset with id() variable" -- the id() guard,
* which fires before the data are ever examined.  `assert _rc != 0' passed for
* that reason on every build, including one where the no-cause-events condition
* was not checked at all.  The fixture now stsets with id() and the assertion
* names the specific refusal, so the test can only pass for its own reason.
local ++test_count
capture noisily {
    clear
    input double t byte status double x byte sentinel double subjid
    1 0 1 41 1
    2 0 2 42 2
    end
    quietly stset t, failure(status == 1) id(subjid)

    tempfile _h1log
    capture log close _h1
    quietly log using "`_h1log'", replace text name(_h1)
    capture noisily finegray x, compete(status) cause(1)
    local _h1rc = _rc
    capture log close _h1

    tempname _fh1
    local _h1blob ""
    file open `_fh1' using "`_h1log'", read text
    file read `_fh1' line
    while r(eof) == 0 {
        local _h1blob `"`_h1blob' `line'"'
        file read `_fh1' line
    }
    file close `_fh1'

    display as text "  H1 rc = `_h1rc'"
    assert `_h1rc' == 198
    * the refusal under test, not the stset id() guard that used to fire here
    assert strpos(`"`_h1blob'"', "no observations with compete() == 1") > 0
    assert strpos(`"`_h1blob'"', "requires stset with id()") == 0
    assert sentinel[1] == 41
    assert sentinel[2] == 42
}
if _rc == 0 local ++pass_count
else local ++fail_count

* H2: finegray_predict with no estimates in e().  Same rule: name the refusal.
local ++test_count
capture noisily {
    clear
    set obs 1
    generate byte sentinel = 43

    tempfile _h2log
    capture log close _h2
    quietly log using "`_h2log'", replace text name(_h2)
    capture noisily finegray_predict cif_hat, cif
    local _h2rc = _rc
    capture log close _h2

    tempname _fh2
    local _h2blob ""
    file open `_fh2' using "`_h2log'", read text
    file read `_fh2' line
    while r(eof) == 0 {
        local _h2blob `"`_h2blob' `line'"'
        file read `_fh2' line
    }
    file close `_fh2'

    display as text "  H2 rc = `_h2rc'"
    assert `_h2rc' == 301
    assert strpos(`"`_h2blob'"', "last estimates not found") > 0
    assert sentinel == 43
}
if _rc == 0 local ++pass_count
else local ++fail_count
display "RESULT: test_finegray_hostile tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    capture log close _all
    exit 1
}
capture log close _all
