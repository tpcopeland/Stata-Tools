* test_pct_floor.do - 2.6.0 percentage display rule (_tabtools_fmt_pct)
*
* A percentage above 0 and below 100 never prints as 0 or 100. Where the
* requested decimals round it there, it gains one decimal at a time up to
* max(d, 2), then prints <0.01 or >99.99. A true 0 or 100, a missing value
* and a non-fixed (%g) format print as string() always did.
*
* F1  helper scalar mode: a literal table of value x format -> text,
*     including decimal-comma formats and a d = 3 cap (<0.001)
* F2  helper variable mode equals scalar mode over a grid, and the grid
*     obeys the rule's invariants (never 0/100 inside (0,100); escalated
*     text within half a unit of the value; unescalated text is string())
* F3  table1_tc bin, bine, cat at the default %5.0f (1 in 1,000 -> 0.1;
*     999 in 1,000 -> 99.9); true 0 and 100 unchanged
* F4  percformat(%5.1f): 1 in 2,500 -> 0.04; 1 in 200,000 -> <0.01; a
*     per-variable %fmt; catrowperc
* F5  table1_tc missing and missingsummary rows (incl. wtcompare crude and
*     weighted columns) and headerperc; headerperc beside a withheld
*     group N prints no "(.)"
* F6  weighted columns: a rare level escalates; a level holding every
*     weighted observation still prints 100 (sum-order ulp is not "not all")
* F7  crosstab colpct, rowpct, totalpct at digits(1) and digits(0)
* F8  tabcell np, nocount, ci(exact) (limits follow escalated decimals), enp
* F9  survtab survival and reverse percentages
*
* Run from tabtools/qa.

clear all
version 17.0
set more off
set varabbrev off

capture log close _pfl
log using "test_pct_floor.log", replace text name(_pfl)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

local pass_count = 0
local fail_count = 0
local test_count = 0

* _f_cell FACTOR COL: r(s) = trimmed COL in the first row whose trimmed
* factor is FACTOR, from the data in memory (a table1_tc ..., clear table);
* OCC() picks the #th such row
capture program drop _f_cell
program define _f_cell, rclass
    syntax anything(name=fac), col(name) [occ(integer 1)]
    gettoken fac : fac
    local s ""
    local seen 0
    forvalues i = 1/`=_N' {
        if strtrim(factor[`i']) == `"`fac'"' {
            local ++seen
            if `seen' == `occ' {
                local s = strtrim(`col'[`i'])
                continue, break
            }
        }
    }
    return local s `"`s'"'
end

* _f_fcell FRAME KEY COL: r(s) = trimmed COL in the first row of FRAME whose
* trimmed c1 is KEY
capture program drop _f_fcell
program define _f_fcell, rclass
    args fr key col
    local s ""
    frame `fr' {
        forvalues i = 1/`=_N' {
            if strtrim(c1[`i']) == `"`key'"' {
                local s = strtrim(`col'[`i'])
                continue, break
            }
        }
    }
    return local s `"`s'"'
end

* _f_is TEXT EXPECTED: error 9 with a message when they differ
capture program drop _f_is
program define _f_is
    args got want
    if `"`got'"' != `"`want'"' {
        display as error `"    got [`got'], expected [`want']"'
        exit 9
    }
end

**# F1 helper scalar mode
local ++test_count
capture noisily {
    * value | format | expected
    local cases ""
    local cases `"`cases' "0|%5.0f|0" "0|%5.1f|0.0" ".|%5.0f|." "0.004|%5.0f|<0.01""'
    local cases `"`cases' "0.004|%5.1f|<0.01" "0.004|%5.2f|<0.01" "0.004|%5.3f|0.004" "0.04|%5.0f|0.04""'
    local cases `"`cases' "0.04|%5.1f|0.04" "0.3|%5.0f|0.3" "0.3|%5.1f|0.3" "0.6|%5.0f|1""'
    local cases `"`cases' "12.5|%5.1f|12.5" "99.4|%5.0f|99" "99.6|%5.0f|99.6" "99.96|%5.0f|99.96""'
    local cases `"`cases' "99.96|%5.1f|99.96" "99.995|%5.1f|>99.99" "99.99996|%6.3f|>99.999" "100|%5.0f|100""'
    local cases `"`cases' "100|%5.1f|100.0" "0.04|%9.1fc|0.04" "0.04|%5.1g|.04" "1e-12|%5.1f|0.0""'
    local cases `"`cases' "99.99999999999|%5.0f|100""'
    foreach c of local cases {
        local c = subinstr(`"`c'"', "|", " ", .)
        gettoken v rest : c
        gettoken f want : rest
        local want = strtrim(`"`want'"')
        _tabtools_fmt_pct, value(`v') format(`f')
        _f_is `"`r(text)'"' `"`want'"'
    }
    * decimal-comma formats escalate and cap with their comma; d > 2 caps at d
    local ccases `" "0.04|%5,1f|0,04" "99.96|%5,1f|99,96" "0.004|%5,0f|<0,01" "0.3|%5,1f|0,3" "0|%5,1f|0,0" "0.0004|%6.3f|<0.001" "'
    foreach c of local ccases {
        local c = subinstr(`"`c'"', "|", " ", .)
        gettoken v rest : c
        gettoken f want : rest
        local want = strtrim(`"`want'"')
        _tabtools_fmt_pct, value(`v') format(`f')
        _f_is `"`r(text)'"' `"`want'"'
    }
    * r(decimals) is set only where the rule escalated or capped
    _tabtools_fmt_pct, value(0.3) format(%5.0f)
    assert r(decimals) == 1
    _tabtools_fmt_pct, value(0.004) format(%5.1f)
    assert r(decimals) == 2
    _tabtools_fmt_pct, value(0.3) format(%5.1f)
    assert missing(r(decimals))
    * value() is an expression evaluated at full precision: 100*7/20000 is
    * 0.034999999999999996, which a macro round trip turns into .035
    _tabtools_fmt_pct, value(100 * 7 / 20000) format(%5.0f)
    _f_is `"`r(text)'"' "0.03"
    * a value that is not an expression is refused
    capture _tabtools_fmt_pct, value(1 +) format(%5.1f)
    assert _rc
}
if _rc == 0 {
    display as result "  PASS: F1 helper scalar mode, literal table"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 helper scalar mode (rc=`=_rc')"
    local ++fail_count
}

**# F2 helper variable mode == scalar mode; rule invariants over a grid
local ++test_count
capture noisily {
    clear
    set seed 26100801
    quietly set obs 3000
    gen double v = .
    * edges, then counts over denominators, then uniform draws
    quietly replace v = 0 in 1
    quietly replace v = 100 in 2
    quietly replace v = 1e-15 in 3
    quietly replace v = 100 - 1e-15 in 4
    quietly replace v = 100 * (_n - 4) / 20000 in 5/1000
    quietly replace v = 100 - 100 * (_n - 1000) / 20000 in 1001/2000
    quietly replace v = 100 * runiform() in 2001/3000
    foreach f in %5.0f %4.1f %5.2f %9.1fc %5,1f {
        capture drop t dd
        _tabtools_fmt_pct v, format(`f') generate(t) decimals(dd)
        local d = real(substr("`f'", strpos(subinstr("`f'", ",", ".", 1), ".") + 1, 1))
        local cap = max(`d', 2)
        forvalues i = 1/`=_N' {
            _tabtools_fmt_pct, value(v[`i']) format(`f')
            if `"`r(text)'"' != strtrim(t[`i']) {
                display as error "    `f' row `i' v=`=v[`i']': scalar [`r(text)'] vs variable [`=t[`i']']"
                exit 9
            }
        }
        * inside (0,100), with the 1e-9 tolerance: never 0 or 100
        gen byte inside = v > 1e-9 & v < 100 - 1e-9
        gen double tn = real(subinstr(t, ",", ".", .))
        assert !inlist(tn, 0, 100) if inside
        * capped text only where the value is within half a unit of the cap
        assert v < 0.5 * 10^(-`cap') if substr(t, 1, 1) == "<" & inside
        assert v >= 100 - 0.5 * 10^(-`cap') if substr(t, 1, 1) == ">" & inside
        * escalated text is within half a unit of the value at its decimals
        assert abs(tn - v) <= 0.5 * 10^(-dd) + 1e-12 if !missing(dd) & !inlist(substr(t, 1, 1), "<", ">")
        * unescalated rows are string() exactly
        assert t == string(v, "`f'") if missing(dd)
        drop inside tn
    }
}
if _rc == 0 {
    display as result "  PASS: F2 variable mode equals scalar mode; invariants over 3,000 values x 5 formats"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 helper variable mode (rc=`=_rc')"
    local ++fail_count
}

capture program drop _f_data
program define _f_data
    clear
    quietly set obs 2000
    gen byte grp = _n > 1000
    gen byte rare = _n == 1 | _n == 1001
    gen byte cat3 = cond(_n == 1, 1, cond(_n < 1500, 2, 3))
    gen byte bine = rare
    gen byte allone = 1
end

**# F3 table1_tc default %5.0f
local ++test_count
capture noisily {
    _f_data
    table1_tc, by(grp) vars(rare bin \ cat3 cat \ bine bine) clear
    _f_cell rare, col(grp_0)
    _f_is `"`r(s)'"' "1 (0.1)"
    _f_cell bine, col(grp_1)
    _f_is `"`r(s)'"' "1 (0.1)"
    _f_cell 1, col(grp_0)
    _f_is `"`r(s)'"' "1 (0.1)"
    _f_cell 1, col(grp_1)
    _f_is `"`r(s)'"' "0 (0)"
    _f_cell 2, col(grp_0)
    _f_is `"`r(s)'"' "999 (99.9)"
    _f_cell 2, col(grp_1)
    _f_is `"`r(s)'"' "499 (50)"
    _f_cell 3, col(grp_0)
    _f_is `"`r(s)'"' "0 (0)"
    * a level holding the whole group still prints 100
    _f_data
    table1_tc, by(grp) vars(allone bin) clear
    _f_cell allone, col(grp_0)
    _f_is `"`r(s)'"' "1,000 (100)"
}
if _rc == 0 {
    display as result "  PASS: F3 table1_tc bin/bine/cat at %5.0f: 0.1 and 99.9, true 0 and 100 kept"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 table1_tc default format (rc=`=_rc')"
    local ++fail_count
}

**# F4 percformat(%5.1f), per-variable %fmt, catrowperc
local ++test_count
capture noisily {
    clear
    quietly set obs 402500
    gen byte grp = _n > 2500
    * grp 0: 1 of 2,500 (0.04%); grp 1: 1 of 400,000 (0.00025%)
    gen byte y = inlist(_n, 1, 2501)
    table1_tc, by(grp) vars(y bin) percformat(%5.1f) clear
    _f_cell y, col(grp_0)
    _f_is `"`r(s)'"' "1 (0.04)"
    _f_cell y, col(grp_1)
    _f_is `"`r(s)'"' "1 (<0.01)"
    * a per-variable format follows the same rule
    clear
    quietly set obs 402500
    gen byte grp = _n > 2500
    gen byte y = inlist(_n, 1, 2501)
    table1_tc, by(grp) vars(y bin %5.0f) clear
    _f_cell y, col(grp_0)
    _f_is `"`r(s)'"' "1 (0.04)"
    * catrowperc: 1 of 1 row is 100, 0 of 1 stays 0, 999/1,498 is 67
    _f_data
    table1_tc, by(grp) vars(cat3 cat) catrowperc clear
    _f_cell 1, col(grp_0)
    _f_is `"`r(s)'"' "1 (100)"
    _f_cell 1, col(grp_1)
    _f_is `"`r(s)'"' "0 (0)"
    _f_cell 2, col(grp_0)
    _f_is `"`r(s)'"' "999 (67)"
}
if _rc == 0 {
    display as result "  PASS: F4 percformat %5.1f gives 0.04 and <0.01; per-variable format; catrowperc"
    local ++pass_count
}
else {
    display as error "  FAIL: F4 percformat and catrowperc (rc=`=_rc')"
    local ++fail_count
}

**# F5 missing rows and headerperc
local ++test_count
capture noisily {
    _f_data
    replace cat3 = . in 2
    table1_tc, by(grp) vars(cat3 cat) missing clear
    _f_cell Missing, col(grp_0)
    _f_is `"`r(s)'"' "1 (0.1)"
    * missingsummary rows (desctab.ado), plain and the wtcompare crude and
    * weighted columns
    clear
    quietly set obs 2000
    gen byte grp = _n > 1000
    gen x = cond(_n == 5, ., _n)
    gen double w = 0.1 + mod(_n, 7) / 3
    table1_tc, by(grp) vars(x contn) missingsummary clear
    _f_cell Missing, col(grp_0)
    _f_is `"`r(s)'"' "1 (0.1)"
    _f_cell Missing, col(grp_1)
    _f_is `"`r(s)'"' "0"
    clear
    quietly set obs 2000
    gen byte grp = _n > 1000
    gen x = cond(_n == 5, ., _n)
    gen double w = 0.1 + mod(_n, 7) / 3
    table1_tc, by(grp) vars(x contn) missingsummary wt(w) wtcompare clear
    _f_cell Missing, col(Cr_0)
    _f_is `"`r(s)'"' "1 (0.1)"
    _f_cell Missing, col(Wt_0)
    _f_is `"`r(s)'"' "1 (0.1)"
    * headerperc: two groups of 1 in 3,000 print 0.03
    clear
    quietly set obs 3000
    gen byte g = 1 + (_n > 1) + (_n > 2)
    gen byte y = mod(_n, 2)
    table1_tc, by(g) vars(y bin) headerperc clear
    _f_cell "No. (Column %)", col(g_1)
    _f_is `"`r(s)'"' "1 (0.03)"
    _f_cell "No. (Column %)", col(g_3)
    _f_is `"`r(s)'"' "2,998 (99.9)"
    * a percentage with a withheld group N beside it is omitted, not "(.)"
    clear
    quietly set obs 3000
    gen byte g = 1 + (_n > 2) + (_n > 3)
    gen byte y = mod(_n, 2)
    table1_tc, by(g) vars(y bin) headerperc smallcells(5) clear
    _f_cell "No. (Column %)", col(g_3)
    _f_is `"`r(s)'"' "2,997"
}
if _rc == 0 {
    display as result "  PASS: F5 missing and missingsummary rows 0.1 (incl. wtcompare), headerperc 0.03, no (.) beside a withheld N"
    local ++pass_count
}
else {
    display as error "  FAIL: F5 missing rows and headerperc (rc=`=_rc')"
    local ++fail_count
}

**# F6 weighted columns
local ++test_count
capture noisily {
    _f_data
    gen double w = 0.1 + mod(_n, 7) / 3
    table1_tc, by(grp) vars(rare bin \ allone bin) wt(w) clear
    _f_cell rare, col(grp_0)
    local s `"`r(s)'"'
    assert !inlist(real(`"`s'"'), 0, 100) & !missing(real(`"`s'"'))
    _f_cell allone, col(grp_0)
    _f_is `"`r(s)'"' "100"
    _f_cell allone, col(grp_1)
    _f_is `"`r(s)'"' "100"
}
if _rc == 0 {
    display as result "  PASS: F6 weighted rare level escalates; a full weighted level prints 100"
    local ++pass_count
}
else {
    display as error "  FAIL: F6 weighted columns (rc=`=_rc')"
    local ++fail_count
}

**# F7 crosstab
local ++test_count
capture noisily {
    _f_data
    crosstab cat3 grp, frame(_fct)
    _f_fcell _fct 1 c2
    _f_is `"`r(s)'"' "1 (0.1%)"
    _f_fcell _fct 1 c3
    _f_is `"`r(s)'"' "0 (0.0%)"
    _f_fcell _fct 2 c2
    _f_is `"`r(s)'"' "999 (99.9%)"
    frame drop _fct
    crosstab cat3 grp, rowpct digits(0) frame(_fct)
    _f_fcell _fct 1 c2
    _f_is `"`r(s)'"' "1 (100%)"
    _f_fcell _fct 2 c2
    _f_is `"`r(s)'"' "999 (67%)"
    frame drop _fct
    crosstab cat3 grp, colpct digits(0) frame(_fct)
    _f_fcell _fct 1 c2
    _f_is `"`r(s)'"' "1 (0.1%)"
    _f_fcell _fct 2 c2
    _f_is `"`r(s)'"' "999 (99.9%)"
    frame drop _fct
    crosstab cat3 grp, totalpct digits(0) frame(_fct)
    * 1 of 2,000 is 0.05%, which rounds half up to 0.1 at one decimal
    _f_fcell _fct 1 c2
    _f_is `"`r(s)'"' "1 (0.1%)"
    frame drop _fct
}
if _rc == 0 {
    display as result "  PASS: F7 crosstab colpct/rowpct/totalpct at digits(1) and digits(0)"
    local ++pass_count
}
else {
    display as error "  FAIL: F7 crosstab (rc=`=_rc')"
    capture frame drop _fct
    local ++fail_count
}

**# F8 tabcell
local ++test_count
capture noisily {
    tabcell np, n(1) d(1000)
    _f_is `"`r(cell)'"' "1 (0.1)"
    tabcell np, n(1) d(10000) pformat(%4.0f)
    _f_is `"`r(cell)'"' "1 (0.01)"
    tabcell np, n(1) d(10) nocount
    _f_is `"`r(cell)'"' "10.0"
    tabcell np, n(1) d(1000) nocount pformat(%4.0f)
    _f_is `"`r(cell)'"' "0.1"
    tabcell np, n(0) d(1000)
    _f_is `"`r(cell)'"' "0 (0.0)"
    tabcell np, n(1000) d(1000)
    _f_is `"`r(cell)'"' "1,000 (100.0)"
    tabcell np, n(99999) d(100000)
    _f_is `"`r(cell)'"' "99,999 (>99.99)"
    * the exact limits print at the escalated decimals; unescalated, at pformat()
    tabcell np, n(1) d(100000) ci(exact)
    _f_is `"`r(cell)'"' "1 (<0.01; 0.00, 0.01)"
    tabcell np, n(1) d(5000) ci(exact) nocount
    _f_is `"`r(cell)'"' "0.02 (0.00, 0.11)"
    tabcell np, n(2) d(20) ci(exact)
    _f_is `"`r(cell)'"' "2 (10.0; 1.2, 31.7)"
    tabcell np, n(1) d(3000) pformat(%5,1f)
    _f_is `"`r(cell)'"' "1 (0,03)"
    tabcell np, n(1) d(100000) pformat(%5,1f) ci(exact) sep("; ")
    _f_is `"`r(cell)'"' "1 (<0,01; 0,00; 0,01)"
    tabcell enp, e(1) n(5000)
    _f_is `"`r(cell)'"' "1/5,000 (0.02)"
    tabcell enp, e(0) n(5000)
    _f_is `"`r(cell)'"' "0/5,000 (0.0)"
}
if _rc == 0 {
    display as result "  PASS: F8 tabcell np/nocount/ci(exact)/enp"
    local ++pass_count
}
else {
    display as error "  FAIL: F8 tabcell (rc=`=_rc')"
    local ++fail_count
}

**# F9 survtab
local ++test_count
capture noisily {
    * 1 of 3,000 survives past t = 10: S(10) = 0.033%
    clear
    quietly set obs 3000
    gen t = cond(_n == 1, 20, 1 + mod(_n, 5))
    gen byte d = 1
    quietly stset t, failure(d)
    survtab, times(10) frame(_fsv)
    _f_fcell _fsv "10 years" c2
    _f_is `"`r(s)'"' "0.03%"
    frame drop _fsv
    * reverse: 1 of 3,000 fails by t = 1: F(1) = 0.033%
    clear
    quietly set obs 3000
    gen t = cond(_n == 1, 1, 50)
    gen byte d = _n == 1
    quietly stset t, failure(d)
    survtab, times(1) reverse frame(_fsv)
    _f_fcell _fsv "1 yr" c2
    _f_is `"`r(s)'"' "0.03%"
    frame drop _fsv
    survtab, times(1) frame(_fsv)
    _f_fcell _fsv "1 yr" c2
    _f_is `"`r(s)'"' "99.97%"
    frame drop _fsv
    * no event by t: survival 100 stays 100
    replace t = t + 1
    quietly stset t, failure(d)
    survtab, times(1) frame(_fsv)
    _f_fcell _fsv "1 yr" c2
    _f_is `"`r(s)'"' "100.0%"
    frame drop _fsv
}
if _rc == 0 {
    display as result "  PASS: F9 survtab survival and reverse 0.03%, 99.97%, 100.0%"
    local ++pass_count
}
else {
    display as error "  FAIL: F9 survtab (rc=`=_rc')"
    capture frame drop _fsv
    local ++fail_count
}

display "RESULT: test_pct_floor tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _pfl
if `fail_count' > 0 exit 9
