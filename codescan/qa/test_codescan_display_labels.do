* test_codescan_display_labels.do - label text displays literally (4.3.3)
*
* Covers:
*   T1:    SMCL markup in label() text prints as typed in the console table
*          and the detail table (4.3.2 rendered {bf:Bold} as bold "Bold");
*          the variable label still holds the raw text
*   T2:    the 21-column console cut counts visible characters, not markup:
*          a 24-character label prints its first 20 characters plus "~"
*   T3:    graph bar labels show the markup as typed (4.3.2 drew bold text)
*   T4:    _codescan_smcl_literal escapes every brace in one pass, leaves
*          other bytes (multibyte UTF-8 included) unchanged, and an escaped
*          label renders back to the original text in a text log
*   T6:    a session holding the older Mata library (no escape helper)
*          reloads _codescan_definitions.ado instead of failing
*   T5:    help Example 4 glosses E116 with Stata's own ICD-10 description
*          of E11.6, not the hypoglycaemia code E16.2; the label() entry
*          documents compound-quoted labels
*
* Expected console rows are compared as whole lines read from a text log, so
* an interpreted directive (which disappears from the log) fails the match.

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
local _tag = substr("`_stem'", strrpos("`_stem'", "/") + 1, .) + "_csdl"

capture program drop _csdl_data
program define _csdl_data
    clear
    quietly set obs 4
    generate str6 dx1 = cond(_n == 1, "E110", cond(_n == 2, "Z00", cond(_n == 3, "E119", "I10")))
end

* 1 if file `1' has a line exactly equal to global CSDL_LINE, else 0.
capture program drop _csdl_has_line
program define _csdl_has_line, rclass
    args fn
    tempname fh
    local found 0
    file open `fh' using "`fn'", read text
    file read `fh' line
    while r(eof) == 0 {
        mata: st_local("hit", strofreal(st_local("line") == st_global("CSDL_LINE")))
        if `hit' local found 1
        file read `fh' line
    }
    file close `fh'
    return scalar found = `found'
end


**# T1: console and detail rows carry SMCL markup as typed

local ++test_count
capture noisily {
    _csdl_data
    * want1 = "{bf:Bold} d {"   want2 = "a}b{c -(}"
    mata: st_global("CSDL_W1", char(123) + "bf:Bold" + char(125) + " d " + char(123))
    mata: st_global("CSDL_W2", "a" + char(125) + "b" + char(123) + "c -(" + char(125))
    mata: st_local("l1", st_global("CSDL_W1"))
    mata: st_local("l2", st_global("CSDL_W2"))
    local con "`_tmp'`_tag'_t1.log"
    log using "`con'", name(csdl) text replace
    codescan dx1, define(dm2 "E11" | htn "I10") ///
        label(dm2 `"`macval(l1)'"' \ htn `"`macval(l2)'"') detail
    log close csdl
    * Raw text in the data sink is unchanged.
    mata: assert(st_varlabel("dm2") == st_global("CSDL_W1"))
    mata: assert(st_varlabel("htn") == st_global("CSDL_W2"))
    * Console rows: label padded to column 24, the count to column 32, the
    * prevalence from column 36. Oracle: rows 1
    * and 3 carry E11*, row 4 carries I10, so 2/4 = 50.0% and 1/4 = 25.0%.
    mata: st_global("CSDL_LINE", sprintf("  %-21s%9s   %9s%%", st_global("CSDL_W1"), "2", "50.0"))
    _csdl_has_line "`con'"
    assert r(found) == 1
    mata: st_global("CSDL_LINE", sprintf("  %-21s%9s   %9s%%", st_global("CSDL_W2"), "1", "25.0"))
    _csdl_has_line "`con'"
    assert r(found) == 1
    * Detail rows.
    mata: st_global("CSDL_LINE", "  " + st_global("CSDL_W1") + ": 2 in dx1")
    _csdl_has_line "`con'"
    assert r(found) == 1
    mata: st_global("CSDL_LINE", "  " + st_global("CSDL_W2") + ": 1 in dx1")
    _csdl_has_line "`con'"
    assert r(found) == 1
    capture erase "`con'"
}
if _rc == 0 {
    display as result "  PASS: T1 - console and detail show SMCL label text as typed"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - SMCL label text in console/detail (error `=_rc')"
    local ++fail_count
    capture log close csdl
}


**# T2: console truncation counts visible characters

local ++test_count
capture noisily {
    _csdl_data
    * 25 characters, a complete directive inside the first 20:
    * "{it:AB} CDEFGHIJKLMNOPQRS". 4.3.2 cut the raw bytes and then rendered
    * the directive, printing "AB CDEFGHIJKLM~" out of alignment.
    mata: st_global("CSDL_W1", char(123) + "it:AB" + char(125) + " CDEFGHIJKLMNOPQRS")
    mata: assert(strlen(st_global("CSDL_W1")) == 25)
    mata: st_local("l1", st_global("CSDL_W1"))
    local con "`_tmp'`_tag'_t2.log"
    log using "`con'", name(csdl) text replace
    codescan dx1, define(dm2 "E11") label(dm2 `"`macval(l1)'"')
    log close csdl
    mata: st_global("CSDL_LINE", sprintf("  %-21s%9s   %9s%%", substr(st_global("CSDL_W1"), 1, 20) + "~", "2", "50.0"))
    _csdl_has_line "`con'"
    assert r(found) == 1
    capture erase "`con'"
}
if _rc == 0 {
    display as result "  PASS: T2 - truncation cuts the visible text, not markup"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - console truncation of a markup label (error `=_rc')"
    local ++fail_count
    capture log close csdl
}


**# T3: graph bar labels show the markup as typed

local ++test_count
capture noisily {
    _csdl_data
    mata: st_global("CSDL_W1", char(123) + "bf:Bold" + char(125) + " d " + char(123))
    mata: st_local("l1", st_global("CSDL_W1"))
    local svg "`_tmp'`_tag'_t3.svg"
    codescan dx1, define(dm2 "E11") label(dm2 `"`macval(l1)'"') graph
    graph export "`svg'", as(svg) replace
    graph drop _all
    * The bar label is one plain <text> element holding the literal text. An
    * interpreted {bf:} splits it into <tspan>s with the braces gone.
    tempname fh
    local found 0
    file open `fh' using "`svg'", read text
    file read `fh' line
    while r(eof) == 0 {
        mata: st_local("hit", strofreal(strpos(st_local("line"), ">" + st_global("CSDL_W1") + "</text>") > 0))
        if `hit' local found 1
        file read `fh' line
    }
    file close `fh'
    assert `found' == 1
    capture erase "`svg'"
}
if _rc == 0 {
    display as result "  PASS: T3 - graph bar label shows SMCL text as typed"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - SMCL label text in graph (error `=_rc')"
    local ++fail_count
}


**# T4: the escape helper, byte for byte

local ++test_count
capture noisily {
    * Load the bundled helper the way codescan does (a scan call autoloads it).
    _csdl_data
    quietly codescan dx1, define(dm2 "E11")
    mata: assert(_codescan_smcl_literal("") == "")
    mata: p = "plain " + char(36) + "x " + char(96) + "y" + char(39) + " (a)"
    mata: assert(_codescan_smcl_literal(p) == p)
    * a{b}c{c -(}  ->  a{c -(}b{c )-}c{c -(}c -({c )-}
    mata: s = "a" + char(123) + "b" + char(125) + "c" + char(123) + "c -(" + char(125)
    mata: want = "a{c -(}b{c )-}c{c -(}c -({c )-}"
    mata: assert(_codescan_smcl_literal(s) == want)
    * Multibyte text passes through; only the braces change.
    mata: u = uchar(197) + "lder " + char(123) + "x" + char(125)
    mata: assert(_codescan_smcl_literal(u) == uchar(197) + "lder {c -(}x{c )-}")
    * Rendering the escaped text gives back the original.
    local con "`_tmp'`_tag'_t4.log"
    mata: st_local("esc", _codescan_smcl_literal(s))
    log using "`con'", name(csdl) text replace
    display as text `"`macval(esc)'"'
    log close csdl
    mata: st_global("CSDL_LINE", s)
    _csdl_has_line "`con'"
    assert r(found) == 1
    capture erase "`con'"
    mata: mata drop s want u p
}
if _rc == 0 {
    display as result "  PASS: T4 - escape helper is exact and renders back to the input"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - escape helper (error `=_rc')"
    local ++fail_count
    capture log close csdl
    capture mata: mata drop s want u p
}


**# T5: help Example 4 gloss matches Stata's ICD-10 table

local ++test_count
capture noisily {
    clear
    quietly set obs 2
    generate str6 code = cond(_n == 1, "E11.6", "E16.2")
    icd10 generate desc = code, description
    local d116 = desc[1]
    local d162 = desc[2]
    * Stata 17: "E11.6 Type 2 diabetes mellitus: With other specified complications"
    assert strpos(lower("`d116'"), "with other specified complications") > 0
    assert strpos(lower("`d162'"), "hypoglycaemia") > 0
    findfile codescan.sthlp
    * Scan the help in Mata: the compound-quote example holds backticks that
    * a Stata-level string would hand to the macro processor.
    mata: L = cat(st_global("r(fn)"))
    mata: g = select(L, strpos(L, "{cmd:E116} (") :== 1)
    mata: assert(rows(g) == 1)
    mata: assert(strpos(strlower(g[1]), "hypoglyc") == 0)
    mata: assert(strpos(strlower(g[1]), "type 2 diabetes mellitus with other specified complications") > 0)
    mata: want = "{cmd:label(dm2 " + char(96) + char(34) + char(96) + "lbl" + char(39) + char(34) + char(39) + ")}"
    mata: assert(sum(strpos(L, want) :> 0) >= 1)
    mata: mata drop L g want
}
if _rc == 0 {
    display as result "  PASS: T5 - Example 4 E116 gloss matches icd10; label() macro guidance present"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - help Example 4 gloss / label() guidance (error `=_rc')"
    local ++fail_count
}


**# T6: a session holding the older Mata library reloads the new helper

local ++test_count
capture noisily {
    * A session that loaded 4.3.2 has every other codescan Mata function but
    * not _codescan_smcl_literal(); the call must still reload the helper.
    * Route test only: the loader's mata-which probes return 111 for any
    * workspace function, so _codescan_definitions.ado is re-run on every
    * call and this cell cannot isolate the new probe line.
    _csdl_data
    quietly codescan dx1, define(dm2 "E11")
    drop dm2
    capture mata: mata drop _codescan_smcl_literal()
    mata: st_global("CSDL_W1", char(123) + "bf:Stale" + char(125))
    mata: st_local("l1", st_global("CSDL_W1"))
    local con "`_tmp'`_tag'_t6.log"
    log using "`con'", name(csdl) text replace
    codescan dx1, define(dm2 "E11") label(dm2 `"`macval(l1)'"')
    log close csdl
    mata: st_global("CSDL_LINE", sprintf("  %-21s%9s   %9s%%", st_global("CSDL_W1"), "2", "50.0"))
    _csdl_has_line "`con'"
    assert r(found) == 1
    capture erase "`con'"
}
if _rc == 0 {
    display as result "  PASS: T6 - stale Mata session reloads the escape helper"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 - helper reload in a stale session (error `=_rc')"
    local ++fail_count
    capture log close csdl
}


**# Summary

macro drop CSDL_W1 CSDL_W2 CSDL_LINE
assert "`c(varabbrev)'" == "`_qa_va0'"
_codescan_qa_restore "`_qa_owner'"
_codescan_qa_publish "test_codescan_display_labels" `test_count' `pass_count' `fail_count'
display as result "RESULT: test_codescan_display_labels tests=`test_count' pass=`pass_count' fail=`fail_count'"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}

display as result "ALL TESTS PASSED"
