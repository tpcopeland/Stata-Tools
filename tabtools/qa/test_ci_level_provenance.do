* test_ci_level_provenance.do - CI-level provenance handling for regtab/effecttab
*
* Regression coverage for the Stata 19 breakage: collect save writes an
* undocumented "ci-level" key on Stata 17 but omits it entirely on Stata 19.
* _tabtools_collect_ci_level used to exit 459 when the key was absent, which
* made regtab and effecttab unusable on Stata 19 for every user.
*
* The absent-key state is reproducible on Stata 17: a collection built from a
* non-estimation command (collect: summarize) carries no ci-level key either.
* The caller fallback is exercised by shadowing the helper with a stub that
* reports no provenance, which is what the helper genuinely returns on 19.

clear all
set more off
set varabbrev off
version 17.0

capture log close _cilevel
log using "test_ci_level_provenance.log", replace text name(_cilevel)

local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"

* Standard targeted local install. Without it this suite ran the helper from
* source but resolved every PUBLIC command from whatever adopath happened to be
* present, so under an empty isolated PLUS/PERSONAL it scored 3/8 with five
* r(199) failures -- and against a stale install it would have silently tested
* the wrong code.
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
capture which regtab
if _rc {
    display as error "bootstrap failed: regtab not discoverable after net install"
    exit 111
}

run "`pkg_dir'/_tabtools_common.ado"

**# Test 1: key present (estimation collection) -> found, level read
sysuse auto, clear
collect clear
collect: regress price mpg weight
capture noisily _tabtools_collect_ci_level
local rc = _rc
if `rc' == 0 & r(found) == 1 & abs(r(level) - 95) < 1e-8 {
    display as result "  PASS: provenance found in an estimation collection (level=95)"
    local ++pass_count
}
else {
    display as error "  FAIL: provenance lookup (rc=`rc' found=`=r(found)' level=`=r(level)')"
    local ++fail_count
}

**# Test 2: key absent -> helper reports found=0 and does NOT error
* Pre-fix this exited 459. That is the exact failure Stata 19 users hit.
collect clear
collect: summarize price mpg
capture noisily _tabtools_collect_ci_level
local rc = _rc
if `rc' == 0 & r(found) == 0 & missing(r(level)) {
    display as result "  PASS: absent ci-level key reports found=0 without erroring"
    local ++pass_count
}
else {
    display as error "  FAIL: absent-key path (rc=`rc' found=`=r(found)' level=`=r(level)')"
    local ++fail_count
}

**# Test 3: non-default level is read back, not assumed
collect clear
collect: regress price mpg weight, level(90)
capture noisily _tabtools_collect_ci_level
local rc = _rc
if `rc' == 0 & r(found) == 1 & abs(r(level) - 90) < 1e-8 {
    display as result "  PASS: non-default collected level(90) read from provenance"
    local ++pass_count
}
else {
    display as error "  FAIL: level(90) provenance (rc=`rc' found=`=r(found)' level=`=r(level)')"
    local ++fail_count
}

**# Stub: emulate a Stata 19 collect save (no ci-level key ever written)
capture program drop _tabtools_collect_ci_level
program _tabtools_collect_ci_level, rclass
    return scalar found = 0
    return scalar level = .
end

**# Test 4: regtab REFUSES to guess when provenance is absent and level() is not given
* This used to assert the opposite -- that falling back to c(level) was correct.
* It is not: c(level) is the CURRENT session setting, while the intervals were
* computed when the models ran. The two can differ, and the old behavior labeled
* real 90% bounds as "95% CI" and returned r(ci_level)=95 at rc=0.
set level 95
sysuse auto, clear
collect clear
collect: regress price mpg weight
collect: regress price mpg weight foreign
capture frame drop _ci_fb1
capture noisily regtab, frame(_ci_fb1) models("M1 \ M2")
local rc = _rc
local _made = 0
capture confirm frame _ci_fb1
if _rc == 0 local _made = 1
if `rc' == 198 & `_made' == 0 {
    display as result "  PASS: regtab refuses to infer the level, and writes no frame"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab should refuse without provenance (rc=`rc' frame_created=`_made')"
    local ++fail_count
}

**# Test 4b: ADVERSARY -- 90% bounds must never be labeled with a later set level
* Build the collection at 90%, then move the session to 95% before rendering.
* With real provenance the 90 must win. This is the exact mislabeling the old
* fallback produced whenever provenance was missing.
run "`pkg_dir'/_tabtools_common.ado"
sysuse auto, clear
set level 90
collect clear
collect: regress price mpg weight
set level 95
capture frame drop _ci_adv
capture noisily regtab, frame(_ci_adv)
local rc = _rc
if `rc' == 0 & abs(`=r(ci_level)' - 90) < 1e-8 {
    display as result "  PASS: 90% collection keeps its 90% label after set level 95"
    local ++pass_count
}
else {
    display as error "  FAIL: session level leaked into the label (rc=`rc' ci_level=`=r(ci_level)')"
    local ++fail_count
}
set level 95

* restore the no-provenance stub for the remaining fallback-path tests
capture program drop _tabtools_collect_ci_level
program _tabtools_collect_ci_level, rclass
    return scalar found = 0
    return scalar level = .
end

**# Test 5: regtab honours explicit level() with no provenance (no false conflict)
collect clear
collect: regress price mpg weight
capture noisily regtab, frame(_ci_fb2) level(90)
local rc = _rc
if `rc' == 0 & abs(`=r(ci_level)' - 90) < 1e-8 {
    display as result "  PASS: regtab honours level(90) when provenance is unavailable"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab level() fallback (rc=`rc' ci_level=`=r(ci_level)')"
    local ++fail_count
}

**# Test 6: the refusal does NOT depend on what set level happens to be
* Previously this asserted the fallback tracked `set level 99'. Tracking the
* session setting was the defect, so the requirement is now the opposite: the
* refusal must fire identically whatever c(level) is.
set level 99
collect clear
collect: regress price mpg weight
capture frame drop _ci_fb3
capture noisily regtab, frame(_ci_fb3)
local rc = _rc
if `rc' == 198 {
    display as result "  PASS: regtab refuses at set level 99 too (no session inference)"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab should refuse regardless of set level (rc=`rc' ci_level=`=r(ci_level)')"
    local ++fail_count
}
set level 95

**# Test 7: effecttab falls back rather than dying
* effecttab accepts only teffects/margins collections, hence the different DGP.
webuse cattaneo2, clear
collect clear
collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
capture frame drop _ci_fb4
capture noisily effecttab, frame(_ci_fb4)
local rc = _rc
if `rc' == 198 {
    display as result "  PASS: effecttab refuses to infer the level (shares the helper)"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab should refuse without provenance (rc=`rc' ci_level=`=r(ci_level)')"
    local ++fail_count
}

**# Test 7b: effecttab still honours an explicit level() with no provenance
capture frame drop _ci_fb4b
capture noisily effecttab, frame(_ci_fb4b) level(90)
local rc = _rc
if `rc' == 0 & abs(`=r(ci_level)' - 90) < 1e-8 {
    display as result "  PASS: effecttab honours level(90) when provenance is unavailable"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab level() with no provenance (rc=`rc' ci_level=`=r(ci_level)')"
    local ++fail_count
}

**# Restore the real helper and confirm the conflict guard still fires
run "`pkg_dir'/_tabtools_common.ado"

**# Test 8: level() conflicting with real provenance still errors
sysuse auto, clear
collect clear
collect: regress price mpg weight
capture regtab, frame(_ci_fb5) level(90)
if _rc == 198 {
    display as result "  PASS: level() conflicting with real provenance still errors 198"
    local ++pass_count
}
else {
    display as error "  FAIL: conflict guard did not fire (rc=`=_rc')"
    local ++fail_count
}

**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_ci_level_provenance tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _cilevel
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_ci_level_provenance tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _cilevel
