clear all
set more off
version 16.0
* wide log lines so scanned console text is never wrapped
set linesize 255

* test_datacheck_gates.do - datacheck rule(), stat(), binary(), the PASS line,
* the 1.8.0 families (events, intervals, keyset, constant, stat statistics,
* inrange spans, bands/bandwarn, review items, heaping, coverage, groupstat,
* sets, checks() rows), the named verdict, minversion(), fast-path parity,
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
    * 1.8.0 F1: gatesonly does no classification, so profile results are unset
    quietly datacheck, gatesonly exclude(secret)
    assert "`r(singlelevel_vars)'" == ""
    assert missing(r(n_singlelevel))
}
_dg `=_rc' "r(singlelevel_vars): one nonmissing level; all-missing, two-level, excluded not listed; unset under gatesonly"

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
* 10. events(): every covariate level carries an event (1.8.0 G1)
* ============================================================
* 60 rows; mstype = mod(_n,3)+1, so level 1 is n = 3,6,...,60, level 2 is
* n = 1,4,...,58 and level 3 is n = 2,5,...,59 (20 rows each).  Events on
* level 1 with n <= 30 (n = 3..30: 10 events) and level 2 with n <= 12
* (n = 1,4,7,10: 4 events); level 3 has none.
capture program drop _dg_events
program define _dg_events
    clear
    set obs 60
    gen long id = _n
    gen byte mstype = mod(_n, 3) + 1
    label define _dgmst 1 "RRMS" 2 "SPMS" 3 "PPMS", replace
    label values mstype _dgmst
    gen byte _d = (mstype == 1 & _n <= 30) | (mstype == 2 & _n <= 12)
    gen str1 sx = cond(mod(_n, 2), "F", "M")
    gen byte grp = cond(_n <= 30, 1, 2)
end

_dg_events
capture frame drop dg_ev
capture {
    capture datacheck, gatesonly events(_d: mstype sx) violations(dg_ev, replace)
    assert _rc == 9
    frame dg_ev: assert _N == 1
    frame dg_ev: assert gate[1] == "events" & variable[1] == "mstype" & label[1] == "_d"
    frame dg_ev: assert group[1] == "mstype = 3"
    frame dg_ev: assert strpos(message[1], "events(_d): mstype = 3 (PPMS) has 0 events") == 1
}
_dg `=_rc' "events(): the eventless level fails, named with its value label; the string covariate passes"

_dg_events
capture {
    capture datacheck, gatesonly events(_d: mstype, min(5)) warn violations(dg_ev, replace)
    assert _rc == 0
    frame dg_ev: assert _N == 2
    frame dg_ev: assert observed[1] == "4 events" & observed[2] == "0 events"
    capture datacheck, gatesonly events(_d: mstype, min(5)) maskrare warn violations(dg_ev, replace)
    * 4 events is a small cell; 0 is printed as 0
    frame dg_ev: assert observed[1] == "<5 events" & observed[2] == "0 events"
}
_dg `=_rc' "events() min(): levels below min fail; under maskrare a nonzero count below 5 prints <5, zero prints 0"

_dg_events
capture {
    * events among id <= 12: level 1 has n = 3,6,9,12 (4), level 2 has 4
    capture datacheck, gatesonly events(_d if id <= 12: mstype) warn violations(dg_ev, replace)
    frame dg_ev: assert _N == 1 & group[1] == "mstype = 3"
    * no event has id > 30, so every level fails
    capture datacheck, gatesonly events(_d if id > 30: mstype) warn violations(dg_ev, replace)
    frame dg_ev: assert _N == 3
}
_dg `=_rc' "events() entry if restricts the event sum only; levels still come from the call's sample"

_dg_events
gen byte lv = mstype
replace lv = . if lv == 3
capture {
    capture datacheck, gatesonly events(_d: lv)
    assert _rc == 0
    * an explicit Unknown code is a level and is checked
    replace lv = 99 in 59
    capture datacheck, gatesonly events(_d: lv) warn violations(dg_ev, replace)
    frame dg_ev: assert _N == 1 & group[1] == "lv = 99"
}
_dg `=_rc' "events(): a missing level is skipped; an explicit code such as 99 is checked"

_dg_events
capture {
    capture datacheck, gatesonly events(_d: id)
    assert _rc == 198
    capture datacheck, gatesonly events(_d mstype)
    assert _rc == 198
    capture datacheck, gatesonly events(sx: mstype)
    assert _rc == 109
}
_dg `=_rc' "events(): a covariate beyond maxcat(), a spec without a colon, and a string event are errors"

_dg_events
capture {
    * group 1 (n <= 30): level 3 has no events; group 2: no events at all
    capture datacheck, gatesonly by(grp) events(_d: mstype) warn violations(dg_ev, replace)
    frame dg_ev: assert _N == 4
    frame dg_ev: count if strpos(group, "by(grp | grp=2)") == 1
    frame dg_ev: assert r(N) == 3
}
_dg `=_rc' "events() within by(): each group is checked on its own levels"
capture frame drop dg_ev

* ============================================================
* 11. intervals(): structure checked on its own sort (1.8.0 G2)
* ============================================================
capture program drop _dg_intervals
program define _dg_intervals
    clear
    set obs 12
    gen long id = .
    gen double start = .
    gen double stop = .
    gen byte ev = .
    replace id = 1 in 1
    replace start = 0 in 1
    replace stop = 10 in 1
    replace ev = 0 in 1
    replace id = 1 in 2
    replace start = 10 in 2
    replace stop = 20 in 2
    replace ev = 1 in 2
    replace id = 2 in 3
    replace start = 0 in 3
    replace stop = 5 in 3
    replace ev = 0 in 3
    replace id = 2 in 4
    replace start = 5 in 4
    replace stop = 12 in 4
    replace ev = 0 in 4
    replace id = 2 in 5
    replace start = 12 in 5
    replace stop = 20 in 5
    replace ev = 1 in 5
    replace id = 3 in 6
    replace start = 0 in 6
    replace stop = 10 in 6
    replace ev = 0 in 6
    replace id = 3 in 7
    replace start = 8 in 7
    replace stop = 15 in 7
    replace ev = 0 in 7
    replace id = 3 in 8
    replace start = 15 in 8
    replace stop = 20 in 8
    replace ev = 0 in 8
    replace id = 4 in 9
    replace start = 0 in 9
    replace stop = 10 in 9
    replace ev = 1 in 9
    replace id = 4 in 10
    replace start = 20 in 10
    replace stop = 30 in 10
    replace ev = 0 in 10
    replace id = 5 in 11
    replace start = 5 in 11
    replace stop = 5 in 11
    replace ev = 0 in 11
    replace id = 5 in 12
    replace start = . in 12
    replace stop = 9 in 12
    replace ev = 0 in 12
    set seed 20260930
    gen double _u = runiform()
    sort _u
    drop _u
end
* hand count: missing = id 5 row 2; order = id 5 (5, 5); overlap = id 3
* (8 < 10); gap = id 4 (20 > 10); event_last = id 4 first row.
_dg_intervals
capture frame drop dg_iv
capture {
    capture datacheck, gatesonly intervals(id start stop, contiguous event(ev)) ///
        violations(dg_iv, replace)
    assert _rc == 9
    frame dg_iv: assert _N == 5
    foreach ck in missing order overlap gap event_last {
        frame dg_iv: count if label == "`ck'" & observed == "1 intervals in 1 persons"
        assert r(N) == 1
        frame dg_iv: count if label == "`ck'" & strpos(message, "intervals(`ck'):") == 1
        assert r(N) == 1
    }
}
_dg `=_rc' "intervals(): missing, order, overlap, gap and event_last each named once with hand counts"

_dg_intervals
capture {
    * the caller's order does not matter: sorted and shuffled agree
    capture datacheck, gatesonly intervals(id start stop, contiguous event(ev)) warn violations(dg_iv, replace)
    frame dg_iv: local m1 = message[1] + message[2] + message[3] + message[4] + message[5]
    sort id start
    capture datacheck, gatesonly intervals(id start stop, contiguous event(ev)) warn violations(dg_iv, replace)
    frame dg_iv: local m2 = message[1] + message[2] + message[3] + message[4] + message[5]
    assert `"`m1'"' == `"`m2'"'
    * tol(2): 8 >= 10 - 2, so the overlap passes; the gap (20 > 12) stays
    capture datacheck, gatesonly intervals(id start stop, contiguous tol(2)) warn violations(dg_iv, replace)
    frame dg_iv: count if label == "overlap"
    assert r(N) == 0
    frame dg_iv: count if label == "gap"
    assert r(N) == 1
    * without contiguous or event(), neither check runs
    capture datacheck, gatesonly intervals(id start stop) warn violations(dg_iv, replace)
    frame dg_iv: count if inlist(label, "gap", "event_last")
    assert r(N) == 0
    keep if inlist(id, 1, 2)
    capture datacheck, gatesonly intervals(id start stop, contiguous event(ev))
    assert _rc == 0
}
_dg `=_rc' "intervals(): sort-independent, tol() relaxes overlap only, optional checks off by default, clean file passes"

_dg_intervals
gen byte dose = 1
capture {
    capture datacheck, gatesonly intervals(id dose start stop) warn violations(dg_iv, replace)
    frame dg_iv: assert variable[1] == "id dose start stop"
    capture datacheck, gatesonly intervals(id start, contiguous)
    assert _rc == 198
    capture datacheck, gatesonly intervals(id start stop, tol(-1))
    assert _rc == 198
}
_dg `=_rc' "intervals(): a composite id works; too few variables and a negative tol() are errors"
capture frame drop dg_iv

* ============================================================
* 12. keyset(): the same persons as a saved file (1.8.0 G3)
* ============================================================
tempfile dg_ids
clear
set obs 50
gen long id = _n
gen str4 sid = "P" + string(_n)
save "`dg_ids'", replace
capture frame drop dg_ks
capture {
    capture datacheck, gatesonly keyset(id using "`dg_ids'" \ sid using "`dg_ids'")
    assert _rc == 0
    * persons_swapped: drop 5 ids, add 5 others; the count rule still passes
    drop if id <= 5
    set obs 50
    replace id = 100 + _n - 45 if missing(id)
    quietly count
    local nper = r(N)
    capture datacheck, gatesonly rule("same_persons": `nper' == 50)
    assert _rc == 0
    capture datacheck, gatesonly keyset(id using "`dg_ids'") warn violations(dg_ks, replace)
    assert r(keyset_only_master) == 5 & r(keyset_only_using) == 5
    frame dg_ks: assert _N == 1 & gate[1] == "keyset"
    frame dg_ks: assert strpos(message[1], "keyset(id): equal") == 1
}
_dg `=_rc' "keyset(): swapped persons fail though the count rule passes; both directions counted"

capture {
    clear
    set obs 40
    gen long id = _n
    capture datacheck, gatesonly keyset(id using "`dg_ids'", subset)
    assert _rc == 0
    capture datacheck, gatesonly keyset(id using "`dg_ids'", superset)
    assert _rc == 9
    assert r(keyset_only_using) == 10
    capture datacheck, gatesonly keyset(id using "`dg_ids'")
    assert _rc == 9
    set obs 60
    replace id = _n
    capture datacheck, gatesonly keyset(id using "`dg_ids'", superset)
    assert _rc == 0
    capture datacheck, gatesonly keyset(id using "`dg_ids'", subset) maskrare warn violations(dg_ks, replace)
    * 10 keys not in the file (>= 5, shown); 0 absent
    frame dg_ks: assert strpos(observed[1], "10 keys not in ") == 1 & strpos(observed[1], "; 0 keys of ") > 0
    assert r(keyset_only_master) == 10 & r(keyset_only_using) == 0
}
_dg `=_rc' "keyset(): subset and superset read one direction each; equal reads both"

capture {
    clear
    set obs 3
    gen str4 id = "P1"
    capture datacheck, gatesonly keyset(id using "`dg_ids'")
    assert _rc != 0 & _rc != 9
    capture datacheck, gatesonly keyset(id using "`c(tmpdir)'/no_such_ids_file")
    assert _rc == 601
    gen long k = _n
    capture datacheck, gatesonly keyset(k using "`dg_ids'", sideways)
    assert _rc == 198
}
_dg `=_rc' "keyset(): type mismatch, a missing file and a bad mode are errors, not violations"
capture frame drop dg_ks

* ============================================================
* 13. constant(): time-fixed values within a key (1.8.0 G5)
* ============================================================
capture program drop _dg_tv
program define _dg_tv
    clear
    set obs 30
    gen long id = ceil(_n / 3)
    bysort id: gen byte fu_band = _n
    gen byte sex = mod(id, 2) + 1
    gen dob = td(01jan1970) + id
    gen str3 grp = cond(id <= 5, "abc", "xyz")
end
_dg_tv
capture frame drop dg_cn
capture {
    capture datacheck, gatesonly constant(id: sex dob grp)
    assert _rc == 0
    * covariate_varies_within_person: 4 persons change sex in band 2
    replace sex = 3 - sex if fu_band == 2 & id <= 4
    capture datacheck, gatesonly constant(id: sex) warn violations(dg_cn, replace)
    frame dg_cn: assert _N == 1 & observed[1] == "4 keys vary"
    frame dg_cn: assert strpos(message[1], "constant(id: sex): 4 keys with more than one value") == 1
    capture datacheck, gatesonly constant(id: sex) maskrare warn violations(dg_cn, replace)
    frame dg_cn: assert observed[1] == "<5 keys vary"
}
_dg `=_rc' "constant(): a covariate varying within 4 persons is caught and masked"

_dg_tv
capture {
    replace dob = . in 20
    capture datacheck, gatesonly constant(id: dob)
    assert _rc == 9
    capture datacheck, gatesonly constant(id: dob, ignoremissing)
    assert _rc == 0
    replace grp = "zzz" in 30
    capture datacheck, gatesonly constant(id: grp) warn violations(dg_cn, replace)
    frame dg_cn: assert observed[1] == "1 keys vary"
    capture datacheck, gatesonly constant(id sex)
    assert _rc == 198
}
_dg `=_rc' "constant(): missing next to a value is a second value unless ignoremissing; strings work"
capture frame drop dg_cn

* ============================================================
* 14. stat(): sum n distinct pmiss ess ratio and a condition per entry (G4)
* ============================================================
* 100 rows: w = 1 on 50 rows and 3 on 50, so sum w = 200, sum w^2 = 500
* and Kish ess = 200^2 / 500 = 80.  x is missing on 10 rows (pmiss 0.1,
* n 90); g takes 7 distinct values; d sums to 20; ev/py = 20 / 1000.
capture program drop _dg_stats
program define _dg_stats
    clear
    set obs 100
    gen long id = _n
    gen double w = cond(_n <= 50, 1, 3)
    gen double x = _n
    replace x = . if _n > 90
    gen byte g = mod(_n, 7)
    gen byte d = _n <= 20
    gen double py = 10
    gen byte grp = cond(_n <= 50, 1, 2)
end
_dg_stats
capture frame drop dg_st
capture {
    capture datacheck, gatesonly stat(sum d 20 20 \ n x 90 90 \ distinct g 7 7 \ ///
        pmiss x 0.1 0.1 \ ess w 79.999999 80.000001 \ ratio d py 0.02 0.02)
    assert _rc == 0
    capture datacheck, gatesonly stat(ess w 81 90 \ ratio d py 0.03 0.04) warn violations(dg_st, replace)
    frame dg_st: assert _N == 2
    frame dg_st: assert observed[1] == "ess 80" & observed[2] == "ratio .02"
    frame dg_st: assert strpos(message[2], "stat(ratio d/py):") == 1
}
_dg `=_rc' "stat(): sum, n, distinct, pmiss, Kish ess and ratio equal their hand values"

_dg_stats
capture {
    * the entry if restricts that entry only: x among id <= 50 has mean 25.5
    capture datacheck, gatesonly stat(mean x 25.5 25.5 if grp == 1 \ n x 90 90)
    assert _rc == 0
    * a comma inside the condition survives
    capture datacheck, gatesonly stat(n x 10 10 if inrange(id, 1, 10))
    assert _rc == 0
    * zero rows: n and sum are 0; pmiss has no value and fails
    capture datacheck, gatesonly stat(n x 0 0 if id > 1000 \ sum d 0 0 if id > 1000)
    assert _rc == 0
    capture datacheck, gatesonly stat(pmiss x 0 1 if id > 1000) warn violations(dg_st, replace)
    frame dg_st: assert strpos(observed[1], "no rows in scope") > 0
    * the call's if combines with the entry's
    capture datacheck if grp == 2, gatesonly stat(n x 20 20 if id <= 70)
    assert _rc == 0
}
_dg `=_rc' "stat(): per-entry conditions, commas in conditions, and zero-row statistics"

_dg_stats
capture {
    capture datacheck, gatesonly stat(sum d 0 1) maskrare warn violations(dg_st, replace)
    frame dg_st: assert observed[1] == "sum 20"
    replace d = 0 if _n > 3
    capture datacheck, gatesonly stat(sum d 0 1) maskrare warn violations(dg_st, replace)
    frame dg_st: assert observed[1] == "sum <5"
    capture datacheck, gatesonly stat(ratio d py 0 1 2)
    assert _rc == 198
    capture datacheck, gatesonly stat(mode x 0 1)
    assert _rc == 198
}
_dg `=_rc' "stat(): a small sum is masked; malformed ratio and unknown statistics are errors"
capture frame drop dg_st

* ============================================================
* 15. inrange(): several variables per bound pair, open bounds (G6)
* ============================================================
clear
set obs 20
gen double a = _n / 2
gen double b = _n
gen double c = cond(_n == 1, -100, 3)
replace c = 6 in 2
gen dt = td(01jan2020) + 30 * (_n - 1)
format dt %td
capture frame drop dg_ir
capture {
    * a is in [0, 10]; b has 11..20 above 10
    capture datacheck, gatesonly inrange(a b 0 10) warn violations(dg_ir, replace)
    frame dg_ir: assert _N == 1 & variable[1] == "b" & strpos(observed[1], "10 outside") == 1
    * an open lower bound: -100 is fine, 6 is above 5
    capture datacheck, gatesonly inrange(c . 5) warn violations(dg_ir, replace)
    frame dg_ir: assert _N == 1 & strpos(observed[1], "1 outside") == 1
    capture datacheck, gatesonly inrange(c . .)
    assert _rc == 198
    * a date written as a string bound parses as a date (r(198) in 1.7.1)
    * 20 dates from 01jan2020 by 30 days: the last is 06jul2021, so the
    * dates after 31dec2020 are rows 14..20 (7 rows)
    capture datacheck, gatesonly inrange(dt 01jan2020 31dec2020) warn violations(dg_ir, replace)
    assert _rc == 0
    frame dg_ir: assert strpos(observed[1], "7 outside") == 1
    capture datacheck, gatesonly inrange(dt 01jan2020 31dec2021)
    assert _rc == 0
}
_dg `=_rc' "inrange(): a bound pair covers several variables, '.' is open, and date strings parse"
capture frame drop dg_ir

* ============================================================
* 16. bands() and bandwarn: invariants and bands in one call (E1)
* ============================================================
_dg_flags
capture log close _dgq
log using "`lg'", text replace name(_dgq)
capture noisily datacheck, gatesonly isid(flag) bands(stat(mean x 0 1)) bandwarn
local brc = _rc
local nerr = r(n_errors)
local nwarn = r(n_warnings)
log close _dgq
capture {
    * band_invariant_split: the failing band warns, the failing invariant halts
    assert `brc' == 9 & `nerr' == 1 & `nwarn' == 1
    _dg_count "`lg'" "BAND WARNINGS (1)"
    assert r(n) == 1
    _dg_count "`lg'" "EXPECTATION VIOLATIONS (1)"
    assert r(n) == 1
}
_dg `=_rc' "bandwarn: a failing band warns while a failing invariant in the same call halts"

_dg_flags
capture {
    capture datacheck, gatesonly isid(id) bands(stat(mean x 0 1)) bandwarn
    assert _rc == 0 & r(n_warnings) == 1 & r(n_errors) == 0
    capture datacheck, gatesonly isid(id) bands(stat(mean x 0 1))
    assert _rc == 9
    capture datacheck, gatesonly isid(flag) bands(stat(mean x 0 1)) warn
    assert _rc == 0 & r(n_warnings) == 2
    capture datacheck, gatesonly bands(isid(id))
    assert _rc == 198
    capture datacheck, gatesonly bands(expectn(20) inrange(x 1 20)) bandwarn
    assert _rc == 0 & r(n_warnings) == 0
    capture datacheck, gatesonly bands(expectn(30 40)) bandwarn violations(dg_bd, replace)
    frame dg_bd: assert kind[1] == "band" & severity[1] == "warning"
}
_dg `=_rc' "bands(): production halts on a band, bare warn downgrades both, invariants are refused inside bands()"
capture frame drop dg_bd

* ============================================================
* 17. review(), complete(), jumps(): printed, never halting (R1 R5 P3)
* ============================================================
_dg_flags
replace x = . in 1/2
gen double y = _n
replace y = . in 3/5
capture log close _dgq
log using "`lg'", text replace name(_dgq)
capture noisily datacheck, gatesonly review("small": x < 5) complete(x y)
local rrc = _rc
local nrev = r(n_reviews)
log close _dgq
capture {
    assert `rrc' == 0 & `nrev' == 2
    * x = 3, 4 are below 5 (rows 1-2 are missing): 2 of 20 rows
    _dg_count "`lg'" "review(small): 2 of 20 rows (10.0%)"
    assert r(n) == 1
    * complete over x y: rows 6..20 are complete, 15 of 20
    _dg_count "`lg'" "complete(x y): 15 of 20 (75.0%) complete"
    assert r(n) == 1
    capture datacheck, gatesonly complete(x y, min(0.8))
    assert _rc == 9
    capture datacheck, gatesonly complete(x y, min(0.7))
    assert _rc == 0
}
_dg `=_rc' "review() and complete() print hand counts and never halt; complete(min()) is a gate"

capture {
    clear
    set obs 20
    gen long id = ceil(_n / 4)
    bysort id: gen byte t = _n
    gen double v = 10
    replace v = 200 if id == 2 & t == 3
    capture datacheck, gatesonly jumps(id t v) warn violations(dg_jp, replace)
    assert _rc == 0 & r(n_reviews) == 1 & r(n_violations) == 0
    * 10 -> 200 and 200 -> 10 are both jumps, in one person
    capture log close _dgq
    log using "`lg'", text replace name(_dgq)
    capture noisily datacheck, gatesonly jumps(id t v, ratio(10))
    log close _dgq
    _dg_count "`lg'" "jumps(v): 2 consecutive pairs in 1 persons"
    assert r(n) == 1
    capture datacheck, gatesonly jumps(id t v, ratio(1))
    assert _rc == 198
}
_dg `=_rc' "jumps(): both sides of a jump are counted; ratio() must exceed 1"
capture frame drop dg_jp

* ============================================================
* 18. heaping() and coverage(): placeholder dates, truncated deliveries (R2 R4)
* ============================================================
* 1000 dates: 100 on 1 Jan 2020, 40 on 1 Feb, 60 on 15 Mar, 800 on 7 Apr.
* Shares: 1 January 10%, the 1st 14%, the 15th 6%.
clear
set obs 1000
gen dt = td(07apr2020)
replace dt = td(01jan2020) in 1/100
replace dt = td(01feb2020) in 101/140
replace dt = td(15mar2020) in 141/200
format dt %td
capture log close _dgq
log using "`lg'", text replace name(_dgq)
capture noisily datacheck, gatesonly heaping(dt)
local hrc = _rc
log close _dgq
capture {
    assert `hrc' == 0
    _dg_count "`lg'" "10.00%*"
    assert r(n) == 1
    * 14% on the 1st is below 5 x 3.29% = 16.4%, so it is not marked
    _dg_count "`lg'" "14.00%*"
    assert r(n) == 0
    _dg_count "`lg'" "14.00%"
    assert r(n) == 1
    _dg_count "`lg'" "6.00%"
    assert r(n) == 1
    _dg_count "`lg'" "6.00%*"
    assert r(n) == 0
    * placeholder_dates: a 2% ceiling on the 1 January share halts
    capture datacheck, gatesonly heaping(dt, max(0.02))
    assert _rc == 9
    capture datacheck, gatesonly heaping(dt, max(0.2 0.2 0.1))
    assert _rc == 0
    capture datacheck, gatesonly heaping(dt, max(0.2 0.1))
    assert _rc == 9
}
_dg `=_rc' "heaping(): hand shares and marks; max() gates the 1 January share, and the 1st with two numbers"

capture program drop _dg_cov
program define _dg_cov
    clear
    set obs `=td(31dec2020) - td(01jan2015) + 1'
    gen dt = td(01jan2015) + _n - 1
    format dt %td
end
_dg_cov
capture frame drop dg_cv
capture {
    capture datacheck, gatesonly coverage(dt 01jan2015 31dec2020, gap(60) years)
    assert _rc == 0
    * truncated_delivery: the file stops 730 days before its end
    drop if dt > td(31dec2020) - 730
    capture datacheck, gatesonly coverage(dt 01jan2015 31dec2020, gap(60)) violations(dg_cv, replace)
    assert _rc == 9
    frame dg_cv: assert _N == 1 & label[1] == "late_end" & kind[1] == "band"
    capture datacheck, gatesonly coverage(dt 01jan2015 31dec2020, gap(60)) bandwarn
    assert _rc == 0
}
_dg `=_rc' "coverage(): a truncated delivery fails late_end; coverage() is a band, so bandwarn warns"

_dg_cov
capture {
    * missing_year: no rows in 2017
    drop if year(dt) == 2017
    capture datacheck, gatesonly coverage(dt 01jan2015 31dec2020, gap(60) years) warn violations(dg_cv, replace)
    frame dg_cv: assert _N == 1 & label[1] == "year_gap" & observed[1] == "no rows in 2017"
    _dg_cov
    set obs `=_N + 3'
    replace dt = td(15jun2014) if missing(dt)
    capture datacheck, gatesonly coverage(dt 01jan2015 31dec2020, gap(60))
    assert _rc == 9
    capture datacheck, gatesonly coverage(dt 01jan2015 31dec2020, gap(600) tail(0.01))
    assert _rc == 0
    capture datacheck, gatesonly coverage(dt 01jan2015 31dec2020)
    assert _rc == 198
    gen double tc = cofd(dt)
    format tc %tc
    capture datacheck, gatesonly coverage(tc 01jan2015 31dec2020, gap(60))
    assert _rc == 198
}
_dg `=_rc' "coverage(): a missing year and out-of-window dates fail; gap() is required; %tc is refused"
capture frame drop dg_cv

* ============================================================
* 19. groupstat(): a statistic by group against the pooled value (R3)
* ============================================================
* 3 sites x 2 years, 30 rows each; site 3 in 2020 reports in the wrong unit
capture program drop _dg_lab
program define _dg_lab
    clear
    set seed 11
    set obs 180
    gen byte site = ceil(_n / 60)
    gen int year = 2019 + mod(_n, 2)
    gen double bcell = 50 + 10 * rnormal()
    replace bcell = bcell * 1000 if site == 3 & year == 2020
end
_dg_lab
capture frame drop dg_gs
capture {
    capture datacheck, gatesonly groupstat(median bcell, by(site year) band(0.05 20) relative) ///
        violations(dg_gs, replace)
    assert _rc == 9
    frame dg_gs: assert _N == 1 & strpos(group[1], "3 2020") > 0
    capture datacheck, gatesonly groupstat(median bcell, by(site year))
    assert _rc == 0 & r(n_reviews) == 1
}
_dg `=_rc' "groupstat(relative): a laboratory unit switch in one site-year halts; without band() it is a review"

_dg_lab
capture {
    * oracle: summarize, detail within each group; a band around group
    * (1, 2019)'s median passes that group only, and every other failing
    * cell reports its own median
    quietly summarize bcell if site == 1 & year == 2019, detail
    local m11 = r(p50)
    local lo = `m11' - 1e-9
    local hi = `m11' + 1e-9
    capture datacheck, gatesonly groupstat(median bcell, by(site year) band(`lo' `hi')) ///
        warn violations(dg_gs, replace)
    frame dg_gs: assert _N == 5
    foreach s in 1 2 3 {
        foreach y in 2019 2020 {
            if `s' == 1 & `y' == 2019 continue
            quietly summarize bcell if site == `s' & year == `y', detail
            * a failing value prints at full precision (%14.0g, as stat())
            local ms = strtrim(string(r(p50), "%14.0g"))
            frame dg_gs: count if strpos(group, "`s' `y'") > 0 & regexm(observed, "^median " + "`ms'" + "(;|$)")
            assert r(N) == 1
        }
    }
}
_dg `=_rc' "groupstat(): each group's median equals summarize, detail within the group"

clear
set obs 43
gen byte g = cond(_n <= 20, 1, cond(_n <= 40, 2, 3))
gen double x = cond(mod(_n, 4) == 0, ., _n)
capture log close _dgq
log using "`lg'", text replace name(_dgq)
capture noisily datacheck, gatesonly groupstat(pmiss x, by(g)) maskrare
log close _dgq
capture {
    * group 3 has 3 rows: pooled away under the mask of 5
    _dg_count "`lg'" "groups with <5 rows: 1"
    assert r(n) == 1
    * the pmiss computation is the one datamvp bytable() reads
    quietly datamvp x, bytable(g) nosummary notable
    matrix M = r(miss_by)
    * hand: group 1 rows 4 8 12 16 20 missing (5 of 20); group 2 rows
    * 24 28 32 36 40 (5 of 20); group 3 rows 41-43 none
    assert !missing(M[1, 1], M[1, 2], M[1, 3])
    assert reldif(M[1, 1], 25) < 1e-12 & reldif(M[1, 2], 25) < 1e-12 & M[1, 3] == 0
    capture datacheck, gatesonly groupstat(pmiss x, by(g) band(0.3 1)) warn violations(dg_gs, replace)
    frame dg_gs: count if regexm(observed, "^pmiss [.]25(;|$)")
    assert r(N) == 2
}
_dg `=_rc' "groupstat(pmiss): small groups pooled under the mask; values agree with datamvp bytable()"
capture frame drop dg_gs

* ============================================================
* 20. sets(): matched-set structure (P3)
* ============================================================
clear
set obs 50
gen long set_id = ceil(_n / 5)
bysort set_id: gen byte exposure = (_n == 1)
gen index_dt = td(01jan2020) + set_id
capture frame drop dg_ms
capture {
    capture datacheck, gatesonly sets(set_id exposure, k(4) index(index_dt))
    assert _rc == 0
    * rows 11-15 are set 3 (row 11 exposed); rows 21-25 are set 5
    replace exposure = 1 in 12
    replace index_dt = index_dt + 1 in 25
    capture datacheck, gatesonly sets(set_id exposure, k(4) index(index_dt)) warn violations(dg_ms, replace)
    * set 3 now has 2 exposed and 3 unexposed rows; set 5 has two index dates
    frame dg_ms: count if label == "exposed" & observed == "1 sets"
    assert r(N) == 1
    frame dg_ms: count if label == "unexposed" & observed == "1 sets"
    assert r(N) == 1
    frame dg_ms: count if label == "index" & observed == "1 sets"
    assert r(N) == 1
}
_dg `=_rc' "sets(): one set with two exposed, and one with two index dates, are named per check"
capture frame drop dg_ms

* ============================================================
* 21. checks() rows for the 1.8.0 families
* ============================================================
_dg_events
tempfile spec2 dg_ids2
preserve
keep id
save "`dg_ids2'", replace
clear
input str12 gate str20 var str40 pattern str20 values str10 arg1 str10 arg2 str8 kind
"events"   "mstype"     ""           "_d"        ""      ""     ""
"keyset"   "id"         ""           "PLACEHOLD" ""      ""     ""
"constant" "sx"         ""           "id"        ""      ""     ""
"stat"     "id"         "id <= 30"   "n"         "30"    "30"   ""
"stat"     "_d"         ""           "sum"       "0"     "1"    "band"
"review"   "early"      "id < 10"    ""          ""      ""     ""
"complete" "mstype sx"  ""           ""          "0.9"   ""     ""
"intervals" "id mstype grp" ""       ""          ""      ""     ""
end
replace values = "`dg_ids2'" if gate == "keyset"
save "`spec2'", replace
restore
capture {
    capture datacheck, gatesonly checks("`spec2'") bandwarn
    local rc_spec = _rc
    local v_spec "`r(violations)'"
    local c_spec "`r(checks_run)'"
    capture datacheck, gatesonly events(_d: mstype) keyset(id using "`dg_ids2'") ///
        constant(id: sx) stat(n id 30 30 if id <= 30) bands(stat(sum _d 0 1)) ///
        review("early": id < 10) complete(mstype sx, min(0.9)) ///
        intervals(id mstype grp) bandwarn
    assert _rc == `rc_spec'
    assert "`r(violations)'" == "`v_spec'"
    assert "`r(checks_run)'" == "`c_spec'"
    assert strpos("`v_spec'", "stat events intervals") == 1
}
_dg `=_rc' "checks(): 1.8.0 family rows, including a band row, reproduce the inline verdict"

* ============================================================
* 22. the verdict names the dataset; minversion() (E3 E4)
* ============================================================
_dg_flags
local dgfile "`c(tmpdir)'/dg_named_fixture.dta"
quietly save "`dgfile'", replace
use "`dgfile'", clear
capture log close _dgq
log using "`lg'", text replace name(_dgq)
datacheck, gatesonly isid(id) maskrare
replace x = x + 1
datacheck, gatesonly isid(id)
datacheck, gatesonly isid(id) name(flags, restricted)
log close _dgq
capture {
    _dg_count "`lg'" "PASS: dg_named_fixture, 1 gate(s) (isid), N = 20, 0 violations [masked <5]"
    assert r(n) == 1
    _dg_count "`lg'" "PASS: dg_named_fixture (modified), 1 gate(s) (isid), N = 20, 0 violations"
    assert r(n) == 1
    _dg_count "`lg'" "PASS: flags, restricted, 1 gate(s)"
    assert r(n) == 1
}
_dg `=_rc' "PASS line: dataset basename, (modified) after a change, name() override, active masking"
capture erase "`dgfile'"

capture {
    clear
    capture datacheck, minversion(1.8.0)
    assert _rc == 0
    local v = "`r(version)'"
    findfile datacheck.ado
    tempname fh
    file open `fh' using "`r(fn)'", read text
    file read `fh' line
    file close `fh'
    assert regexm(`"`line'"', "Version `v' ")
    capture datacheck, minversion(99.0)
    assert _rc == 198
    capture datacheck, minversion(1.8.0.1.2)
    assert _rc == 198
    capture datacheck, minversion(1.7)
    assert _rc == 0
    sysuse auto, clear
    capture datacheck, gatesonly isid(make)
    assert "`r(version)'" == "`v'"
}
_dg `=_rc' "minversion(): answers without data, refuses a newer request, and r(version) matches the header"

* ============================================================
* 23. gatesonly fast path: same verdicts as the profile (F1)
* ============================================================
capture program drop _dg_parity
program define _dg_parity
    clear
    set seed 3
    set obs 300
    gen long id = ceil(_n / 3)
    bysort id: gen start = _n * 10
    gen stop = start + 10
    replace stop = start in 7
    gen byte _d = runiform() < 0.2
    gen byte grp = mod(id, 4)
    forvalues j = 1/10 {
        gen double z`j' = rnormal()
    }
    gen str3 s = cond(_n <= 150, "a", "b")
    replace grp = 9 in 5
end
local pcall `"isid(id start) rule("ok": start < stop) inrange(z1 -3 3) allowed(grp 0 1 2 3) stat(mean z2 -0.1 0.1 \ sum _d 50 70) events(_d: grp s) intervals(id start stop) constant(id: grp) warn"'
capture {
    _dg_parity
    capture datacheck, gatesonly `pcall' violations(dg_p1, replace)
    local g1 "`r(checks_run)'"
    capture datacheck id start stop z1 z2 grp _d s, gatesonly `pcall' violations(dg_p2, replace)
    local g2 "`r(checks_run)'"
    capture quietly datacheck, `pcall' violations(dg_p3, replace)
    local g3 "`r(checks_run)'"
    assert "`g1'" == "`g2'" & "`g1'" == "`g3'"
    frame dg_p1: assert _N >= 4
    foreach f in dg_p2 dg_p3 {
        frame dg_p1: local n1 = _N
        frame `f': assert _N == `n1'
        forvalues j = 1/`n1' {
            frame dg_p1: local m1 = message[`j']
            frame `f': assert message[`j'] == `"`m1'"'
        }
    }
}
_dg `=_rc' "gatesonly fast path, gatesonly with a varlist, and profile mode give identical gate records"
foreach f in dg_p1 dg_p2 dg_p3 {
    capture frame drop `f'
}

* by(): the one-sort key tags still judge each group on its own rows (F3)
capture {
    clear
    set obs 40
    gen byte grp = cond(_n <= 20, 1, 2)
    gen long id = _n
    replace id = 22 in 21
    gen byte v = 1
    replace v = 2 in 1/20
    capture datacheck, gatesonly by(grp) isid(id) warn violations(dg_f3, replace)
    frame dg_f3: assert _N == 1 & strpos(group[1], "grp=2") > 0
    * rows 1 and 2 identical within group 1 only
    replace id = 1 in 2
    capture datacheck, gatesonly by(grp) nodups warn violations(dg_f3, replace)
    frame dg_f3: assert _N == 2
    frame dg_f3: count if strpos(group, "grp=1") > 0
    assert r(N) == 1
}
_dg `=_rc' "by(): isid and nodups flag only the group holding the duplicate"
capture frame drop dg_f3

* ============================================================
* 24. 1.8.0 review round: parser, parity, nested intervals, checks kinds
* ============================================================
capture {
    clear
    set obs 20
    gen double x = _n
    gen str1 s = cond(_n <= 10, "a", "b")
    gen byte d = mod(_n, 2)
    gen byte g = mod(_n, 3)
    * a string literal inside a per-entry condition: x in rows 1-10 has
    * mean 5.5; r(111) in the first 1.8.0 build
    capture datacheck, gatesonly stat(mean x 5.5 5.5 if s == "a")
    assert _rc == 0
    capture datacheck, gatesonly events(d if s == "a": g)
    assert _rc == 0
    capture datacheck, gatesonly groupstat(mean x, by(g) if s == "b")
    assert _rc == 0
    capture datacheck, gatesonly groupstat(mean x, by(nosuchvar))
    assert _rc == 111
}
_dg `=_rc' "stat(), events(), groupstat(): a string literal in the entry's if condition is kept"

capture {
    * nodups compares the varlist and the option varlists on every path:
    * a and k together are distinct, a alone is not
    clear
    set obs 10
    gen byte a = 1
    gen long k = _n
    capture datacheck a, gatesonly nodups id(k)
    local rf = _rc
    capture quietly datacheck a, nodups id(k)
    local rp = _rc
    assert `rf' == `rp' & `rf' == 0
    capture datacheck a, gatesonly nodups exclude(k)
    local rf = _rc
    capture quietly datacheck a, nodups exclude(k)
    assert _rc == `rf'
}
_dg `=_rc' "gatesonly fast path: nodups with a varlist compares id()/exclude() columns like the profile"

capture {
    * nested: (0,100) holds (10,20) and (30,40); the latest earlier stop is
    * 100, so rows 2 and 3 overlap and no gap exists
    clear
    set obs 3
    gen long id = 1
    gen double start = cond(_n == 1, 0, cond(_n == 2, 10, 30))
    gen double stop = cond(_n == 1, 100, cond(_n == 2, 20, 40))
    capture datacheck, gatesonly intervals(id start stop, contiguous) warn violations(dg_nv, replace)
    frame dg_nv: assert _N == 1 & label[1] == "overlap" & observed[1] == "2 intervals in 1 persons"
}
_dg `=_rc' "intervals(): a nested interval is compared with the latest earlier stop"
capture frame drop dg_nv

_dg_flags
tempfile spec3
preserve
clear
set obs 1
gen str8 gate = "stat"
gen str8 var = "x"
gen str8 values = "mean"
gen str8 arg1 = "0"
gen str8 arg2 = "1"
gen str8 kind = "review"
save "`spec3'", replace
restore
capture {
    capture datacheck, gatesonly checks("`spec3'")
    assert _rc == 198
}
_dg `=_rc' "checks(): kind review is refused; only invariant and band rows exist"

* ============================================================
* 25. Gate-helper review 2026-09-30: untested samples, float bounds, masking
* ============================================================
* A gate never passes on a sample it did not test; float values are compared
* at float precision at a threshold; counts whose complement in the printed N
* is a small cell are masked.

* events(): lv is missing on every row, so no level is tested
clear
set obs 6
gen byte _d = 1
gen byte lv = .
gen byte grp = cond(_n <= 3, 1, 2)
capture frame drop dg_b
capture {
    capture datacheck, gatesonly events(_d: lv)
    assert _rc == 9
    capture datacheck, gatesonly events(_d: lv) warn violations(dg_b, replace)
    frame dg_b: assert _N == 1 & gate[1] == "events" & observed[1] == "no nonmissing levels"
    frame dg_b: assert strpos(message[1], "events(_d): lv has no nonmissing level in scope") == 1
    * within by(): only the group without a level fails
    replace lv = 1 if grp == 1
    capture datacheck, gatesonly by(grp) events(_d: lv) warn violations(dg_b, replace)
    frame dg_b: assert _N == 1 & strpos(group[1], "by(grp | grp=2)") == 1
}
_dg `=_rc' "events(): a covariate with no nonmissing level in scope fails, not a pass on 0 levels"

* groupstat(): an entry if that selects no rows, and a min() above every group
clear
set obs 10
gen byte g = mod(_n, 2)
gen double y = _n
gen byte z = 0
capture {
    capture datacheck, gatesonly bands(groupstat(mean y, by(g) band(100 200) if z == 1)) warn violations(dg_b, replace)
    assert _rc == 0
    frame dg_b: assert _N == 1 & gate[1] == "groupstat" & observed[1] == "no rows in scope"
    capture datacheck, gatesonly groupstat(mean y, by(g) if z == 1)
    assert _rc == 0
    * each group has 5 rows; min(50) leaves none in the band
    capture datacheck, gatesonly bands(groupstat(mean y, by(g) min(50) band(100 200))) warn violations(dg_b, replace)
    frame dg_b: assert _N == 1 & observed[1] == "0 groups tested"
    frame dg_b: assert strpos(message[1], "no group has 50 or more rows") > 0
    * min(5) keeps both groups (means 5 and 6), inside [5, 6]
    capture datacheck, gatesonly bands(groupstat(mean y, by(g) min(5) band(5 6)))
    assert _rc == 0
}
_dg `=_rc' "groupstat() band: an empty entry scope and a min() that excludes every group fail, not pass"

* groupstat(): a float median equal to the typed bound is inside it, as in stat()
clear
set obs 6
gen byte g = _n <= 3
gen float y = 0.2
capture {
    capture datacheck, gatesonly bands(stat(median y 0.1 0.2))
    assert _rc == 0
    capture datacheck, gatesonly bands(groupstat(median y, by(g) band(0.1 0.2)))
    assert _rc == 0
    * one float step above the bound still fails in both groups
    replace y = 0.2000001
    capture datacheck, gatesonly bands(groupstat(median y, by(g) band(0.1 0.2))) warn violations(dg_b, replace)
    frame dg_b: assert _N == 2
}
_dg `=_rc' "groupstat() band: a float percentile is compared with the float-rounded bound"

* intervals(): rows without an id belong to no person and are not compared
clear
input id start stop
1 0 10
1 10 20
. 0 5
. 3 8
end
capture {
    capture datacheck, gatesonly intervals(id start stop, contiguous) warn violations(dg_b, replace)
    frame dg_b: assert _N == 1 & label[1] == "missing"
    * the two rows have no id, so they are intervals of no person
    frame dg_b: assert observed[1] == "2 intervals in 0 persons"
    frame dg_b: assert strpos(message[1], "have a missing id, start, or stop") > 0
}
_dg `=_rc' "intervals(): a missing id fails intervals(missing) and creates no overlap between strangers"

* intervals(): an event on a row already failing intervals(missing) is not
* also an event_last violation; the id's last interval carries it
clear
input id start stop ev
2 . 5 1
2 5 9 1
end
capture {
    capture datacheck, gatesonly intervals(id start stop, event(ev)) warn violations(dg_b, replace)
    frame dg_b: assert _N == 1 & label[1] == "missing"
}
_dg `=_rc' "intervals(): event_last reads only the rows the ordering checks use"

* intervals(): a float start typed on the tolerance boundary is within tol()
clear
input long id float start float stop
1 0 10
1 10.1 20
end
capture {
    capture datacheck, gatesonly intervals(id start stop, contiguous tol(0.1))
    assert _rc == 0
    replace start = 10.2 in 2
    capture datacheck, gatesonly intervals(id start stop, contiguous tol(0.1)) warn violations(dg_b, replace)
    frame dg_b: assert _N == 1 & label[1] == "gap"
}
_dg `=_rc' "intervals() tol(): float start +/- tol compared at float precision"

* jumps(): float values typed exactly ratio()-fold apart are no jump
clear
input long id float t float v
1 1 0.11
1 2 1.1
1 3 12
end
local dgled "`c(tmpdir)'/dg_b_jumps_ledger.dta"
capture erase "`dgled'"
capture frame drop dg_led
capture {
    datacheck, gatesonly jumps(id t v) ledger("`dgled'")
    frame create dg_led
    * 0.11 -> 1.1 is exactly 10-fold; 1.1 -> 12 is a jump
    frame dg_led: use "`dgled'", clear
    frame dg_led: assert _N == 1 & observed_num[1] == 1
}
_dg `=_rc' "jumps(): a float pair exactly ratio()-fold apart is not counted"
capture frame drop dg_led
capture erase "`dgled'"

* keyset(): a quoted filename containing a comma (helper contract)
clear
set obs 3
gen long id = _n
local dgkf "`c(tmpdir)'/dg b,keys.dta"
save "`dgkf'", replace
capture frame drop dg_rf
frame create dg_rf str32 fam str10 kind byte ok strL label strL variable strL grp ///
    strL observed double obsnum strL expected double nscope strL scope strL msg ///
    double minshown byte omasked
capture {
    _datacheck_keyset, spec(`"id using "`dgkf'""') rf(dg_rf) kind(invariant)
    assert r(only_master) == 0 & r(only_using) == 0 & r(mode) == "equal"
    _datacheck_keyset, spec(`"id using "`dgkf'", subset"') rf(dg_rf) kind(invariant)
    assert r(mode) == "subset"
    frame dg_rf: assert _N == 2 & ok[1] == 1 & ok[2] == 1
}
_dg `=_rc' "keyset(): a quoted filename with a comma is read whole, options after it"
capture frame drop dg_rf
capture erase "`dgkf'"

* stat() under maskrare: a count or pmiss whose complement is a small cell
clear
set obs 20
gen double x = cond(_n <= 2, _n, .)
gen double y = cond(_n <= 18, _n, .)
gen long id = cond(_n <= 18, _n, 1)
capture {
    capture datacheck, gatesonly stat(pmiss x 0 0.5 \ n y 0 1 \ distinct id 0 1) maskrare warn violations(dg_b, replace)
    frame dg_b: assert _N == 3
    * 18 of 20 missing leaves 2 nonmissing; 18 nonmissing of 20 leaves 2
    * missing; 18 distinct of 20 rows leaves 2 duplicated rows
    frame dg_b: assert observed[1] == "pmiss ." & observed[2] == "n all but <5" & observed[3] == "distinct all but <5"
    * without maskrare the values print
    capture datacheck, gatesonly stat(pmiss x 0 0.5 \ n y 0 1) warn violations(dg_b, replace)
    frame dg_b: assert observed[1] == "pmiss .9" & observed[2] == "n 18"
}
_dg `=_rc' "stat() maskrare: n, distinct, and pmiss are masked when their complement is a small cell"

* sets(values) under maskrare: 18 bad rows of 20 give back the 2 good rows
clear
set obs 20
gen long sid = ceil(_n / 2)
gen byte ex = 7
replace ex = 1 in 1
replace ex = 0 in 2
capture {
    capture datacheck, gatesonly sets(sid ex) maskrare warn violations(dg_b, replace)
    frame dg_b: assert _N == 3 & label[1] == "values"
    frame dg_b: assert observed[1] == "all but <5 rows"
    * set counts have no printed total and print as numbers
    frame dg_b: assert observed[2] == "9 sets"
}
_dg `=_rc' "sets(values) maskrare: a row count whose complement in N is small is masked"

* stat() sum and distinct under maskrare: the complement in the nonmissing
* rows is a cell too.  990 ones, 2 zeros, 8 missing: sum 990 beside n 992
* gives back the 2 zeros; 990 distinct ids in 992 nonmissing rows give back
* 2 duplicated rows.
clear
set obs 1000
gen double x = cond(_n <= 990, 1, cond(_n <= 992, 0, .))
gen double id = cond(_n <= 990, _n, cond(_n <= 992, 1, .))
capture {
    capture datacheck, gatesonly stat(sum x 0 1 \ n x 0 1 \ distinct id 0 1) maskrare warn violations(dg_b, replace)
    frame dg_b: assert _N == 3
    frame dg_b: assert observed[1] == "sum all but <5" & observed[2] == "n 992" & observed[3] == "distinct all but <5"
    * without maskrare every value prints
    capture datacheck, gatesonly stat(sum x 0 1 \ distinct id 0 1) warn violations(dg_b, replace)
    frame dg_b: assert observed[1] == "sum 990" & observed[2] == "distinct 990"
    * 6 zeros and 4 missing: neither complement of the sum is small
    replace x = 0 in 993/996
    capture datacheck, gatesonly stat(sum x 0 1) maskrare warn violations(dg_b, replace)
    frame dg_b: assert observed[1] == "sum 990"
}
_dg `=_rc' "stat() maskrare: sum and distinct are masked when their complement in the nonmissing rows is small"

* intervals(): a double start beside a float stop typed equal is contiguous;
* the tol() boundary holds with a float stop too
clear
input long id double start float stop
1 0 1.1
1 1.1 2
end
capture {
    capture datacheck, gatesonly intervals(id start stop, contiguous)
    assert _rc == 0
    replace start = 1.0 in 2
    capture datacheck, gatesonly intervals(id start stop, contiguous tol(0.1))
    assert _rc == 0
    * a start beyond the tolerance still overlaps
    replace start = 0.9 in 2
    capture datacheck, gatesonly intervals(id start stop, contiguous tol(0.1)) warn violations(dg_b, replace)
    frame dg_b: assert _N == 1 & label[1] == "overlap"
}
_dg `=_rc' "intervals() tol(): float precision applies when either start or stop is float"

* keyset() through datacheck: an entry written as one quoted token, which
* 1.8.0 accepted, is the spec; unquoted, quoted-path (with a comma and a
* space), and two-entry forms still work
clear
set obs 3
gen long id = _n
local dgkq "`c(tmpdir)'/dg_b_keyset.dta"
local dgkc "`c(tmpdir)'/dg b,keyset.dta"
save "`dgkq'", replace
save "`dgkc'", replace
capture frame drop dg_b
capture {
    capture datacheck, gatesonly keyset("id using `dgkq'")
    assert _rc == 0
    capture datacheck, gatesonly keyset("id using `dgkq', subset")
    assert _rc == 0
    capture datacheck, gatesonly keyset(id using `dgkq')
    assert _rc == 0
    capture datacheck, gatesonly keyset(id using "`dgkc'", superset \ id using "`dgkq'")
    assert _rc == 0
    * the unwrapped entry still gates: a key lost from memory fails
    drop in 3
    capture datacheck, gatesonly keyset("id using `dgkq'") warn violations(dg_b, replace)
    frame dg_b: assert _N == 1 & gate[1] == "keyset"
}
_dg `=_rc' "keyset(): a whole-quoted 1.8.0-style entry is unwrapped; quoted and unquoted paths still work"
capture frame drop dg_b
capture erase "`dgkq'"
capture erase "`dgkc'"

* complete() under maskrare: a masked share is left out, never printed as
* ".%", on the console and in the ledger.  3 of 20 rows are complete (a small
* cell); within by(g) group 2 has 3 rows, so its size is withheld.
clear
set obs 20
gen double x = cond(_n <= 3, 1, .)
gen byte g = cond(_n <= 17, 1, 2)
local dgcl "`c(tmpdir)'/dg_b_complete_ledger.dta"
capture erase "`dgcl'"
capture log close _dgc
log using "`lg'", text replace name(_dgc)
capture noisily datacheck, gatesonly complete(x) maskrare ledger("`dgcl'")
capture noisily datacheck, gatesonly by(g) complete(x, min(0.5)) maskrare warn ledger("`dgcl'")
log close _dgc
capture frame drop dg_led
capture {
    _dg_count "`lg'" ".%"
    assert r(n) == 0
    _dg_count "`lg'" "complete(x): <5 of 20 complete"
    assert r(n) == 1
    frame create dg_led
    frame dg_led: use "`dgcl'", clear
    frame dg_led: count if family == "complete"
    assert !missing(r(N)) & r(N) >= 3
    frame dg_led: count if strpos(observed, ".%") | strpos(message, ".%")
    assert r(N) == 0
}
_dg `=_rc' "complete() maskrare: a masked share is omitted, never .%, in the console and the ledger"
capture frame drop dg_led
capture erase "`dgcl'"
capture frame drop dg_b

* ============================================================
* 26. dataqa findings 2026-09-30: groupstat() headers, masked shares (items 3 4)
* ============================================================

* === End columns of the blank-separated tokens of a line ===
capture program drop _dg_ends
program define _dg_ends, rclass
    args line
    local ends ""
    local len = length(`"`line'"')
    forvalues i = 1/`len' {
        local c = substr(`"`line'"', `i', 1)
        local nx = substr(`"`line'"', `i' + 1, 1)
        if `"`c'"' != " " & (`"`nx'"' == " " | `"`nx'"' == "") local ends "`ends' `i'"
    }
    local ends = strtrim("`ends'")
    return local ends "`ends'"
    return scalar n = wordcount("`ends'")
end

* groupstat(): 12-character abbreviations stay separated, and each header
* ends in the column its cells end in
sysuse auto, clear
gen headroom_rating = headroom
gen displacement_cc = displacement
capture log close _dgq
log using "`lg'", text replace name(_dgq)
capture noisily datacheck, gatesonly groupstat(pmiss headroom_rating displacement_cc, by(foreign))
local grc = _rc
log close _dgq
capture {
    assert `grc' == 0
    tempname gfh
    local hdr ""
    local nrow = 0
    file open `gfh' using "`lg'", read text
    file read `gfh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "  Group ") == 1 & strpos(`"`line'"', "headroom_r~g") local hdr `"`line'"'
        else if `"`hdr'"' != "" & inlist(word(`"`line'"', 1), "Domestic", "Foreign", "pooled") {
            local ++nrow
            local row`nrow' `"`line'"'
        }
        file read `gfh' line
    }
    file close `gfh'
    assert `nrow' == 3
    * Group, headroom_r~g, displaceme~c: three tokens, not two run together
    _dg_ends `"`hdr'"'
    assert r(n) == 3
    local hends "`r(ends)'"
    forvalues k = 1/3 {
        _dg_ends `"`row`k''"'
        assert r(n) == 3
        assert word("`r(ends)'", 2) == word("`hends'", 2) & word("`r(ends)'", 3) == word("`hends'", 3)
    }
    * at least one blank before each column
    assert strpos(`"`hdr'"', " headroom_r~g displaceme~c") > 0
}
_dg `=_rc' "groupstat(): 12-character headers are separated and end in their cells' column"
capture file close `gfh'

* _datacheck_mshare r(pcttxt): the share ready to print
capture {
    _datacheck_mshare 12 100 5
    assert "`r(pcttxt)'" == "12.0%" & "`r(pct)'" == "12.0"
    _datacheck_mshare 2 100 5
    assert "`r(pcttxt)'" == "[masked]" & "`r(pct)'" == "."
    _datacheck_mshare 98 100 5
    assert "`r(pcttxt)'" == "[masked]"
    _datacheck_mshare 0 100 5
    assert "`r(pcttxt)'" == "0.0%"
    _datacheck_mshare 0 0 5
    assert "`r(pcttxt)'" == "n/a" & "`r(pct)'" == "."
    _datacheck_mshare 2 100 0
    assert "`r(pcttxt)'" == "2.0%"
}
_dg `=_rc' "_datacheck_mshare: r(pcttxt) is 12.0%, [masked], or n/a"

* heaping() and coverage() under maskrare: 200 dates, 2 on 1 January 2021
* and 2 on 1 January 2030, outside [2020, 2021]; no share prints as .%.
* 1 January holds 4 dates (masked); the 1st holds 10 (5%), the 15th 7.
clear
set obs 200
gen visit_dt = td(01jan2020) + _n
replace visit_dt = td(01jan2021) in 1/2
replace visit_dt = td(01jan2030) in 3/4
format visit_dt %td
tempfile dgl4f
local dgl4 "`dgl4f'.dta"
capture erase "`dgl4'"
capture log close _dgq
log using "`lg'", text replace name(_dgq)
capture noisily datacheck, gatesonly maskrare name(visits) heaping(visit_dt) ///
    bands(coverage(visit_dt td(01jan2020) td(31dec2021), gap(400))) ledger("`dgl4'", run(h1))
local hrc = _rc
log close _dgq
capture frame drop dg_led
capture {
    assert `hrc' == 9
    _dg_count "`lg'" ".%"
    assert r(n) == 0
    _dg_count "`lg'" "[masked]"
    assert r(n) >= 1
    _dg_count "`lg'" "coverage(outside): <5 of visit_dt dates outside [01jan2020, 31dec2021], tail allows 0%"
    assert r(n) == 1
    frame create dg_led
    frame dg_led {
        use "`dgl4'", clear
        count if strpos(observed, ".%") | strpos(message, ".%") | strpos(message, "(.")
        assert r(N) == 0
        count if family == "heaping"
        assert r(N) == 1
        assert observed == "Jan 1 [masked], 1st 5.00%, 15th 3.50%" if family == "heaping"
        assert missing(observed_num) & obs_masked == 1 if family == "heaping"
        assert observed == "<5 dates outside" if family == "coverage" & label == "outside"
    }
    * unmasked, the share is printed with its sign once
    capture datacheck, gatesonly heaping(visit_dt) ///
        bands(coverage(visit_dt td(01jan2020) td(31dec2021), gap(400))) warn violations(dg_b, replace)
    frame dg_b: assert _N == 1 & observed[1] == "2 dates (1.0%) outside"
}
_dg `=_rc' "heaping()/coverage() maskrare: a masked share reads [masked], never .%; the message drops it"
capture frame drop dg_led
capture frame drop dg_b
capture erase "`dgl4'"

* heaping() with no nonmissing date prints n/a, not .%
clear
set obs 20
gen e_dt = .
format e_dt %td
capture log close _dgq
log using "`lg'", text replace name(_dgq)
capture noisily datacheck, gatesonly heaping(e_dt)
local hrc = _rc
log close _dgq
capture {
    assert `hrc' == 0
    _dg_count "`lg'" ".%"
    assert r(n) == 0
    _dg_count "`lg'" "n/a        n/a        n/a"
    assert r(n) == 1
}
_dg `=_rc' "heaping(): an empty date variable prints n/a for each share"

* groupstat() band: a failing value prints at full precision.  A constant
* float 0.2 has mean .200000003, above band(0 0.2); at %10.4g it read ".2",
* a value inside the band.  The table cell stays short.
clear
set obs 40
gen byte g = _n > 20
gen float x = 0.2
capture frame drop dg_gb
capture log close _dgq
log using "`lg'", text replace name(_dgq)
capture noisily datacheck, gatesonly groupstat(mean x, by(g) band(0 0.2)) warn violations(dg_gb, replace)
log close _dgq
capture {
    local xs = strtrim(string(float(0.2), "%14.0g"))
    assert "`xs'" != ".2"
    frame dg_gb: assert _N == 2
    frame dg_gb: assert regexm(observed[1], "^mean `xs'(;|$)") & regexm(observed[2], "^mean `xs'(;|$)")
    frame dg_gb: local o1 = observed[1]
    assert regexm("`o1'", "^mean ([^;]*)")
    assert real(regexs(1)) > 0.2
    _dg_count "`lg'" "groupstat(mean x): mean `xs' in group 0, expected [0, .2]"
    assert r(n) == 1
    _dg_count "`lg'" "mean .2 in group"
    assert r(n) == 0
    * the cells keep %10.4g
    local pl : display "  " %-24s "pooled" %13s ".2"
    _dg_count "`lg'" "`pl'"
    assert r(n) == 1
}
_dg `=_rc' "groupstat() band: a failing value prints at full precision, cells stay short"
capture frame drop dg_gb

* heaping() and coverage(): a daily date without a date display format is
* refused, and the message says how to fix it; %-td and %tdCCYY-NN-DD pass
clear
set obs 30
gen d = td(01jan2020) + _n
capture log close _dgq
log using "`lg'", text replace name(_dgq)
capture noisily datacheck, gatesonly heaping(d)
local rc1 = _rc
capture noisily datacheck, gatesonly coverage(d 01jan2020 31dec2020, gap(0))
local rc2 = _rc
log close _dgq
capture {
    assert `rc1' == 198 & `rc2' == 198
    _dg_count "`lg'" "heaping(): d must be a daily (%td) date; give it a daily date display format, e.g. format d %td"
    assert r(n) == 1
    _dg_count "`lg'" "coverage(): d must be a daily (%td) date; give it a daily date display format, e.g. format d %td"
    assert r(n) == 1
    foreach f in %-td %tdCCYY-NN-DD {
        format d `f'
        capture datacheck, gatesonly heaping(d)
        assert _rc == 0
        * the dates run from 2 to 31 January 2020
        capture datacheck, gatesonly coverage(d 02jan2020 31jan2020, gap(0))
        assert _rc == 0
    }
}
_dg `=_rc' "heaping()/coverage(): an unformatted date is r(198) with the format fix named; %-td and %tdCCYY-NN-DD pass"

* groupstat(relative): the cells are the ratios band() tests, as the
* heading says; the pooled row stays raw.  Oracle: summarize, detail.
sysuse auto, clear
quietly summarize price if rep78 == 4, detail
local m4 = r(p50)
quietly summarize price, detail
local m0 = r(p50)
local r4 = strtrim(string(`m4' / `m0', "%10.4g"))
local p0 = strtrim(string(`m0', "%10.4g"))
capture frame drop dg_gr
capture log close _dgq
log using "`lg'", text replace name(_dgq)
capture noisily datacheck, gatesonly groupstat(median price, by(rep78) relative band(0.9 1.1)) ///
    warn violations(dg_gr, replace)
log close _dgq
capture {
    local l4 : display "  " %-24s "4" %13s "`r4'"
    _dg_count "`lg'" "`l4'"
    assert r(n) == 1
    local lp : display "  " %-24s "pooled" %13s "`p0'"
    _dg_count "`lg'" "`lp'"
    assert r(n) == 1
    * the raw median is not printed as a cell
    local l4raw : display "  " %-24s "4" %13s strtrim(string(`m4', "%10.4g"))
    _dg_count "`lg'" "`l4raw'"
    assert r(n) == 0
    * the failure reports the same ratio
    frame dg_gr: assert _N == 1
    frame dg_gr: local o1 = observed[1]
    assert regexm("`o1'", "^ratio to pooled ([^;]*)")
    assert abs(real(regexs(1)) - `m4' / `m0') < 1e-9
}
_dg `=_rc' "groupstat(relative): cells show group/pooled, the value band() tests; pooled stays raw"
capture frame drop dg_gr

* heaping()/coverage(): a date in another unit gets the conversion, not
* the display-format advice
clear
set obs 30
gen tm = ym(2020, 1) + _n
format tm %tm
gen double tc = cofd(td(01jan2020) + _n)
format tc %tc
gen double tbig = tc
format tbig %tC
gen tq = yq(2020, 1) + _n
format tq %tq
capture log close _dgq
log using "`lg'", text replace name(_dgq)
capture noisily datacheck, gatesonly heaping(tm)
local rc1 = _rc
capture noisily datacheck, gatesonly coverage(tc 01jan2020 31dec2020, gap(0))
local rc2 = _rc
capture noisily datacheck, gatesonly heaping(tbig)
local rc3 = _rc
capture noisily datacheck, gatesonly coverage(tq 01jan2020 31dec2020, gap(0))
local rc4 = _rc
log close _dgq
capture {
    assert `rc1' == 198 & `rc2' == 198 & `rc3' == 198 & `rc4' == 198
    _dg_count "`lg'" "heaping(): tm has a %tm format, not a daily (%td) date; convert it to a daily date with dofm()"
    assert r(n) == 1
    _dg_count "`lg'" "coverage(): tc has a %tc format, not a daily (%td) date; convert it to a daily date with dofc()"
    assert r(n) == 1
    _dg_count "`lg'" "heaping(): tbig has a %tC format, not a daily (%td) date; convert it to a daily date with dofC()"
    assert r(n) == 1
    _dg_count "`lg'" "coverage(): tq has a %tq format, not a daily (%td) date; convert it to a daily date with dofq()"
    assert r(n) == 1
    _dg_count "`lg'" "format tm %td"
    assert r(n) == 0
    _dg_count "`lg'" "display format"
    assert r(n) == 0
}
_dg `=_rc' "heaping()/coverage(): %tm, %tc, %tC, %tq dates get the dof*() conversion, no format advice"

* groupstat(relative) with a pooled value of 0: the ratio is undefined; one
* failure says so, whatever each group holds
clear
set obs 40
gen byte g = ceil(_n / 20)
gen double z = 0
capture frame drop dg_gz
capture {
    capture datacheck, gatesonly groupstat(median z, by(g) band(0.9 1.1) relative) warn violations(dg_gz, replace)
    assert _rc == 0
    frame dg_gz: assert _N == 1
    frame dg_gz: assert observed[1] == "pooled 0"
    frame dg_gz: assert message[1] == "groupstat(median z): ratio to pooled undefined, pooled median 0, expected ratio to pooled in [.9, 1.1]"
    capture datacheck, gatesonly groupstat(median z, by(g) band(0.9 1.1) relative)
    assert _rc == 9
}
_dg `=_rc' "groupstat(relative): a pooled value of 0 fails once as an undefined ratio"
capture frame drop dg_gz

* groupstat() under the mask: one withheld marker in a column.  pmiss and
* a count masked in a ratio column read [suppr.], never "." or "<5"
sysuse auto, clear
capture log close _dgq
log using "`lg'", text replace name(_dgq)
capture noisily datacheck, gatesonly maskrare groupstat(pmiss rep78, by(foreign))
capture noisily datacheck, gatesonly maskrare groupstat(n rep78, by(rep78) relative band(0 10))
log close _dgq
capture {
    * 4 of 52 domestic and 1 of 22 foreign rep78 are missing: both masked
    local ld : display "  " %-24s "Domestic" %13s "[suppr.]"
    _dg_count "`lg'" "`ld'"
    assert r(n) == 1
    local lf : display "  " %-24s "Foreign" %13s "[suppr.]"
    _dg_count "`lg'" "`lf'"
    assert r(n) == 1
    local c5 : display %13s "<5"
    _dg_count "`lg'" "`c5'"
    assert r(n) == 0
}
_dg `=_rc' "groupstat() masking: pmiss and ratio cells use [suppr.], not . or <5"

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
