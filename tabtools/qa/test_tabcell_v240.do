* test_tabcell_v240.do - tabcell local()/global(), pstyle(Pfootnote), np ci(exact)
*
* Oracles: hand-built strings; the exact binomial limits from Stata's own
* cii proportions, exact (r(lb), r(ub)) and, independently of any beta
* quantile, from the defining tail equations of Clopper and Pearson (1934):
* Pr(K >= k | p = lb) = a/2 and Pr(K <= k | p = ub) = a/2, K ~ binomial(d, p),
* evaluated with binomialtail() and binomial(). The footnote styles are
* checked against the table style's number (tabcell p, table style), which
* test_tabcell_v230.do pins to regtab.

clear all
set more off
set varabbrev off
version 17.0

capture log close _tc240
log using "test_tabcell_v240.log", replace text name(_tc240)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

local pass_count = 0
local fail_count = 0

* A program that calls tabcell, local(): the local must land in the
* program's scope (tabcell's caller), not in the do-file that called it.
capture program drop _tc240_inner
program define _tc240_inner, rclass
    version 17.0
    tabcell n, n(42) local(inner)
    return local seen `"`inner'"'
end

**# L1: local() and global() store the cell; r() is still posted
capture noisily {
    local c "stale"
    tabcell n, n(12345) local(c)
    assert `"`c'"' == "12,345"
    assert `"`r(cell)'"' == "12,345" & "`r(form)'" == "n" & r(missing) == 0
    global TC240_G "stale"
    tabcell est, b(1.234) ll(1.01) ul(1.5) global(TC240_G)
    assert `"$TC240_G"' == "1.23 (1.01, 1.50)"
    assert r(estimate) == 1.234 & "`r(source)'" == "numbers"
    * both at once
    tabcell np, n(3) d(40) local(c2) global(TC240_G2)
    assert `"`c2'"' == "3 (7.5)" & `"$TC240_G2"' == "3 (7.5)"
    assert `"`c2'"' == `"`r(cell)'"'
    * every form stores
    tabcell p, p(0.0499) local(cp)
    assert `"`cp'"' == "0.050"
    tabcell enp, e(12) n(74) local(ce)
    assert `"`ce'"' == "12/74 (16.2)"
    tabcell iqr, median(20) q1(18) q3(25) format(%4.0f) local(ci)
    assert `"`ci'"' == "20 (18, 25)"
    * a 31-character local name works (the longest Stata allows)
    tabcell n, n(7) local(abcdefghijklmnopqrstuvwxyzabcde)
    assert `"`abcdefghijklmnopqrstuvwxyzabcde'"' == "7"
    * inside a program the local lands in the program, not here
    local inner "untouched"
    _tc240_inner
    assert `"`r(seen)'"' == "42"
    assert `"`inner'"' == "untouched"
    * the empty missing("") cell stores an empty macro
    local ce2 "stale"
    tabcell n, n(.) missing("") local(ce2)
    assert `"`ce2'"' == "" & r(missing) == 1
}
if _rc == 0 {
    display as result "  PASS: L1 local()/global() store the cell, r() kept, program scope"
    local ++pass_count
}
else {
    display as error "  FAIL: L1 local()/global() (rc=`=_rc')"
    local ++fail_count
}
macro drop TC240_G TC240_G2

**# L2: embedded quotes, backquotes and dollar signs survive as data
capture noisily {
    tabcell est, b(.) ll(.) ul(.) missing(`"say "hi""') local(q)
    assert `"`macval(q)'"' == `"say "hi""'
    assert `"`macval(q)'"' == `"`r(cell)'"'
    tabcell est, b(.) ll(.) ul(.) missing(`"a `"b"' c"') local(q2) global(TC240_Q)
    assert `"`macval(q2)'"' == `"a `"b"' c"'
    assert `"$TC240_Q"' == `"a `"b"' c"'
    * a $ and a ` in the text are not re-expanded
    global TC240_X "EXPANDED"
    * (built by an expression: a caller line re-scans `_dl'TC240_X itself)
    local _mt = "cost " + char(36) + "TC240_X"
    tabcell n, n(.) missing(`"`macval(_mt)'"') local(q3)
    assert `"`macval(q3)'"' == "cost " + char(36) + "TC240_X"
    * the defect behind it predates local(): r(cell) printed "cost EXPANDED"
    * (read through Mata: `r(cell)' in an assert line is itself re-scanned)
    mata: st_local("_rcell", st_global("r(cell)"))
    assert `"`macval(_rcell)'"' == "cost " + char(36) + "TC240_X"
    local _mt = "x" + char(96) + "y"
    tabcell n, n(.) missing(`"`macval(_mt)'"') local(q4)
    assert `"`macval(q4)'"' == "x" + char(96) + "y"
}
if _rc == 0 {
    display as result "  PASS: L2 compound and embedded quotes, \$ and backquote stored verbatim"
    local ++pass_count
}
else {
    display as error "  FAIL: L2 quote handling (rc=`=_rc')"
    local ++fail_count
}
macro drop TC240_Q TC240_X

**# L3: name validation and refusals
capture noisily {
    capture tabcell n, n(3) local(abcdefghijklmnopqrstuvwxyzabcdef)
    assert _rc == 198
    capture tabcell n, n(3) local(1abc)
    assert _rc == 198
    capture tabcell n, n(3) local(a b)
    assert _rc == 103
    capture tabcell n, n(3) global(_x)
    assert _rc == 198
    capture tabcell n, n(3) global(1abc)
    assert _rc == 198
    * a 32-character global is legal
    tabcell n, n(3) global(abcdefghijklmnopqrstuvwxyzabcdef)
    assert "$abcdefghijklmnopqrstuvwxyzabcdef" == "3"
    macro drop abcdefghijklmnopqrstuvwxyzabcdef
    capture tabcell n, n(3) global(abcdefghijklmnopqrstuvwxyzabcdefg)
    assert _rc == 198
    * generate() makes a variable, not a cell
    clear
    set obs 2
    gen double k = _n
    capture tabcell n, n(k) generate(cell) local(c)
    assert _rc == 198
    capture confirm variable cell
    assert _rc == 111
    capture tabcell n, n(k) generate(cell) global(TC240_C)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: L3 bad names and generate() with local()/global() refused"
    local ++pass_count
}
else {
    display as error "  FAIL: L3 name validation (rc=`=_rc')"
    local ++fail_count
}

**# L4: a failed call clears the macro (no stale cell)
capture noisily {
    local c "previous cell"
    global TC240_S "previous cell"
    capture tabcell p, p(2) local(c) global(TC240_S)
    assert _rc == 198
    assert `"`c'"' == ""
    assert `"$TC240_S"' == ""
    local c "previous cell"
    capture tabcell est, b(.) ll(.) ul(.) local(c)
    assert _rc == 459
    assert `"`c'"' == ""
    * a refused name clears nothing it did not validate
    local keep "kept"
    capture tabcell n, n(3) local(abcdefghijklmnopqrstuvwxyzabcdef)
    assert _rc == 198 & "`keep'" == "kept"
    * failures before or inside syntax (an unknown option, a bad form word)
    * clear the macros too: the names are read before anything can fail
    tabcell p, p(0.0123) local(x) global(TC240_S)
    assert "`x'" == "0.012" & "$TC240_S" == "0.012"
    capture tabcell p, p(0.5) local(x) global(TC240_S) bogus
    assert _rc == 198
    assert `"`x'"' == "" & `"$TC240_S"' == ""
    tabcell p, p(0.0123) local(x) global(TC240_S)
    capture tabcell pp, p(0.5) local(x) global(TC240_S)
    assert _rc == 198
    assert `"`x'"' == "" & `"$TC240_S"' == ""
    * a valid local() is cleared when the global() name is the failure
    tabcell p, p(0.0123) local(x)
    capture tabcell p, p(0.5) local(x) global(_bad)
    assert _rc == 198 & `"`x'"' == ""
}
if _rc == 0 {
    display as result "  PASS: L4 failure clears local()/global()"
    local ++pass_count
}
else {
    display as error "  FAIL: L4 failure clears macros (rc=`=_rc')"
    local ++fail_count
}
macro drop TC240_S

**# P1: pstyle(Pfootnote) is the footnote text with a capital P
capture noisily {
    foreach pv in 0 0.0000001 0.0004 0.000999 0.001 0.0123 0.0499 0.05 0.0999 0.1 0.5 0.989 0.99 0.991 0.9999 1 {
        foreach dp in "3 2" "4 3" "2 1" {
            local pd : word 1 of `dp'
            local hd : word 2 of `dp'
            tabcell p, p(`pv') pdp(`pd') highpdp(`hd')
            local tab `"`r(cell)'"'
            tabcell p, p(`pv') pdp(`pd') highpdp(`hd') pstyle(footnote)
            local low `"`r(cell)'"'
            tabcell p, p(`pv') pdp(`pd') highpdp(`hd') pstyle(Pfootnote)
            local cap `"`r(cell)'"'
            * the number is the table text; the letter is P
            if inlist(substr("`tab'", 1, 1), "<", ">") {
                local want = "P " + substr("`tab'", 1, 1) + " " + substr("`tab'", 2, .)
            }
            else local want = "P = `tab'"
            if `"`cap'"' != `"`want'"' {
                display as error "p=`pv' pdp=`pd': got [`cap'] want [`want']"
                exit 9
            }
            assert `"`low'"' == "p" + substr(`"`want'"', 2, .)
        }
    }
    * spelled examples
    tabcell p, p(0.0004) pstyle(Pfootnote)
    assert `"`r(cell)'"' == "P < 0.001"
    tabcell p, p(0.0123) pstyle(Pfootnote)
    assert `"`r(cell)'"' == "P = 0.012"
    tabcell p, p(0.995) pstyle(Pfootnote)
    assert `"`r(cell)'"' == "P > 0.99"
    tabcell p, p(0.0123) pstyle(footnote)
    assert `"`r(cell)'"' == "p = 0.012"
    * case-insensitive keyword; the table style is unchanged
    tabcell p, p(0.0123) pstyle(PFOOTNOTE)
    assert `"`r(cell)'"' == "P = 0.012"
    tabcell p, p(0.0123) pstyle(pfootnote)
    assert `"`r(cell)'"' == "P = 0.012"
    tabcell p, p(0.0123)
    assert `"`r(cell)'"' == "0.012"
    capture tabcell p, p(0.0123) pstyle(capital)
    assert _rc == 198
    * missing(): the text, not "P = ."
    tabcell p, p(.) pstyle(Pfootnote) missing("NA")
    assert `"`r(cell)'"' == "NA"
    * generate() renders the same strings row by row
    clear
    input double pv
    0.0004
    0.0123
    0.5
    0.995
    .
    end
    tabcell p, p(pv) pstyle(Pfootnote) missing("--") generate(pc)
    assert pc[1] == "P < 0.001" & pc[2] == "P = 0.012" & pc[3] == "P = 0.50"
    assert pc[4] == "P > 0.99" & pc[5] == "--"
}
if _rc == 0 {
    display as result "  PASS: P1 Pfootnote = footnote with capital P over a p grid, scalar and generate()"
    local ++pass_count
}
else {
    display as error "  FAIL: P1 pstyle(Pfootnote) (rc=`=_rc')"
    local ++fail_count
}

**# CI1: np ci(exact) against cii proportions, exact (k = 0 and k = d included)
capture noisily {
    local nchk 0
    foreach d in 1 2 5 20 40 137 1000 {
        local mid = floor(`d' / 3)
        local ks "0 1 `mid' `=`d'-1' `d'"
        local ks : list uniq ks
        foreach k of local ks {
            foreach lev in 90 95 99 {
                quietly cii proportions `d' `k', exact level(`lev')
                local olb = r(lb)
                local oub = r(ub)
                tabcell np, n(`k') d(`d') ci(exact) level(`lev')
                if reldif(r(lb) / 100, `olb') > 1e-10 | reldif(r(ub) / 100, `oub') > 1e-10 {
                    display as error "d=`d' k=`k' level=`lev': lb `=r(lb)/100' vs `olb', ub `=r(ub)/100' vs `oub'"
                    exit 9
                }
                assert r(level) == `lev' & "`r(citype)'" == "exact"
                assert reldif(r(pct), 100 * `k' / `d') < 1e-12
                * the printed text is the cii numbers in pformat()
                local want = strtrim(string(`k', "%12.0fc")) + " (" + ///
                    strtrim(string(100 * `k' / `d', "%4.1f")) + "; " + ///
                    strtrim(string(100 * `olb', "%4.1f")) + ", " + ///
                    strtrim(string(100 * `oub', "%4.1f")) + ")"
                if `"`r(cell)'"' != `"`want'"' {
                    display as error "d=`d' k=`k': cell [`r(cell)'] want [`want']"
                    exit 9
                }
                local ++nchk
            }
        }
    }
    display as text "  cii comparisons: `nchk'"
    assert `nchk' == 87
    * edges spelled out: k = 0 lower limit 0, k = d upper limit 100
    tabcell np, n(0) d(20) ci(exact)
    assert r(lb) == 0 & reldif(r(ub) / 100, 1 - 0.025^(1/20)) < 1e-12
    assert `"`r(cell)'"' == "0 (0.0; 0.0, 16.8)"
    tabcell np, n(20) d(20) ci(exact)
    assert r(ub) == 100 & reldif(r(lb) / 100, 0.025^(1/20)) < 1e-12
    assert `"`r(cell)'"' == "20 (100.0; 83.2, 100.0)"
    * [R] ci example 6: 2 of 20 promoted, 95%: .0123485, .3169827
    tabcell np, n(2) d(20) ci(exact) pformat(%6.4f)
    assert `"`r(cell)'"' == "2 (10.0000; 1.2349, 31.6983)"
}
if _rc == 0 {
    display as result "  PASS: CI1 Clopper-Pearson limits match cii proportions, exact (k=0, k=d, 3 levels)"
    local ++pass_count
}
else {
    display as error "  FAIL: CI1 cii crossval (rc=`=_rc')"
    local ++fail_count
}

**# CI2: the limits solve Clopper and Pearson's tail equations
* Independent of invibeta(): at p = lb, Pr(K >= k) = a/2; at p = ub,
* Pr(K <= k) = a/2. And just inside the interval both tails exceed a/2.
capture noisily {
    foreach dk in "10 3" "50 1" "50 49" "333 17" "7 0" "7 7" "2500 1250" {
        local d : word 1 of `dk'
        local k : word 2 of `dk'
        foreach lev in 80 95 99.5 {
            local a = (1 - `lev' / 100) / 2
            tabcell np, n(`k') d(`d') ci(exact) level(`lev')
            local lb = r(lb) / 100
            local ub = r(ub) / 100
            if `k' > 0 {
                assert abs(binomialtail(`d', `k', `lb') - `a') < 1e-9
                assert binomialtail(`d', `k', `lb' * (1 + 1e-6)) > `a'
            }
            else assert `lb' == 0
            if `k' < `d' {
                assert abs(binomial(`d', `k', `ub') - `a') < 1e-9
                assert binomial(`d', `k', `ub' * (1 - 1e-6)) > `a'
            }
            else assert `ub' == 1
            assert `lb' <= `k' / `d' & `k' / `d' <= `ub'
        }
    }
}
if _rc == 0 {
    display as result "  PASS: CI2 limits satisfy the binomial tail equations at a/2"
    local ++pass_count
}
else {
    display as error "  FAIL: CI2 tail equations (rc=`=_rc')"
    local ++fail_count
}

**# CI3: generate() column equals the scalar cells; masks, zero denominator
capture noisily {
    clear
    input double(k d)
    0 20
    2 20
    20 20
    3 40
    7 137
    0 0
    . 10
    end
    tabcell np, n(k) d(d) ci(exact) level(90) mincell(5) missing("n/a") generate(cell)
    assert r(N) == 6 & r(N_missing) == 1
    forvalues i = 1/6 {
        local kk = k[`i']
        local dd = d[`i']
        tabcell np, n(`kk') d(`dd') ci(exact) level(90) mincell(5)
        assert cell[`i'] == `"`r(cell)'"'
    }
    assert cell[7] == "n/a"
    * masked count: no percentage, no interval, limits not returned
    assert cell[4] == "<5"
    tabcell np, n(3) d(40) ci(exact) mincell(5)
    assert `"`r(cell)'"' == "<5" & missing(r(lb)) & missing(r(ub)) & missing(r(pct))
    * zero denominator: the count alone, no limits
    assert cell[6] == "0"
    tabcell np, n(0) d(0) ci(exact)
    assert `"`r(cell)'"' == "0" & missing(r(lb)) & missing(r(ub))
    * sep() and pformat() apply to the limits
    tabcell np, n(2) d(20) ci(exact) sep(" to ") pformat(%5.2f)
    assert `"`r(cell)'"' == "2 (10.00; 1.23 to 31.70)"
    * without ci() np is unchanged
    tabcell np, n(2) d(20)
    assert `"`r(cell)'"' == "2 (10.0)"
    assert missing(r(lb))
}
if _rc == 0 {
    display as result "  PASS: CI3 generate() = scalar, mincell mask, d = 0, sep()/pformat()"
    local ++pass_count
}
else {
    display as error "  FAIL: CI3 generate/masks (rc=`=_rc')"
    local ++fail_count
}

**# CI4: refusals
capture noisily {
    capture tabcell np, n(2.5) d(20) ci(exact)
    assert _rc == 459
    capture tabcell np, n(2) d(20.5) ci(exact)
    assert _rc == 459
    clear
    input double(k d)
    1 10
    1.5 10
    end
    capture tabcell np, n(k) d(d) ci(exact) generate(c)
    assert _rc == 459
    capture confirm variable c
    assert _rc == 111
    capture tabcell np, n(2) d(20) ci(wilson)
    assert _rc == 198
    capture tabcell enp, e(2) n(20) ci(exact)
    assert _rc == 198
    capture tabcell n, n(2) ci(exact)
    assert _rc == 198
    * level() and sep() still belong to est/iqr unless ci() is given
    capture tabcell np, n(2) d(20) level(90)
    assert _rc == 198
    capture tabcell np, n(2) d(20) sep(" to ")
    assert _rc == 198
    capture tabcell np, n(2) d(20) ci(exact) level(5)
    assert _rc == 198
    capture tabcell np, n(30) d(20) ci(exact)
    assert _rc == 198
    capture tabcell np, n(.) d(20) ci(exact)
    assert _rc == 459
    tabcell np, n(.) d(20) ci(exact) missing("--")
    assert `"`r(cell)'"' == "--" & missing(r(lb))
    * c(level) is the default
    set level 90
    tabcell np, n(2) d(20) ci(exact)
    assert r(level) == 90
    set level 95
}
if _rc == 0 {
    display as result "  PASS: CI4 non-integer counts, other forms, other methods refused"
    local ++pass_count
}
else {
    display as error "  FAIL: CI4 refusals (rc=`=_rc')"
    local ++fail_count
}
set level 95

**# H1: session hygiene with the new options
capture noisily {
    set varabbrev on
    quietly frames dir
    local before `"`r(frames)'"'
    capture tabcell np, n(2.5) d(20) ci(exact) local(c)
    assert c(varabbrev) == "on"
    tabcell np, n(2) d(20) ci(exact) local(c)
    assert c(varabbrev) == "on"
    quietly frames dir
    assert `"`r(frames)'"' == `"`before'"'
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: H1 varabbrev restored and no frames left"
    local ++pass_count
}
else {
    display as error "  FAIL: H1 session hygiene (rc=`=_rc')"
    local ++fail_count
}
set varabbrev off

local _tc = `pass_count' + `fail_count'
display "RESULT: test_tabcell_v240 tests=`_tc' pass=`pass_count' fail=`fail_count'"
log close _tc240
if `fail_count' > 0 exit 1
