* test_codescan_v203_hardening.do
* Regression tests for the v2.0.3 hardening:
*   (1) malformed-regex rejection (compile-probe) via define() AND codefile()
*   (2) unicode-aware nocase matching (ustrregexm/ustrupper) + ASCII regression guard
*   (3) missing-date exclusion note + r(n_excluded_missingdate)
* Prior to v2.0.3 a malformed pattern silently matched nothing (false-zero
* cohort) and case folding was byte-based (å never folded to Å).

clear all
version 16.0
set varabbrev off

capture log close _all
log using "test_codescan_v203_hardening.log", text replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

* Bootstrap: derive package root from qa/ working directory (relocatable)
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

* Guarded shared bootstrap. Sandboxes PLUS/PERSONAL under c(tmpdir), then
* installs this working copy. Running this suite standalone must not mutate
* the developer's real adopath, which the bare net install here used to do;
* only run_all.do was sandboxed. Idempotent, so the lane re-entering it is
* harmless.
quietly do "`qa_dir'/_codescan_qa_common.do"
_codescan_qa_bootstrap

* Session settings captured for the hygiene check at the end of this suite.
* A suite that leaves c(level) or c(varabbrev) changed silently alters every
* later suite in the lane -- the level-80/99 CI scenarios restored inside a
* captured block, so any assertion failure above them used to leak.
local _qa_level0 = c(level)
local _qa_va0 "`c(varabbrev)'"
local _qa_pwd0 "`c(pwd)'"

discard

**# 1. Malformed-regex rejection via define()

* Each structurally-invalid pattern must exit 198 (not silently match 0).
foreach bad in "a{2,1}" "*abc" "(unclosed" "[unclosed" "a)b" {
    local ++test_count
    capture noisily {
        clear
        set obs 3
        gen str8 dx1 = "E11"
        capture codescan dx1, define(x "`bad'") mode(regex)
        assert _rc == 198
        * No indicator may be left behind by the rejected call.
        capture confirm variable x
        assert _rc != 0
    }
    if _rc == 0 {
        display as result "  PASS: malformed define() rejected [`bad']"
        local ++pass_count
    }
    else {
        display as error "  FAIL: malformed define() rejected [`bad'] (error `=_rc')"
        local ++fail_count
    }
}

**# 2. Malformed regex in an exclusion (~) pattern is rejected

local ++test_count
capture noisily {
    clear
    set obs 3
    gen str8 dx1 = "E11"
    capture codescan dx1, define(x "E1" ~ "a{2,1}") mode(regex)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: malformed exclusion pattern rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: malformed exclusion pattern rejected (error `=_rc')"
    local ++fail_count
}

**# 3. Malformed-regex rejection via codefile()

local ++test_count
capture noisily {
    clear
    set obs 3
    gen str8 dx1 = "E11"
    preserve
    clear
    set obs 1
    gen str20 name = "bad"
    gen str20 pattern = "a{2,1}"
    tempfile cf
    export delimited using "`cf'.csv", replace
    restore
    capture codescan dx1, codefile("`cf'.csv") mode(regex)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: malformed codefile() pattern rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: malformed codefile() pattern rejected (error `=_rc')"
    local ++fail_count
}

**# 4. Valid regex (incl. legitimate quantifiers/classes) still scans

local ++test_count
capture noisily {
    clear
    set obs 4
    gen str8 dx1 = ""
    replace dx1 = "E1199" in 1
    replace dx1 = "I10"   in 2
    replace dx1 = "E10"   in 3
    replace dx1 = "Z00"   in 4
    * {2,3} is a valid quantifier; [0-35] a valid class; alternation valid.
    codescan dx1, define(dm "E11[0-9]{2,3}" | htn "I1[0-35]") mode(regex)
    assert dm  == 1 in 1
    assert dm  == 0 in 3
    assert htn == 1 in 2
}
if _rc == 0 {
    display as result "  PASS: valid quantifier/class/alternation scans"
    local ++pass_count
}
else {
    display as error "  FAIL: valid quantifier/class/alternation scans (error `=_rc')"
    local ++fail_count
}

**# 5. Unicode nocase known-answer — å folds to Å and matches

local ++test_count
capture noisily {
    clear
    set obs 4
    gen str8 dx1 = ""
    replace dx1 = "å250" in 1
    replace dx1 = "Å251" in 2
    replace dx1 = "E11"  in 3
    replace dx1 = "z00"  in 4
    * Pattern given uppercase; nocase must match both the lower- and upper-å rows.
    codescan dx1, define(scand "Å25") mode(regex) nocase
    assert scand == 1 in 1
    assert scand == 1 in 2
    assert scand == 0 in 3
    assert scand == 0 in 4
    quietly count if scand == 1
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS: unicode nocase folds å/Å"
    local ++pass_count
}
else {
    display as error "  FAIL: unicode nocase folds å/Å (error `=_rc')"
    local ++fail_count
}

**# 6. Unicode nocase in prefix mode

local ++test_count
capture noisily {
    clear
    set obs 3
    gen str8 dx1 = ""
    replace dx1 = "ä10" in 1
    replace dx1 = "Ä11" in 2
    replace dx1 = "B20" in 3
    codescan dx1, define(g "Ä1") mode(prefix) nocase
    assert g == 1 in 1
    assert g == 1 in 2
    assert g == 0 in 3
}
if _rc == 0 {
    display as result "  PASS: unicode nocase prefix mode"
    local ++pass_count
}
else {
    display as error "  FAIL: unicode nocase prefix mode (error `=_rc')"
    local ++fail_count
}

**# 7. ASCII regression guard — case-sensitive results unchanged under ICU

local ++test_count
capture noisily {
    clear
    set obs 5
    gen str8 dx1 = ""
    replace dx1 = "E119" in 1
    replace dx1 = "E11"  in 2
    replace dx1 = "e11"  in 3
    replace dx1 = "I10"  in 4
    replace dx1 = "E66"  in 5
    * Default (case-sensitive) regex: lowercase e11 must NOT match E11.
    codescan dx1, define(dm "E11") mode(regex)
    assert dm == 1 in 1
    assert dm == 1 in 2
    assert dm == 0 in 3
    assert dm == 0 in 4
    assert dm == 0 in 5
    quietly count if dm == 1
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS: ASCII case-sensitive results unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: ASCII case-sensitive results unchanged (error `=_rc')"
    local ++fail_count
}

**# 8. Missing-date note + r(n_excluded_missingdate) — collapse mode

local ++test_count
capture noisily {
    clear
    set obs 6
    gen long pid = _n
    gen str8 dx1 = "E11"
    gen evdate  = mdy(1,1,2020)
    gen refdate = mdy(6,1,2020)
    * Two rows have a missing event date — must be excluded from the window.
    replace evdate = . in 1
    replace evdate = . in 2
    codescan dx1, define(dm "E11") mode(regex) ///
        id(pid) date(evdate) refdate(refdate) lookback(3650) collapse
    assert r(n_excluded_missingdate) == 2
}
if _rc == 0 {
    display as result "  PASS: r(n_excluded_missingdate) collapse mode == 2"
    local ++pass_count
}
else {
    display as error "  FAIL: r(n_excluded_missingdate) collapse mode (error `=_rc')"
    local ++fail_count
}

**# 9. Missing-date scalar — row-level mode (missing refdate)

local ++test_count
capture noisily {
    clear
    set obs 5
    gen long pid = _n
    gen str8 dx1 = "E11"
    * evdate falls inside the forward window [refdate, refdate+3650].
    gen evdate  = mdy(7,1,2020)
    gen refdate = mdy(6,1,2020)
    replace refdate = . in 3
    codescan dx1, define(dm "E11") mode(regex) ///
        id(pid) date(evdate) refdate(refdate) lookforward(3650)
    assert r(n_excluded_missingdate) == 1
    * The missing-refdate row is zeroed even though its code matched.
    assert dm == 0 in 3
}
if _rc == 0 {
    display as result "  PASS: r(n_excluded_missingdate) row-level == 1"
    local ++pass_count
}
else {
    display as error "  FAIL: r(n_excluded_missingdate) row-level (error `=_rc')"
    local ++fail_count
}

**# 10. No window → scalar is not posted

local ++test_count
capture noisily {
    clear
    set obs 3
    gen str8 dx1 = "E11"
    codescan dx1, define(dm "E11") mode(regex)
    * r(n_excluded_missingdate) is only returned when a window is active.
    assert "`r(n_excluded_missingdate)'" == ""
}
if _rc == 0 {
    display as result "  PASS: scalar absent without a time window"
    local ++pass_count
}
else {
    display as error "  FAIL: scalar absent without a time window (error `=_rc')"
    local ++fail_count
}


**# Settings hygiene

* This suite must not leak a session setting to whatever runs next.
local ++test_count
capture noisily {
    assert c(level) == `_qa_level0'
    assert "`c(varabbrev)'" == "`_qa_va0'"
    assert "`c(pwd)'" == "`_qa_pwd0'"
}
if _rc == 0 {
    display as result "  PASS: no session setting leaked"
    local ++pass_count
}
else {
    display as error "  FAIL: session setting leaked (error `=_rc')"
    local ++fail_count
}


**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_codescan_v203_hardening tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _all
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_codescan_v203_hardening tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _all
