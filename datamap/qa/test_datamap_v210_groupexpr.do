*! test_datamap_v210_groupexpr.do Version 1.0.0  2026/11/15
*! datamap 2.1.0 F9(a) groupstat() any number of statistics and several
*! variables per colon entry, F9(b) stat() expression arguments, F9(c)
*! byrule() group aggregates
*! Author: Timothy P Copeland, Karolinska Institutet
*
* Oracles are base Stata (count, summarize, _pctile, collapse, egen) on
* the fixture, never dataprobe itself, except where the property is that a
* new form equals an existing one (the multi-statistic ledger rows against
* the single-statistic entries).
*
*   G1  groupstat 8 statistics, one variable: two column blocks of at most
*       six, every cell and pooled value against summarize/_pctile, every
*       line within 80 columns, one review row per statistic
*   G2  7 statistics x 2 variables: one table per variable; the ledger rows
*       equal the single-statistic entries' rows; z cells against summarize
*   G3  maskrare: n, mean, sd, median cells of two variables follow the
*       count-if rules; no shown n cell below the mask; pooled n withheld
*   G4  edge cases: one group, an all-missing variable, an empty entry
*       scope, string and strL variables (n distinct pmiss), hostile group
*       values, 13 statistics
*   G5  refusals: a variable named twice, a non-numeric variable for mean,
*       a statistic twice, band() on several statistics
*   X1  stat(mean (dx == 1)): the share among known dx, not Stata's 0 for
*       missing; pass and fail bands; the label is the text
*   X2  every statistic over an expression against base Stata; ratio with
*       two expressions
*   X3  maskrare: a small count and a small share are withheld
*   X4  string and strL operands; "" is missing
*   X5  hostile expression text (" ' $ { } and a backtick) reaches the
*       ledger and the console as typed
*   X6  refusals: missing(), ., subscripts, _n, unclosed (, string result,
*       unknown variable; the plain forms are unchanged
*   X7  if/in and the entry's if; exclude() and safe withhold the value
*   X8  empty scope and all-missing operands
*   X9  by() + maskrare: stat(sum (flag == 1)), n and pmiss of (x + 0)
*       write the rows their variable forms write, and the pooled
*       remainder of the sum is never 1 to m-1 (collapse oracle)
*   R1  byrule total(): float weights fail == 1 and pass the documented
*       tolerance; a perturbed group and an all-missing group fail; counts
*       of failing groups against collapse
*   R2  spread() mean() gmin() gmax() count() against collapse; a row term
*       mixed with an aggregate; min()/max() stay row functions
*   R3  string group variable with hostile values, a missing group value,
*       an if/in sample, and by(): failing groups against collapse
*   R4  maskrare: <m and all but <m group counts, observed_num withheld
*   R5  refusals: nested aggregates, missing(), subscripts in an argument,
*       unclosed (, unknown variable; a plain byrule() reads as before
version 16.0
clear all
set processors 1
set linesize 255
capture log close _all
log using "test_datamap_v210_groupexpr.log", replace text name(main)
local pkg_dir = regexr("`c(pwd)'", "/qa$", "")
tempfile base
local W "`base'_v210gx"
capture mkdir "`W'"
capture mkdir "`W'/plus"
capture mkdir "`W'/personal"
mata: assert(direxists(st_local("W") + "/plus"))
local oldplus : sysdir PLUS
local oldpersonal : sysdir PERSONAL
sysdir set PLUS "`W'/plus"
sysdir set PERSONAL "`W'/personal"
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") replace
discard
macro drop DATAMAP_DQ
global GX_T 0
global GX_P 0
global GX_F 0

**# Helpers

capture program drop _gx_tally
program define _gx_tally
    args rc msg
    global GX_T = $GX_T + 1
    if `rc' == 0 {
        display as result "PASS: `msg'"
        global GX_P = $GX_P + 1
    }
    else {
        display as error "FAIL (rc=`rc'): `msg'"
        global GX_F = $GX_F + 1
    }
end

* _gx_block file header: the indented lines under the header line, up to
* the next blank or command line
capture program drop _gx_block
program define _gx_block, rclass
    args file header
    tempname fh
    local n = 0
    local on = 0
    local seen = 0
    file open `fh' using `"`file'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if `on' {
            if strtrim(`"`macval(line)'"') == "" | substr(`"`macval(line)'"', 1, 1) == "." {
                local on = 0
            }
            else if substr(`"`macval(line)'"', 1, 2) == "  " {
                local ++n
                return local l`n' `"`macval(line)'"'
            }
        }
        if strtrim(`"`macval(line)'"') == `"`header'"' & !`seen' {
            local on = 1
            local seen = 1
        }
        file read `fh' line
    }
    file close `fh'
    return scalar n = `n'
    return scalar seen = `seen'
end

* _gx_cell line j: cell j of a multi-statistic table row (10 wide after a
* 16-wide label), and the label
capture program drop _gx_cell
program define _gx_cell, rclass
    args line j
    return local c = strtrim(substr(`"`macval(line)'"', 19 + 10 * (`j' - 1), 10))
    return local g = strtrim(substr(`"`macval(line)'"', 3, 16))
end

* _gx_fmt value: a cell as the table prints an unmasked number; r(s2) and
* r(s3): the value 1e-12 below and above, since a sum taken in another
* order can differ in the last bits and round the other way at a tie
capture program drop _gx_fmt
program define _gx_fmt, rclass
    args x
    if missing(`x') {
        return local s "."
        return local s2 "."
        return local s3 "."
    }
    else {
        return local s = strtrim(string(`x', "%10.4g"))
        return local s2 = strtrim(string(`x' - abs(`x') * 1e-12, "%10.4g"))
        return local s3 = strtrim(string(`x' + abs(`x') * 1e-12, "%10.4g"))
    }
end

* _gx_count file: a line count of the log matching a literal text
capture program drop _gx_has
program define _gx_has, rclass
    args file text
    mata: _gx_t = cat(st_local("file"))
    mata: st_numscalar("r(n)", sum(strpos(_gx_t, st_local("text")) :> 0))
    mata: mata drop _gx_t
    return scalar n = r(n)
end

* 120 rows, groups A..D of 30 (g), y with missings, z, dx 0/1/2 with
* missings, sex with blanks, id of 10 rows each, float weights 0.1
capture program drop _gx_fix
program define _gx_fix
    clear
    set seed 21015
    quietly set obs 120
    gen str1 g = word("A B C D", 1 + mod(_n - 1, 4))
    gen double y = round(rnormal(50, 10), 0.01)
    quietly replace y = . in 5/7
    quietly replace y = .a in 40
    gen double z = round(runiform() * 100, 0.001)
    gen byte dx = cond(runiform() < .3, 1, cond(runiform() < .5, 2, 0))
    quietly replace dx = . in 10/19
    gen str5 sex = cond(mod(_n, 3) == 0, "F", "M")
    quietly replace sex = "" in 20/22
    gen long id = ceil(_n / 10)
    gen float w = 0.1
    gen double t = mod(_n * 7, 10) + 1
    gen double ym = .
    gen byte one = 1
end

**# G1 eight statistics, one variable: two column blocks
capture noisily {
    _gx_fix
    capture erase "`W'/g1.dta"
    tempfile lg
    quietly log using "`lg'.log", replace text name(g1)
    dataprobe, gatesonly groupstat(n mean sd p5 p25 median p75 p95: y, by(g)) ledger("`W'/g1.dta")
    quietly log close g1
    _gx_block "`lg'.log" "GROUPSTAT n mean sd p5 p25 median p75 p95: y by(g)"
    assert r(seen) == 1
    * block 1: header, A-D, pooled; block 2: header, A-D, pooled
    assert r(n) == 12
    local nb = r(n)
    forvalues i = 1/`nb' {
        local L`i' `"`r(l`i')'"'
        assert ustrlen(`"`L`i''"') <= 80
    }
    local h1 : list retokenize L1
    local h7 : list retokenize L7
    assert "`h1'" == "Group n mean sd p5 p25 median"
    assert "`h7'" == "Group p75 p95"
    local st1 "n mean sd p5 p25 p50"
    local st2 "p75 p95"
    foreach b in 1 2 {
        local off = cond(`b' == 1, 0, 6)
        local ns : word count `st`b''
        forvalues r = 1/5 {
            local i = `off' + 1 + `r'
            _gx_cell `"`L`i''"' 1
            local lv "`r(g)'"
            if `r' <= 4 {
                assert "`lv'" == word("A B C D", `r')
                local cnd `"g == "`lv'""'
            }
            else {
                assert "`lv'" == "pooled"
                local cnd "1"
            }
            forvalues j = 1/`ns' {
                local s : word `j' of `st`b''
                if "`s'" == "n" {
                    quietly count if `cnd' & !missing(y)
                    local e = r(N)
                }
                else if "`s'" == "mean" | "`s'" == "sd" {
                    quietly summarize y if `cnd'
                    local e = cond("`s'" == "mean", r(mean), r(sd))
                }
                else {
                    local p = substr("`s'", 2, .)
                    quietly _pctile y if `cnd', p(`p')
                    local e = r(r1)
                }
                _gx_fmt `e'
                local es "`r(s)'"
                local es2 "`r(s2)'"
                local es3 "`r(s3)'"
                _gx_cell `"`L`i''"' `j'
                assert inlist(`"`r(c)'"', "`es'", "`es2'", "`es3'")
            }
        }
    }
    use "`W'/g1.dta", clear
    quietly keep if family == "groupstat"
    assert _N == 8
    assert status == "review"
    foreach l in "n y" "mean y" "sd y" "p5 y" "p25 y" "median y" "p75 y" "p95 y" {
        quietly count if label == "`l'"
        assert r(N) == 1
    }
}
local rc = _rc
capture log close g1
_gx_tally `rc' "G1 eight statistics wrap into blocks of six; cells against summarize/_pctile; 80 columns"

**# G2 seven statistics x two variables: one table each; ledger = single entries
capture noisily {
    _gx_fix
    capture erase "`W'/g2a.dta"
    capture erase "`W'/g2b.dta"
    tempfile lg
    quietly log using "`lg'.log", replace text name(g2)
    dataprobe, gatesonly groupstat(n mean sd p10 median p90 sum: y z, by(g)) ledger("`W'/g2a.dta")
    quietly log close g2
    dataprobe, gatesonly groupstat(n y z, by(g) \ mean y z, by(g) \ sd y z, by(g) \ ///
        p10 y z, by(g) \ median y z, by(g) \ p90 y z, by(g) \ sum y z, by(g)) ledger("`W'/g2b.dta")
    foreach v in y z {
        _gx_block "`lg'.log" "GROUPSTAT n mean sd p10 median p90 sum: `v' by(g)"
        assert r(seen) == 1
        assert r(n) == 12
        forvalues i = 1/12 {
            local L`i' `"`r(l`i')'"'
        }
        local h7 : list retokenize L7
        assert "`h7'" == "Group sum"
        forvalues r = 1/4 {
            local lv = word("A B C D", `r')
            local i = 1 + `r'
            local Li `"`L`i''"'
            local i2 = 7 + `r'
            local Lj `"`L`i2''"'
            quietly summarize `v' if g == "`lv'"
            local mu = r(mean)
            local sm = r(sum)
            _gx_fmt `mu'
            local es "`r(s)'"
            _gx_cell `"`Li'"' 2
            assert "`r(g)'" == "`lv'"
            assert `"`r(c)'"' == `"`es'"'
            _gx_fmt `sm'
            local es "`r(s)'"
            local es2 "`r(s2)'"
            local es3 "`r(s3)'"
            _gx_cell `"`Lj'"' 1
            assert inlist(`"`r(c)'"', "`es'", "`es2'", "`es3'")
        }
    }
    * the y table comes before the z table
    mata: _gx_t = cat(st_local("lg") + ".log")
    mata: _gx_iy = selectindex(strpos(_gx_t, "GROUPSTAT n mean sd p10 median p90 sum: y by(g)") :> 0)
    mata: _gx_iz = selectindex(strpos(_gx_t, "GROUPSTAT n mean sd p10 median p90 sum: z by(g)") :> 0)
    mata: assert(rows(_gx_iy) == 1 & rows(_gx_iz) == 1 & _gx_iy < _gx_iz)
    mata: mata drop _gx_t _gx_iy _gx_iz
    foreach f in a b {
        use "`W'/g2`f'.dta", clear
        quietly keep if family == "groupstat"
        keep label variable status observed observed_num message obs_masked minshown
        sort label variable
        tempfile g2`f'
        quietly save "`g2`f''"
    }
    use "`g2a'", clear
    assert _N == 14
    cf _all using "`g2b'"
}
local rc = _rc
capture log close g2
_gx_tally `rc' "G2 seven statistics x two variables: a table per variable; ledger rows = single-statistic entries"

**# G3 maskrare: count-if rules cell by cell for two variables
capture noisily {
    _gx_fix
    * groups of 40, 30, 20, 12, 7, 4, 3, 2, 2 rows
    quietly gen str2 g2 = ""
    local cut 0 40 70 90 102 109 113 116 118 120
    forvalues k = 1/9 {
        local a = real(word("`cut'", `k')) + 1
        local b = real(word("`cut'", `k' + 1))
        quietly replace g2 = "G`k'" in `a'/`b'
    }
    tempfile lg
    quietly log using "`lg'.log", replace text name(g3)
    dataprobe, gatesonly groupstat(n mean sd median p25 p75 p90: y z, by(g2) min(2)) maskrare mincell(5)
    quietly log close g3
    local nsup = 0
    foreach v in y z {
        _gx_block "`lg'.log" "GROUPSTAT n mean sd median p25 p75 p90: `v' by(g2)"
        assert r(seen) == 1
        local nb = r(n)
        forvalues i = 1/`nb' {
            local L`i' `"`r(l`i')'"'
            assert ustrlen(`"`L`i''"') <= 80
        }
        * the first block: header, the groups, pooled
        local i = 2
        while 1 {
            _gx_cell `"`L`i''"' 1
            local lv "`r(g)'"
            if "`lv'" == "pooled" | "`lv'" == "Group" continue, break
            * 2.1.0: under the mask a listed group of 1 to 4 rows is named by
            * its number (group k, the k-th sorted level), never by its value
            if regexm("`lv'", "^group ([0-9]+)$") {
                local _gk = real(regexs(1))
                quietly levelsof g2, local(_glev)
                local lv : word `_gk' of `_glev'
                quietly count if g2 == "`lv'"
                assert r(N) >= 1 & r(N) < 5
            }
            else {
                quietly count if g2 == "`lv'"
                assert r(N) >= 5
            }
            quietly count if g2 == "`lv'" & !missing(`v')
            local cnt = r(N)
            quietly count if g2 == "`lv'"
            local nr = r(N)
            quietly summarize `v' if g2 == "`lv'"
            local mu = r(mean)
            local sdv = r(sd)
            quietly count if g2 == "`lv'" & `v' <= `mu' & !missing(`v')
            local le = r(N)
            quietly count if g2 == "`lv'" & `v' >= `mu' & !missing(`v')
            local ge = r(N)
            quietly _pctile `v' if g2 == "`lv'", p(50)
            local md = r(r1)
            quietly count if g2 == "`lv'" & `v' <= `md' & !missing(`v')
            local lem = r(N)
            quietly count if g2 == "`lv'" & `v' >= `md' & !missing(`v')
            local gem = r(N)
            local e1 = cond(`cnt' >= 1 & `cnt' < 5, "<5", ///
                cond(`nr' - `cnt' >= 1 & `nr' - `cnt' < 5, "[suppr.]", strtrim(string(`cnt', "%10.4g"))))
            local e2 = cond(`le' < 5 | `ge' < 5, "[suppr.]", strtrim(string(`mu', "%10.4g")))
            local e3 = cond(`cnt' < 5, "[suppr.]", strtrim(string(`sdv', "%10.4g")))
            local e4 = cond(`lem' < 5 | `gem' < 5, "[suppr.]", strtrim(string(`md', "%10.4g")))
            forvalues j = 1/4 {
                _gx_cell `"`L`i''"' `j'
                local c `"`r(c)'"'
                * the pooled-remainder rule may withhold a further n cell
                if `j' == 1 & `"`c'"' == "[suppr.]" & `"`e1'"' != "<5" {
                }
                else assert `"`c'"' == `"`e`j''"'
                if inlist(`"`c'"', "<5", "[suppr.]") local ++nsup
                if `j' == 1 & !inlist(`"`c'"', "<5", "[suppr.]") assert real(`"`c'"') >= 5
            }
            local ++i
        }
        * pooled n is withheld: groups were pooled away or masked
        _gx_cell `"`L`i''"' 1
        assert "`r(g)'" == "pooled"
        assert `"`r(c)'"' == "[suppr.]"
        * the small-group line follows the last block
        assert strpos(`"`L`nb''"', "groups with <2 rows:") == 0
    }
    assert `nsup' >= 8
}
local rc = _rc
capture log close g3
_gx_tally `rc' "G3 maskrare: n/mean/sd/median cells of two variables follow the count-if rules"

**# G4 edge cases
capture noisily {
    * one group
    _gx_fix
    tempfile lg
    quietly log using "`lg'.log", replace text name(g4)
    dataprobe, gatesonly groupstat(n mean sd p1 p5 p10 p25 p50: y, by(one))
    quietly log close g4
    _gx_block "`lg'.log" "GROUPSTAT n mean sd p1 p5 p10 p25 p50: y by(one)"
    assert r(n) == 6
    local L2 `"`r(l2)'"'
    quietly count if !missing(y)
    local en = r(N)
    _gx_cell `"`L2'"' 1
    assert "`r(g)'" == "1"
    assert "`r(c)'" == "`en'"

    * an all-missing variable: n 0, the rest missing
    _gx_fix
    quietly log using "`lg'.log", replace text name(g4)
    dataprobe, gatesonly groupstat(n mean sd median p75 p90 p95: ym, by(g))
    quietly log close g4
    _gx_block "`lg'.log" "GROUPSTAT n mean sd median p75 p90 p95: ym by(g)"
    assert r(n) == 12
    forvalues r = 2/5 {
        local L`r' `"`r(l`r')'"'
    }
    forvalues r = 2/5 {
        _gx_cell `"`L`r''"' 1
        assert "`r(c)'" == "0"
        forvalues j = 2/6 {
            _gx_cell `"`L`r''"' `j'
            assert "`r(c)'" == "."
        }
    }

    * an empty entry scope: one review row per statistic and variable
    _gx_fix
    capture erase "`W'/g4.dta"
    quietly log using "`lg'.log", replace text name(g4)
    dataprobe, gatesonly groupstat(n mean sd p5 p25 median p75: y z, by(g) if g == "none") ledger("`W'/g4.dta")
    quietly log close g4
    _gx_has "`lg'.log" "no rows in scope"
    assert r(n) >= 14
    use "`W'/g4.dta", clear
    quietly count if family == "groupstat" & observed == "no rows in scope" & status == "review"
    assert r(N) == 14

    * string and strL variables: n distinct pmiss, wrapped at 6
    _gx_fix
    gen strL sl = sex
    quietly replace sl = "long" + char(10) + "line" in 1
    quietly log using "`lg'.log", replace text name(g4)
    dataprobe, gatesonly groupstat(n distinct pmiss n1 n2 n3 n4: sex sl, by(g))
    quietly log close g4
    * n1..n4 are not statistics: refused before anything prints
}
local rc0 = _rc
* the last call above is a deliberate error; the block is judged below
capture log close g4
capture noisily {
    assert `rc0' == 198
    _gx_fix
    gen strL sl = sex
    quietly replace sl = "x" in 1
    tempfile lg
    quietly log using "`lg'.log", replace text name(g4)
    dataprobe, gatesonly groupstat(n distinct pmiss: sex sl, by(g))
    quietly log close g4
    foreach v in sex sl {
        _gx_block "`lg'.log" "GROUPSTAT n distinct pmiss: `v' by(g)"
        assert r(n) == 6
        forvalues i = 1/6 {
            local L`i' `"`r(l`i')'"'
        }
        forvalues r = 1/4 {
            local i = 1 + `r'
            local lv = word("A B C D", `r')
            quietly count if g == "`lv'" & `v' != ""
            local en = r(N)
            quietly generate byte _tg = 0
            quietly bysort g `v': replace _tg = (_n == 1) if g == "`lv'" & `v' != ""
            quietly count if _tg == 1
            local ed = r(N)
            drop _tg
            quietly count if g == "`lv'" & `v' == ""
            local ep = strtrim(string(r(N) / 30, "%10.4g"))
            _gx_cell `"`L`i''"' 1
            assert "`r(c)'" == "`en'"
            _gx_cell `"`L`i''"' 2
            assert "`r(c)'" == "`ed'"
            _gx_cell `"`L`i''"' 3
            assert "`r(c)'" == "`ep'"
        }
    }

    * hostile group values: one row per group, ledger rows per statistic
    _gx_fix
    quietly gen str20 hg = ""
    quietly replace hg = "a" + char(34) + "b" if g == "A"
    quietly replace hg = "c'd" if g == "B"
    quietly replace hg = char(36) + "e{f}" if g == "C"
    quietly replace hg = char(96) + "g'" if g == "D"
    capture erase "`W'/g4h.dta"
    quietly log using "`lg'.log", replace text name(g4)
    dataprobe, gatesonly groupstat(n mean sd p5 p25 median p75: y, by(hg)) ledger("`W'/g4h.dta")
    quietly log close g4
    * the n cells are the groups' counts, whatever the labels hold (read
    * in Mata: a label's backtick must not be expanded by the test)
    mata: _gx_t = cat(st_local("lg") + ".log")
    mata: _gx_i = selectindex(strtrim(_gx_t) :== "GROUPSTAT n mean sd p5 p25 median p75: y by(hg)")
    mata: assert(rows(_gx_i) == 1)
    mata: st_local("got", invtokens(strtrim(substr(_gx_t[(_gx_i + 2)::(_gx_i + 5)], 19, 10))'))
    mata: st_local("nxt", strtrim(substr(_gx_t[_gx_i + 6], 3, 16)))
    mata: mata drop _gx_t _gx_i
    assert "`nxt'" == "pooled"
    local exp ""
    foreach lv in A B C D {
        quietly count if g == "`lv'" & !missing(y)
        local exp "`exp' `r(N)'"
    }
    local gots : list sort got
    local exps : list sort exp
    assert "`gots'" == "`exps'"
    use "`W'/g4h.dta", clear
    quietly count if family == "groupstat"
    assert r(N) == 7

    * thirteen statistics: three blocks (6, 6, 1)
    _gx_fix
    tempfile lg
    quietly log using "`lg'.log", replace text name(g4)
    dataprobe, gatesonly groupstat(n mean sd p1 p5 p10 p25 p50 p75 p90 p95 p99 sum: z, by(g))
    quietly log close g4
    _gx_block "`lg'.log" "GROUPSTAT n mean sd p1 p5 p10 p25 p50 p75 p90 p95 p99 sum: z by(g)"
    assert r(n) == 18
    local L13 `"`r(l13)'"'
    local L15 `"`r(l15)'"'
    local h13 : list retokenize L13
    assert "`h13'" == "Group sum"
    quietly summarize z if g == "B"
    _gx_fmt `r(sum)'
    local es "`r(s)'"
    local es2 "`r(s2)'"
    local es3 "`r(s3)'"
    _gx_cell `"`L15'"' 1
    assert "`r(g)'" == "B"
    assert inlist("`r(c)'", "`es'", "`es2'", "`es3'")
}
local rc = _rc
capture log close g4
_gx_tally `rc' "G4 one group, all-missing, empty scope, string/strL, hostile group values, 13 statistics"

**# G5 refusals
capture noisily {
    _gx_fix
    set varabbrev on
    capture dataprobe, gatesonly groupstat(n mean: y y, by(g))
    assert _rc == 198
    capture dataprobe, gatesonly groupstat(n mean: y sex, by(g))
    assert _rc == 109
    capture dataprobe, gatesonly groupstat(n mean mean: y z, by(g))
    assert _rc == 198
    capture dataprobe, gatesonly groupstat(n mean: y z, by(g) band(0 100))
    assert _rc == 198
    capture dataprobe, gatesonly groupstat(n mean: y nosuch, by(g))
    assert _rc == 111
    capture dataprobe, gatesonly groupstat(n mean sd: y z, by(g))
    assert _rc == 0
    assert c(varabbrev) == "on"
    set varabbrev off
}
local rc = _rc
set varabbrev off
_gx_tally `rc' "G5 refusals: variable twice, non-numeric, statistic twice, band on several statistics"

**# X1 stat(mean (dx == 1)): the share among known dx
capture noisily {
    _gx_fix
    quietly count if dx == 1
    local n1 = r(N)
    quietly count if !missing(dx)
    local nk = r(N)
    local p = `n1' / `nk'
    * Stata's own (dx == 1) is 0 for a missing dx: a different number
    quietly generate double _st = (dx == 1)
    quietly summarize _st
    assert reldif(r(mean), `p') > 1e-3
    drop _st
    local lo = `p' - 0.01
    local hi = `p' + 0.01
    capture erase "`W'/x1.dta"
    tempfile lg
    quietly log using "`lg'.log", replace text name(x1)
    capture noisily dataprobe, gatesonly stat(mean (dx == 1) `lo' `hi' \ mean (dx == 1) 0.9 1) ledger("`W'/x1.dta")
    local drc = _rc
    quietly log close x1
    assert `drc' == 9
    use "`W'/x1.dta", clear
    quietly keep if family == "stat"
    assert _N == 2
    assert label == "mean (dx == 1)"
    assert variable == "(dx == 1)"
    assert reldif(observed_num, `p') < 1e-14
    assert status[1] == "pass"
    assert status[2] == "fail"
    assert strpos(message[2], "stat(mean (dx == 1)): ") == 1
    _gx_has "`lg'.log" "stat(mean (dx == 1)): "
    assert r(n) >= 1
}
local rc = _rc
capture log close x1
_gx_tally `rc' "X1 stat(mean (dx == 1)) is the share among known dx; label is the text"

**# X2 every statistic over an expression against base Stata
capture noisily {
    _gx_fix
    * the expression's values, missing where an operand is missing
    quietly generate double e = (y > 50) * z if !missing(y, z)
    quietly generate double d = (dx > 0) if !missing(dx)
    quietly summarize e, detail
    local emean = r(mean)
    local esd = r(sd)
    local ep25 = r(p25)
    local esum = r(sum)
    local en = r(N)
    quietly levelsof e, local(_l)
    local edist : word count `_l'
    local epm = (_N - `en') / _N
    quietly generate double e2 = e^2
    quietly summarize e2
    local eess = `esum'^2 / r(sum)
    quietly summarize e if !missing(e, d)
    local rn = r(sum)
    quietly summarize d if !missing(e, d)
    local rat = `rn' / r(sum)
    drop e e2 d
    capture erase "`W'/x2.dta"
    quietly dataprobe, gatesonly ledger("`W'/x2.dta") stat( ///
        mean ((y > 50) * z) 0 1e9 \ sd ((y > 50) * z) 0 1e9 \ p25 ((y > 50) * z) 0 1e9 \ ///
        sum ((y > 50) * z) 0 1e9 \ n ((y > 50) * z) 0 1e9 \ distinct ((y > 50) * z) 0 1e9 \ ///
        pmiss ((y > 50) * z) 0 1 \ ess ((y > 50) * z) 0 1e9 \ ///
        ratio ((y > 50) * z) (dx > 0) 0 1e9)
    use "`W'/x2.dta", clear
    quietly keep if family == "stat"
    assert _N == 9
    assert status == "pass"
    local i = 0
    foreach s in mean sd p25 sum n distinct pmiss ess {
        local ++i
        local e = cond("`s'" == "mean", `emean', cond("`s'" == "sd", `esd', cond("`s'" == "p25", `ep25', ///
            cond("`s'" == "sum", `esum', cond("`s'" == "n", `en', cond("`s'" == "distinct", `edist', ///
            cond("`s'" == "pmiss", `epm', `eess')))))))
        assert label[`i'] == "`s' ((y > 50) * z)"
        assert reldif(observed_num[`i'], `e') < 1e-12
    }
    assert label[9] == "ratio ((y > 50) * z)/(dx > 0)"
    assert variable[9] == "((y > 50) * z) (dx > 0)"
    assert reldif(observed_num[9], `rat') < 1e-12
}
local rc = _rc
_gx_tally `rc' "X2 every statistic over an expression, and ratio of two, against base Stata"

**# X3 maskrare: a small count and a small share are withheld
capture noisily {
    _gx_fix
    quietly replace dx = 0 if !missing(dx)
    quietly replace dx = 1 in 30/32
    capture erase "`W'/x3.dta"
    quietly dataprobe, gatesonly maskrare mincell(5) ledger("`W'/x3.dta") ///
        stat(sum (dx == 1) 0 1000 \ mean (dx == 1) 0 1 \ n (dx == 1) 0 1000)
    use "`W'/x3.dta", clear
    quietly keep if family == "stat"
    assert _N == 3
    * three ones: the sum prints <5, the share is withheld, n (110 known) shows
    assert observed[1] == "sum <5"
    assert missing(observed_num[1]) & obs_masked[1] == 1
    assert missing(observed_num[2]) & obs_masked[2] == 1
    assert strpos(observed[2], "0.027") == 0
    assert observed_num[3] == 110 & obs_masked[3] == 0
}
local rc = _rc
_gx_tally `rc' "X3 maskrare: a small count of an expression and its share are withheld"

**# X4 string and strL operands: "" is missing
capture noisily {
    _gx_fix
    gen strL sl = sex
    quietly count if sex == "F"
    local nf = r(N)
    quietly count if sex != ""
    local p = `nf' / r(N)
    capture erase "`W'/x4.dta"
    quietly dataprobe, gatesonly ledger("`W'/x4.dta") stat(mean (sex == "F") 0 1 \ mean (sl == "F") 0 1 \ pmiss (sl == "F") 0 1)
    use "`W'/x4.dta", clear
    quietly keep if family == "stat"
    assert reldif(observed_num[1], `p') < 1e-14
    assert reldif(observed_num[2], `p') < 1e-14
    assert reldif(observed_num[3], 3 / 120) < 1e-14
    assert label[2] == `"mean (sl == "F")"'
}
local rc = _rc
_gx_tally `rc' "X4 string and strL operands; a blank string is missing"

**# X5 hostile expression text reaches ledger and console as typed
capture noisily {
    _gx_fix
    local hv = "x" + char(36) + "r{s}'t"
    quietly gen str20 h = cond(mod(_n, 4) == 0, "`macval(hv)'", "o")
    local ex = "(h == " + char(34) + "`macval(hv)'" + char(34) + ")"
    capture erase "`W'/x5.dta"
    tempfile lg
    quietly log using "`lg'.log", replace text name(x5)
    capture noisily dataprobe, gatesonly ledger("`W'/x5.dta") stat(mean `macval(ex)' 0 0.1)
    assert _rc == 9
    quietly log close x5
    use "`W'/x5.dta", clear
    quietly keep if family == "stat"
    assert _N == 1
    assert label == "mean " + `"`macval(ex)'"'
    assert reldif(observed_num, 0.25) < 1e-14
    assert status == "fail"
    _gx_has "`lg'.log" `"stat(mean `macval(ex)'): "'
    assert r(n) >= 1
    * a backtick inside the literal
    _gx_fix
    local hv2 = "a" + char(96) + "b"
    quietly gen str20 h = cond(_n <= 30, "`macval(hv2)'", "o")
    local ex2 = "(h == " + char(34) + "`macval(hv2)'" + char(34) + ")"
    capture erase "`W'/x5b.dta"
    quietly dataprobe, gatesonly ledger("`W'/x5b.dta") stat(mean `macval(ex2)' 0 1)
    use "`W'/x5b.dta", clear
    quietly keep if family == "stat"
    assert label == "mean " + `"`macval(ex2)'"'
    assert reldif(observed_num, 0.25) < 1e-14
}
local rc = _rc
capture log close x5
_gx_tally `rc' "X5 hostile expression text (quotes, dollar, braces, backtick) as typed"

**# X6 refusals; the plain forms unchanged
capture noisily {
    _gx_fix
    set varabbrev on
    foreach e in "(missing(dx))" "(mi(dx))" "(dx == .)" "(dx > .a)" "(y[_n-1] > 0)" "(_n > 3)" "(_N)" {
        capture dataprobe, gatesonly stat(mean `e' 0 1)
        assert _rc == 198
        assert c(varabbrev) == "on"
    }
    * an unclosed ( reaches stat() through a checks() row
    preserve
    clear
    quietly set obs 2
    gen str5 gate = "stat"
    gen str12 var = cond(_n == 1, "(dx == 1", "(dx == 1)")
    gen str4 values = "mean"
    gen str1 arg1 = "0"
    gen str1 arg2 = "1"
    quietly save "`W'/x6ck.dta", replace
    quietly keep in 2
    quietly save "`W'/x6ok.dta", replace
    restore
    capture dataprobe, gatesonly checks("`W'/x6ck.dta")
    assert _rc == 198
    capture erase "`W'/x6okl.dta"
    capture dataprobe, gatesonly checks("`W'/x6ok.dta") ledger("`W'/x6okl.dta")
    assert _rc == 0
    preserve
    use "`W'/x6okl.dta", clear
    quietly count if family == "stat" & label == "mean (dx == 1)" & variable == "(dx == 1)"
    assert r(N) == 1
    restore
    capture dataprobe, gatesonly stat(mean (sex) 0 1)
    assert _rc == 109
    capture dataprobe, gatesonly stat(mean (nosuch > 1) 0 1)
    assert _rc == 111
    capture dataprobe, gatesonly stat(mean (dx == 1) 0)
    assert _rc == 198
    * a decimal is a number, not a missing literal
    capture dataprobe, gatesonly stat(mean (dx > .5) 0 1 \ mean (y * 1e-2 > 0.5) 0 1)
    assert _rc == 0
    set varabbrev off
    * the plain forms read as before
    capture erase "`W'/x6.dta"
    quietly dataprobe, gatesonly ledger("`W'/x6.dta") stat(mean y 0 100 \ ratio y z 0 100)
    use "`W'/x6.dta", clear
    quietly keep if family == "stat"
    assert label[1] == "mean y" & strtrim(variable[1]) == "y"
    assert label[2] == "ratio y/z" & variable[2] == "y z"
}
local rc = _rc
set varabbrev off
_gx_tally `rc' "X6 refusals (missing(), ., subscripts, unclosed, string, unknown); plain forms unchanged"

**# X7 if/in, the entry's if, exclude() and safe
capture noisily {
    _gx_fix
    quietly count if dx == 1 & g == "A" & _n <= 100
    local n1 = r(N)
    quietly count if !missing(dx) & g == "A" & _n <= 100
    local p = `n1' / r(N)
    capture erase "`W'/x7.dta"
    quietly dataprobe in 1/100, gatesonly ledger("`W'/x7.dta") ///
        stat(mean (dx == 1) 0 1 if g == "A" \ mean (dx == 1) 0 1)
    use "`W'/x7.dta", clear
    quietly keep if family == "stat"
    assert reldif(observed_num[1], `p') < 1e-14
    _gx_fix
    capture erase "`W'/x7b.dta"
    capture noisily dataprobe, gatesonly exclude(dx) ledger("`W'/x7b.dta") stat(mean (dx == 1) 0.9 1)
    use "`W'/x7b.dta", clear
    quietly keep if family == "stat"
    assert observed == "mean [excluded]"
    assert missing(observed_num)
    assert status == "fail"
    _gx_fix
    gen int dt = td(01jan2020) + _n
    format dt %td
    capture erase "`W'/x7c.dta"
    quietly dataprobe, gatesonly safe ledger("`W'/x7c.dta") stat(mean (dt + 0) 0 1e9 \ n (dt + 0) 0 1e9)
    use "`W'/x7c.dta", clear
    quietly keep if family == "stat"
    assert observed[1] == "mean [withheld]"
    assert missing(observed_num[1])
    assert observed_num[2] == 120
}
local rc = _rc
_gx_tally `rc' "X7 if/in and the entry's if; exclude() and safe withhold an expression's value"

**# X8 empty scope and all-missing operands
capture noisily {
    _gx_fix
    capture erase "`W'/x8.dta"
    capture noisily dataprobe, gatesonly ledger("`W'/x8.dta") ///
        stat(mean (dx == 1) 0 1 if g == "none" \ mean (ym > 0) 0 1 \ n (ym > 0) 0 0 \ pmiss (ym > 0) 1 1)
    assert _rc == 9
    use "`W'/x8.dta", clear
    quietly keep if family == "stat"
    assert observed[1] == "mean no nonmissing values" & status[1] == "fail"
    assert observed[2] == "mean no nonmissing values" & status[2] == "fail"
    assert observed_num[3] == 0 & status[3] == "pass"
    assert observed_num[4] == 1 & status[4] == "pass"
}
local rc = _rc
_gx_tally `rc' "X8 empty scope and all-missing operands"

**# X9 by() + maskrare: an expression's per-group count is withheld as its variable's
* (fixer, review finding 1).  Three groups of 30 with 6, 6 and 4 flagged
* rows: the pooled frequency table prints 16, so showing 6 and 6 gives the
* masked 4 back.  Oracle: collapse counts; the property is the documented
* pooled-remainder rule (the total minus the shown counts is never 1 to
* m-1) and that each expression form writes the rows its variable form
* writes.
capture program drop _gx_x9rows
program define _gx_x9rows
    * keep the stat rows of a ledger: group, shown value, masked flag
    args file
    use `"`file'"', clear
    quietly keep if family == "stat"
    keep grp observed observed_num obs_masked
    quietly generate byte supp = strpos(observed, "[suppressed]") > 0
    drop observed
    sort grp
end
capture noisily {
    clear
    set seed 21019
    quietly set obs 90
    gen byte g = 1 + floor((_n - 1) / 30)
    gen byte flag = inlist(_n, 1, 2, 3, 4, 5, 6, 31, 32, 33, 34, 35, 36, 61, 62, 63, 64)
    gen double x = _n
    quietly replace x = . if inlist(_n, 7, 8, 40)
    gen double u = runiform()
    sort u
    drop u
    tempfile x9d
    quietly save `x9d'
    * oracle: per-group counts of flag == 1 and of missing x, and the totals
    preserve
    gen byte one = flag == 1
    gen byte mx = missing(x)
    collapse (sum) k = one m = mx, by(g)
    forvalues j = 1/3 {
        local k`j' = k[`j']
        local m`j' = m[`j']
    }
    restore
    quietly count if flag == 1
    local ktot = r(N)
    assert `ktot' == 16 & `k1' == 6 & `k2' == 6 & `k3' == 4
    local i = 0
    foreach f in "sum flag 100 200" "sum (flag == 1) 100 200" "sum (flag) 100 200" ///
        "n x 1000 2000" "n (x + 0) 1000 2000" "pmiss x 0.5 1" "pmiss (x + 0) 0.5 1" {
        local ++i
        foreach bf in "" byfreq {
            use `x9d', clear
            capture erase "`W'/x9_`i'`bf'.dta"
            quietly dataprobe flag x, by(g) maskrare warn `bf' stat(`f') ledger("`W'/x9_`i'`bf'.dta")
        }
    }
    * the sum forms: shown counts equal collapse; the remainder is not 1 to 4
    foreach i in 1 2 3 {
        foreach bf in "" byfreq {
            _gx_x9rows "`W'/x9_`i'`bf'.dta"
            assert _N == 3
            local rem = `ktot'
            forvalues j = 1/3 {
                if !missing(observed_num[`j']) {
                    assert observed_num[`j'] == `k`j''
                    local rem = `rem' - observed_num[`j']
                }
            }
            assert !(`rem' >= 1 & `rem' < 5)
            assert supp[1] + supp[2] + supp[3] >= 1
        }
    }
    * each expression form writes its variable form's rows
    foreach pr in "1 2" "1 3" "4 5" "6 7" {
        gettoken a b : pr
        local b = strtrim("`b'")
        foreach bf in "" byfreq {
            _gx_x9rows "`W'/x9_`a'`bf'.dta"
            tempfile ref
            quietly save `ref'
            _gx_x9rows "`W'/x9_`b'`bf'.dta"
            cf _all using `ref'
        }
    }
}
local rc = _rc
_gx_tally `rc' "X9 by() + maskrare: an expression's per-group sum, n and pmiss are withheld as its variable's"

**# R1 byrule total(): float weights, tolerance, failing groups against collapse
capture noisily {
    _gx_fix
    * id 3: one weight 0.2 (total 1.1); id 5: every weight missing
    quietly replace w = 0.2 in 25
    quietly replace w = . if id == 5
    preserve
    quietly generate double wd = w
    quietly collapse (sum) tw = wd (count) nw = wd, by(id)
    quietly count if abs(tw - 1) > 1e-6 | nw == 0
    local nbad_tol = r(N)
    quietly count if tw != 1 | nw == 0
    local nbad_eq = r(N)
    restore
    assert `nbad_tol' == 2
    assert `nbad_eq' == 12
    capture erase "`W'/r1.dta"
    tempfile lg
    quietly log using "`lg'.log", replace text name(r1)
    capture noisily dataprobe, gatesonly ledger("`W'/r1.dta") ///
        byrule(id: "weq": total(w) == 1 \ id: "wtol": abs(total(w) - 1) <= 1e-6 \ id: "wgt": total(w) > 0.5)
    quietly log close r1
    use "`W'/r1.dta", clear
    quietly keep if family == "byrule"
    assert _N == 3
    assert observed[1] == "`nbad_eq' groups fail" & observed_num[1] == `nbad_eq'
    assert observed[2] == "`nbad_tol' groups fail" & observed_num[2] == `nbad_tol'
    * total(w) > 0.5 holds for id 3 but the all-missing id 5 fails
    assert observed[3] == "1 group fails" & observed_num[3] == 1
    assert message[2] == "byrule(wtol): 2 groups fail abs(total(w) - 1) <= 1e-6"
    _gx_has "`lg'.log" "byrule(wtol): 2 groups fail abs(total(w) - 1) <= 1e-6"
    assert r(n) == 1
    * with the weights corrected, the tolerance rule passes and == still fails
    _gx_fix
    capture erase "`W'/r1b.dta"
    capture noisily dataprobe, gatesonly ledger("`W'/r1b.dta") ///
        byrule(id: "weq": total(w) == 1 \ id: "wtol": abs(total(w) - 1) <= 1e-6)
    use "`W'/r1b.dta", clear
    quietly keep if family == "byrule"
    assert status[1] == "fail" & observed_num[1] == 12
    assert status[2] == "pass" & observed[2] == "0 groups fail"
}
local rc = _rc
capture log close r1
_gx_tally `rc' "R1 byrule total(): float weights need the tolerance; perturbed and all-missing groups fail"

**# R2 spread() mean() gmin() gmax() count(); mixed row terms; min()/max() stay row functions
capture noisily {
    _gx_fix
    quietly replace y = . if id == 7
    preserve
    quietly collapse (max) mx = y (min) mn = y (mean) mu = y (count) ny = y (count) nr = one, by(id)
    quietly count if mx - mn > 30 | ny == 0
    local b_spread = r(N)
    quietly count if mu < 50 | ny == 0
    local b_mean = r(N)
    quietly count if ny < 9
    local b_count = r(N)
    quietly count if ny == 0
    local b_mm = r(N)
    restore
    assert `b_mm' == 1
    capture erase "`W'/r2.dta"
    capture noisily dataprobe, gatesonly ledger("`W'/r2.dta") ///
        byrule(id: "spread": spread(y) <= 30 \ id: "mean": mean(y) >= 50 \ ///
        id: "count": count(y) >= 9 \ id: "mm": gmax(y) - gmin(y) == spread(y) \ ///
        id: "size": count(1) == 10 \ id (t): "first": _n > 1 | t == gmin(t) \ ///
        id: "rowmax": max(y, 0) >= 0)
    use "`W'/r2.dta", clear
    quietly keep if family == "byrule"
    assert _N == 7
    assert observed_num[1] == `b_spread'
    assert observed_num[2] == `b_mean'
    assert observed_num[3] == `b_count'
    assert observed_num[4] == `b_mm'
    assert observed_num[5] == 0 & status[5] == "pass"
    assert observed_num[6] == 0 & status[6] == "pass"
    * a row rule: counted in rows, as before
    assert observed[7] == "0 fail" & status[7] == "pass"
}
local rc = _rc
_gx_tally `rc' "R2 spread/mean/gmin/gmax/count against collapse; mixed row terms; max() a row function"

**# R3 hostile string groups, a missing group value, if/in, by()
capture noisily {
    _gx_fix
    quietly gen str20 hs = ""
    quietly replace hs = "a" + char(34) + "b" if id <= 3
    quietly replace hs = "c'd" if inrange(id, 4, 6)
    quietly replace hs = char(36) + "e{f}" if inrange(id, 7, 9)
    quietly replace hs = char(96) + "g'" if id == 10
    * id 11, 12: hs blank, a group of its own (by semantics)
    quietly replace w = 0.3 in 1
    quietly replace w = 0.3 in 115
    preserve
    quietly generate double wd = w
    quietly collapse (sum) tw = wd (count) nr = one, by(hs)
    assert _N == 5
    quietly count if abs(tw - nr / 10) > 1e-6
    local ea = r(N)
    restore
    * row 1 (group a"b) and row 115 (the blank group) are 0.2 above
    assert `ea' == 2
    capture erase "`W'/r3.dta"
    capture noisily dataprobe, gatesonly ledger("`W'/r3.dta") ///
        byrule(hs: "w": abs(total(w) - count(1) / 10) <= 1e-6)
    use "`W'/r3.dta", clear
    quietly keep if family == "byrule"
    assert observed_num == `ea'
    * if/in: rows 1..110 with g != "A": the blank group loses row 115
    _gx_fix
    quietly replace w = 0.3 in 2
    quietly replace w = 0.3 in 115
    preserve
    quietly keep in 1/110
    quietly keep if g != "A"
    quietly generate double wd = w
    quietly collapse (sum) tw = wd (count) nr = one, by(id)
    quietly count if abs(tw - nr / 10) > 1e-6
    local eb = r(N)
    restore
    assert `eb' == 1
    capture erase "`W'/r3b.dta"
    capture noisily dataprobe if g != "A" in 1/110, gatesonly ledger("`W'/r3b.dta") ///
        byrule(id: "w": abs(total(w) - count(1) / 10) <= 1e-6)
    use "`W'/r3b.dta", clear
    quietly keep if family == "byrule"
    assert observed_num == `eb'
    * a missing id value is its own group
    _gx_fix
    quietly replace id = . in 1/5
    preserve
    quietly collapse (count) nr = one, by(id)
    quietly count if nr != 10
    local ec = r(N)
    restore
    assert `ec' == 2
    capture erase "`W'/r3c.dta"
    capture noisily dataprobe, gatesonly ledger("`W'/r3c.dta") byrule(id: "n": count(1) == 10)
    use "`W'/r3c.dta", clear
    quietly keep if family == "byrule"
    assert observed_num == `ec'
    * by(): the aggregates are taken over the call's sample, and each by()
    * group counts the failing id groups that have rows in it
    _gx_fix
    quietly gen str1 bg = cond(id <= 6, "B", "C")
    quietly replace w = 0.3 in 15
    quietly replace w = 0.3 in 85
    quietly replace w = 0.3 in 95
    capture erase "`W'/r3d.dta"
    capture noisily dataprobe, gatesonly by(bg) ledger("`W'/r3d.dta") byrule(id: "w": abs(total(w) - 1) <= 1e-6)
    use "`W'/r3d.dta", clear
    quietly keep if family == "byrule"
    assert _N == 2
    quietly count if strpos(grp, "[B]") & observed_num == 1
    assert r(N) == 1
    quietly count if strpos(grp, "[C]") & observed_num == 2
    assert r(N) == 1
}
local rc = _rc
_gx_tally `rc' "R3 hostile string groups, a missing group value, if/in and by(): counts against collapse"

**# R4 maskrare group counts
capture noisily {
    _gx_fix
    * three failing id groups of 12: <5; then ten failing: all but <5
    quietly replace w = 0.3 if inlist(id, 1, 2, 3) & mod(_n, 10) == 1
    capture erase "`W'/r4.dta"
    capture noisily dataprobe, gatesonly maskrare mincell(5) ledger("`W'/r4.dta") ///
        byrule(id: "w": abs(total(w) - 1) <= 1e-6)
    use "`W'/r4.dta", clear
    quietly keep if family == "byrule"
    assert observed == "<5 groups fail"
    assert missing(observed_num) & obs_masked == 1
    _gx_fix
    quietly replace w = 0.3 if id <= 10 & mod(_n, 10) == 1
    capture erase "`W'/r4b.dta"
    capture noisily dataprobe, gatesonly maskrare mincell(5) ledger("`W'/r4b.dta") ///
        byrule(id: "w": abs(total(w) - 1) <= 1e-6)
    use "`W'/r4b.dta", clear
    quietly keep if family == "byrule"
    assert observed == "all but <5 groups fail"
    assert missing(observed_num) & obs_masked == 1
    * six failing of 12: shown
    _gx_fix
    quietly replace w = 0.3 if id <= 6 & mod(_n, 10) == 1
    capture erase "`W'/r4c.dta"
    capture noisily dataprobe, gatesonly maskrare mincell(5) ledger("`W'/r4c.dta") ///
        byrule(id: "w": abs(total(w) - 1) <= 1e-6)
    use "`W'/r4c.dta", clear
    quietly keep if family == "byrule"
    assert observed == "6 groups fail" & observed_num == 6 & obs_masked == 0
}
local rc = _rc
_gx_tally `rc' "R4 maskrare: <m and all but <m failing-group counts, observed_num withheld"

**# R5 refusals; plain byrule unchanged
capture noisily {
    _gx_fix
    set varabbrev on
    foreach e in "total(count(w)) == 1" "total(missing(w)) == 0" "total(w[_n-1]) > 0" ///
        "total(w == .) == 0" "spread(_n) < 3" {
        capture dataprobe, gatesonly byrule(id: "bad": `e')
        assert _rc == 198
        assert c(varabbrev) == "on"
    }
    capture dataprobe, gatesonly byrule(id: "bad": total(nosuch) == 1)
    assert _rc == 111
    * an unclosed ( reaches byrule() through a checks() row
    preserve
    clear
    quietly set obs 1
    gen str6 gate = "byrule"
    gen str3 var = "bad"
    gen str2 values = "id"
    gen str12 pattern = "total(w > 0"
    quietly save "`W'/r5ck.dta", replace
    restore
    capture dataprobe, gatesonly checks("`W'/r5ck.dta")
    assert _rc == 198
    capture dataprobe, gatesonly byrule(id: "bad": total(sex) == 1)
    assert _rc == 109
    set varabbrev off
    * the plain form reads as before, in rows
    quietly count if !(y > 1000)
    local nneg = r(N)
    capture erase "`W'/r5.dta"
    capture quietly dataprobe, gatesonly ledger("`W'/r5.dta") byrule(id (t): "seq": _n >= 1 \ id: "neg": y > 1000)
    assert _rc == 9
    use "`W'/r5.dta", clear
    quietly keep if family == "byrule"
    assert message[1] == "byrule(seq): 0 obs fail _n >= 1"
    assert observed_num[2] == `nneg'
    assert observed[2] == "`nneg' fail"
    * order and data unchanged after an aggregate rule
    _gx_fix
    quietly generate long _ord = _n
    quietly dataprobe, gatesonly byrule(id (t): "first": _n > 1 | t == gmin(t))
    assert _ord == _n
    assert "`: sortedby'" == ""
}
local rc = _rc
set varabbrev off
_gx_tally `rc' "R5 refusals (nested, missing(), subscripts, ., unclosed, unknown, string); plain form and data order unchanged"

quietly cd "`c(pwd)'"
macro drop DATAMAP_DQ
sysdir set PLUS "`oldplus'"
sysdir set PERSONAL "`oldpersonal'"
display "RESULT: test_datamap_v210_groupexpr tests=$GX_T pass=$GX_P fail=$GX_F"
local _f = $GX_F
macro drop GX_T GX_P GX_F
log close main
if `_f' exit 1
