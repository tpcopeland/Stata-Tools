* test_bugfix_2026_10_06_g.do - stratetab/ratetab: one tie rule for every printed number
*
* Bug (2026-10-06 report): events, person-years and the rate/CI cells were
* rounded by two different rules. pydigits(0) used round() (half away from
* zero: 123.5 -> 124) and the rate/CI cells used round(x, 10^-d), but events
* and pydigits(1..10) went straight through string(x, "%24.nfc"), which rounds
* an exact binary tie to even (string(2.25, "%9.1f") = "2.2",
* string(0.25, "%9.1f") = "0.2"). One table therefore printed person-years
* 2.2 beside a rate 2.3 for the same 2.25. Fixed: events, person-years and a
* cformat() fixed format are rounded with round() first, so the rule is half
* upward (round()) everywhere; every value here is nonnegative.
*
* Oracles: hand-built strate-format files whose _D, _Y, _Rate, _Lower, _Upper
* are exactly representable ties (x.25, x.5, x.75) and non-ties (0.35, 1.15),
* with the printed text written out by hand; console text, frame cells and
* the CSV line are each read back. Run from tabtools/qa.

clear all
version 17.0
set more off
set varabbrev off

capture log close _bfg
log using "test_bugfix_2026_10_06_g.log", replace text name(_bfg)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear

local pass_count = 0
local fail_count = 0
local fx "`output_dir'/bfg_fx"
local fe "`output_dir'/bfg_fe"

* Five levels: Y = 2.25, 0.25, 123.5, 1234567.5 and the non-tie 0.35. The
* rate equals Y; the limits are other ties and non-ties (1.15). Events are
* x.5 ties in the first file and x.25/x.75 ties in the second.
capture program drop _bfg_file
program define _bfg_file
    version 17.0
    args file kind
    clear
    quietly set obs 5
    gen byte arm = _n
    gen double _Y = cond(_n == 1, 2.25, cond(_n == 2, 0.25, cond(_n == 3, 123.5, cond(_n == 4, 1234567.5, 0.35))))
    if "`kind'" == "x" gen double _D = cond(_n == 1, 2.5, cond(_n == 2, 0.5, cond(_n == 3, 1.5, cond(_n == 4, 3.5, 7))))
    else gen double _D = cond(_n == 1, 2.25, cond(_n == 2, 0.25, cond(_n == 3, 0.75, cond(_n == 4, 1.25, 7))))
    gen double _Rate = _Y
    gen double _Lower = cond(_n == 1, 0.25, cond(_n == 2, 2.25, cond(_n == 3, 0.35, cond(_n == 4, 1234567.5, 2.5))))
    gen double _Upper = cond(_n == 1, 123.5, cond(_n == 2, 0.75, cond(_n == 3, 2.25, cond(_n == 4, 0.25, 1.15))))
    quietly save "`file'", replace
end

* Assert that exactly one frame row has c1 == lab and the three cells below
capture program drop _bfg_row
program define _bfg_row, rclass
    version 17.0
    args fr lab e2 e3 e4
    frame `fr': quietly count if strtrim(c1) == "`lab'" & c2 == `"`e2'"' & c3 == `"`e3'"' & c4 == `"`e4'"'
    local n = r(N)
    if `n' != 1 {
        display as error `"row `lab' of `fr': expected [`e2'] [`e3'] [`e4']"'
        frame `fr': list c1 c2 c3 c4 if strtrim(c1) == "`lab'", noobs
        exit 9
    }
    return scalar n = `n'
end

* Number of lines of a text file matching a regular expression into r(n)
capture program drop _bfg_grep
program define _bfg_grep, rclass
    version 17.0
    args file rx
    tempname fh
    local n = 0
    file open `fh' using `"`file'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if ustrregexm(`"`macval(line)'"', `"`rx'"') local ++n
        file read `fh' line
    }
    file close `fh'
    return scalar n = `n'
end

* Exact line of a CSV into r(n)
capture program drop _bfg_csvline
program define _bfg_csvline, rclass
    version 17.0
    args file want
    tempname fh
    local n = 0
    file open `fh' using `"`file'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if `"`macval(line)'"' == `"`want'"' local ++n
        file read `fh' line
    }
    file close `fh'
    return scalar n = `n'
end

_bfg_file "`fx'" x
_bfg_file "`fe'" e

**# G1: pydigits(0) person-years and digits(0) rate/CI, half upward (round())
capture noisily {
    stratetab, using("`fx'") outcomes(1) ratescale(1) level(95) pydigits(0) digits(0) frame(g1, replace)
    _bfg_row g1 1 "3" "2" "2 (0, 124)"
    assert r(n) == 1
    _bfg_row g1 2 "1" "0" "0 (2, 1)"
    assert r(n) == 1
    _bfg_row g1 3 "2" "124" "124 (0, 2)"
    assert r(n) == 1
    _bfg_row g1 4 "4" "1,234,568" "1234568 (1234568, 0)"
    assert r(n) == 1
    _bfg_row g1 5 "7" "0" "0 (3, 1)"
    assert r(n) == 1
    frame drop g1
}
if _rc == 0 {
    display as result "  PASS: G1 pydigits(0)/digits(0) ties: events 2.5->3, 0.5->1, Y 123.5->124"
    local ++pass_count
}
else {
    display as error "  FAIL: G1 digits(0) tie rule (rc=`=_rc')"
    local ++fail_count
}

**# G2: pydigits(1) and digits(1): person-years agree with the rate column
capture noisily {
    stratetab, using("`fx'") outcomes(1) ratescale(1) level(95) pydigits(1) digits(1) frame(g2, replace)
    _bfg_row g2 1 "3" "2.3" "2.3 (0.3, 123.5)"
    assert r(n) == 1
    _bfg_row g2 2 "1" "0.3" "0.3 (2.3, 0.8)"
    assert r(n) == 1
    _bfg_row g2 3 "2" "123.5" "123.5 (0.3, 2.3)"
    assert r(n) == 1
    _bfg_row g2 4 "4" "1,234,567.5" "1234567.5 (1234567.5, 0.3)"
    assert r(n) == 1
    _bfg_row g2 5 "7" "0.3" "0.3 (2.5, 1.1)"
    assert r(n) == 1
    frame drop g2
}
if _rc == 0 {
    display as result "  PASS: G2 pydigits(1)/digits(1): 2.25->2.3, 0.25->0.3; non-tie 0.35->0.3, 1.15->1.1"
    local ++pass_count
}
else {
    display as error "  FAIL: G2 digits(1) tie rule (rc=`=_rc')"
    local ++fail_count
}

**# G3: pydigits(2) and digits(2) print the exact values, trailing zeros kept
capture noisily {
    stratetab, using("`fx'") outcomes(1) ratescale(1) level(95) pydigits(2) digits(2) frame(g3, replace)
    _bfg_row g3 1 "3" "2.25" "2.25 (0.25, 123.50)"
    assert r(n) == 1
    _bfg_row g3 2 "1" "0.25" "0.25 (2.25, 0.75)"
    assert r(n) == 1
    _bfg_row g3 3 "2" "123.50" "123.50 (0.35, 2.25)"
    assert r(n) == 1
    _bfg_row g3 4 "4" "1,234,567.50" "1234567.50 (1234567.50, 0.25)"
    assert r(n) == 1
    _bfg_row g3 5 "7" "0.35" "0.35 (2.50, 1.15)"
    assert r(n) == 1
    frame drop g3
}
if _rc == 0 {
    display as result "  PASS: G3 pydigits(2)/digits(2) exact, no change"
    local ++pass_count
}
else {
    display as error "  FAIL: G3 digits(2) (rc=`=_rc')"
    local ++fail_count
}

**# G4: eventdigits(1) and eventdigits(0) on x.25/x.75 events
capture noisily {
    stratetab, using("`fe'") outcomes(1) ratescale(1) level(95) digits(0) eventdigits(1) frame(g4a, replace)
    _bfg_row g4a 1 "2.3" "2" "2 (0, 124)"
    assert r(n) == 1
    _bfg_row g4a 2 "0.3" "0" "0 (2, 1)"
    assert r(n) == 1
    _bfg_row g4a 3 "0.8" "124" "124 (0, 2)"
    assert r(n) == 1
    _bfg_row g4a 4 "1.3" "1,234,568" "1234568 (1234568, 0)"
    assert r(n) == 1
    _bfg_row g4a 5 "7.0" "0" "0 (3, 1)"
    assert r(n) == 1
    stratetab, using("`fe'") outcomes(1) ratescale(1) level(95) digits(0) eventdigits(2) frame(g4b, replace)
    _bfg_row g4b 1 "2.25" "2" "2 (0, 124)"
    assert r(n) == 1
    _bfg_row g4b 3 "0.75" "124" "124 (0, 2)"
    assert r(n) == 1
    frame drop g4a
    frame drop g4b
}
if _rc == 0 {
    display as result "  PASS: G4 eventdigits(1): 2.25->2.3, 0.25->0.3, 1.25->1.3; eventdigits(2) exact"
    local ++pass_count
}
else {
    display as error "  FAIL: G4 eventdigits tie rule (rc=`=_rc')"
    local ++fail_count
}

**# G5: the same cells in the console table and in the CSV line
capture noisily {
    local lg "`output_dir'/bfg_g5.log"
    local csv "`output_dir'/bfg_g5.csv"
    capture erase "`csv'"
    local ls0 = c(linesize)
    set linesize 255
    capture log close _bfg5
    log using "`lg'", replace text name(_bfg5)
    stratetab, using("`fx'") outcomes(1) ratescale(1) level(95) pydigits(1) digits(1) csv("`csv'")
    log close _bfg5
    set linesize `ls0'
    _bfg_grep "`lg'" "^ *\| +2 +1 +0\.3 +0\.3 \(2\.3, 0\.8\) +\|$"
    assert r(n) == 1
    _bfg_grep "`lg'" "^ *\| +1 +3 +2\.3 +2\.3 \(0\.3, 123\.5\) +\|$"
    assert r(n) == 1
    _bfg_csvline "`csv'" `"   1,3,2.3,"2.3 (0.3, 123.5)""'
    assert r(n) == 1
    _bfg_csvline "`csv'" `"   2,1,0.3,"0.3 (2.3, 0.8)""'
    assert r(n) == 1
    _bfg_csvline "`csv'" `"   3,2,123.5,"123.5 (0.3, 2.3)""'
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: G5 console and CSV carry the same tie-rounded text"
    local ++pass_count
}
else {
    display as error "  FAIL: G5 console/CSV text (rc=`=_rc')"
    local ++fail_count
}
capture log close _bfg5
set linesize 80

**# G6: cformat() fixed formats round ties the same way; g format untouched
capture noisily {
    stratetab, using("`fx'") outcomes(1) ratescale(1) level(95) pydigits(1) cformat(%14.1fc) frame(g6a, replace)
    _bfg_row g6a 1 "3" "2.3" "2.3 (0.3, 123.5)"
    assert r(n) == 1
    _bfg_row g6a 2 "1" "0.3" "0.3 (2.3, 0.8)"
    assert r(n) == 1
    _bfg_row g6a 4 "4" "1,234,567.5" "1,234,567.5 (1,234,567.5, 0.3)"
    assert r(n) == 1
    stratetab, using("`fx'") outcomes(1) ratescale(1) level(95) pydigits(1) cformat(%9.2f) frame(g6b, replace)
    _bfg_row g6b 3 "2" "123.5" "123.50 (0.35, 2.25)"
    assert r(n) == 1
    * a significant-digit format keeps string()'s own rule: 2.25 at 3 digits is 2.25
    stratetab, using("`fx'") outcomes(1) ratescale(1) level(95) pydigits(1) cformat(%9.3g) frame(g6c, replace)
    _bfg_row g6c 1 "3" "2.3" "2.25 (.25, 124)"
    assert r(n) == 1
    frame drop g6a
    frame drop g6b
    frame drop g6c
}
if _rc == 0 {
    display as result "  PASS: G6 cformat(%14.1fc) ties 2.25->2.3; %9.2f exact; %9.3g unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: G6 cformat tie rule (rc=`=_rc')"
    local ++fail_count
}

**# G7: ratetab prints the tie-rounded person-time; r() and saving() keep 2.25
capture noisily {
    clear
    quietly set obs 4
    gen byte g = 1 + (_n > 2)
    gen long ev = 1
    gen double py = cond(_n <= 2, 1.125, 0.125)
    local sv "`output_dir'/bfg_g7.dta"
    ratetab g, events(ev) exposure(py) per(1) pydigits(1) digits(1) frame(g7, replace) saving("`sv'", replace)
    matrix E = r(estimates)
    assert E[1, 5] == 2.25 & E[2, 5] == 0.25
    _bfg_row g7 1 "2" "2.3" "0.9 (0.1, 3.2)"
    assert r(n) == 1
    _bfg_row g7 2 "2" "0.3" "8.0 (1.0, 28.9)"
    assert r(n) == 1
    frame drop g7
    use "`sv'", clear
    assert persontime[1] == 2.25 & persontime[2] == 0.25
    assert abs(rate[1] - 2 / 2.25) < 1e-12 & rate[2] == 8
}
if _rc == 0 {
    display as result "  PASS: G7 ratetab 2.25 -> 2.3, 0.25 -> 0.3 printed; r(estimates) and saving() unrounded"
    local ++pass_count
}
else {
    display as error "  FAIL: G7 ratetab person-time tie / stored values (rc=`=_rc')"
    local ++fail_count
}

capture erase "`fx'.dta"
capture erase "`fe'.dta"

local _tests = `pass_count' + `fail_count'
display "RESULT: test_bugfix_2026_10_06_g tests=`_tests' pass=`pass_count' fail=`fail_count'"
capture log close _bfg
if `fail_count' > 0 exit 1
