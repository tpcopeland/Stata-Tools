* test_massdesas_hostile.do - Hostile directory, filename, and state contracts.
* Seed: 20260823. This suite has no randomized draws.

version 14.0
clear all
set more off
set varabbrev off

local qa_dir "`c(pwd)'"
capture log close _all
log using "test_massdesas_hostile.log", replace text name(_massdesas_hostile)
do "`qa_dir'/_massdesas_qa_common.do"
quietly _massdesas_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Missing directories fail cleanly and preserve caller data
local ++test_count
capture noisily {
    clear
    input double protected
    9
    .a
    end
    gen long row_before = _n
    local before_pwd `"`c(pwd)'"'
    tempfile absent
    capture noisily massdesas, directory("`absent'_does_not_exist")
    local call_rc = _rc
    assert `call_rc' == 601
    assert protected[1] == 9
    assert protected[2] == .a
    assert row_before == _n
    assert `"`c(pwd)'"' == `"`before_pwd'"'
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Empty directories fail cleanly and preserve caller data
local ++test_count
capture noisily {
    clear
    input double protected
    13
    .a
    end
    gen long row_before = _n
    tempfile empty_anchor
    local empty_dir "`empty_anchor'_empty hostile"
    capture mkdir "`empty_dir'"
    local before_pwd `"`c(pwd)'"'
    capture noisily massdesas, directory("`empty_dir'")
    local call_rc = _rc
    assert `call_rc' == 601
    assert protected[1] == 13
    assert protected[2] == .a
    assert row_before == _n
    assert `"`c(pwd)'"' == `"`before_pwd'"'
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# A space-containing directory and 31-character source basename convert once
local ++test_count
capture noisily {
    clear
    input double protected
    17
    .a
    end
    gen long row_before = _n
    tempfile fixture_anchor
    local fixture_dir "`fixture_anchor'_space hostile"
    capture mkdir "`fixture_dir'"
    local stem "abcdefghijklmnopqrstuvwxyzabcde"
    local sasfile "`fixture_dir'/`stem'.sas7bdat"
    local fixture_r = subinstr("`sasfile'", "\\", "/", .)
    shell Rscript -e "haven::write_sas(data.frame(value=c(1,2)), '`fixture_r'')"
    confirm file "`sasfile'"
    local before_pwd `"`c(pwd)'"'
    quietly massdesas, directory("`fixture_dir'")
    assert r(n_converted) == 1
    assert r(n_failed) == 0
    confirm file "`fixture_dir'/`stem'.dta"
    assert protected[1] == 17
    assert protected[2] == .a
    assert row_before == _n
    assert `"`c(pwd)'"' == `"`before_pwd'"'
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_massdesas_hostile tests=`test_count' pass=`pass_count' fail=`fail_count'"
_massdesas_qa_cleanup
capture log close _massdesas_hostile
if `fail_count' > 0 exit 1
