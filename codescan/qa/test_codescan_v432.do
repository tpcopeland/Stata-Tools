* test_codescan_v432.do - Regression tests for the v4.3.2 label() fix
*
* Covers:
*   T1:    compound-quoted label() text carrying a backtick and a $ reaches
*          the variable label, the date-summary labels, the console table,
*          the export label column, and the graph bar label byte for byte
*          (4.3.1: r(132) "too few quotes")
*   T2:    the same text through save() and back through codefile() keeps
*          its bytes (the codefile label path; 4.3.1 refused a backtick or $
*          in the label column); the pattern column still refuses them
*   T3:    a backslash outside quotes still separates entries; one inside
*          quotes is label text
*   T4:    refusals keep their rc: embedded double quote, missing text, an
*          invalid name, and a name that matches no condition are r(198)
*
* Every expected label is built byte by byte with char() in Mata, never by the
* macro processor the fix removes from the path.

clear all
version 16.0
set varabbrev off
capture log close _all

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

quietly do "`qa_dir'/_codescan_qa_common.do"
_codescan_qa_bootstrap
local _qa_owner "`r(owner)'"

local _qa_va0 "`c(varabbrev)'"
local _tmp "`c(tmpdir)'"
if substr("`_tmp'", -1, 1) != "/" local _tmp "`_tmp'/"
tempfile _stem
local _tag = substr("`_stem'", strrpos("`_stem'", "/") + 1, .) + "_cs432"

* Bait: a wrongly expanded $CS432_BAIT or `q' shows up as a changed label.
global CS432_BAIT "EXPANDED"

capture program drop _cs432_data
program define _cs432_data
    clear
    quietly set obs 4
    generate long pid = cond(_n <= 2, 1, _n - 1)
    generate str6 dx1 = cond(_n == 1, "E110", cond(_n == 2, "Z00", cond(_n == 3, "E119", "I10")))
    generate double visit_dt = 21900 + _n
    format visit_dt %td
end


**# T1: compound-quoted label with backtick and $ reaches every sink

local ++test_count
capture noisily {
    _cs432_data
    * want = "P $CS432_BAIT `q end"
    mata: st_global("CS432_WANT", "P " + char(36) + "CS432_BAIT " + char(96) + "q end")
    mata: st_local("lbl", st_global("CS432_WANT"))
    local csv "`_tmp'`_tag'_t1.csv"
    local con "`_tmp'`_tag'_t1.log"
    log using "`con'", name(cs432) text replace
    codescan dx1, define(dm2 "E11") label(dm2 `"`macval(lbl)'"') ///
        id(pid) date(visit_dt) merge earliestdate latestdate ///
        export("`csv'", replace) graph
    * log close clears r(): read it first. Identity is untouched by the label.
    assert "`r(conditions)'" == "dm2"
    log close cs432
    mata: assert(st_varlabel("dm2") == st_global("CS432_WANT"))
    mata: assert(st_varlabel("dm2_first") == "Earliest " + st_global("CS432_WANT") + " Date")
    mata: assert(st_varlabel("dm2_last") == "Latest " + st_global("CS432_WANT") + " Date")
    preserve
    import delimited using "`csv'", clear stringcols(_all) varnames(1)
    assert _N == 1
    mata: assert(st_sdata(1, "label") == st_global("CS432_WANT"))
    assert condition[1] == "dm2"
    restore
    * Console: the table row begins with the label as typed.
    tempname fh
    local found 0
    file open `fh' using "`con'", read text
    file read `fh' line
    while r(eof) == 0 {
        mata: st_local("hit", strofreal(strpos(st_local("line"), "  " + st_global("CS432_WANT") + " ") == 1))
        if `hit' local found 1
        file read `fh' line
    }
    file close `fh'
    assert `found' == 1
    capture erase "`csv'"
    capture erase "`con'"
}
if _rc == 0 {
    display as result "  PASS: T1 - backtick/\$ label text reaches every sink verbatim"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - verbatim label text (error `=_rc')"
    local ++fail_count
    capture log close cs432
}


**# T2: label bytes survive save() and codefile()

local ++test_count
capture noisily {
    _cs432_data
    mata: st_global("CS432_WANT", "U " + char(96) + "tick " + char(36) + "CS432_BAIT end")
    mata: st_local("lbl", st_global("CS432_WANT"))
    local rules "`_tmp'`_tag'_t2.csv"
    codescan dx1, define(dm2 "E11" | htn "I10") label(dm2 `"`macval(lbl)'"') ///
        save("`rules'", replace)
    mata: assert(st_varlabel("dm2") == st_global("CS432_WANT"))
    drop dm2 htn
    codescan dx1, codefile("`rules'")
    mata: assert(st_varlabel("dm2") == st_global("CS432_WANT"))
    * htn had no label: it falls back to its name, not to a neighbour's text.
    mata: assert(st_varlabel("htn") == "htn")
    * Oracle from the fixture: rows 1 and 3 carry E11*, row 4 carries I10.
    assert dm2 == inlist(_n, 1, 3)
    assert htn == (_n == 4)
    * The guard still covers the pattern column, and the compound-quote
    * closer in a label.
    drop dm2 htn
    preserve
    clear
    quietly set obs 1
    generate str32 name = "dm2"
    generate str20 pattern = "E1" + char(96) + "x"
    generate str20 label = "Diabetes"
    quietly export delimited using "`rules'", replace
    replace pattern = "E11"
    replace label = "A" + char(34) + char(39) + "B"
    tempfile badlab
    quietly save "`badlab'.dta"
    restore
    * expect: REFUSED
    capture codescan dx1, codefile("`rules'")
    assert _rc == 198
    * expect: REFUSED
    capture codescan dx1, codefile("`badlab'.dta")
    assert _rc == 198
    capture confirm variable dm2
    assert _rc == 111
    capture erase "`rules'"
}
if _rc == 0 {
    display as result "  PASS: T2 - save()/codefile() label round trip is byte exact"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - codefile label round trip (error `=_rc')"
    local ++fail_count
}


**# T3: backslash separates entries only outside quotes

local ++test_count
capture noisily {
    _cs432_data
    codescan dx1, define(dm2 "E11" | htn "I10") label(dm2 "Ratio \ CI" \ htn Hypertension)
    mata: assert(st_varlabel("dm2") == "Ratio " + char(92) + " CI")
    mata: assert(st_varlabel("htn") == "Hypertension")
    drop dm2 htn
    codescan dx1, define(dm2 "E11" | htn "I10") label(dm2 `"Diabetes, type 2"' \ htn "Hypertension")
    mata: assert(st_varlabel("dm2") == "Diabetes, type 2")
    mata: assert(st_varlabel("htn") == "Hypertension")
}
if _rc == 0 {
    display as result "  PASS: T3 - backslash separator vs quoted backslash"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - label() entry separation (error `=_rc')"
    local ++fail_count
}


**# T4: refusals keep r(198) and leave the data untouched

local ++test_count
capture noisily {
    _cs432_data
    local k0 = c(k)
    * expect: REFUSED
    capture codescan dx1, define(dm2 "E11") label(dm2 `"He said "yes""')
    assert _rc == 198
    * expect: REFUSED (define()'s | used as the label() separator)
    capture codescan dx1, define(dm2 "E11" | htn "I10") label(dm2 "Diabetes" | htn "Hypertension")
    assert _rc == 198
    * expect: REFUSED (name without text)
    capture codescan dx1, define(dm2 "E11") label(dm2)
    assert _rc == 198
    * expect: REFUSED (not a Stata name)
    capture codescan dx1, define(dm2 "E11") label(2dm "Diabetes")
    assert _rc == 198
    * expect: REFUSED (no such condition)
    capture codescan dx1, define(dm2 "E11") label(chf "Heart failure")
    assert _rc == 198
    assert c(k) == `k0'
    capture confirm variable dm2
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: T4 - label() refusals keep r(198)"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - label() refusals (error `=_rc')"
    local ++fail_count
}


**# Summary

macro drop CS432_BAIT CS432_WANT
assert "`c(varabbrev)'" == "`_qa_va0'"
_codescan_qa_restore "`_qa_owner'"
_codescan_qa_publish "test_codescan_v432" `test_count' `pass_count' `fail_count'
display as result "RESULT: test_codescan_v432 tests=`test_count' pass=`pass_count' fail=`fail_count'"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}

display as result "ALL TESTS PASSED"
