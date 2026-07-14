clear all
set more off
version 16.0

* test_datamap_v152.do - Regression tests for datamap 1.5.2
*   1. format(json) survives negative values with magnitude < 1
*      (_datamap_json_number dropped the "=" and errored r(198))
*   2. Mata distinct-value counters in _datamap_classify agree with the
*      -tabulate- / -duplicates report- semantics they replaced

local test_count = 0
local pass_count = 0

local qa_dir  "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local tmp_dir "`qa_dir'/data"

capture mkdir "`tmp_dir'"

capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") replace
discard

* Reports the verdict; the caller owns the tally.  `ok' arrives as a single
* 0/1 token so -args- does not split a parenthesized expression.
capture program drop _v152_say
program define _v152_say
    version 16.0
    args ok label
    if `ok' display as result "PASS: `label'"
    else    display as error  "FAIL: `label'"
end

**# Test 1: negative sub-unit values in format(json)

clear
set obs 500
set seed 4242
* mean, min, p25, p50 all land in (-1, 0)
gen double negsmall = -abs(rnormal(0, 0.1)) - 0.01
gen double posmall  =  abs(rnormal(0, 0.1)) + 0.01
gen byte grp = mod(_n, 3)
save "`tmp_dir'/_v152_neg.dta", replace

local ++test_count
capture datamap, single("`tmp_dir'/_v152_neg.dta") format(json) ///
    output("`tmp_dir'/_v152_neg.json")
local jrc = _rc
local ok = (`jrc' == 0)
local pass_count = `pass_count' + `ok'
_v152_say `ok' "format(json) with negative sub-unit values (rc=`jrc')"

* Scan the emitted JSON once for leading-dot numbers in either sign.
tempname fh
local badneg = 0
local badpos = 0
local sawneg = 0
capture file open `fh' using "`tmp_dir'/_v152_neg.json", read text
if _rc == 0 {
    file read `fh' line
    while r(eof) == 0 {
        if regexm(`"`macval(line)'"', `": *-\.[0-9]"')  local badneg = 1
        if regexm(`"`macval(line)'"', `": *\.[0-9]"')   local badpos = 1
        if regexm(`"`macval(line)'"', `": *-0\.[0-9]"') local sawneg = 1
        file read `fh' line
    }
    file close `fh'
}

local ++test_count
local ok = (`badneg' == 0 & `sawneg' == 1)
local pass_count = `pass_count' + `ok'
_v152_say `ok' "negative numbers emitted as -0.x, not -.x"

local ++test_count
local ok = (`badpos' == 0)
local pass_count = `pass_count' + `ok'
_v152_say `ok' "positive numbers emitted as 0.x, not .x"

local ++test_count
local ok = 0
capture confirm file "`tmp_dir'/_v152_neg.json"
if _rc == 0 {
    * Round-trip through Python to prove the payload is legal JSON
    tempfile pyout
    shell python3 -c "import json,sys; json.load(open('`tmp_dir'/_v152_neg.json')); print('OK')" > "`pyout'" 2>&1
    file open `fh' using "`pyout'", read text
    file read `fh' line
    if strpos(`"`macval(line)'"', "OK") > 0 local ok = 1
    file close `fh'
}
local pass_count = `pass_count' + `ok'
_v152_say `ok' "emitted JSON parses as valid JSON"

**# Test 2: distinct-value counts match -tabulate- semantics

* Numeric with system + extended missing: distinct count excludes all missing
clear
set obs 6
gen double v = .
replace v = 1 in 1
replace v = 2 in 2
replace v = 2 in 3
replace v = .a in 4
replace v = .b in 5
* obs 6 stays system missing
save "`tmp_dir'/_v152_miss.dta", replace

tempfile cls
quietly _datamap_classify using "`tmp_dir'/_v152_miss.dta", saving("`cls'") maxcat(25)
preserve
quietly use "`cls'", clear
quietly summarize unique_vals if varname == "v"
local got = r(mean)
restore

local ++test_count
local ok = (`got' == 2)
local pass_count = `pass_count' + `ok'
_v152_say `ok' "numeric distinct count excludes . and .a-.z (got `got')"

* High-cardinality numeric: previously fell back to -duplicates report-, which
* counted missing as a distinct value and inflated the count.
clear
set obs 20000
gen double hc = _n
replace hc = . in 1/5
save "`tmp_dir'/_v152_hc.dta", replace

tempfile cls2
* cap(0): this test is about the MISSING-value contract at high cardinality, so
* it needs the exact count.  From 1.6.0 the default cap(1000) would censor a
* 19,995-distinct variable to 1001 and the missing-exclusion could not be seen.
quietly _datamap_classify using "`tmp_dir'/_v152_hc.dta", saving("`cls2'") maxcat(25) cap(0)
preserve
quietly use "`cls2'", clear
quietly summarize unique_vals if varname == "hc"
local got_hc = r(mean)
quietly levelsof classification if varname == "hc", local(cls_hc) clean
restore

local ++test_count
local ok = (`got_hc' == 19995)
local pass_count = `pass_count' + `ok'
_v152_say `ok' "high-cardinality count excludes missing (got `got_hc')"

local ++test_count
local ok = ("`cls_hc'" == "continuous")
local pass_count = `pass_count' + `ok'
_v152_say `ok' "high-cardinality numeric stays continuous"

* String distinct count treats "" as a value (matches -duplicates report-)
clear
set obs 4
gen str5 s = "x"
replace s = "" in 2
replace s = "y" in 3
save "`tmp_dir'/_v152_str.dta", replace

tempfile cls3
quietly _datamap_classify using "`tmp_dir'/_v152_str.dta", saving("`cls3'") maxcat(25)
preserve
quietly use "`cls3'", clear
quietly summarize unique_vals if varname == "s"
local got_s = r(mean)
restore

local ++test_count
local ok = (`got_s' == 3)
local pass_count = `pass_count' + `ok'
_v152_say `ok' "string distinct count counts empty string as a value (got `got_s')"

* strL is countable and does not abort classification
clear
set obs 3
gen strL big = "val" + string(_n)
save "`tmp_dir'/_v152_strl.dta", replace

tempfile cls4
capture quietly _datamap_classify using "`tmp_dir'/_v152_strl.dta", saving("`cls4'") maxcat(25)
local strl_rc = _rc

local ++test_count
local ok = (`strl_rc' == 0)
local pass_count = `pass_count' + `ok'
_v152_say `ok' "strL variable classifies without error (rc=`strl_rc')"

* All-missing numeric: 0 distinct non-missing values, no abort
clear
set obs 10
gen double allmiss = .
save "`tmp_dir'/_v152_allmiss.dta", replace

tempfile cls5
capture quietly _datamap_classify using "`tmp_dir'/_v152_allmiss.dta", saving("`cls5'") maxcat(25)
local am_rc = _rc
local got_am = -1
if `am_rc' == 0 {
    preserve
    quietly use "`cls5'", clear
    quietly summarize unique_vals if varname == "allmiss"
    local got_am = r(mean)
    restore
}

local ++test_count
local ok = (`am_rc' == 0 & `got_am' == 0)
local pass_count = `pass_count' + `ok'
_v152_say `ok' "all-missing numeric counts 0 distinct (rc=`am_rc', n=`got_am')"

* detect(binary) still fires on a two-value numeric
clear
set obs 100
gen byte bin = mod(_n, 2)
replace bin = . in 1
save "`tmp_dir'/_v152_bin.dta", replace

tempfile cls6
quietly _datamap_classify using "`tmp_dir'/_v152_bin.dta", saving("`cls6'") ///
    maxcat(25) detect_binary(1)
preserve
quietly use "`cls6'", clear
quietly summarize is_binary if varname == "bin"
local got_bin = r(mean)
restore

local ++test_count
local ok = (`got_bin' == 1)
local pass_count = `pass_count' + `ok'
_v152_say `ok' "detect(binary) flags two-value numeric (got `got_bin')"

* Excluded variables still report no cardinality
clear
set obs 50
gen long patid = _n
gen double x = rnormal()
save "`tmp_dir'/_v152_excl.dta", replace

tempfile cls7
quietly _datamap_classify using "`tmp_dir'/_v152_excl.dta", saving("`cls7'") ///
    maxcat(25) exclude("patid")
preserve
quietly use "`cls7'", clear
quietly count if varname == "patid" & missing(unique_vals)
local excl_ok = (r(N) == 1)
restore

local ++test_count
local ok = `excl_ok'
local pass_count = `pass_count' + `ok'
_v152_say `ok' "excluded variable leaks no unique_vals"

* datadict consumes the same classifier without error
local ++test_count
capture datadict, single("`tmp_dir'/_v152_neg.dta") output("`tmp_dir'/_v152_dict.md")
local dd_rc = _rc
local ok = (`dd_rc' == 0)
local pass_count = `pass_count' + `ok'
_v152_say `ok' "datadict still runs on shared classifier (rc=`dd_rc')"

**# Test 3: _datamap_nuniq helper contract

clear
set obs 100
gen double x   = mod(_n, 7)
replace x = .  in 1
replace x = .a in 2
gen str3 s = "a" + string(mod(_n, 3))
replace s = "" in 1

* Numeric: distinct excludes . and .a-.z
local ++test_count
_datamap_nuniq x
local ok = (r(n) == 7)
local pass_count = `pass_count' + `ok'
_v152_say `ok' "_datamap_nuniq numeric excludes missing (got `r(n)')"

* String default: "" is not a value
_datamap_nuniq s
local n_plain = r(n)
local ++test_count
local ok = (`n_plain' == 3)
local pass_count = `pass_count' + `ok'
_v152_say `ok' "_datamap_nuniq string excludes empty by default (got `n_plain')"

* String countempty: "" is a value (classification-pass semantics)
_datamap_nuniq s, countempty
local n_empty = r(n)
local ++test_count
local ok = (`n_empty' == `n_plain' + 1)
local pass_count = `pass_count' + `ok'
_v152_say `ok' "_datamap_nuniq countempty counts empty string (got `n_empty')"

* _datamap_ndistinct is a private sub-program of datamap.ado, so it is only
* reachable through a datamap run.  Exercise it via panel detection, whose
* "Unique Units" line is exactly its return value.
preserve
clear
set obs 600
gen long pid = ceil(_n/3)
gen double yv = rnormal()
save "`tmp_dir'/_v152_panel.dta", replace
capture datamap, single("`tmp_dir'/_v152_panel.dta") detect(panel) panelid(pid) ///
    output("`tmp_dir'/_v152_panel.txt")
local pnl_rc = _rc
restore

local ++test_count
local ok = (`pnl_rc' == 0)
local pass_count = `pass_count' + `ok'
_v152_say `ok' "detect(panel) runs through _datamap_ndistinct (rc=`pnl_rc')"

local ++test_count
tempname pfh
local units_ok = 0
capture file open `pfh' using "`tmp_dir'/_v152_panel.txt", read text
if _rc == 0 {
    file read `pfh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "Unique Units: 200") > 0 local units_ok = 1
        file read `pfh' line
    }
    file close `pfh'
}
local ok = `units_ok'
local pass_count = `pass_count' + `ok'
_v152_say `ok' "_datamap_ndistinct counts 200 panel units via detect(panel)"

* The helper must not sort, reorder, or add variables to the caller's data
local ++test_count
gen long _row = _n
quietly describe, varlist
local before_vars "`r(varlist)'"
_datamap_nuniq x
quietly describe, varlist
local after_vars "`r(varlist)'"
quietly count if _row != _n
local reordered = r(N)
local ok = ("`before_vars'" == "`after_vars'" & `reordered' == 0)
local pass_count = `pass_count' + `ok'
_v152_say `ok' "_datamap_nuniq leaves data order and varlist untouched"

* varabbrev is restored after the helper runs (c(varabbrev) is "on"/"off")
local ++test_count
local _entry_varabbrev = c(varabbrev)
set varabbrev on
_datamap_nuniq x
local ok = ("`c(varabbrev)'" == "on")
set varabbrev `_entry_varabbrev'
local pass_count = `pass_count' + `ok'
_v152_say `ok' "_datamap_nuniq restores varabbrev"

**# Summary

local fail_count = `test_count' - `pass_count'
display _newline "datamap 1.5.2 regression tests"
display "Tests run:    `test_count'"
display "Passed:       `pass_count'"
display "Failed:       `fail_count'"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 9
}
display as result "ALL TESTS PASSED"
