clear all
set more off
version 16.0

* test_datamap_v154.do - Regression tests for datamap 1.5.4
*   1. datadict's documented mincell(5) privacy default is honored
*   2. explicit/configured invalid thresholds are rejected, not defaulted
*   3. datamvp rejects invalid filters and graph-only no-op options

local test_count = 0
local pass_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local tmp_dir "`qa_dir'/data"

capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") replace
discard

capture program drop _v154_record
program define _v154_record
    version 16.0
    args ok label
    if `ok' display as result "PASS: `label'"
    else    display as error  "FAIL: `label'"
end

**# datadict privacy default

clear
input byte arm
1
1
2
end
label define arm_lbl 1 "Control" 2 "Treatment"
label values arm arm_lbl

local dict "`tmp_dir'/_v154_dictionary.md"
capture noisily datadict, output("`dict'") stats
local dict_rc = _rc
local saw_suppressed = 0
tempname fh
capture file open `fh' using "`dict'", read text
if _rc == 0 {
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "suppressed <5") local saw_suppressed = 1
        file read `fh' line
    }
    file close `fh'
}
local ++test_count
local ok = (`dict_rc' == 0 & `saw_suppressed')
local pass_count = `pass_count' + `ok'
_v154_record `ok' "datadict defaults to mincell(5)"

**# Explicit negative thresholds

foreach spec in "maxc(-1)" "maxfr(-1)" "mince(-1)" {
    local ++test_count
    capture noisily datadict, output("`dict'") `spec'
    local ok = (_rc == 198)
    local pass_count = `pass_count' + `ok'
    _v154_record `ok' "datadict rejects `spec'"
}

foreach spec in "maxc(-1)" "maxfr(-1)" "rare(-1)" "outl(-1)" "mince(-1)" {
    local ++test_count
    capture noisily datacheck, `spec'
    local ok = (_rc == 198)
    local pass_count = `pass_count' + `ok'
    _v154_record `ok' "datacheck rejects `spec'"
}

**# Invalid configured thresholds

local badcfg "`tmp_dir'/_v154_bad_config.txt"
file open `fh' using "`badcfg'", write text replace
file write `fh' "maxcat = -2" _n
file close `fh'

local ++test_count
capture noisily datadict, output("`dict'") config("`badcfg'")
local ok = (_rc == 198)
local pass_count = `pass_count' + `ok'
_v154_record `ok' "datadict rejects invalid configured maxcat"

local ++test_count
capture noisily datacheck, config("`badcfg'")
local ok = (_rc == 198)
local pass_count = `pass_count' + `ok'
_v154_record `ok' "datacheck rejects invalid configured maxcat"

**# datamvp validation and no-op rejection

replace arm = . in 3
foreach spec in "minfreq(0)" "minmissing(-2)" "maxmissing(-2)" ///
    "top(2)" "groupgap(2)" "legendopts(rows(2))" {
    local ++test_count
    capture noisily datamvp arm, `spec'
    local ok = (_rc == 198)
    local pass_count = `pass_count' + `ok'
    _v154_record `ok' "datamvp rejects `spec' without a valid graph context"
}

local ++test_count
capture noisily datamvp arm, graph(bar) top(2) nodraw
local ok = (_rc == 198)
local pass_count = `pass_count' + `ok'
_v154_record `ok' "datamvp rejects top() outside graph(patterns)"

local ++test_count
capture noisily datamvp arm, graph(bar) groupgap(2) nodraw
local ok = (_rc == 198)
local pass_count = `pass_count' + `ok'
_v154_record `ok' "datamvp rejects groupgap() without over()"

local ++test_count
capture noisily datamvp arm, graph(bar) title("top(2) is text") nodraw
local ok = (_rc == 0)
local pass_count = `pass_count' + `ok'
_v154_record `ok' "option-like title text is not parsed as top()"

local map_with_option_text "`tmp_dir'/maxcat(-1).txt"
local ++test_count
capture noisily datamap, output("`map_with_option_text'")
local ok = (_rc == 0)
local pass_count = `pass_count' + `ok'
_v154_record `ok' "option-like output path is not parsed as maxcat()"

local ++test_count
local entry_varabbrev = c(varabbrev)
set varabbrev on
capture datamvp arm, minfreq(0)
local ok = (_rc == 198 & "`c(varabbrev)'" == "on")
set varabbrev `entry_varabbrev'
local pass_count = `pass_count' + `ok'
_v154_record `ok' "validation failures restore varabbrev"

capture erase "`dict'"
capture erase "`badcfg'"
capture erase "`map_with_option_text'"

**# Summary

local fail_count = `test_count' - `pass_count'
display _newline "datamap 1.5.4 regression tests"
display "Tests run:    `test_count'"
display "Passed:       `pass_count'"
display "Failed:       `fail_count'"
display "RESULT: test_datamap_v154 tests=`test_count' pass=`pass_count' fail=`fail_count'"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 9
}
display as result "ALL TESTS PASSED"
