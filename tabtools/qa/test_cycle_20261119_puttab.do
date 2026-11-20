* test_cycle_20261119_puttab.do - puttab smallcells() review cycle 2026-11-19
* F1: a counts() column that copies another count (a fraction() denominator,
*     a numerator, or a fraction's denom-num) is printed raw where the
*     original is masked; refused r(459) in full mode.
* F2: withhold() keyed by a fraction() denominator blanks the listed cells
*     wherever any part of the fraction is masked.

clear all
set more off
set varabbrev off
version 17.0

capture log close _cyc
log using "test_cycle_20261119_puttab.log", replace text name(_cyc)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

local test_count = 0
local pass_count = 0
local fail_count = 0

* r(text): the whole file, lines joined by "|"
capture program drop _cyc_slurp
program define _cyc_slurp, rclass
    args f
    tempname fh
    local out ""
    file open `fh' using `"`f'"', read text
    file read `fh' line
    while r(eof) == 0 {
        local out `"`out'|`macval(line)'"'
        file read `fh' line
    }
    file close `fh'
    return local text `"`macval(out)'"'
end

* run a puttab call under a private log; r(rc) and r(log) (the log text)
capture program drop _cyc_run
program define _cyc_run, rclass
    gettoken cmd 0 : 0
    tempfile lg
    local ls = c(linesize)
    capture log close _cycinner
    quietly log using `"`lg'"', text replace name(_cycinner)
    * one error message per log line, not wrapped at 80 columns
    set linesize 255
    capture noisily `cmd'
    local rc = _rc
    set linesize `ls'
    quietly log close _cycinner
    _cyc_slurp `"`lg'"'
    local t `"`r(text)'"'
    return local log `"`macval(t)'"'
    return scalar rc = `rc'
end

**# F1: copies of a count

**## F1a: a copy of a fraction() denominator is refused, nothing written
local ++test_count
capture noisily {
    clear
    input str6 lab e1 n1 e0 n0
    "a" 4 8 20 50
    "b" 30 60 25 60
    end
    generate n1c = n1
    local csv "`output_dir'/cyc_f1a.csv"
    capture erase "`csv'"
    _cyc_run `"puttab lab e1 n1 n1c e0 n0, csv("`csv'") counts(e1 n1 n1c e0 n0) fraction(e1/n1 e0/n0) smallcells(5)"'
    assert r(rc) == 459
    assert strpos(`"`r(log)'"', "n1c equals n1 in every exported row") > 0
    assert strpos(`"`r(log)'"', "leave n1c out of the table") > 0
    confirm new file "`csv'"
}
local _r = _rc
if `_r' == 0 local ++pass_count
else local ++fail_count
display cond(`_r' == 0, "  PASS", "  FAIL") ": F1a copy of a fraction() denominator refused (rc=`_r')"

**## F1b: a copy of a numerator printed where the numerator is >=k
local ++test_count
capture noisily {
    clear
    input str6 lab e1 n1
    "a" 38 40
    "b" 30 60
    end
    generate e1c = e1
    local csv "`output_dir'/cyc_f1b.csv"
    capture erase "`csv'"
    * the fraction alone masks the numerator (den-num = 2 is small)
    puttab lab e1 n1, csv("`csv'") counts(e1 n1) fraction(e1/n1) smallcells(5)
    _cyc_slurp "`csv'"
    assert strpos(`"`r(text)'"', "|a,≥5/40") > 0
    erase "`csv'"
    _cyc_run `"puttab lab e1 n1 e1c, csv("`csv'") counts(e1 n1 e1c) fraction(e1/n1) smallcells(5)"'
    assert r(rc) == 459
    assert strpos(`"`r(log)'"', "e1c equals e1 in every exported row") > 0
    confirm new file "`csv'"
}
local _r = _rc
if `_r' == 0 local ++pass_count
else local ++fail_count
display cond(`_r' == 0, "  PASS", "  FAIL") ": F1b copy of a complementary-masked numerator refused (rc=`_r')"

**## F1c: a printed denom-num (non-events) column beside a masked numerator
local ++test_count
capture noisily {
    clear
    input str6 lab e1 n1 ne1
    "a" 2 20 18
    "b" 12 40 28
    end
    local csv "`output_dir'/cyc_f1c.csv"
    capture erase "`csv'"
    _cyc_run `"puttab lab e1 n1 ne1, csv("`csv'") counts(e1 n1 ne1) fraction(e1/n1) smallcells(5)"'
    assert r(rc) == 459
    assert strpos(`"`r(log)'"', "ne1 equals n1 - e1 in every exported row") > 0
    assert strpos(`"`r(log)'"', "masked e1/n1 in exported row 1") > 0
    confirm new file "`csv'"
}
local _r = _rc
if `_r' == 0 local ++pass_count
else local ++fail_count
display cond(`_r' == 0, "  PASS", "  FAIL") ": F1c copy of denom-num refused (rc=`_r')"

**## F1d: no false refusal: copies with nothing masked, or masked alike
local ++test_count
capture noisily {
    clear
    input str6 lab e1 n1 x
    "a" 10 30 3
    "b" 12 40 7
    end
    generate n1c = n1
    generate xc = x
    local csv "`output_dir'/cyc_f1d.csv"
    capture erase "`csv'"
    puttab lab e1 n1 n1c x xc, csv("`csv'") counts(e1 n1 n1c x xc) fraction(e1/n1) smallcells(5)
    _cyc_slurp "`csv'"
    assert `"`r(text)'"' == "|lab,e1,n1c,x,xc|a,10/30,30,<5,<5|b,12/40,40,7,7"
}
local _r = _rc
if `_r' == 0 local ++pass_count
else local ++fail_count
display cond(`_r' == 0, "  PASS", "  FAIL") ": F1d unmasked or identically masked copies still print (rc=`_r')"

**## F1e: primary mode protects printed counts alone, so a copy is accepted
local ++test_count
capture noisily {
    clear
    input str6 lab e1 n1
    "a" 4 8
    "b" 30 60
    end
    generate n1c = n1
    local csv "`output_dir'/cyc_f1e.csv"
    capture erase "`csv'"
    puttab lab e1 n1 n1c, csv("`csv'") counts(e1 n1 n1c) fraction(e1/n1) smallcells(5, primary)
    _cyc_slurp "`csv'"
    assert `"`r(text)'"' == "|lab,e1,n1c|a,<5/8,8|b,30/60,60"
}
local _r = _rc
if `_r' == 0 local ++pass_count
else local ++fail_count
display cond(`_r' == 0, "  PASS", "  FAIL") ": F1e primary mode unchanged for copies (rc=`_r')"

**## F1f: equal fraction() denominators (a matched design) are not copies
local ++test_count
capture noisily {
    clear
    input str6 lab e1 n1 e0 n0
    "a" 4 8 3 8
    "b" 30 60 25 60
    end
    local csv "`output_dir'/cyc_f1f.csv"
    capture erase "`csv'"
    puttab lab e1 n1 e0 n0, csv("`csv'") counts(e1 n1 e0 n0) fraction(e1/n1 e0/n0) smallcells(5)
    _cyc_slurp "`csv'"
    assert `"`r(text)'"' == "|lab,e1,e0|a,<5/≥5,<5/8|b,30/60,25/60"
}
local _r = _rc
if `_r' == 0 local ++pass_count
else local ++fail_count
display cond(`_r' == 0, "  PASS", "  FAIL") ": F1f equal denominators of two fractions still print (rc=`_r')"

**# F2: withhold() keyed by a fraction() denominator

**## F2a: denominator key blanks the rate where the numerator is masked
local ++test_count
capture noisily {
    clear
    input str12 lab e1 n1 double rate
    "a" 2 20 .1
    "b" 12 40 .3
    "Total" 14 60 .2
    end
    local csv "`output_dir'/cyc_f2a.csv"
    capture erase "`csv'"
    puttab lab e1 n1 rate, csv("`csv'") counts(e1 n1) fraction(e1/n1) smallcells(5) withhold(n1: rate)
    _cyc_slurp "`csv'"
    assert `"`r(text)'"' == "|lab,e1,rate|a,<5/20,|b,12/40,0.30|Total,14/60,0.20"
}
local _r = _rc
if `_r' == 0 local ++pass_count
else local ++fail_count
display cond(`_r' == 0, "  PASS", "  FAIL") ": F2a withhold(denominator: rate) blanks the masked row only (rc=`_r')"

**## F2b: denominator key, masked denom-num (>=k numerator) also blanks
local ++test_count
capture noisily {
    clear
    input str12 lab e1 n1 double rate
    "a" 38 40 .95
    "b" 12 40 .3
    end
    local csv "`output_dir'/cyc_f2b.csv"
    capture erase "`csv'"
    puttab lab e1 n1 rate, csv("`csv'") counts(e1 n1) fraction(e1/n1) smallcells(5) withhold(n1: rate)
    _cyc_slurp "`csv'"
    assert `"`r(text)'"' == "|lab,e1,rate|a,≥5/40,|b,12/40,0.30"
}
local _r = _rc
if `_r' == 0 local ++pass_count
else local ++fail_count
display cond(`_r' == 0, "  PASS", "  FAIL") ": F2b withhold(denominator: rate) covers a masked denom-num (rc=`_r')"

**## F2c: numerator key unchanged, and the two keys agree
local ++test_count
capture noisily {
    clear
    input str12 lab e1 n1 double rate
    "a" 2 20 .1
    "b" 12 40 .3
    "Total" 14 60 .2
    end
    local csv "`output_dir'/cyc_f2c.csv"
    capture erase "`csv'"
    puttab lab e1 n1 rate, csv("`csv'") counts(e1 n1) fraction(e1/n1) smallcells(5) withhold(e1: rate)
    _cyc_slurp "`csv'"
    assert `"`r(text)'"' == "|lab,e1,rate|a,<5/20,|b,12/40,0.30|Total,14/60,0.20"
}
local _r = _rc
if `_r' == 0 local ++pass_count
else local ++fail_count
display cond(`_r' == 0, "  PASS", "  FAIL") ": F2c withhold(numerator: rate) unchanged (rc=`_r')"

display as result "puttab cycle 2026-11-19 QA summary: `pass_count' passed, `fail_count' failed"
local _tc = `pass_count' + `fail_count'
display "RESULT: test_cycle_20261119_puttab tests=`_tc' pass=`pass_count' fail=`fail_count'"
log close _cyc
if `fail_count' > 0 exit 1
