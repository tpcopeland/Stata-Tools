* test_codescan_stress_adversarial.do - Stress and adversarial QA for codescan
* Usage: cd codescan/qa && stata-mp -b do test_codescan_stress_adversarial.do

clear all
version 16.0

capture log close _all
tempfile adversarial_log
log using "`adversarial_log'", replace text name(adversarial) nomsg

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


local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _make_codescan_adversarial_data
program define _make_codescan_adversarial_data
    clear
    set obs 12
    gen long pid = ceil(_n / 3)
    replace pid = . in 12
    gen double refdate = td(01jan2020) + 10 * pid
    replace refdate = td(01jan2020) in 12
    gen double dxdate = refdate - mod(_n, 5)
    replace dxdate = . in 5
    format refdate dxdate %td
    gen byte original_order = _n

    forvalues j = 1/40 {
        gen str20 dx`j' = ""
    }

    replace dx1 = "E11.9" in 1
    replace dx2 = "i10!" in 1
    replace dx3 = "Z99?" in 1
    replace dx4 = "A(B)" in 1
    replace dx1 = "e110" in 2
    replace dx5 = "I13" in 2
    replace dx6 = "E119" in 3
    replace dx7 = "I25.10" in 4
    replace dx8 = "Z99.1" in 4
    replace dx9 = "e11x" in 5
    replace dx10 = "I10" in 6
    replace dx11 = "E11.65" in 7
    replace dx12 = "ABC|DEF" in 8
    replace dx13 = "A+B" in 9
    replace dx14 = "literal.dot" in 10
    replace dx15 = "." in 11
    replace dx16 = "" in 12
    replace dx40 = "E11.9" in 12
end

**# Stress Tests

local ++test_count
capture noisily {
    _make_codescan_adversarial_data
    codescan dx1-dx40, ///
        define(dm2 "E11" | htn "I1[0-35]" | zdevice "Z99" | punct "A\(B\)|A\+B|ABC\|DEF|literal\.dot") ///
        id(pid) date(dxdate) refdate(refdate) lookback(10) inclusive ///
        collapse alldates countrows detail nocase

    assert _N == 4
    assert r(N) == 4
    assert r(n_conditions) == 4
    assert r(collapsed) == 1
    assert r(mode) == "regex"
    assert rowsof(r(summary)) == 4
    * 3.0.0: count prevalence ci_low ci_high total_hits positive_units
    assert colsof(r(summary)) == 6

    assert dm2 == 1 if pid == 1
    assert htn == 1 if pid == 1
    assert zdevice == 1 if pid == 2
    assert punct == 1 if pid == 1
    assert punct == 1 if pid == 3
    assert dm2_nrows == 3 if pid == 1
    assert zdevice_nrows == 1 if pid == 2
    assert punct_nrows == 2 if pid == 3
    quietly count if missing(pid)
    assert r(N) == 0
    assert dm2_first <= dm2_last if dm2 == 1
    assert dm2_count <= dm2_nrows if dm2 == 1

    matrix S = r(summary)
    assert S[1, 1] >= 0
    assert S[2, 1] >= 0
    assert S[3, 1] >= 0
    assert S[4, 1] >= 0
    matrix V = r(varcounts)
    assert rowsof(V) > 0
    assert colsof(V) > 0
}
if _rc == 0 {
    display as result "  PASS: many variables, missingness, duplicate ids, punctuation, nocase collapse"
    local ++pass_count
}
else {
    display as error "  FAIL: many-variable adversarial collapse (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input long pid double n1 double n2
    1 110 999
    1 210 111
    2 119 130
    2 .   450
    3 999 110
    end

    codescan n1 n2, define(prefix11 "11") mode(prefix) tostring id(pid) collapse countrows

    assert _N == 3
    assert prefix11 == 1 if pid == 1
    assert prefix11 == 1 if pid == 2
    assert prefix11 == 1 if pid == 3
    assert prefix11_nrows == 2 if pid == 1
    assert prefix11_nrows == 1 if pid == 2
    assert prefix11_nrows == 1 if pid == 3
}
if _rc == 0 {
    display as result "  PASS: numeric tostring stress converts and collapses deterministic prefixes"
    local ++pass_count
}
else {
    display as error "  FAIL: numeric tostring stress (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _make_codescan_adversarial_data
    codescan dx1-dx4, define(dm2 "E11" | htn "I1") matched_code(hitcode) unmatched(nohit)
    assert hitcode == "E11.9" in 1
    assert nohit == 0 in 1
    assert nohit == 1 in 12

    * Each probe gets fresh data. Without that, the indicator variables left
    * behind by the previous call change which guard fires first, so the return
    * code depends on scan history rather than on the option being rejected —
    * that ambiguity is why this used to accept inlist(_rc, 110, 198).
    _make_codescan_adversarial_data
    capture codescan dx1-dx4, define(dm2 "E11") matched_code(dm2)
    assert _rc == 198

    _make_codescan_adversarial_data
    capture codescan dx1-dx4, define(dm2 "E11") unmatched(dx1)
    assert _rc == 198
    * The rejected call must not have damaged the input column it named.
    assert dx1[1] == "E11.9"

    _make_codescan_adversarial_data
    capture codescan dx1-dx4, define(pid "E11") id(pid) collapse
    assert _rc == 198

    _make_codescan_adversarial_data
    capture codescan dx1-dx4, define(dm2 "E11") generate(thisprefixistoolongforstatavarnames_)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: output name collisions and invalid names rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: output collision guards (error `=_rc')"
    local ++fail_count
}

local _orig_va_stress = c(varabbrev)
local ++test_count
capture noisily {
    _make_codescan_adversarial_data

    * Run the whole error battery under BOTH settings. Asserting only that
    * c(varabbrev) is "on" or "off" is a tautology; asserting only the "off"
    * case would pass on a command that hardcodes `set varabbrev off` in its
    * cleanup, which is the actual failure mode this guards.
    foreach va in on off {
        set varabbrev `va'

        capture codescan dx1-dx3, define(dm2 "E11") mode(exact)
        assert _rc == 198
        capture codescan dx1-dx3, define(dm2 "E11") lookback(10)
        assert _rc == 198
        capture codescan dx1-dx3, define(dm2 "E11") lookforward(-2) date(dxdate) refdate(refdate)
        assert _rc == 198
        capture codescan dx1-dx3, define(dm2 "E11") codefile("not_allowed.csv")
        assert _rc == 198
        capture codescan dx1-dx3, define(dm2 "E11") export("bad.ext")
        assert _rc == 198
        capture codescan dx1-dx3, define(dm2 "E11") saving("")
        assert _rc == 198

        * The caller's setting must come back exactly as it was left.
        assert "`c(varabbrev)'" == "`va'"
    }
}
local _stress_rc = _rc
* Restore unconditionally, outside the captured block, before the verdict.
set varabbrev `_orig_va_stress'
if `_stress_rc' == 0 {
    display as result "  PASS: invalid option combinations reject deterministically"
    local ++pass_count
}
else {
    display as error "  FAIL: invalid option stress (error `_stress_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _make_codescan_adversarial_data
    tempfile csvout dtaout

    forvalues k = 1/5 {
        _make_codescan_adversarial_data
        capture drop dm2 htn dm2_first dm2_last dm2_count htn_first htn_last htn_count hitcode nohit
        codescan dx1-dx8, define(dm2 "E11" | htn "I1") nocase replace ///
            matched_code(hitcode) unmatched(nohit) export("`csvout'.csv", replace)
        assert r(N) == 12
        assert r(n_conditions) == 2
        assert dm2 == 1 in 1
        assert htn == 1 in 1
        confirm file "`csvout'.csv"

        _make_codescan_adversarial_data
        codescan dx1-dx8, define(dm2 "E11" | htn "I1") nocase id(pid) collapse replace ///
            saving("`dtaout'.dta", replace)
        confirm file "`dtaout'.dta"
        assert r(N) == 4
    }
}
if _rc == 0 {
    display as result "  PASS: repeated invocations with temp output replacement in one session"
    local ++pass_count
}
else {
    display as error "  FAIL: repeated invocation stress (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _make_codescan_adversarial_data
    codescan_describe dx1-dx40, top(8) nodots
    assert r(n_vars) == 40
    assert r(n_unique) >= 10
    assert r(n_entries) >= 14
    assert rowsof(r(top_codes)) == 8
    assert colsof(r(top_codes)) == 3
    assert colsof(r(chapters)) == 2

    capture codescan_describe dx1-dx40, top(0)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: codescan_describe wide sparse data and invalid top guard"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe wide sparse stress (error `=_rc')"
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

display as result "RESULT: test_codescan_stress_adversarial tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close adversarial
    exit 1
}

display as result "ALL TESTS PASSED"
log close adversarial
