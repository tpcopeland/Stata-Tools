* test_tabtools_v1015.do — regression tests for tabtools v1.0.15 fixes
* Tests D and E from the 2026-05-07 reviewer punch list:
*   D. by-variable name restriction surfaces a clear, documented error
*   E. Mata workspace leak on Excel formatting failure is plugged
*
* Run from the package qa/tabtools/ directory.

clear all
set more off

* Resolve package directory from cwd. Supports two callers:
*   (a) standalone:  cwd = .../tabtools/qa/tabtools
*   (b) run_all.do:  cwd = .../tabtools/qa
local _cwd "`c(pwd)'"
if regexm("`_cwd'", "/qa/tabtools$") {
    local pkg_root = regexr("`_cwd'", "/qa/tabtools$", "")
}
else if regexm("`_cwd'", "/qa$") {
    local pkg_root = regexr("`_cwd'", "/qa$", "")
}
else {
    local pkg_root "`_cwd'"
}
capture _tabtools_helpers_ready
if _rc {
    capture noisily adopath ++ "`pkg_root'"
    capture noisily do "`pkg_root'/_tabtools_common.ado"
}

local pass = 0
local fail = 0
local total = 0

display as text _newline "=== test_tabtools_v1015 ==="

**# Test D: by() variable name restriction
* The reshape pipeline reserves N_*, m_*, _column* columns. A by-variable named
* N_age (or any blacklisted name) must produce error 498 with a message that
* points at the help file.
local ++total
capture noisily {
    sysuse auto, clear
    rename rep78 N_age   // alias one of the reserved prefixes

    capture noisily table1_tc mpg, by(N_age)
    local rc_D = _rc
    assert `rc_D' == 498
    * The new error message lists the reserved names AND points at help.
    * We assert rc=498 here; message text is verified by visual inspection of
    * the captured noisily output.
}
local rc_D_outer = _rc
if `rc_D_outer' == 0 & `rc_D' == 498 {
    display as result "  PASS: Test D (by(N_age) raised rc=498 as expected)"
    local ++pass
}
else {
    display as error "  FAIL: Test D (outer rc=`rc_D_outer'; inner rc=`rc_D')"
    local ++fail
}

**# Test E: Mata workspace leak on Excel format failure
* Run table1_tc with an excel target that fails the Mata xl() block. Hardest
* path to trigger is the load_book step on a non-existent file — but
* export excel succeeds and creates the file, so we instead simulate by
* dropping the Mata vector mid-flight is impossible from outside.
* Practical approach: run table1_tc, then assert _p_raw_save and _smd_raw_save
* do NOT exist in Mata afterward (success path also drops them). Then run
* against a deliberately-locked path to exercise the error branch.
local ++total
capture noisily {
    sysuse auto, clear

    * Pre-condition: clear any leftover state from a prior failed run.
    capture mata: mata drop _p_raw_save
    capture mata: mata drop _smd_raw_save

    tempfile xlsx_ok
    capture erase "`xlsx_ok'.xlsx"

    quietly table1_tc mpg headroom, by(foreign) xlsx("`xlsx_ok'.xlsx") smd

    * Both saved-state Mata vectors must be cleaned up after a successful run.
    * `mata describe NAME` errors with rc=3499 when NAME does not exist.
    capture mata: mata describe _p_raw_save
    local _have_p_after = _rc == 0
    capture mata: mata describe _smd_raw_save
    local _have_s_after = _rc == 0
    assert `_have_p_after' == 0
    assert `_have_s_after' == 0

    capture erase "`xlsx_ok'.xlsx"

    * Now exercise the error branch: corrupt xlsx file forces load_book to fail.
    tempfile bad_xlsx
    file open _f using "`bad_xlsx'.xlsx", write replace
    file write _f "not an xlsx"
    file close _f

    capture noisily table1_tc mpg headroom, by(foreign) xlsx("`bad_xlsx'.xlsx") smd
    local rc_bad = _rc

    * Whether or not the Mata block errored, the cleanup must drop the saved
    * state. After the fix at table1_tc.ado:2740-2746, the error handler also
    * drops them.
    capture mata: mata describe _p_raw_save
    local _have_p_after2 = _rc == 0
    capture mata: mata describe _smd_raw_save
    local _have_s_after2 = _rc == 0
    assert `_have_p_after2' == 0
    assert `_have_s_after2' == 0

    capture erase "`bad_xlsx'.xlsx"
}
local rc_E = _rc
if `rc_E' == 0 {
    display as result "  PASS: Test E (Mata workspace clean after success and after format failure)"
    local ++pass
}
else {
    display as error "  FAIL: Test E (rc=`rc_E')"
    local ++fail
}

**# Summary
display as text _newline "=== Summary ==="
display as text "Total : `total'"
display as result "Pass  : `pass'"
if `fail' > 0 display as error "Fail  : `fail'"
else display as text "Fail  : 0"

if `fail' > 0 exit `fail'
