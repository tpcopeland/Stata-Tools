* test_logdoc_hostile.do - Hostile path and caller-state contracts for logdoc.
* Seed: 20260823. This suite has no randomized draws.

version 16.0
clear all
set more off
set varabbrev off

local qa_dir = regexr("`c(pwd)'", "/+$", "")
local pkg_dir = regexr("`qa_dir'", "/qa/?$", "")
capture log close _all
log using "test_logdoc_hostile.log", replace text name(_logdoc_hostile)

capture ado uninstall logdoc
quietly net install logdoc, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Shell-hostile paths reject before mutating caller data or source
local ++test_count
capture noisily {
    clear
    input double protected
    7
    .a
    end
    gen long row_before = _n
    tempfile source
    local source_smcl "`source'.smcl"
    tempname fh
    file open `fh' using "`source_smcl'", write text replace
    file write `fh' "{smcl}" _n "{res}SOURCE_SENTINEL" _n
    file close `fh'

    local hostile_output "`c(tmpdir)'/logdoc_hostile_`=char(36)'.html"
    capture noisily logdoc using "`source_smcl'", output("`hostile_output'") format(html) replace quiet
    local call_rc = _rc
    assert `call_rc' == 198
    assert protected[1] == 7
    assert protected[2] == .a
    assert row_before == _n
    tempname readfh
    file open `readfh' using "`source_smcl'", read text
    file read `readfh' line
    file read `readfh' line
    file close `readfh'
    assert strpos(`"`line'"', "SOURCE_SENTINEL") > 0
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Spaces and a 31-character basename survive conversion unchanged
local ++test_count
capture noisily {
    clear
    input double protected
    11
    .a
    end
    gen long row_before = _n
    tempfile base
    local outdir "`base' hostile space"
    capture mkdir "`outdir'"
    local stem "abcdefghijklmnopqrstuvwxyzabcde"
    local source_smcl "`outdir'/`stem'.smcl"
    local output_html "`outdir'/`stem'.html"
    tempname fh
    file open `fh' using "`source_smcl'", write text replace
    file write `fh' "{smcl}" _n "{res}31_CHAR_SENTINEL" _n
    file close `fh'

    quietly logdoc using "`source_smcl'", output("`output_html'") format(html) replace quiet
    confirm file "`output_html'"
    assert !missing(r(nblocks))
    assert r(nblocks) > 0
    assert protected[1] == 11
    assert protected[2] == .a
    assert row_before == _n
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_logdoc_hostile tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _logdoc_hostile
if `fail_count' > 0 exit 1
