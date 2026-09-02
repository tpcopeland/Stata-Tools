* test_finegray_fg07_options.do
* Regression tests: reject option combinations the selected statistic ignores
* (FG-07).  Before this fix, finegray_predict and finegray_cif silently accepted
* several options that had no effect, so a misspelled or misplaced analysis
* option looked honored.  Each rejection is paired with a POSITIVE CONTROL -- the
* same call minus the offending option -- so a test that passes for the wrong
* reason (an unrelated guard firing at 198) is caught: rc 198 is generic.
*
* Every rejection test FAILS on the pre-fix code, where the option was accepted
* at rc 0.
clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_fg07_options.log", replace name(_fg07)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _mk_fg07
program define _mk_fg07
    clear
    set seed 5150
    quietly set obs 500
    gen long id = _n
    gen double x = rnormal()
    gen double t = ceil(8 * runiform())
    gen byte ev = cond(runiform() < .45, 1, cond(runiform() < .5, 2, 0))
    quietly stset t, failure(ev) id(id)
    quietly finegray x, compete(ev) cause(1) nolog
end

**# 1. predict xb with timevar() is rejected; xb alone is accepted
local ++test_count
capture noisily {
    _mk_fg07
    capture drop _q*
    gen double horizon = 4
    capture finegray_predict q1, xb timevar(horizon)
    assert _rc == 198
    capture finegray_predict q1ok, xb
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: FG07-1 xb timevar() rejected; xb alone ok"
    local ++pass_count
}
else {
    display as error "  FAIL: FG07-1 (rc=`=_rc')"
    local ++fail_count
}

**# 2. predict xb with level() is rejected; xb alone is accepted
local ++test_count
capture noisily {
    _mk_fg07
    capture finegray_predict q2, xb level(80)
    assert _rc == 198
    capture finegray_predict q2ok, xb
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: FG07-2 xb level() rejected; xb alone ok"
    local ++pass_count
}
else {
    display as error "  FAIL: FG07-2 (rc=`=_rc')"
    local ++fail_count
}

**# 3. predict cif with level() but no ci is rejected; cif ci level() is accepted
local ++test_count
capture noisily {
    _mk_fg07
    gen double horizon3 = 4
    capture finegray_predict q3, cif timevar(horizon3) level(80)
    assert _rc == 198
    capture finegray_predict q3ok, cif ci timevar(horizon3) level(80)
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: FG07-3 cif level() without ci rejected; with ci ok"
    local ++pass_count
}
else {
    display as error "  FAIL: FG07-3 (rc=`=_rc')"
    local ++fail_count
}

**# 4. predict basecshazard with level() is rejected; basecshazard alone accepted
local ++test_count
capture noisily {
    _mk_fg07
    capture finegray_predict q4, basecshazard level(80)
    assert _rc == 198
    capture finegray_predict q4ok, basecshazard
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: FG07-4 basecshazard level() rejected; alone ok"
    local ++pass_count
}
else {
    display as error "  FAIL: FG07-4 (rc=`=_rc')"
    local ++fail_count
}

**# 5. cif bootstrap() without ci is rejected; cif ci bootstrap() is accepted
local ++test_count
capture noisily {
    _mk_fg07
    capture finegray_cif, attime(5) bootstrap(25) seed(1) nograph
    assert _rc == 198
    capture finegray_cif, attime(5) ci bootstrap(25) seed(1) nograph
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: FG07-5 cif bootstrap() without ci rejected; with ci ok"
    local ++pass_count
}
else {
    display as error "  FAIL: FG07-5 (rc=`=_rc')"
    local ++fail_count
}

**# 5b. predict bootstrap() without ci is rejected before resampling
local ++test_count
capture noisily {
    _mk_fg07
    gen double horizon5b = 5
    capture finegray_predict q5b, cif timevar(horizon5b) bootstrap(25) seed(1)
    assert _rc == 198
    capture confirm variable q5b
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: FG07-5b predict bootstrap() without ci rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: FG07-5b (rc=`=_rc')"
    local ++fail_count
}

**# 6. cif level() without ci is rejected; cif ci level() is accepted
local ++test_count
capture noisily {
    _mk_fg07
    capture finegray_cif, attime(5) level(80) nograph
    assert _rc == 198
    capture finegray_cif, attime(5) ci level(80) nograph
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: FG07-6 cif level() without ci rejected; with ci ok"
    local ++pass_count
}
else {
    display as error "  FAIL: FG07-6 (rc=`=_rc')"
    local ++fail_count
}

**# 7. cif attime() with timepoints() is rejected; each alone is accepted
* CIF-1.  Both options name the times the CIF is evaluated at, and the grid
* builder took attime() first, so the pair ran at rc 0 with timepoints() parsed,
* dropped, and never mentioned: `finegray_cif, attime(4) timepoints(1 2 3)'
* returned a one-row table at t = 4.  attime() also switches table mode on, so
* there is no defensible winner to pick silently.
local ++test_count
capture noisily {
    _mk_fg07
    capture finegray_cif, attime(4) timepoints(1 2 3) nograph
    display as text "  attime() + timepoints() rc = `=_rc' (pre-fix: 0, timepoints() dropped)"
    assert _rc == 198

    * positive controls: each option alone still works, and each still drives the
    * grid it is supposed to.  Without these, an unrelated 198 would pass above.
    capture noisily finegray_cif, attime(4) nograph
    assert _rc == 0
    matrix _c1a = r(table)
    assert rowsof(_c1a) == 1
    assert _c1a[1,1] == 4

    capture noisily finegray_cif, timepoints(1 2 3) nograph
    assert _rc == 0
    matrix _c1b = r(table)
    assert rowsof(_c1b) == 3
    matrix drop _c1a _c1b
}
if _rc == 0 {
    display as result "  PASS: FG07-7/CIF-1 attime() with timepoints() rejected; each alone honored"
    local ++pass_count
}
else {
    display as error "  FAIL: FG07-7/CIF-1 (rc=`=_rc')"
    local ++fail_count
}

**# 8. M1: derived newvar names are checked BEFORE the work, and the two ways
* they can fail are told apart.
*
* `ci' derives newvar_lci / newvar_uci, so its budget is 28 characters, not
* Stata's 32; `schoenfeld' derives newvar_2 ... newvar_p, so its budget is 30
* for a 2-9 covariate model.  Neither ceiling was documented.
*
* The ORDERING half is what fails on the pre-fix build, and it needs a probe
* that separates "checked early" from "checked at all": rc 198 alone does not,
* because the old code also ended at 198, just later.  So pair the over-long
* name with an `if' that selects no observations.  Pre-fix reached the
* no-observations guard first and exited 2000; the name only failed afterwards.
* (The wasted work is the point CIF, not the bootstrap -- the old `confirm' sat
* between them.)
*
* The MESSAGE half is the schoenfeld stub check, which returned 110 "variable
* already exists" for every failure, including a name that was simply too long.
* `confirm new variable' distinguishes them: 110 taken, 198 malformed.
local ++test_count
capture noisily {
    _mk_fg07
    * ordering: an empty `if' must NOT win over an unusable name
    capture noisily finegray_predict abcdefghij_abcdefghij_abcdefg if id < 0, cif ci
    display as text "  over-long ci newvar + empty if rc = `=_rc' (pre-fix: 2000)"
    assert _rc == 198

    capture noisily finegray_predict abcdefghij_abcdefghij_abcdefg, cif ci
    display as text "  over-long ci newvar rc = `=_rc'"
    assert _rc == 198
    * nothing was created, including the point estimate
    capture confirm variable abcdefghij_abcdefghij_abcdefg
    assert _rc != 0

    * positive control: 28 characters is the documented ceiling and is accepted
    capture noisily finegray_predict abcdefghij_abcdefghij_abcdef, cif ci
    assert _rc == 0
    confirm variable abcdefghij_abcdefghij_abcdef
    confirm variable abcdefghij_abcdefghij_abcdef_lci
    confirm variable abcdefghij_abcdefghij_abcdef_uci

    * a TAKEN suffix name is a different failure and must say so: 110, not 198
    drop abcdefghij_abcdefghij_abcdef
    capture noisily finegray_predict abcdefghij_abcdefghij_abcdef, cif ci
    display as text "  existing _lci with a valid stub rc = `=_rc'"
    assert _rc == 110

    * schoenfeld: 2 covariates, so the stub carries a _2 suffix.  31 characters
    * makes stub_2 33 and therefore invalid -- 198, not "already exists".
    quietly finegray x c.x#c.x, compete(ev) cause(1) nolog
    capture noisily finegray_predict abcdefghij_abcdefghij_abcdefghi, schoenfeld
    display as text "  over-long schoenfeld stub rc = `=_rc' (pre-fix: 110)"
    assert _rc == 198
    capture confirm variable abcdefghij_abcdefghij_abcdefghi
    assert _rc != 0

    * positive control: 30 characters fits, and both stub variables appear
    capture noisily finegray_predict abcdefghij_abcdefghij_abcdefgh, schoenfeld
    assert _rc == 0
    confirm variable abcdefghij_abcdefghij_abcdefgh
    confirm variable abcdefghij_abcdefghij_abcdefgh_2

    * and a genuinely taken stub name still reports 110
    drop abcdefghij_abcdefghij_abcdefgh
    capture noisily finegray_predict abcdefghij_abcdefghij_abcdefgh, schoenfeld
    display as text "  existing schoenfeld _2 with a valid stub rc = `=_rc'"
    assert _rc == 110
}
if _rc == 0 {
    display as result "  PASS: FG07-8/M1 derived newvar names checked up front; 198 vs 110 distinguished"
    local ++pass_count
}
else {
    display as error "  FAIL: FG07-8/M1 (rc=`=_rc')"
    local ++fail_count
}

**# FG07-9  attime()/timepoints() collapse duplicate horizons
* WATCHED FAIL 2026-09-01: on the pre-fix build `finegray_cif, attime(1 1 2)'
* returned a THREE-row r(table) whose first two rows were the identical t = 1
* row, and printed t = 1 twice.  `numlist, sort' orders a list but keeps its
* duplicates, and nothing downstream collapsed them.  The assertion is on the
* RETURNED table, not on the printed one: a duplicate horizon is a duplicate
* row of r(table), and a caller assembling several profiles would have
* double-counted it.
local ++test_count
capture noisily {
    _mk_fg07
    quietly finegray_cif, attime(1 1 2) nograph
    matrix _fg07dup = r(table)
    display as text "  attime(1 1 2) -> r(table) has " rowsof(_fg07dup) " row(s)"
    assert rowsof(_fg07dup) == 2
    assert _fg07dup[1,1] == 1 & _fg07dup[2,1] == 2
    * the deduplicated table equals the one the user could have typed
    quietly finegray_cif, attime(1 2) nograph
    assert mreldif(r(table), _fg07dup) == 0
    * three copies of one horizon collapse to one row, not to zero
    quietly finegray_cif, attime(3 3 3) nograph
    assert rowsof(r(table)) == 1
    * timepoints() takes the same path (curve mode)
    quietly finegray_cif, timepoints(1 1 2 2 3) nograph
    matrix _fg07dup2 = r(table)
    quietly finegray_cif, timepoints(1 2 3) nograph
    assert rowsof(_fg07dup2) == rowsof(r(table))
    assert mreldif(r(table), _fg07dup2) == 0
    * a list with no duplicates is untouched
    quietly finegray_cif, attime(2 4 6) nograph
    assert rowsof(r(table)) == 3
}
if _rc == 0 {
    display as result "  PASS: FG07-9 duplicate attime()/timepoints() horizons collapse"
    local ++pass_count
}
else {
    display as error "  FAIL: FG07-9 (rc=`=_rc')"
    local ++fail_count
}
capture matrix drop _fg07dup _fg07dup2

**# Summary
display as text _newline ///
    "RESULT: test_finegray_fg07_options tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _fg07
    exit 1
}
display as result "ALL TESTS PASSED"
log close _fg07
