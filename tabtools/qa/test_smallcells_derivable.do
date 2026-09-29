*! test_smallcells_derivable.do  2026-09-29
*! desctab/table1_tc smallcells(): unprinted counts that follow from printed
*! cells (missing and negative rows) are protected; group and total N are
*! never withheld; wtcompare without wtn/percent_n is refused (2.1.17)
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
set processors 1
set varabbrev off
version 17.0

capture log close _scderiv
log using "test_smallcells_derivable.log", replace text name(_scderiv)

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# Bootstrap

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

capture program drop _dv_record
program define _dv_record
    args label rc passed failed
    if `rc' == 0 {
        display as result "  PASS: `label'"
        c_local pass_count = `passed' + 1
    }
    else {
        display as error "  FAIL: `label' (rc=`rc')"
        c_local fail_count = `failed' + 1
        c_local failed_tests "`failed_tests' `label'"
    }
end

* Independent attacker. Reads only the published table (a desctab frame in
* memory) and recovers what a reader can: for each categorical block, the
* non-missing denominator from the sum of fully printed levels or from the
* column percentages, so the missing count is N minus it; for each binary
* row, the denominator from n/N or from n (pct), so the negative count is
* denominator minus n and the missing count N minus denominator. A leak is
* a count pinned to one value v with 0 < v < k. It never reads the package's
* masks. colpct = 0 when percentages are row percentages (catrowperc).
capture program drop _dv_attack
program define _dv_attack, rclass
    version 17.0
    syntax, K(integer) COLS(string) [COLPct(integer 1)]
    local leaks 0
    local desc ""
    local nobs = _N
    local ncol : word count `cols'
    * Header N per column
    local c 0
    foreach v of local cols {
        local ++c
        local N_`c' .
        forvalues r = 1/`nobs' {
            local s = `v'[`r']
            if ustrregexm(`"`s'"', "^N=([0-9,]+)$") {
                local N_`c' = real(subinstr(ustrregexs(1), ",", "", .))
            }
        }
    }
    local r 3
    while `r' <= `nobs' {
        local f = factor[`r']
        if substr(`"`f'"', 1, 1) == " " | `"`f'"' == "" {
            local ++r
            continue
        }
        * Level rows follow the block header
        local first = `r' + 1
        local last = `r'
        while `last' + 1 <= `nobs' {
            local g = factor[`last' + 1]
            if substr(`"`g'"', 1, 1) != " " continue, break
            local ++last
        }
        local c 0
        foreach v of local cols {
            local ++c
            local N = `N_`c''
            if missing(`N') continue
            if `last' >= `first' {
                * categorical block
                local allexact 1
                local sum 0
                local pcells ""
                forvalues q = `first'/`last' {
                    local s = `v'[`q']
                    if ustrregexm(`"`s'"', "^([0-9,]+)( \(([0-9.]+)\))?$") {
                        local n = real(subinstr(ustrregexs(1), ",", "", .))
                        local p = ustrregexs(3)
                        local sum = `sum' + `n'
                        if "`p'" != "" & `colpct' local pcells "`pcells' `n':`p'"
                    }
                    else local allexact 0
                }
                local dset ""
                if `allexact' local dset "`sum'"
                else if "`pcells'" != "" {
                    forvalues d = `=max(`sum', 1)'/`N' {
                        local ok 1
                        foreach np of local pcells {
                            gettoken n p : np, parse(":")
                            local p = substr("`p'", 2, .)
                            local dec = cond(strpos("`p'", "."), ///
                                strlen("`p'") - strpos("`p'", "."), 0)
                            if abs(100 * `n' / `d' - real("`p'")) > 0.5 * 10^(-`dec') + 1e-9 local ok 0
                        }
                        if `ok' local dset "`dset' `d'"
                    }
                }
                local nd : word count `dset'
                if `nd' == 1 {
                    local m = `N' - `dset'
                    if `m' > 0 & `m' < `k' {
                        local ++leaks
                        local desc `"`desc' [`f' `v' missing=`m']"'
                    }
                }
            }
            else {
                * binary row
                local s = `v'[`r']
                local dset ""
                local n .
                if ustrregexm(`"`s'"', "^([0-9,]+)/([0-9,]+)$") {
                    local n = real(subinstr(ustrregexs(1), ",", "", .))
                    local dset = real(subinstr(ustrregexs(2), ",", "", .))
                }
                else if ustrregexm(`"`s'"', "^([0-9,]+) \(([0-9.]+)\)$") {
                    local n = real(subinstr(ustrregexs(1), ",", "", .))
                    local p = ustrregexs(2)
                    local dec = cond(strpos("`p'", "."), ///
                        strlen("`p'") - strpos("`p'", "."), 0)
                    forvalues d = `=max(`n', 1)'/`N' {
                        if abs(100 * `n' / `d' - real("`p'")) <= 0.5 * 10^(-`dec') + 1e-9 ///
                            local dset "`dset' `d'"
                    }
                }
                local nd : word count `dset'
                if `nd' == 1 & !missing(`n') {
                    local neg = `dset' - `n'
                    local m = `N' - `dset'
                    if `neg' > 0 & `neg' < `k' {
                        local ++leaks
                        local desc `"`desc' [`f' `v' negative=`neg']"'
                    }
                    if `m' > 0 & `m' < `k' {
                        local ++leaks
                        local desc `"`desc' [`f' `v' missing=`m']"'
                    }
                }
            }
        }
        local r = `last' + 1
    }
    * Every header N at or above k must be printed exactly
    local hidden_n 0
    local c 0
    foreach v of local cols {
        local ++c
        if missing(`N_`c'') local ++hidden_n
    }
    return scalar leaks = `leaks'
    return scalar hidden_n = `hidden_n'
    return local desc `"`desc'"'
end

capture program drop _dv_cat_fixture
program define _dv_cat_fixture
    * Action-note A01 fixture: group a (23) has 3 missing; group b (25) none
    version 17.0
    clear
    quietly set obs 48
    generate byte gg = 1 + (_n > 23)
    label define _dv_g 1 "a" 2 "b", replace
    label values gg _dv_g
    generate byte cc = .
    quietly replace cc = 1 if inrange(_n, 1, 10) | inrange(_n, 24, 35)
    quietly replace cc = 2 if inrange(_n, 11, 20) | inrange(_n, 36, 48)
end

capture program drop _dv_bin_fixture
program define _dv_bin_fixture
    * Action-note A01 fixture: group a (20) has 18 positives and 2 negatives
    version 17.0
    clear
    quietly set obs 40
    generate byte gg = 1 + (_n > 20)
    generate byte b = inrange(_n, 1, 18) | inrange(_n, 21, 30)
end

**# A01: categorical missing count derivable from levels and group N

local ++test_count
capture noisily {
    _dv_cat_fixture
    desctab, by(gg) vars(cc cat) smallcells(5) frame(_dv, replace)
    frame _dv {
        _dv_attack, k(5) cols(gg_1 gg_2)
        assert r(leaks) == 0
        assert r(hidden_n) == 0
        * the protection is visible: a complementary marker, no percentages
        * for the variable, and the test suppressed
        quietly count if ustrregexm(gg_1, "^≥5$")
        assert r(N) == 1
        quietly count if strpos(gg_1, "(") | strpos(gg_2, "(")
        assert r(N) == 0
        quietly count if pvalue == "Suppressed"
        assert r(N) == 1
    }
    frame drop _dv
}
_dv_record "categorical: hidden missing 3 of group N 23 is not recoverable" `=_rc' `pass_count' `fail_count'

local ++test_count
capture noisily {
    * the printed-missing route keeps its 2.1.16 behaviour: same cells as
    * the unprinted route, plus the coded missing row
    _dv_cat_fixture
    desctab, by(gg) vars(cc cat) smallcells(5) missingsummary frame(_dv, replace)
    frame _dv {
        _dv_attack, k(5) cols(gg_1 gg_2)
        assert r(leaks) == 0
        quietly count if ustrtrim(factor) == "Missing" & gg_1 == "<5" & gg_2 == "0"
        assert r(N) == 1
    }
    frame drop _dv
}
_dv_record "categorical missingsummary: missing row coded <5, no leak" `=_rc' `pass_count' `fail_count'

**# A01: binary negative count derivable from the percentage denominator

local ++test_count
capture noisily {
    _dv_bin_fixture
    desctab, by(gg) vars(b bin) smallcells(5) frame(_dv, replace)
    frame _dv {
        _dv_attack, k(5) cols(gg_1 gg_2)
        assert r(leaks) == 0
        assert r(hidden_n) == 0
        quietly count if strpos(gg_1, "(") | strpos(gg_2, "(")
        assert r(N) == 0
        quietly count if pvalue == "Suppressed"
        assert r(N) == 1
    }
    frame drop _dv
    * table1_tc is the same engine
    _dv_bin_fixture
    table1_tc, by(gg) vars(b bin) smallcells(5) frame(_dv, replace)
    frame _dv {
        _dv_attack, k(5) cols(gg_1 gg_2)
        assert r(leaks) == 0
    }
    frame drop _dv
}
_dv_record "binary: 18 (90) no longer releases 2 negatives" `=_rc' `pass_count' `fail_count'

local ++test_count
capture noisily {
    _dv_bin_fixture
    desctab, by(gg) vars(b bin) smallcells(5) slashN frame(_dv, replace)
    frame _dv {
        _dv_attack, k(5) cols(gg_1 gg_2)
        assert r(leaks) == 0
        quietly count if factor == "b" & gg_1 == "≥5" & gg_2 == "10/20"
        assert r(N) == 1
    }
    frame drop _dv
}
_dv_record "binary slashN: cells as in 2.1.16 (>=5, 10/20)" `=_rc' `pass_count' `fail_count'

**# A01: no over-protection when every unprinted count is zero or >= k

local ++test_count
capture noisily {
    clear
    quietly set obs 60
    generate byte gg = 1 + (_n > 30)
    generate byte cc = cond(mod(_n, 2), 1, 2)
    quietly replace cc = . if inrange(_n, 1, 6)
    generate byte b = mod(_n, 3) == 0
    quietly replace b = . if inrange(_n, 31, 36)
    desctab, by(gg) vars(cc cat \ b bin) smallcells(5) total(after) frame(_dv, replace)
    assert r(N_primary_suppressed) == 0
    assert r(N_secondary_suppressed) == 0
    frame _dv {
        quietly count if pvalue == "Suppressed"
        assert r(N) == 0
        quietly count if strpos(gg_1, "(")
        assert r(N) == 3
    }
    frame drop _dv
}
_dv_record "hidden counts 0 or >= k: percentages and p-values kept" `=_rc' `pass_count' `fail_count'

**# Group and total N are never withheld

local ++test_count
capture noisily {
    _dv_cat_fixture
    generate byte d = mod(_n, 3)
    desctab, by(gg) vars(cc cat \ d cat) smallcells(5) total(after) frame(_dv, replace)
    frame _dv {
        assert gg_1[2] == "N=23" & gg_2[2] == "N=25" & gg_T[2] == "N=48"
        _dv_attack, k(5) cols(gg_1 gg_2 gg_T)
        assert r(leaks) == 0
        * a complete variable adds back to each group N, so the header is
        * public whatever one block decides; the cc block must hold alone
        quietly count if strpos(gg_1, "(") & ustrtrim(factor) == "0"
        assert r(N) == 1
    }
    frame drop _dv
    _dv_cat_fixture
    generate byte d = mod(_n, 3)
    desctab, by(gg) vars(cc cat \ d cat) smallcells(5) total(after) ///
        missingsummary frame(_dv, replace)
    frame _dv {
        assert gg_1[2] == "N=23" & gg_T[2] == "N=48"
        _dv_attack, k(5) cols(gg_1 gg_2 gg_T)
        assert r(leaks) == 0
    }
    frame drop _dv
}
_dv_record "total(after): N=23/25/48 printed, missing count still protected" `=_rc' `pass_count' `fail_count'

local ++test_count
capture noisily {
    * engine contract: with fixedmargins no column or grand margin is ever
    * a complementary suppression; without it, the same block hides them
    matrix C = (10, 12 \ 10, 13 \ 3, 0)
    matrix E = (1, 1 \ 1, 1 \ 0, 0)
    matrix S = J(3, 2, 1)
    matrix RE = (1 \ 1 \ 0)
    matrix RS = (1 \ 1 \ 1)
    matrix CE = (1, 1)
    matrix CS = (1, 1)
    _tabtools_smallcells, counts(C) exact(E) sensitive(S) rowexact(RE) ///
        rowsensitive(RS) colexact(CE) colsensitive(CS) grandexact(1) ///
        grandsensitive(1) smallcells(5)
    matrix CM0 = r(colmask)
    local T0 = r(totalmask)
    assert CM0[1, 1] == 2 | CM0[1, 2] == 2 | `T0' == 2
    _tabtools_smallcells, counts(C) exact(E) sensitive(S) rowexact(RE) ///
        rowsensitive(RS) colexact(CE) colsensitive(CS) grandexact(1) ///
        grandsensitive(1) smallcells(5) fixedmargins
    matrix CM = r(colmask)
    matrix M = r(mask)
    matrix RM = r(rowmask)
    assert CM[1, 1] == 0 & CM[1, 2] == 0
    assert r(totalmask) == 0
    assert M[3, 1] == 1
    assert RM[3, 1] == 1
    * something printed carries the complement
    assert M[1, 1] == 2 | M[2, 1] == 2 | RM[1, 1] == 2 | RM[2, 1] == 2
}
_dv_record "_tabtools_smallcells fixedmargins never withholds col/grand margins" `=_rc' `pass_count' `fail_count'

local ++test_count
capture noisily {
    * group 2: N=11, levels 5 and 5, one missing. Printed levels are >= 5,
    * so their sum is >= 10 and the missing count is 0 or 1; the withheld
    * percentages say a count was protected, so it is 1. Only withholding
    * N=11 would cover it, and every other variable releases N. Refuse.
    clear
    input byte gg byte cc int f
    1 1 10
    1 2 9
    1 . 5
    2 1 5
    2 2 5
    2 . 1
    end
    quietly expand f
    drop f
    generate byte d = mod(_n, 2)
    set varabbrev on
    datasignature
    local sig "`r(datasignature)'"
    tempfile msg
    capture log close _dvmsg
    log using "`msg'", text replace name(_dvmsg)
    capture noisily desctab, by(gg) vars(d cat \ cc cat) smallcells(5)
    local rc = _rc
    log close _dvmsg
    assert `rc' == 498
    assert c(varabbrev) == "on"
    set varabbrev off
    datasignature
    assert "`r(datasignature)'" == "`sig'"
    tempname fh
    file open `fh' using "`msg'", read text
    local found 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "variable cc:") local found 1
        file read `fh' line
    }
    file close `fh'
    assert `found'
    * 2.1.16 hid N=11 on the printed-missing route; now the same refusal
    capture desctab, by(gg) vars(d cat \ cc cat) smallcells(5) missingsummary
    assert _rc == 498
}
_dv_record "unprotectable without hiding N: r(498) names the variable, data intact" `=_rc' `pass_count' `fail_count'

**# Randomised attacker sweep over routes

local ++test_count
capture noisily {
    local routes `" "" "total(after)" "catrowperc" "missingsummary" "total(after) missingsummary" "slashN" "total(before) slashN" "'
    local nroutes : word count `routes'
    local leaks_total 0
    local runs 0
    local refused 0
    local leakdesc ""
    set seed 20260929
    forvalues rep = 1/40 {
        local n1 = 8 + floor(runiform() * 20)
        local n2 = 8 + floor(runiform() * 20)
        local m1 = floor(runiform() * 6)
        local m2 = floor(runiform() * 6)
        local g1 = floor(runiform() * 6)
        local g2 = floor(runiform() * 6)
        local ncat = 2 + floor(runiform() * 2)
        clear
        quietly set obs `=`n1' + `n2''
        generate byte gg = 1 + (_n > `n1')
        generate long id = cond(gg == 1, _n, _n - `n1')
        generate byte cc = 1 + mod(id * 7 + `rep', `ncat')
        quietly replace cc = . if (gg == 1 & id <= `m1') | (gg == 2 & id <= `m2')
        generate byte b = 1
        quietly replace b = 0 if (gg == 1 & id > `m1' & id <= `m1' + `g1') | ///
            (gg == 2 & id > `m2' & id <= `m2' + `g2')
        quietly replace b = . if (gg == 1 & id > `n1' - 2 & `rep' > 20)
        forvalues ro = 1/`nroutes' {
            local opt : word `ro' of `routes'
            local colpct = strpos("`opt'", "catrowperc") == 0
            local cols "gg_1 gg_2"
            if strpos("`opt'", "total(") local cols "`cols' gg_T"
            capture desctab, by(gg) vars(cc cat \ b bin) smallcells(5) `opt' ///
                frame(_dv, replace)
            if _rc == 498 {
                local ++refused
                continue
            }
            if _rc error _rc
            local ++runs
            frame _dv {
                _dv_attack, k(5) cols(`cols') colpct(`colpct')
                local leaks_total = `leaks_total' + r(leaks) + r(hidden_n)
                if r(leaks) + r(hidden_n) > 0 ///
                    local leakdesc `"`leakdesc' rep`rep'/`opt':`r(desc)' hiddenN=`r(hidden_n)'"'
            }
            frame drop _dv
        }
    }
    display as text "  sweep: runs=`runs' refused(498)=`refused' leaks=`leaks_total'"
    if `leaks_total' display as error `"  `leakdesc'"'
    assert `runs' >= 250
    assert `leaks_total' == 0
}
_dv_record "40 fixtures x 7 routes: attacker recovers no count below k" `=_rc' `pass_count' `fail_count'

**# A06: wtcompare weighted columns are percent-only

local ++test_count
capture noisily {
    clear
    quietly set obs 40
    generate byte gg = 1 + (_n > 20)
    generate byte cc = 2
    quietly replace cc = 1 if inlist(_n, 1, 2) | inrange(_n, 21, 28)
    generate byte b = inrange(_n, 1, 10) | inrange(_n, 21, 32)
    generate double w = cond(mod(_n, 2) == 1, 1, 3)
    * the same call without smallcells runs, so r(198) is the refusal
    desctab, by(gg) vars(cc cat \ b bin) wt(w) wtcompare
    capture desctab, by(gg) vars(cc cat \ b bin) wt(w) wtcompare smallcells(5)
    assert _rc == 198
    capture table1_tc, by(gg) vars(cc cat \ b bin) wt(w) wtcompare smallcells(5)
    assert _rc == 198
    desctab, by(gg) vars(cc cat \ b bin) wt(w) wtcompare smallcells(5) wtn
    desctab, by(gg) vars(cc cat \ b bin) wt(w) wtcompare smallcells(5) percent_n
}
_dv_record "wtcompare smallcells refused (198); wtn and percent_n run" `=_rc' `pass_count' `fail_count'

local ++test_count
capture noisily {
    clear
    quietly set obs 40
    generate byte gg = 1 + (_n > 20)
    generate byte b = mod(_n, 2)
    generate double w = 1 + mod(_n, 3)
    * refusal message names the percent-only cause
    tempfile msg
    capture log close _dvmsg
    log using "`msg'", text replace name(_dvmsg)
    capture noisily desctab, by(gg) vars(b bin) wt(w) wtcompare smallcells(5)
    local rc = _rc
    log close _dvmsg
    assert `rc' == 198
    tempname fh
    file open `fh' using "`msg'", read text
    local found 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "cannot be combined with percent-only display") local found 1
        file read `fh' line
    }
    file close `fh'
    assert `found'
    * without wt(), the more specific wtcompare error still wins
    capture log close _dvmsg
    log using "`msg'", text replace name(_dvmsg)
    capture noisily desctab, by(gg) vars(b bin) wtcompare smallcells(5)
    local rc = _rc
    log close _dvmsg
    assert `rc' == 198
    file open `fh' using "`msg'", read text
    local found 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "wtcompare requires wt()") local found 1
        file read `fh' line
    }
    file close `fh'
    assert `found'
}
_dv_record "refusal names percent-only; wtcompare without wt() keeps its error" `=_rc' `pass_count' `fail_count'

**# Summary

display as result "Derivable small-cell tests: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_smallcells_derivable tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _scderiv
if `fail_count' > 0 exit 1
