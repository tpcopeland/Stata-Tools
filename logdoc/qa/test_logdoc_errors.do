* Public error-path contracts for logdoc and logdoc_py.

version 16.0
clear all
set varabbrev off

local qa_dir = regexr("`c(pwd)'", "/+$", "")
local pkg_dir = regexr("`qa_dir'", "/qa/?$", "")
capture ado uninstall logdoc
quietly net install logdoc, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Parser rejection restores varabbrev and preserves active estimates
local ++test_count
capture noisily {
    sysuse auto, clear
    gen long order_before = _n
    regress price mpg
    local e_cmd_before "`e(cmd)'"
    local e_n_before = e(N)
    set varabbrev on
    capture noisily logdoc_py, quiet verbose
    local call_rc = _rc
    assert `call_rc' == 198
    assert _N == 74
    assert order_before == _n
    assert "`e(cmd)'" == "`e_cmd_before'"
    assert e(N) == `e_n_before'
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Missing input is an exact late failure with no output artifact
local ++test_count
capture noisily {
    clear
    input double protected
    21
    .a
    end
    gen long order_before = _n
    tempfile absent output
    local output_html "`output'.html"
    set varabbrev on
    capture noisily logdoc using "`absent'.smcl", output("`output_html'") format(html) quiet
    local call_rc = _rc
    assert `call_rc' == 601
    capture confirm file "`output_html'"
    assert _rc == 601
    assert protected[1] == 21
    assert protected[2] == .a
    assert order_before == _n
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Invalid format is rejected before any missing-input conversion work
local ++test_count
capture noisily {
    clear
    input double protected
    34
    .a
    end
    gen long order_before = _n
    tempfile absent output
    local output_html "`output'.html"
    set varabbrev on
    capture noisily logdoc using "`absent'.smcl", output("`output_html'") format(badformat) quiet
    local call_rc = _rc
    assert `call_rc' == 198
    capture confirm file "`output_html'"
    assert _rc == 601
    assert protected[1] == 34
    assert protected[2] == .a
    assert order_before == _n
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Output-input collision and run-only option both reject without mutation
local ++test_count
capture noisily {
    clear
    input double protected
    55
    .a
    end
    gen long order_before = _n
    tempfile source
    local source_smcl "`source'.smcl"
    tempname fh
    file open `fh' using "`source_smcl'", write text replace
    file write `fh' "{smcl}" _n "{res}ERROR_CONTRACT_SOURCE" _n
    file close `fh'
    set varabbrev on
    capture noisily logdoc using "`source_smcl'", output("`source_smcl'") quiet
    local collision_rc = _rc
    assert `collision_rc' == 198
    capture noisily logdoc using "`source_smcl'", output("`source_smcl'.html") stataexe("stata-mp") quiet
    local option_rc = _rc
    assert `option_rc' == 198
    tempname readfh
    file open `readfh' using "`source_smcl'", read text
    file read `readfh' line
    file read `readfh' line
    file close `readfh'
    assert strpos(`"`line'"', "ERROR_CONTRACT_SOURCE") > 0
    assert protected[1] == 55
    assert protected[2] == .a
    assert order_before == _n
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_logdoc_errors tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 exit 1
