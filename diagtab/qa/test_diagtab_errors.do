*! test_diagtab_errors.do - Public error-contract coverage for diagtab
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
set more off
set varabbrev off
version 17.0

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall diagtab
quietly net install diagtab, from("`pkg_dir'") replace
discard

capture program drop _dte_record
program define _dte_record
    args rc label
    if `rc' == 0 {
        display as result "  PASS: `label'"
    }
    else {
        display as error "  FAIL: `label' (error `rc')"
    }
end

**# Early output-option validation

local ++test_count
capture noisily {
    clear
    input byte test gold marker
    1 1 81
    1 0 81
    0 1 81
    0 0 81
    end

    capture noisily diagtab test gold, open
    local call_rc = _rc
    assert `call_rc' == 198
    assert marker == 81
    assert _N == 4

    capture noisily diagtab test gold
    local legal_rc = _rc
    assert `legal_rc' == 0
    assert r(TP) == 1
    assert r(TN) == 1
}
local block_rc = _rc
_dte_record `block_rc' "open requires xlsx()/excel() and leaves the input unchanged"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

**# Mid-path empty marked sample

local ++test_count
capture noisily {
    clear
    input long id byte test gold marker
    1 1 1 82
    2 1 0 82
    3 0 1 82
    4 0 0 82
    end

    capture noisily diagtab test gold if id < 0
    local call_rc = _rc
    assert `call_rc' == 2000
    assert marker == 82
    assert test == (id <= 2)
    assert gold == inlist(id, 1, 3)

    capture noisily diagtab test gold if id <= 4
    local legal_rc = _rc
    assert `legal_rc' == 0
    assert r(TP) + r(FP) + r(FN) + r(TN) == 4
}
local block_rc = _rc
_dte_record `block_rc' "an empty if-sample errors without mutation; the legal sample runs"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

**# Late frame destination collision must not silently overwrite

local ++test_count
capture noisily {
    clear
    input byte test gold marker
    1 1 83
    1 0 83
    0 1 83
    0 0 83
    end
    capture frame drop diagtab_existing
    capture frame drop diagtab_result
    frame create diagtab_existing
    frame diagtab_existing: clear
    frame diagtab_existing: set obs 1
    frame diagtab_existing: generate byte sentinel = 99

    capture noisily diagtab test gold, frame(diagtab_existing)
    local call_rc = _rc
    assert `call_rc' == 110
    assert marker == 83
    frame diagtab_existing: assert sentinel == 99

    capture noisily diagtab test gold, frame(diagtab_result)
    local legal_rc = _rc
    assert `legal_rc' == 0
    assert "`r(frame)'" == "diagtab_result"
    frame diagtab_result: confirm variable c1
    assert marker == 83
    capture frame drop diagtab_existing
    capture frame drop diagtab_result
}
local block_rc = _rc
_dte_record `block_rc' "existing frames are protected; a fresh frame destination works"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_diagtab_errors tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
exit 0
