clear all
set more off
version 16.0
* wide log lines so scanned console text is never wrapped
set linesize 255

* test_datacheck_gates.do - datacheck rule(), stat(), binary(), the PASS line,
* r(singlelevel_vars), maskrare extremes, quietly silence, and frame-target
* violations()/makespec().  Expected values are hand-computed from the
* constructed fixtures; console contracts are checked by scanning a text log.

* === Bootstrap: targeted local reinstall ===
local qa_dir  "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
discard

* === Tally helper ===
global TC 0
global PASS 0
global FAIL 0
capture program drop _dg
program define _dg
    args rc msg
    global TC = $TC + 1
    if `rc' == 0 {
        display as result "  PASS: `msg'"
        global PASS = $PASS + 1
    }
    else {
        display as error "  FAIL (rc=`rc'): `msg'"
        global FAIL = $FAIL + 1
    }
end

* === Log scanner: count lines containing a literal string ===
capture program drop _dg_count
program define _dg_count, rclass
    args file needle
    tempname fh
    local n = 0
    file open `fh' using `"`file'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', `"`needle'"') local ++n
        file read `fh' line
    }
    file close `fh'
    return scalar n = `n'
end

* === Lines printed between a command echo and the next prompt ===
capture program drop _dg_between
program define _dg_between, rclass
    args file start
    tempname fh
    local inside = 0
    local n = 0
    local nonblank = 0
    file open `fh' using `"`file'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if `inside' & substr(`"`macval(line)'"', 1, 2) == ". " local inside = 0
        if `inside' {
            local ++n
            if strtrim(`"`macval(line)'"') != "" local ++nonblank
        }
        if strpos(`"`macval(line)'"', `"`start'"') == 1 local inside = 1
        file read `fh' line
    }
    file close `fh'
    return scalar n = `n'
    return scalar nonblank = `nonblank'
end

capture program drop _dg_flags
program define _dg_flags
    clear
    set obs 20
    gen long id = _n
    gen byte flag = 1 if _n <= 3
    gen byte k = 7
    gen double x = _n
    gen str3 s = cond(_n <= 10, "a", "b")
end

tempfile lg

* ============================================================
* 1. quietly datacheck prints nothing (plan item 6a)
* ============================================================
_dg_flags
capture log close _dgq
log using "`lg'", text replace name(_dgq)
quietly datacheck flag k x s, rare(5) outliers(1)
log close _dgq
capture {
    _dg_between "`lg'" ". quietly datacheck flag k x s"
    assert r(nonblank) == 0
    assert r(n) <= 1
}
_dg `=_rc' "quietly datacheck: profile emphasis lines and frequency rows stay silent"

* every other emphasis site: zero variance, outliers, and the patterns table
_dg_flags
replace x = . in 1/2
capture log close _dgq
log using "`lg'", text replace name(_dgq)
quietly datacheck x k s, continuous(k) outliers(0.1) patterns
log close _dgq
capture {
    _dg_between "`lg'" ". quietly datacheck x k s"
    assert r(nonblank) == 0
    assert r(n) <= 1
}
_dg `=_rc' "quietly datacheck: zero-variance, outlier, and patterns output stay silent"

* positive control: the same call without quietly does print the constant line
_dg_flags
capture log close _dgq
log using "`lg'", text replace name(_dgq)
datacheck flag k x s, rare(5) outliers(1)
log close _dgq
capture {
    _dg_count "`lg'" "single level (constant)"
    assert !missing(r(n))
    assert r(n) >= 1
}
_dg `=_rc' "positive control: noisy profile prints the single-level line"

* ============================================================
* 2. violations()/makespec() to a new frame with replace (plan item 6b)
* ============================================================
_dg_flags
capture frame drop dg_newviol
capture {
    datacheck, gatesonly inrange(x 1 10) warn violations(dg_newviol, replace)
    frame dg_newviol: assert _N == 1
    frame dg_newviol: assert gate[1] == "inrange"
}
_dg `=_rc' "violations(newframe, replace) creates the frame instead of r(111)"
capture frame drop dg_newviol

_dg_flags
capture frame drop dg_newspec
capture {
    datacheck, makespec(dg_newspec, replace)
    frame dg_newspec: assert _N >= 1
    frame dg_newspec: assert gate[1] == "expectn"
}
_dg `=_rc' "makespec(newframe, replace) creates the frame instead of r(111)"
capture frame drop dg_newspec

_dg_flags
capture frame drop dg_v2
capture {
    datacheck, gatesonly inrange(x 1 10) warn violations(dg_v2)
    capture datacheck, gatesonly inrange(x 1 10) warn violations(dg_v2)
    assert _rc == 110
    datacheck, gatesonly inrange(x 1 5) warn violations(dg_v2, replace)
    frame dg_v2: assert strpos(message[1], "15 obs outside") > 0
}
_dg `=_rc' "violations() frame: exists without replace r(110); replace overwrites"
capture frame drop dg_v2

* ============================================================
* 3. PASS line (plan item 1)
* ============================================================
_dg_flags
capture log close _dgq
log using "`lg'", text replace name(_dgq)
datacheck, gatesonly isid(id) rule("positive": x > 0 \ "small": x <= 20)
* log close clears r(); read the returns first
local nck = r(n_checks)
local nvl = r(n_violations)
log close _dgq
capture {
    assert `nck' == 2
    assert `nvl' == 0
    _dg_count "`lg'" "PASS: 2 gate(s) (isid rule), N = 20, 0 violations"
    assert r(n) == 1
}
_dg `=_rc' "passing gates print one PASS line naming the families; rules count as one family"

_dg_flags
capture log close _dgq
log using "`lg'", text replace name(_dgq)
datacheck, gatesonly isid(flag) warn
log close _dgq
capture {
    _dg_count "`lg'" "PASS:"
    assert r(n) == 0
    _dg_count "`lg'" "WARNINGS (1)"
    assert r(n) == 1
}
_dg `=_rc' "no PASS line when a gate warns"

_dg_flags
capture log close _dgq
log using "`lg'", text replace name(_dgq)
datacheck, gatesonly
log close _dgq
capture {
    _dg_count "`lg'" "nothing was checked"
    assert r(n) == 1
    _dg_count "`lg'" "PASS:"
    assert r(n) == 0
}
_dg `=_rc' "gatesonly with no gates says nothing was checked, not PASS"

* ============================================================
* 4. rule()
* ============================================================
* intervals deliberately NOT sorted by id: rules must see this order
clear
input long id start stop str3 arm
2 0 5 "B"
1 0 10 "A"
1 10 20 "A"
1 10 20 "A"
2 7 9 "B"
3 0 4 "C"
end
* by hand in this order: row 3 continues row 2 (10 == 10), row 4 overlaps
* row 3 (10 < 20), row 5 follows row 1? no: row 4 is id 1, so row 5 starts a
* new id run; ids change at rows 2, 5, 6.  no_overlap fails row 4 only.
* contig fails row 4 only.  arm in {A,B} fails row 6 only.
capture frame drop dg_rv
capture {
    * profile mode: KEY STRUCTURE sorts by id before the gates are read
    datacheck, id(id) nodups warn violations(dg_rv, replace) ///
        rule("no_overlap": id != id[_n-1] | start >= stop[_n-1] \ ///
             contig: id != id[_n-1] | start == stop[_n-1] \ ///
             "arm A or B": inlist(arm, "A", "B"))
    assert r(n_violations) == 4
    assert "`r(violations)'" == "nodups rule rule rule"
    frame dg_rv: assert variable[2] == "no_overlap" & observed[2] == "1 fail"
    frame dg_rv: assert variable[3] == "contig" & observed[3] == "1 fail"
    frame dg_rv: assert variable[4] == "arm A or B" & observed[4] == "1 fail"
    frame dg_rv: assert expected[4] == `"inlist(arm, "A", "B")"'
    frame dg_rv: assert message[4] == `"rule(arm A or B): 1 obs fail inlist(arm, "A", "B")"'
    * the user's data and order are untouched
    assert id[1] == 2 & id[2] == 1 & _N == 6
}
_dg `=_rc' "rule(): counts in the caller's row order, labels, and quoted expressions saved intact"
capture frame drop dg_rv

* nodups is not fooled by a subscripted rule that differs between identical rows
capture {
    datacheck, gatesonly nodups rule("r": id != id[_n-1] | start >= stop[_n-1]) warn
    assert strpos("`r(violations)'", "nodups") > 0
}
_dg `=_rc' "nodups still finds the duplicated row when a subscripted rule is present"

* if/in subset and by()
clear
input long id byte grp double v
1 1 5
2 1 -1
3 2 -2
4 2 -3
5 2 4
end
capture {
    datacheck if grp == 1, gatesonly rule("pos": v > 0) warn
    assert r(n_violations) == 1
    assert r(N) == 2
    datacheck, gatesonly by(grp) rule("pos": v > 0) warn violations(dg_rb, replace)
    assert r(n_violations) == 2
    frame dg_rb: assert observed[1] == "1 fail" & observed[2] == "2 fail"
}
_dg `=_rc' "rule(): if-subset and per-group counts"
capture frame drop dg_rb

* missing follows Stata if-semantics: . > 0 is true, so the rule holds
clear
input double v
1
.
end
capture {
    datacheck, gatesonly rule("pos": v > 0)
    assert r(n_violations) == 0
    datacheck, gatesonly rule("pos_nm": v > 0 & !missing(v)) warn
    assert r(n_violations) == 1
}
_dg `=_rc' "rule(): missing compares as large, !missing() makes it fail"

* errors: bad expression is an error with its own rc, not a violation
clear
set obs 3
gen x = _n
capture {
    capture datacheck, gatesonly rule("bad": nosuchvar > 1)
    assert _rc == 111
    capture datacheck, gatesonly rule(nolabelcolon)
    assert _rc == 198
    capture datacheck, gatesonly rule("": x > 0)
    assert _rc == 198
    capture datacheck, gatesonly rule("bad": x > )
    assert _rc != 0 & _rc != 9
}
_dg `=_rc' "rule(): unparseable specs and invalid expressions error (not r(9))"

* a failing rule halts with r(9)
capture {
    capture datacheck, gatesonly rule("small": x < 3)
    assert _rc == 9
}
_dg `=_rc' "rule(): a failing rule halts with r(9) without warn"

* ============================================================
* 5. stat()
* ============================================================
clear
set obs 100
gen byte outcome = _n <= 10
gen double income = _n
gen float fx = 0.1
gen dt = td(01jan2020) + _n
format dt %td
gen double allmiss = .
capture {
    * mean(outcome) = 0.10, median(income) = 50.5, p99(income) = 99.5
    datacheck, gatesonly stat(mean outcome 0.05 0.15 \ median income 50 51 \ p99 income 99 100)
    assert r(n_violations) == 0
    assert r(n_checks) == 1
    * float median exactly at a float-rounded bound is not a violation
    datacheck, gatesonly stat(p50 fx 0.1 0.1)
    assert r(n_violations) == 0
    * commas accepted; date literals accepted
    datacheck, gatesonly stat(mean outcome 0.05, 0.15 \ median dt td(01feb2020) td(01mar2020))
    assert r(n_violations) == 0
}
_dg `=_rc' "stat(): mean, median, p99, float bounds, commas, and date literals pass on known values"

capture frame drop dg_sv
capture {
    datacheck, gatesonly warn violations(dg_sv, replace) ///
        stat(mean outcome 0.2 0.5 \ median income 1000 2000 \ mean allmiss 0 1)
    assert r(n_violations) == 3
    frame dg_sv: assert observed[1] == "mean .1"
    frame dg_sv: assert observed[2] == "median 50.5"
    frame dg_sv: assert expected[2] == "[1000, 2000]"
    frame dg_sv: assert strpos(observed[3], "no nonmissing values") > 0
}
_dg `=_rc' "stat(): out-of-band and all-missing statistics are violations with the observed value"
capture frame drop dg_sv

capture {
    capture datacheck, gatesonly stat(max income 0 1)
    assert _rc == 198
    capture datacheck, gatesonly stat(mean income 5 1)
    assert _rc == 198
    capture datacheck, gatesonly stat(mean income 1)
    assert _rc == 198
}
_dg `=_rc' "stat(): unsupported statistic, reversed band, and short spec are r(198)"

* the observed value is reported exactly, not rounded to the display width:
* median of 20000 + 37*(1..50) is 20943.5, just below a band starting at 20944
clear
set obs 50
gen double inc = 20000 + 37 * _n
capture frame drop dg_sp
capture {
    datacheck, gatesonly stat(median inc 20944 30000) warn violations(dg_sp, replace)
    assert r(n_violations) == 1
    frame dg_sp: assert observed[1] == "median 20943.5"
}
_dg `=_rc' "stat(): observed value keeps full precision beside the band"
capture frame drop dg_sp

clear
set obs 4
gen str1 s = "a"
capture {
    capture datacheck, gatesonly stat(mean s 0 1)
    assert _rc == 109
}
_dg `=_rc' "stat(): a string variable is r(109)"

* ============================================================
* 6. binary()
* ============================================================
clear
set obs 10
gen byte good = mod(_n, 2)
replace good = . in 10
gen byte onemiss = 1 if _n <= 3
gen byte three = mod(_n, 3)
gen byte allmiss = .
capture frame drop dg_bv
capture {
    datacheck, gatesonly binary(good)
    assert r(n_violations) == 0
    datacheck, gatesonly binary(good onemiss three allmiss) warn violations(dg_bv, replace)
    assert r(n_violations) == 3
    frame dg_bv: assert variable[1] == "onemiss" & observed[1] == "only 1 observed (7 missing)"
    frame dg_bv: assert variable[2] == "three" & observed[2] == "3 obs not 0/1 (0 missing)"
    frame dg_bv: assert variable[3] == "allmiss" & observed[3] == "neither 0 nor 1 observed (10 missing)"
}
_dg `=_rc' "binary(): 1/missing, non-0/1, and all-missing flags fail; a 0/1 flag with missing passes"
capture frame drop dg_bv

gen byte grp = _n <= 5
capture {
    * good within grp==1 (rows 1-5): 1 0 1 0 1 -> ok; grp==0 (6-10): 0 1 0 1 . -> ok
    datacheck, gatesonly by(grp) binary(good)
    assert r(n_violations) == 0
    * onemiss is 1/1/1/./. in grp 1 and all missing in grp 0
    datacheck, gatesonly by(grp) binary(onemiss) warn
    assert r(n_violations) == 2
    capture datacheck, gatesonly binary(nosuch)
    assert _rc == 111
}
_dg `=_rc' "binary(): evaluated within by() groups; unknown variable is r(111)"

* ============================================================
* 7. r(singlelevel_vars)
* ============================================================
clear
set obs 12
gen byte onemiss = 1 if _n <= 3
gen byte both = mod(_n, 2)
gen byte allmiss = .
gen str4 sconst = cond(_n <= 6, "x", "")
gen str4 stwo = cond(_n <= 6, "x", "y")
gen byte secret = 1
capture {
    quietly datacheck, exclude(secret)
    assert "`r(singlelevel_vars)'" == "onemiss sconst"
    assert r(n_singlelevel) == 2
    quietly datacheck, gatesonly exclude(secret)
    assert "`r(singlelevel_vars)'" == "onemiss sconst"
}
_dg `=_rc' "r(singlelevel_vars): one nonmissing level; all-missing, two-level, excluded not listed"

* ============================================================
* 8. maskrare: p1/p99 replace min/max (plan item 5)
* ============================================================
clear
set obs 1000
gen double lab = _n
gen dx = td(01jan2000) + 3 * _n
format dx %td
capture log close _dgq
log using "`lg'", text replace name(_dgq)
datacheck lab dx, maskrare
log close _dgq
capture {
    _dg_count "`lg'" "min="
    assert r(n) == 0
    _dg_count "`lg'" "max="
    assert r(n) == 0
    * summarize, detail: p1 = (lab[10]+lab[11])/2 = 10.5, p99 = 990.5; 10 obs
    * lie at or below p1, so both are shown with the default mask of 5
    _dg_count "`lg'" "p1=      10.5"
    assert r(n) == 1
    _dg_count "`lg'" "p99=     990.5"
    assert r(n) == 1
    * dates at month precision: p1 of dx is 01jan2000 + 31.5 -> 2000-02
    _dg_count "`lg'" "p1=2000-02"
    assert r(n) == 1
}
_dg `=_rc' "maskrare profile: no min/max, known p1/p99, dates to month"

keep in 1/300
capture log close _dgq
log using "`lg'", text replace name(_dgq)
datacheck lab, maskrare
log close _dgq
capture {
    * N = 300: p1 = 3.5 has 3 observations at or below it (< 5)
    _dg_count "`lg'" "p1=[suppressed]"
    assert r(n) == 1
    _dg_count "`lg'" "p50=     150.5"
    assert r(n) == 1
}
_dg `=_rc' "maskrare profile: a percentile with fewer than mincell obs beyond it is suppressed"

capture frame drop dg_mv
capture {
    datacheck, gatesonly inrange(lab 5 295) warn violations(dg_mv, replace)
    frame dg_mv: assert strpos(message[1], "(min 1, max 300)") > 0
    datacheck, gatesonly inrange(lab 5 295) maskrare warn violations(dg_mv, replace)
    frame dg_mv: assert strpos(message[1], "min") == 0 & strpos(message[1], "max") == 0
    frame dg_mv: assert strpos(message[1], "(p1 [suppressed], p99 [suppressed])") > 0
    frame dg_mv: assert observed[1] == "9 outside; p1 [suppressed], p99 [suppressed]"
}
_dg `=_rc' "maskrare inrange(): violation text reports guarded p1/p99, never min/max"
capture frame drop dg_mv

keep in 1/4
capture {
    datacheck, gatesonly stat(p99 lab 0 1 \ mean lab 0 1) maskrare warn violations(dg_sm, replace)
    frame dg_sm: assert observed[1] == "p99 [suppressed]"
    frame dg_sm: assert observed[2] == "mean [suppressed]"
}
_dg `=_rc' "maskrare stat(): small-N statistics are suppressed in violation text"
capture frame drop dg_sm

* ============================================================
* 9. checks() rows for rule, stat, binary
* ============================================================
clear
set obs 20
gen long id = _n
gen double start = _n
gen double stop = _n + 1
gen byte ev = mod(_n, 2)
gen byte onemiss = 1 if _n <= 2
tempfile spec
preserve
clear
input str10 gate str20 var str40 pattern str10 values str10 arg1 str10 arg2
"rule"   "ordered" "start < stop" ""       ""  ""
"stat"   "stop"    ""             "median" "0" "5"
"binary" "ev"      ""             ""       ""  ""
"binary" "onemiss" ""             ""       ""  ""
"rule"   "t: order" "start < stop" ""      ""  ""
end
save "`spec'", replace
restore
capture {
    datacheck, gatesonly checks("`spec'") warn
    assert r(n_checks) == 3
    assert r(n_violations) == 2
    assert "`r(violations)'" == "stat binary"
}
_dg `=_rc' "checks(): rule, stat, and binary rows evaluate like the options; a colon in a rule label is kept"

* ============================================================
* Summary
* ============================================================
display as result "Results: $PASS/$TC passed, $FAIL failed"
if $FAIL > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_datacheck_gates tests=$TC pass=$PASS fail=$FAIL"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_datacheck_gates tests=$TC pass=$PASS fail=$FAIL"
exit 0
