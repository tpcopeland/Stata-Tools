* Deterministic hostile-input contract tests for compress_tc.
clear all
version 16.0
set seed 303004
set varabbrev off
capture log close _all
log using "test_compress_tc_hostile.log", replace text nomsg

capture ado uninstall compress_tc
local pkg_dir = subinstr("`c(pwd)'", "/qa", "", 1)
adopath ++ "`pkg_dir'"
local test_count = 0
local pass_count = 0
local fail_count = 0

* dryrun must preserve values and storage types, including a 32-character name.
local ++test_count
capture noisily {
    clear
    set obs 2
    generate str32 abcdefghijklmnopqrstuvwxyzabcdef = cond(_n == 1, "short", "a much longer value")
    generate byte sentinel = 81 + _n
    local before_type : type abcdefghijklmnopqrstuvwxyzabcdef
    generate str32 before = abcdefghijklmnopqrstuvwxyzabcdef
    compress_tc abcdefghijklmnopqrstuvwxyzabcdef, dryrun quietly
    local after_type : type abcdefghijklmnopqrstuvwxyzabcdef
    assert "`after_type'" == "`before_type'"
    assert abcdefghijklmnopqrstuvwxyzabcdef == before
    assert sentinel[1] == 82
    assert sentinel[2] == 83
    assert "`r(varlist)'" == "abcdefghijklmnopqrstuvwxyzabcdef"
}
if _rc == 0 local ++pass_count
else local ++fail_count

* A constant variable and a repeated call must retain user values exactly.
local ++test_count
capture noisily {
    clear
    set obs 3
    generate str20 _compress_tc_probe = "constant"
    generate byte sentinel = _n + 90
    compress_tc _compress_tc_probe, nocompress quietly
    assert _compress_tc_probe == "constant"
    compress_tc _compress_tc_probe, nocompress quietly
    assert _compress_tc_probe == "constant"
    assert sentinel[1] == 91
    assert sentinel[3] == 93
}
if _rc == 0 local ++pass_count
else local ++fail_count

* Numeric-only input is a valid no-op with a concrete empty varlist return.
local ++test_count
capture noisily {
    clear
    input double x byte sentinel
    1 91
    . 92
    end
    compress_tc x, quietly
    assert "`r(varlist)'" == ""
    assert sentinel[1] == 91
    assert sentinel[2] == 92
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_compress_tc_hostile tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    capture log close _all
    exit 1
}
capture log close _all
