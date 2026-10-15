* test_codescan_v434.do - Regression tests for the v4.3.4 zero-match summary note
*
* Covers:
*   T1: several empty conditions print ONE summary note listing every empty
*       name (4.3.3 printed one note per empty condition)
*   T2: exactly one empty condition keeps the singular note
*   T3: no empty condition prints no note
*   T4: long empty-condition names wrap at word boundaries
*   T5: header, collapse and merge counts are not padded mid-sentence
*       (a fixed %10.0fc printed "N =          4 observations")
*   T6: co-occurrence columns widen for names of 9+ characters (a fixed %9s
*       ran "cancer" and "metastatic" together as "cancermetastatic")
*   T7: status-line display contract. Every status/confirmation line is
*       unindented, one parenthesised sentence, second clause after "; ",
*       no "--"; under preserve/frame() the collapse line says the data in
*       memory is unchanged; codescan_describe headers use the command name
*   T8: status lines print only after every side effect succeeded: a failed
*       export()/saving() leaves no "(... collapsed ...)" or "(... saved ...)"
*       claim in front of the error
*   T9: report footnotes are one SMCL paragraph each: at a wide line one
*       line, at a narrow line wrapped with a 3-space hanging indent
*   T10: in-place collapse with a failed export()/saving()/save() restores
*        the caller's data exactly and returns the error (was: collapsed
*        table left in memory with rc 603)
*   T11: a count of 1 is singular in the header, status line and notes
*   T12: status lines wrap at word boundaries at linesize 80 (a frame
*        line past 80 columns was broken by Stata mid-word)
*   T13: a file path containing SMCL ({c 45}, {p_end}) prints literally in
*        the status lines (was: interpreted, showing a path that does not exist)

clear all
version 16.0
set varabbrev off
capture log close _all

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
quietly do "`qa_dir'/_codescan_qa_common.do"
_codescan_qa_bootstrap
local _qa_owner "`r(owner)'"

local _tmp "`c(tmpdir)'"
if substr("`_tmp'", -1, 1) != "/" local _tmp "`_tmp'/"
tempfile _stem
local _tag = substr("`_stem'", strrpos("`_stem'", "/") + 1, .) + "_cs434"

capture mata: mata drop _cs434_note()
mata:
// Join the lines of the "(note: ..." block (up to the line ending in ")") with
// single spaces; return the joined text, line count and longest line.
void _cs434_note(string scalar f)
{
    string colvector L
    real scalar i, on, n, mx
    string scalar j
    L = cat(f)
    on = 0; n = 0; mx = 0; j = ""
    for (i = 1; i <= rows(L); i++) {
        if (substr(L[i], 1, 7) == "(note: ") on = 1
        if (on) {
            j = j + (n > 0 ? " " : "") + strtrim(L[i])
            n++
            mx = max((mx, strlen(L[i])))
            if (substr(L[i], strlen(L[i]), 1) == ")") break
        }
    }
    st_local("joined", j); st_local("nlines", strofreal(n)); st_local("maxlen", strofreal(mx))
}
end

capture program drop _cs434_data
program define _cs434_data
    clear
    quietly set obs 4
    generate long pid = _n
    generate str6 dx1 = cond(_n == 1, "E110", cond(_n == 2, "Z00", cond(_n == 3, "E119", "I10")))
end

* Count the "matched 0" note lines in a text log; return the count and the first.
capture program drop _cs434_scan
program define _cs434_scan, rclass
    args con
    tempname fh
    local nn 0
    local first ""
    file open `fh' using "`con'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "(note: ") == 1 & strpos(`"`macval(line)'"', "matched 0") {
            local ++nn
            if `nn' == 1 local first `"`macval(line)'"'
        }
        file read `fh' line
    }
    file close `fh'
    return scalar nn = `nn'
    return local first `"`macval(first)'"'
end

**# T1
local ++test_count
capture noisily {
    _cs434_data
    local con "`_tmp'`_tag'_t1.log"
    log using "`con'", name(cs434) text replace
    codescan dx1, define(dm "E11" a1 "QQ1" b2 "QQ2" c3 "QQ3")
    log close cs434
    _cs434_scan "`con'"
    capture erase "`con'"
    assert r(nn) == 1
    assert `"`r(first)'"' == "(note: 3 conditions matched 0 observations: a1 b2 c3)"
}
if _rc == 0 {
    display as result "  PASS: T1 - one summary note lists all empty conditions"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - summary note (error `=_rc')"
    local ++fail_count
    capture log close cs434
}

**# T2
local ++test_count
capture noisily {
    _cs434_data
    local con "`_tmp'`_tag'_t2.log"
    log using "`con'", name(cs434) text replace
    codescan dx1, define(dm "E11" a1 "QQ1")
    log close cs434
    _cs434_scan "`con'"
    capture erase "`con'"
    assert r(nn) == 1
    assert `"`r(first)'"' == "(note: condition a1 matched 0 observations)"
}
if _rc == 0 {
    display as result "  PASS: T2 - single empty condition keeps singular note"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - singular note (error `=_rc')"
    local ++fail_count
    capture log close cs434
}

**# T3
* guard: expected green at HEAD (behaviour-preservation: no empty condition, no note)
local ++test_count
capture noisily {
    _cs434_data
    local con "`_tmp'`_tag'_t3.log"
    log using "`con'", name(cs434) text replace
    codescan dx1, define(dm "E11" ht "I10")
    log close cs434
    _cs434_scan "`con'"
    capture erase "`con'"
    assert r(nn) == 0
}
if _rc == 0 {
    display as result "  PASS: T3 - no empty condition, no note"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - no note (error `=_rc')"
    local ++fail_count
    capture log close cs434
}

**# T4
local ++test_count
capture noisily {
    _cs434_data
    local defs `"dm "E11""'
    local names ""
    forvalues k = 1/9 {
        local defs `"`defs' condition_number_`k' "QQ`k'""'
        local names "`names' condition_number_`k'"
    }
    local con "`_tmp'`_tag'_t4.log"
    log using "`con'", name(cs434) text replace
    codescan dx1, define(`defs')
    log close cs434
    mata: _cs434_note("`con'")
    assert "`nlines'" != "" 
    assert real("`maxlen'") <= 80
    local want "(note: 9 conditions matched 0 observations: `=strtrim("`names'")')"
    assert `"`joined'"' == `"`want'"'
    assert real("`nlines'") >= 2
    capture erase "`con'"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: T4 long names wrap at word boundaries"
}
else {
    local ++fail_count
    display as error "  FAIL: T4 long names wrap at word boundaries (error `=_rc')"
    capture log close cs434
}

capture mata: mata drop _cs434_has()
capture mata: mata drop _cs434_cooc()
capture mata: mata drop _cs434_block()
capture mata: mata drop _cs434_none()
capture mata: mata drop _cs434_nostatus()
capture mata: mata drop _cs434_para()
capture mata: mata drop _cs434_prefix()
capture mata: mata drop _cs434_status()
mata:
// Return in local `found' 1 if any line of f equals target exactly.
void _cs434_has(string scalar f, string scalar target)
{
    string colvector L
    L = cat(f)
    st_local("found", strofreal(anyof(L, target)))
}
// Co-occurrence block: header tokens, header length, row lengths.
void _cs434_cooc(string scalar f)
{
    string colvector L
    real scalar i, at, ok
    L = cat(f)
    at = 0
    for (i = 1; i <= rows(L); i++) if (L[i] == "  Co-occurrence:") at = i
    if (at == 0 | at + 3 > rows(L)) {
        st_local("hdr", ""); st_local("ok", "0"); return
    }
    st_local("hdr", strtrim(stritrim(L[at + 1])))
    // Every body row ends at the same column as the header (right-aligned).
    ok = 1
    for (i = at + 2; i <= at + 3; i++) ok = ok & (strlen(L[i]) == strlen(L[at + 1]))
    st_local("ok", strofreal(ok))
}
// Lines 1-4 of T7 are consecutive and preceded by exactly one blank line.
void _cs434_block(string scalar f)
{
    string colvector L
    real scalar i, ok
    L = cat(f)
    ok = 0
    for (i = 2; i + 3 <= rows(L); i++) {
        if (L[i] == "(data collapsed to 4 unique pid values)") {
            ok = (L[i-1] == "") & (i < 3 | L[i-2] != "") &
                 (L[i+1] == "(results exported to t7.xlsx)") &
                 (L[i+2] == "(dataset saved to t7.dta)") &
                 (L[i+3] == "(define() saved to t7.csv)")
            break
        }
    }
    st_local("blockok", strofreal(ok))
}
// None of the retired status forms appear in the output.
void _cs434_none(string scalar f)
{
    string colvector L
    real scalar i, bad
    L = cat(f)
    bad = 0
    for (i = 1; i <= rows(L); i++) {
        if (substr(L[i], 1, 1) == ".") continue
        bad = bad | strpos(L[i], "Collapsed to") | strpos(L[i], "Results exported") |
              strpos(L[i], "  (dataset saved") | strpos(L[i], "codescan describe:") |
              strpos(L[i], "Merged patient-level") | strpos(L[i], " -- ")
    }
    st_local("none", strofreal(!bad))
}
// No status line (collapsed/merged/saved/exported) in the output.
void _cs434_nostatus(string scalar f)
{
    string colvector L
    real scalar i, bad
    L = cat(f)
    bad = 0
    for (i = 1; i <= rows(L); i++) {
        if (substr(L[i], 1, 1) == "." | substr(L[i], 1, 1) == ">") continue
        bad = bad | (substr(L[i], 1, 1) == "(" &
              (strpos(L[i], "collapsed to") | strpos(L[i], "merged for") |
               strpos(L[i], "saved to") | strpos(L[i], "exported to")))
    }
    st_local("nostatus", strofreal(!bad))
}
// A paragraph starting with `start': wraps to 2+ lines, every line <= 60,
// continuation lines indented 3 spaces, and the last line ends with ")".
void _cs434_para(string scalar f, string scalar start)
{
    string colvector L
    real scalar i, k, ok
    L = cat(f)
    ok = 0
    for (i = 1; i <= rows(L); i++) {
        if (substr(L[i], 1, strlen(start)) == start) {
            ok = strlen(L[i]) <= 60
            for (k = i + 1; k <= rows(L); k++) {
                if (substr(L[k], 1, 3) != "   " | substr(L[k], 4, 1) == " ") break
                ok = ok & strlen(L[k]) <= 60
            }
            ok = ok & (k > i + 1) & (substr(L[k-1], strlen(L[k-1]), 1) == ")")
            break
        }
    }
    st_local("paraok", strofreal(ok))
}
// 1 if any line of f starts with prefix.
void _cs434_prefix(string scalar f, string scalar pre)
{
    string colvector L
    real scalar i, hit
    L = cat(f)
    hit = 0
    for (i = 1; i <= rows(L); i++) hit = hit | (substr(L[i], 1, strlen(pre)) == pre)
    st_local("found", strofreal(hit))
}
// The status paragraph starting with "(": lines <= 80, no line that is only
// ")" (after trimming), joined text equals want.
void _cs434_status(string scalar f, string scalar want)
{
    string colvector L
    real scalar i, k, ok
    string scalar j
    L = cat(f)
    ok = 0
    for (i = 1; i <= rows(L); i++) {
        if (substr(L[i], 1, 9) == "(results ") {
            j = strtrim(L[i]); ok = strlen(L[i]) <= 80
            for (k = i + 1; k <= rows(L); k++) {
                if (substr(L[k], 1, 1) != " " | strtrim(L[k]) == "") break
                ok = ok & strlen(L[k]) <= 80 & strtrim(L[k]) != ")"
                j = j + " " + strtrim(L[k])
            }
            ok = ok & (j == want)
            break
        }
    }
    st_local("statok", strofreal(ok))
}
end

**# T5
local ++test_count
capture noisily {
    _cs434_data
    local con "`_tmp'`_tag'_t5.log"
    log using "`con'", name(cs434) text replace
    preserve
    codescan dx1, define(dm "E11")
    restore, preserve
    codescan dx1, define(dm "E11") id(pid) collapse
    restore, preserve
    codescan dx1, define(dm "E11") id(pid) merge
    restore
    log close cs434
    mata: _cs434_has("`con'", "codescan: 1 condition, 1 variable, N = 4 observations")
    assert `found' == 1
    mata: _cs434_has("`con'", "(data collapsed to 4 unique pid values)")
    assert `found' == 1
    mata: _cs434_has("`con'", "(patient-level indicators merged for 4 unique pid values)")
    assert `found' == 1
    capture erase "`con'"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: T5 header/collapse/merge counts are trimmed"
}
else {
    local ++fail_count
    display as error "  FAIL: T5 header/collapse/merge counts are trimmed (error `=_rc')"
    capture log close cs434
}

**# T6
local ++test_count
capture noisily {
    _cs434_data
    local _ls0 = c(linesize)
    set linesize 200
    local con "`_tmp'`_tag'_t6.log"
    log using "`con'", name(cs434) text replace
    codescan dx1, define(cancer "E11" metastatic "E119") cooccurrence
    log close cs434
    set linesize `_ls0'
    mata: _cs434_cooc("`con'")
    assert `"`hdr'"' == "cancer metastatic"
    assert `ok' == 1
    capture erase "`con'"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: T6 co-occurrence header separates long names"
}
else {
    local ++fail_count
    display as error "  FAIL: T6 co-occurrence header separates long names (error `=_rc')"
    capture log close cs434
    capture set linesize `_ls0'
}

**# T7
local ++test_count
capture noisily {
    local _wd "`c(pwd)'"
    local _sd "`_tmp'`_tag'_t7"
    capture mkdir "`_sd'"
    quietly cd "`_sd'"
    local con "`_tmp'`_tag'_t7.log"
    local _ls0 = c(linesize)
    set linesize 255
    log using "`con'", name(cs434) text replace
    _cs434_data
    preserve
    codescan dx1, define(dm "E11") id(pid) collapse export(t7.xlsx, replace) ///
        saving(t7.dta, replace) save(t7.csv, replace)
    restore, preserve
    codescan dx1, define(dm "E11") id(pid) collapse preserve
    restore, preserve
    capture frame drop t7fr
    codescan dx1, define(dm "E11") id(pid) collapse frame(t7fr)
    restore, preserve
    codescan dx1, define(dm "E11") id(pid) merge preserve
    restore
    codescan_describe dx1, save(t7d.csv, replace)
    log close cs434
    set linesize `_ls0'
    quietly cd "`_wd'"
    capture frame drop t7fr
    local want1 "(data collapsed to 4 unique pid values)"
    local want2 "(results exported to t7.xlsx)"
    local want3 "(dataset saved to t7.dta)"
    local want4 "(define() saved to t7.csv)"
    local want5 "(results collapsed to 4 unique pid values; data in memory unchanged)"
    local want6 "(results collapsed to 4 unique pid values in frame t7fr; data in memory unchanged)"
    local want7 "(patient-level indicators merged for 4 unique pid values; data in memory unchanged)"
    local want8 "(draft codefile saved to t7d.csv; edit condition names and patterns before use)"
    forvalues k = 1/8 {
        mata: _cs434_has("`con'", st_local("want`k'"))
        if `found' != 1 display as error "T7 missing line `k': `want`k''"
        assert `found' == 1
    }
    * The four first-call lines form one block after a single blank line.
    mata: _cs434_block("`con'")
    assert `blockok' == 1
    * No retired forms survive anywhere in the output.
    mata: _cs434_none("`con'")
    assert `none' == 1
    capture erase "`con'"
    foreach f in t7.xlsx t7.dta t7.csv t7d.csv {
        capture erase "`_sd'/`f'"
    }
    capture rmdir "`_sd'"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: T7 status-line display contract"
}
else {
    local ++fail_count
    display as error "  FAIL: T7 status-line display contract (error `=_rc')"
    capture log close cs434
    capture set linesize `_ls0'
    capture quietly cd "`_wd'"
    capture frame drop t7fr
}

**# T8
local ++test_count
capture noisily {
    local con "`_tmp'`_tag'_t8.log"
    log using "`con'", name(cs434) text replace
    _cs434_data
    preserve
    capture noisily codescan dx1, define(dm "E11") id(pid) collapse preserve ///
        export("/nonexistent_cs434_dir/x.xlsx")
    local rc1 = _rc
    restore, preserve
    capture noisily codescan dx1, define(dm "E11") id(pid) collapse ///
        saving("/nonexistent_cs434_dir/x.dta")
    local rc2 = _rc
    restore
    log close cs434
    assert `rc1' != 0 & `rc2' != 0
    mata: _cs434_nostatus("`con'")
    assert `nostatus' == 1
    capture erase "`con'"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: T8 no status claim before a failed write"
}
else {
    local ++fail_count
    display as error "  FAIL: T8 no status claim before a failed write (error `=_rc')"
    capture log close cs434
}

**# T9
local ++test_count
capture noisily {
    local _ls0 = c(linesize)
    local conw "`_tmp'`_tag'_t9w.log"
    local conn "`_tmp'`_tag'_t9n.log"
    _cs434_data
    replace dx1 = "E110" in 2
    generate str6 dx2 = cond(_n == 1, "E111", "")
    set linesize 255
    log using "`conw'", name(cs434) text replace
    codescan dx1 dx2, define(dm "E11") detail allslots
    codescan dx1 dx2, define(dm "E11") detail replace
    log close cs434
    set linesize 60
    log using "`conn'", name(cs434) text replace
    codescan dx1 dx2, define(dm "E11") detail allslots replace
    log close cs434
    set linesize `_ls0'
    mata: _cs434_has("`conw'", "  (every matching slot counted; a row with the same condition in two variables adds to both)")
    assert `found' == 1
    mata: _cs434_has("`conw'", "  (each row counted once per condition, against the FIRST matching variable in varlist order; add allslots to count every matching slot instead)")
    assert `found' == 1
    mata: _cs434_para("`conn'", "  (every matching slot")
    assert `paraok' == 1
    capture erase "`conw'"
    capture erase "`conn'"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: T9 footnotes are single wrapped paragraphs"
}
else {
    local ++fail_count
    display as error "  FAIL: T9 footnotes are single wrapped paragraphs (error `=_rc')"
    capture log close cs434
    capture set linesize `_ls0'
}

**# T10
local ++test_count
capture noisily {
    _cs434_data
    tempfile _pre10
    quietly save `_pre10'
    foreach _o in `"export("/nonexistent_cs434_dir/x.xlsx")"' ///
                  `"saving("/nonexistent_cs434_dir/x.dta")"' ///
                  `"save("/nonexistent_cs434_dir/x.csv")"' {
        use `_pre10', clear
        capture codescan dx1, define(dm "E11" ht "I10") id(pid) collapse `_o'
        local _rc10 = _rc
        local _col10 = r(collapsed)
        assert `_rc10' == 603
        assert `_col10' == 0
        assert _N == 4
        cf _all using `_pre10'
        capture confirm variable dm
        assert _rc == 111
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: T10 failed write after in-place collapse restores the data"
}
else {
    local ++fail_count
    display as error "  FAIL: T10 failed write after in-place collapse restores the data (error `=_rc')"
}

**# T11
local ++test_count
capture noisily {
    local con "`_tmp'`_tag'_t11.log"
    log using "`con'", name(cs434) text replace
    clear
    quietly set obs 2
    generate long pid = 1
    generate str6 dx1 = "E110"
    generate long d = cond(_n == 1, 22000, .)
    generate long r = 22010
    preserve
    codescan dx1, define(dm "E11") id(pid) date(d) refdate(r) lookback(365) collapse
    restore
    keep in 1
    codescan dx1, define(dm "E11")
    log close cs434
    mata: _cs434_has("`con'", "codescan: 1 condition, 1 variable, N = 1 pid value")
    assert `found' == 1
    mata: _cs434_has("`con'", "(data collapsed to 1 unique pid value)")
    assert `found' == 1
    mata: _cs434_has("`con'", "codescan: 1 condition, 1 variable, N = 1 observation")
    assert `found' == 1
    mata: _cs434_prefix("`con'", "(note: 1 row excluded from the time window")
    assert `found' == 1
    capture erase "`con'"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: T11 singular counts"
}
else {
    local ++fail_count
    display as error "  FAIL: T11 singular counts (error `=_rc')"
    capture log close cs434
}

**# T12
local ++test_count
capture noisily {
    local _ls0 = c(linesize)
    local con "`_tmp'`_tag'_t12.log"
    _cs434_data
    replace pid = 3 in 4
    capture frame drop fzlonger1
    set linesize 80
    log using "`con'", name(cs434) text replace
    preserve
    codescan dx1, define(dm "E11") id(pid) collapse frame(fzlonger1)
    restore
    log close cs434
    set linesize `_ls0'
    capture frame drop fzlonger1
    mata: _cs434_status("`con'", "(results collapsed to 3 unique pid values in frame fzlonger1; data in memory unchanged)")
    assert `statok' == 1
    capture erase "`con'"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: T12 status lines wrap at word boundaries"
}
else {
    local ++fail_count
    display as error "  FAIL: T12 status lines wrap at word boundaries (error `=_rc')"
    capture log close cs434
    capture set linesize `_ls0'
    capture frame drop fzlonger1
}

**# T13
local ++test_count
capture noisily {
    local _ls0 = c(linesize)
    local con "`_tmp'`_tag'_t13.log"
    local f1 "`_tmp'`_tag'_a{c 45}b.dta"
    local f2 "`_tmp'`_tag'_c{p_end}d.csv"
    capture erase "`f1'"
    capture erase "`f2'"
    _cs434_data
    set linesize 255
    log using "`con'", name(cs434) text replace
    preserve
    codescan dx1, define(dm "E11") id(pid) collapse saving("`f1'", replace) export("`f2'", replace)
    restore
    log close cs434
    set linesize `_ls0'
    confirm file "`f1'"
    confirm file "`f2'"
    local hit1 0
    local hit2 0
    tempname fh
    file open `fh' using "`con'", read text
    file read `fh' line
    while r(eof) == 0 {
        if `"`macval(line)'"' == `"(dataset saved to `f1')"' local hit1 1
        if `"`macval(line)'"' == `"(results exported to `f2')"' local hit2 1
        file read `fh' line
    }
    file close `fh'
    assert `hit1' == 1
    assert `hit2' == 1
    capture erase "`f1'"
    capture erase "`f2'"
    capture erase "`con'"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: T13 status-line paths print literally"
}
else {
    local ++fail_count
    display as error "  FAIL: T13 status-line paths print literally (error `=_rc')"
    capture log close cs434
    capture set linesize `_ls0'
}

**# Summary
_codescan_qa_restore "`_qa_owner'"
_codescan_qa_publish "test_codescan_v434" `test_count' `pass_count' `fail_count'
display as result "RESULT: test_codescan_v434 tests=`test_count' pass=`pass_count' fail=`fail_count'"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}

display as result "ALL TESTS PASSED"
