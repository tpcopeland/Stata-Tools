*! test_datacheck_v190_groupfreq.do Version 1.0.0  2026/10/04
*! 1.9.0 O5: a failing groupstat(..., band() [relative]) reports the groups above
*! and below the band, each with its group count and its in-scope row count,
*! masked under maskrare; per-group ledger rows and the passing/review cases are
*! unchanged.  F7: datacheck ..., by(g) byfreq prints a masked frequency table
*! for each categorical and string variable within each by() group.
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set processors 1
set linesize 255
capture log close _all
log using "test_datacheck_v190_groupfreq.log", replace text name(main)
local pkg_dir = regexr("`c(pwd)'", "/qa$", "")
tempfile base
local work "`base'_v190gf"
capture mkdir "`work'"
capture mkdir "`work'/plus"
capture mkdir "`work'/personal"
mata: assert(direxists(st_local("work") + "/plus") & direxists(st_local("work") + "/personal"))
local oldplus : sysdir PLUS
local oldpersonal : sysdir PERSONAL
sysdir set PLUS "`work'/plus"
sysdir set PERSONAL "`work'/personal"
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") replace
discard
macro drop DATAMAP_DQ
global TC 0
global PASS 0
global FAIL 0

capture program drop _u_tally
program define _u_tally
    args rc msg
    global TC = $TC + 1
    if `rc' == 0 {
        display as result "PASS: `msg'"
        global PASS = $PASS + 1
    }
    else {
        display as error "FAIL (rc=`rc'): `msg'"
        global FAIL = $FAIL + 1
    }
end

* Output of the datacheck call in a log (the lines after its echo, up to the next
* echoed command), compared between two logs.  With prefix = 1, the second log's
* lines before its GROUPWISE FREQUENCIES block must equal the whole first output.
mata:
string colvector _gf_out(string scalar f)
{
    string colvector t
    real scalar i, a, b
    t = cat(f)
    a = 0
    for (i = 1; i <= rows(t); i++) {
        if (substr(t[i], 1, 1) == "." & strpos(t[i], "capture noisily datacheck") > 0) {
            a = i + 1
            break
        }
    }
    b = rows(t)
    for (i = a; i <= rows(t); i++) {
        if (substr(t[i], 1, 2) == ". ") {
            b = i - 1
            break
        }
    }
    return(t[|a \ b|])
}
real scalar _gf_same(string scalar fa, string scalar fb, real scalar prefix)
{
    string colvector x, y
    real scalar i
    x = _gf_out(fa)
    y = _gf_out(fb)
    if (prefix) {
        i = selectindex(strtrim(y) :== "GROUPWISE FREQUENCIES")
        y = y[|1 \ i[1] - 2|]
        x = x[|1 \ rows(y)|]
    }
    return(rows(x) == rows(y) & all(x :== y))
}
end

* O5 fixture: 130 rows, mean x by g; A 40 and B 30 pass, C 20 and D 12 sit above,
* E 3 and F 25 sit below.  Pooled mean 1513/130 = 11.638: ratios A,B .859;
* C 1.718; D 2.578; E .0859; F .1718.
capture program drop _o_fix
program define _o_fix
    clear
    quietly set obs 130
    gen str1 g = ""
    quietly replace g = "A" in 1/40
    quietly replace g = "B" in 41/70
    quietly replace g = "C" in 71/90
    quietly replace g = "D" in 91/102
    quietly replace g = "E" in 103/105
    quietly replace g = "F" in 106/130
    gen double x = 10
    quietly replace x = 20 if g == "C"
    quietly replace x = 30 if g == "D"
    quietly replace x = 1 if g == "E"
    quietly replace x = 2 if g == "F"
end

* Run gatesonly with a groupstat entry; leave the groupstat ledger rows in
* memory (the data is restored by the caller re-building the fixture)
capture program drop _o_run
program define _o_run, rclass
    args gs mask logfile
    tempfile led
    capture erase `"`led'.dta"'
    local mopt ""
    if `mask' > 0 local mopt "maskrare mincell(`mask')"
    quietly log using `"`logfile'"', replace text name(orun)
    capture noisily datacheck, gatesonly groupstat(`gs') ledger("`led'.dta") `mopt'
    local drc = _rc
    quietly log close orun
    return scalar rc = `drc'
    return local led `"`led'.dta"'
    global O_LED `"`led'.dta"'
end

* Load the groupstat ledger of a run: fail rows only
capture program drop _o_fails
program define _o_fails
    args led
    quietly use `"`led'"', clear
    quietly keep if family == "groupstat" & status == "fail"
end

* Independent oracle: groups above and below the band and their rows
capture program drop _o_oracle
program define _o_oracle, rclass
    args lo hi rel minrows
    if "`minrows'" == "" local minrows 1
    tempvar m n
    quietly bysort g: egen double `m' = mean(x)
    quietly bysort g: gen long `n' = _N
    quietly summarize x, meanonly
    local pool = r(mean)
    local ga = 0
    local gb = 0
    local ra = 0
    local rb = 0
    quietly levelsof g, local(gl)
    foreach gg of local gl {
        quietly summarize `m' if g == "`gg'", meanonly
        local v = r(mean)
        quietly count if g == "`gg'"
        local nn = r(N)
        if `nn' < `minrows' continue
        if "`rel'" != "" local v = `v' / `pool'
        if `v' > `hi' {
            local ++ga
            local ra = `ra' + `nn'
        }
        else if `v' < `lo' {
            local ++gb
            local rb = `rb' + `nn'
        }
    }
    return scalar ga = `ga'
    return scalar gb = `gb'
    return scalar ra = `ra'
    return scalar rb = `rb'
end

**# O5.1 relative band: 2 groups above (rows 32), 2 below (rows 28), against the oracle
capture noisily {
    _o_fix
    _o_oracle 0.8 1.2 rel
    assert r(ga) == 2 & r(gb) == 2 & r(ra) == 32 & r(rb) == 28
    local want "2 groups above (rows 32), 2 groups below (rows 28)"
    tempfile lg
    _o_run "mean x, by(g) band(0.8 1.2) relative" 0 "`lg'.log"
    assert r(rc) == 9
    _o_fails `"$O_LED"'
    * the per-group ledger rows stay: one failing row per failing group
    assert _N == 4
    assert strpos(observed, "`want'") > 0
    quietly count if substr(observed, 1, 15) == "ratio to pooled"
    assert r(N) == 4
    quietly count if strpos(grp, "by(g) = ") == 1
    assert r(N) == 4
}
local rc = _rc
_u_tally `rc' "O5 relative band: groups and rows above/below match the oracle in the ledger observed text"

**# O5.2 the failing message carries the direction summary
capture noisily {
    _o_fix
    tempfile lg
    _o_run "mean x, by(g) band(0.8 1.2) relative" 0 "`lg'.log"
    quietly use `"$O_LED"', clear
    quietly keep if family == "groupstat" & status == "fail"
    forvalues i = 1/4 {
        local msg = message[`i']
        assert strpos(`"`msg'"', "[2 groups above (rows 32), 2 groups below (rows 28)]") > 0
        assert strpos(`"`msg'"', "expected ratio to pooled in [.8, 1.2]") > 0
    }
    * each failing group is named in its own row
    foreach gg in C D E F {
        quietly count if strpos(grp, "by(g) = `gg'") > 0
        assert r(N) == 1
    }
    * ledger schema: the same columns as before (22, none added)
    quietly use `"$O_LED"', clear
    quietly describe
    assert r(k) == 22
}
local rc = _rc
_u_tally `rc' "O5 failing message names the direction summary; four per-group rows, 22 ledger columns"

**# O5.3 absolute band: above and below by the value, same oracle
capture noisily {
    _o_fix
    _o_oracle 8 12
    assert r(ga) == 2 & r(gb) == 2 & r(ra) == 32 & r(rb) == 28
    tempfile lg
    _o_run "mean x, by(g) band(8 12)" 0 "`lg'.log"
    assert r(rc) == 9
    _o_fails `"$O_LED"'
    assert _N == 4
    assert strpos(observed, "2 groups above (rows 32), 2 groups below (rows 28)") > 0
    * a band that only the top group breaks: one above, none below, no empty direction
    _o_fix
    _o_oracle 8 25
    assert r(ga) == 1 & r(gb) == 2 & r(ra) == 12 & r(rb) == 28
    _o_run "mean x, by(g) band(8 25)" 0 "`lg'.log"
    _o_fails `"$O_LED"'
    assert _N == 3
    assert strpos(observed, "1 group above (rows 12), 2 groups below (rows 28)") > 0
    _o_fix
    _o_run "mean x, by(g) band(0 25)" 0 "`lg'.log"
    _o_fails `"$O_LED"'
    assert _N == 1
    assert strpos(observed, "1 group above (rows 12)") > 0
    assert strpos(observed, "below") == 0
}
local rc = _rc
_u_tally `rc' "O5 absolute band: counts, singular noun, and an empty direction left out"

**# O5.4 maskrare: the small below-band group is pooled away, its rows print as <5
capture noisily {
    * F passes (x=10); E (3 rows, x=1) is the only group below the band
    _o_fix
    quietly replace x = 10 if g == "F"
    _o_oracle 8 25
    assert r(ga) == 1 & r(gb) == 1 & r(ra) == 12 & r(rb) == 3
    tempfile lg
    _o_run "mean x, by(g) band(8 25)" 5 "`lg'.log"
    assert r(rc) == 9
    _o_fails `"$O_LED"'
    assert _N == 2
    quietly count if strpos(observed, "1 group above (rows 12), 1 group below (rows <5)") > 0
    assert r(N) == 2
    * the pooled-away group fails as [suppressed] with its value withheld
    quietly count if strpos(observed, "[suppressed]") > 0 & masked == 1
    assert r(N) == 1
    * the unmasked small row count never reaches the log or the ledger
    quietly use `"$O_LED"', clear
    quietly keep if family == "groupstat"
    quietly count if strpos(observed, "rows 3)") > 0 | strpos(message, "rows 3)") > 0
    assert r(N) == 0
    tempname fh
    file open `fh' using "`lg'.log", read text
    local leak = 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "rows 3)") > 0 local leak = 1
        file read `fh' line
    }
    file close `fh'
    assert `leak' == 0
    * the masked small group is pooled in the table too
    _o_fix
    quietly replace x = 10 if g == "F"
    quietly log using "`lg'2.log", replace text name(o54)
    capture noisily datacheck, groupstat(mean x, by(g) band(8 25)) maskrare mincell(5)
    quietly log close o54
    file open `fh' using "`lg'2.log", read text
    local seen = 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "groups with <5 rows: 1") > 0 local seen = 1
        file read `fh' line
    }
    file close `fh'
    assert `seen' == 1
}
local rc = _rc
_u_tally `rc' "O5 maskrare: below-band rows print <5, pooled-away group still fails, no unmasked 3 anywhere"

**# O5.5 maskrare complement: rows above recoverable from the total print as all but <5
capture noisily {
    * C 40 rows above, E 3 rows below (pooled away), no passing group:
    * total 43, above 40 leaves 3 = a small cell
    clear
    quietly set obs 43
    gen str1 g = cond(_n <= 40, "C", "E")
    gen double x = cond(g == "C", 20, 1)
    tempfile lg
    _o_run "mean x, by(g) band(8 12)" 5 "`lg'.log"
    assert r(rc) == 9
    _o_fails `"$O_LED"'
    assert _N == 2
    quietly count if strpos(observed, "1 group above (rows all but <5), 1 group below (rows <5)") > 0
    assert r(N) == 2
    * a passing remainder of 1..4 rows: both counts withheld together
    clear
    quietly set obs 47
    gen str1 g = cond(_n <= 40, "C", cond(_n <= 44, "E", "P"))
    gen double x = cond(g == "C", 20, cond(g == "E", 1, 10))
    * C 40 above, E 4 below, P 3 passing: remainder 3 is a small cell
    _o_run "mean x, by(g) band(8 12)" 5 "`lg'.log"
    _o_fails `"$O_LED"'
    quietly count if strpos(observed, "1 group above (rows [suppressed]), 1 group below (rows [suppressed])") > 0
    assert r(N) == _N & _N == 2
    * unmasked, the same data prints exact counts
    clear
    quietly set obs 47
    gen str1 g = cond(_n <= 40, "C", cond(_n <= 44, "E", "P"))
    gen double x = cond(g == "C", 20, cond(g == "E", 1, 10))
    _o_run "mean x, by(g) band(8 12)" 0 "`lg'.log"
    _o_fails `"$O_LED"'
    quietly count if strpos(observed, "1 group above (rows 40), 1 group below (rows 4)") > 0
    assert r(N) == 2
    * several small below groups: the group count is masked with the rows
    clear
    quietly set obs 60
    gen str1 g = cond(_n <= 40, "P", "")
    quietly replace g = "a" in 41/42
    quietly replace g = "b" in 43/44
    quietly replace g = "c" in 45/46
    quietly replace g = "d" in 47/48
    quietly replace g = "e" in 49/60
    gen double x = cond(g == "P", 10, cond(g == "e", 10, 1))
    * a b c d: 4 groups of 2 below (8 rows); e 12 rows and P 40 pass
    _o_run "mean x, by(g) band(8 12)" 5 "`lg'.log"
    _o_fails `"$O_LED"'
    assert _N == 4
    * 8 rows reach the mask, but they are four groups of 2: the rows total
    * would pin small groups, so it is withheld (v190 review R1)
    quietly count if strpos(observed, "4 groups below (rows [suppressed])") > 0
    assert r(N) == 4
    quietly count if strpos(observed, "rows 8") > 0
    assert r(N) == 0
}
local rc = _rc
_u_tally `rc' "O5 maskrare complement: all but <5, the withheld remainder, and exact counts when not small"

**# O5.6 min() leaves small groups out of the band and out of the counts
capture noisily {
    _o_fix
    _o_oracle 8 12 "" 10
    assert r(ga) == 2 & r(gb) == 1 & r(ra) == 32 & r(rb) == 25
    tempfile lg
    _o_run "mean x, by(g) band(8 12) min(10)" 0 "`lg'.log"
    _o_fails `"$O_LED"'
    assert _N == 3
    assert strpos(observed, "2 groups above (rows 32), 1 group below (rows 25)") > 0
    * min() above every group: the band tested nothing, no direction at all
    _o_fix
    _o_run "mean x, by(g) band(8 12) min(100)" 0 "`lg'.log"
    _o_fails `"$O_LED"'
    assert _N == 1
    assert strpos(observed, "above") == 0 & strpos(observed, "below") == 0
}
local rc = _rc
_u_tally `rc' "O5 min(): excluded groups are not counted; nothing tested means no direction text"

**# O5.7 the entry's own if narrows the rows counted
capture noisily {
    _o_fix
    preserve
    quietly drop if g == "C" | g == "F"
    * pooled mean now over A B D E: (400+300+360+3)/85
    _o_oracle 8 12
    local ga = r(ga)
    local gb = r(gb)
    local ra = r(ra)
    local rb = r(rb)
    restore
    assert `ga' == 1 & `gb' == 1 & `ra' == 12 & `rb' == 3
    tempfile lg
    _o_run `"mean x, by(g) band(8 12) if g != "C" & g != "F""' 0 "`lg'.log"
    _o_fails `"$O_LED"'
    assert _N == 2
    assert strpos(observed, "1 group above (rows 12), 1 group below (rows 3)") > 0
    * row counts are in-scope rows only: a scope with missing x still counts the rows
    _o_fix
    quietly replace x = . in 91/94
    _o_run "mean x, by(g) band(8 25)" 0 "`lg'.log"
    _o_fails `"$O_LED"'
    assert strpos(observed, "1 group above (rows 12)") > 0
}
local rc = _rc
_u_tally `rc' "O5 entry if: counts follow the entry scope; rows include in-scope rows with missing x"

**# O5.8 passing, review and colon forms carry no direction text
capture noisily {
    _o_fix
    tempfile lg
    _o_run "mean x, by(g) band(0 100)" 0 "`lg'.log"
    assert r(rc) == 0
    quietly use `"$O_LED"', clear
    quietly keep if family == "groupstat"
    quietly count if strpos(observed, "above") > 0 | strpos(observed, "below") > 0 | strpos(message, "above") > 0
    assert r(N) == 0
    assert observed[2] == "6 groups within band"
    assert message[2] == "groupstat(mean x): every tested group within [0, 100]"
    _o_fix
    _o_run "mean x, by(g)" 0 "`lg'.log"
    assert r(rc) == 0
    quietly use `"$O_LED"', clear
    quietly keep if family == "groupstat"
    assert _N == 1
    assert message[1] == "groupstat(mean x, by(g)): 6 group(s) shown, pooled 11.64"
    * the colon form still refuses a band
    _o_fix
    capture datacheck, gatesonly groupstat(n mean: x, by(g) band(0 1))
    assert _rc == 198
    capture datacheck, gatesonly groupstat(n mean: x, by(g) relative)
    assert _rc == 198
    quietly datacheck, gatesonly groupstat(n mean: x, by(g))
}
local rc = _rc
_u_tally `rc' "O5 passing and review rows keep their exact text; colon form still refuses band()"

**# F7 fixture: s has designed counts per group; k is a numeric categorical with a value label
* g1 (12): a5 b4 c2 d1   g2 (9): a2 b2 c5   g3 (3): a3   g4 (7): a2 b2 c2 d1
capture program drop _f_fix
program define _f_fix
    clear
    local rows "g1 a 5 g1 b 4 g1 c 2 g1 d 1 g2 a 2 g2 b 2 g2 c 5 g3 a 3 g4 a 2 g4 b 2 g4 c 2 g4 d 1"
    quietly set obs 31
    gen str2 g = ""
    gen str1 s = ""
    local n = 0
    local nw : word count `rows'
    forvalues i = 1(3)`nw' {
        local gg : word `i' of `rows'
        local ss : word `=`i'+1' of `rows'
        local cc : word `=`i'+2' of `rows'
        forvalues j = 1/`cc' {
            local ++n
            quietly replace g = "`gg'" in `n'
            quietly replace s = "`ss'" in `n'
        }
    }
    assert `n' == 31
    gen byte gn = real(substr(g, 2, 1))
    label define gnl 1 "One" 2 "Two" 3 "Three" 4 "Four"
    label values gn gnl
    gen byte k = cond(s == "a", 1, cond(s == "b", 2, 3))
    label define kl 1 "low" 2 "mid" 3 "high"
    label values k kl
    gen double xx = _n
end

* Parse GROUPWISE FREQUENCIES for variable `var' into frame fpar (grp lev cnt kind)
capture program drop _f_parse
program define _f_parse
    args file var
    capture frame drop fpar
    frame create fpar str80 grp str40 lev double cnt str12 kind
    tempname fh
    local on = 0
    local inv = 0
    local grp ""
    file open `fh' using `"`file'"', read text
    file read `fh' line
    while r(eof) == 0 {
        local L `"`macval(line)'"'
        if strtrim(`"`L'"') == "GROUPWISE FREQUENCIES" local on = 1
        else if `on' & substr(`"`L'"', 1, 1) != " " & strtrim(`"`L'"') != "" local on = 0
        if `on' {
            if substr(`"`L'"', 1, 2) == "  " & substr(`"`L'"', 3, 1) != " " {
                local t = strtrim(`"`L'"')
                if substr(`"`t'"', 1, 3) != "by:" & substr(`"`t'"', 1, 6) != "groups" {
                    local inv = (`"`t'"' == "`var':")
                }
            }
            else if `inv' & substr(`"`L'"', 1, 13) == "    by group " {
                local grp = strtrim(substr(`"`L'"', 14, .))
                local grp = substr(`"`grp'"', 1, length(`"`grp'"') - 1)
            }
            else if `inv' & substr(`"`L'"', 1, 6) == "      " {
                local lv = strtrim(substr(`"`L'"', 7, 28))
                if substr(`"`lv'"', 1, 3) == "..." frame post fpar (`"`grp'"') ("") (.) ("more")
                else if substr(`"`lv'"', 1, 12) == "[suppressed]" frame post fpar (`"`grp'"') ("") (.) ("suppressed")
                else frame post fpar (`"`grp'"') (`"`lv'"') (real(strtrim(substr(`"`L'"', 35, 9)))) ("cell")
            }
        }
        file read `fh' line
    }
    file close `fh'
end

capture program drop _f_run
program define _f_run
    args file opts
    quietly log using `"`file'"', replace text name(frun)
    capture noisily datacheck s, by(g) `opts'
    local drc = _rc
    quietly log close frun
    assert `drc' == 0
end

* helper used by F7.3: counts of suppressed and shown cells in a pooled table
capture program drop _f_pool
program define _f_pool, rclass
    args file var
    tempname fh
    local nsup = 0
    local ncell = 0
    local on = 0
    file open `fh' using `"`file'"', read text
    file read `fh' line
    while r(eof) == 0 {
        local L `"`macval(line)'"'
        if strtrim(`"`L'"') == "CATEGORICAL" | strtrim(`"`L'"') == "STRING" local on = 1
        if `on' & substr(`"`L'"', 1, 4) == "    " & substr(`"`L'"', 5, 1) != " " {
            if strpos(`"`L'"', "[suppressed]") > 0 local ++nsup
            else if substr(strtrim(`"`L'"'), 1, 3) != "..." & strpos(`"`L'"', "(") > 0 local ++ncell
        }
        file read `fh' line
    }
    file close `fh'
    return scalar nsup = `nsup'
    return scalar ncell = `ncell'
end

**# F7.1 unmasked: every group table equals tabulate/count-if for that group
capture noisily {
    _f_fix
    tempfile lg
    _f_run "`lg'.log" "byfreq maxfreq(50)"
    _f_parse "`lg'.log" s
    foreach gg in g1 g2 g3 g4 {
        local nl = 0
        foreach lv in a b c d {
            quietly count if g == "`gg'" & s == "`lv'"
            local e = r(N)
            frame fpar: quietly count if grp == "`gg'" & lev == "`lv'" & cnt == `e'
            if `e' > 0 {
                frame fpar: assert r(N) == 1
                local ++nl
            }
            else {
                frame fpar: quietly count if grp == "`gg'" & lev == "`lv'"
                frame fpar: assert r(N) == 0
            }
        }
        frame fpar: quietly count if grp == "`gg'" & kind == "cell"
        frame fpar: assert r(N) == `nl'
    }
    * order inside a group: descending count, ties by level (g2: c5 then a2 b2; g4: a b c ties then d)
    frame fpar: quietly generate long ord = _n
    frame fpar: quietly summarize ord if grp == "g2" & lev == "c", meanonly
    frame fpar: local oc = r(min)
    frame fpar: quietly summarize ord if grp == "g2" & lev == "a", meanonly
    frame fpar: local oa = r(min)
    frame fpar: quietly summarize ord if grp == "g2" & lev == "b", meanonly
    frame fpar: local ob = r(min)
    assert `oc' < `oa' & `oa' < `ob'
    frame fpar: quietly summarize ord if grp == "g4" & lev == "a", meanonly
    frame fpar: local o1 = r(min)
    frame fpar: quietly summarize ord if grp == "g4" & lev == "b", meanonly
    frame fpar: local o2 = r(min)
    frame fpar: quietly summarize ord if grp == "g4" & lev == "c", meanonly
    frame fpar: local o3 = r(min)
    frame fpar: quietly summarize ord if grp == "g4" & lev == "d", meanonly
    frame fpar: local o4 = r(min)
    assert `o1' < `o2' & `o2' < `o3' & `o3' < `o4'
    frame drop fpar
}
local rc = _rc
_u_tally `rc' "F7 per-group tables equal count-if per group and level; ties in level order"

**# F7.2 maxfreq cuts each group's table; the dropped levels are announced
capture noisily {
    _f_fix
    tempfile lg
    _f_run "`lg'.log" "byfreq maxfreq(2)"
    _f_parse "`lg'.log" s
    * g1 has 4 levels: a b shown, 2 more; g2: c then a; g3 one level; g4: a b, 2 more
    frame fpar: quietly count if grp == "g1" & kind == "cell"
    frame fpar: assert r(N) == 2
    frame fpar: quietly count if grp == "g1" & kind == "more"
    frame fpar: assert r(N) == 1
    frame fpar: quietly count if grp == "g2" & kind == "cell" & ((lev == "c" & cnt == 5) | (lev == "a" & cnt == 2))
    frame fpar: assert r(N) == 2
    frame fpar: quietly count if grp == "g2" & kind == "more"
    frame fpar: assert r(N) == 1
    frame fpar: quietly count if grp == "g3" & kind == "more"
    frame fpar: assert r(N) == 0
    frame fpar: quietly count if grp == "g4" & kind == "cell" & inlist(lev, "a", "b") & cnt == 2
    frame fpar: assert r(N) == 2
    frame drop fpar
    * the pooled table is untouched by byfreq: same CATEGORICAL/STRING text with and without
    tempfile l1 l2
    quietly log using "`l1'.log", replace text name(f72a)
    capture noisily datacheck s, by(g) maxfreq(2)
    quietly log close f72a
    quietly log using "`l2'.log", replace text name(f72b)
    capture noisily datacheck s, by(g) maxfreq(2) byfreq
    quietly log close f72b
    mata: st_local("okpre", strofreal(_gf_same(st_local("l1") + ".log", st_local("l2") + ".log", 1)))
    assert `okpre' == 1
}
local rc = _rc
_u_tally `rc' "F7 maxfreq() per group, more-levels line, and the pooled output above the new block unchanged"

**# F7.3 maskrare mincell: per-cell masking, no small count printed, pooled [suppressed] lines
capture noisily {
    _f_fix
    tempfile lg
    _f_run "`lg'.log" "byfreq maxfreq(50) maskrare mincell(5)"
    _f_parse "`lg'.log" s
    * g3 (3 rows) and g4 (7 rows) are pooled away or kept per the group rule; shown groups
    * print no count under 5
    frame fpar: quietly count if kind == "cell" & cnt < 5
    frame fpar: assert r(N) == 0
    * g1: d1 and c2 are small cells; the two small cells total 3 < 5, so the smallest
    * shown cell (b4) joins the pool as in the pooled table
    frame fpar: quietly count if grp == "g1" & kind == "suppressed"
    frame fpar: assert r(N) == 3
    frame fpar: quietly count if grp == "g1" & kind == "cell" & lev == "a" & cnt == 5
    frame fpar: assert r(N) == 1
    * g2: a2 and b2 are small cells (pool 4 < 5), so the smallest shown cell c5 joins too
    frame fpar: quietly count if grp == "g2" & kind == "suppressed"
    frame fpar: assert r(N) == 3
    frame fpar: quietly count if grp == "g2" & kind == "cell"
    frame fpar: assert r(N) == 0
    frame drop fpar
    * the same rule as the pooled table: _datacheck_freq on each group's own rows
    foreach gg in g1 g2 {
        preserve
        quietly keep if g == "`gg'"
        tempfile lgp
        quietly log using "`lgp'.log", replace text name(f73)
        capture noisily datacheck s, maxfreq(50) maskrare mincell(5)
        quietly log close f73
        restore
        _f_pool "`lgp'.log" s
        local np = r(nsup)
        local nc = r(ncell)
        if "`gg'" == "g1" assert `np' == 3 & `nc' == 1
        if "`gg'" == "g2" assert `np' == 3 & `nc' == 0
    }
}
local rc = _rc
_u_tally `rc' "F7 maskrare: cell masking and complement pooling match the pooled-table rule per group"

**# F7.4 the group labels are the GROUPWISE SUMMARY labels (string by and labelled numeric by)
capture noisily {
    _f_fix
    tempfile lg
    foreach by in g gn {
        quietly log using "`lg'.log", replace text name(f74)
        capture noisily datacheck s, by(`by') byfreq
        local drc = _rc
        quietly log close f74
        assert `drc' == 0
        * labels from the GROUPWISE SUMMARY block
        local sumlab ""
        tempname fh
        local on = 0
        file open `fh' using "`lg'.log", read text
        file read `fh' line
        while r(eof) == 0 {
            local L `"`macval(line)'"'
            if strtrim(`"`L'"') == "GROUPWISE SUMMARY" local on = 1
            else if `on' & strtrim(`"`L'"') == "" local on = 0
            else if `on' & substr(`"`L'"', 1, 2) == "  " & strpos(`"`L'"', "by:") == 0 & strpos(`"`L'"', "Group") == 0 {
                local sumlab `"`sumlab' "`=strtrim(substr(`"`L'"', 3, 20))'""'
            }
            file read `fh' line
        }
        file close `fh'
        _f_parse "`lg'.log" s
        frame fpar: quietly levelsof grp, local(freqlab)
        local nsum : word count `sumlab'
        local nfq : word count `freqlab'
        assert `nsum' == 4 & `nfq' == 4
        foreach l of local sumlab {
            assert `: list l in freqlab'
        }
        frame drop fpar
    }
    * a numeric value-labelled by shows the label text, e.g. "Three"
    _f_parse "`lg'.log" s
    frame fpar: quietly count if grp == "Three" & lev == "a" & cnt == 3
    frame fpar: assert r(N) == 1
    frame drop fpar
    * numeric categorical variable with its own value label
    quietly log using "`lg'.log", replace text name(f74b)
    capture noisily datacheck k, by(g) byfreq maxfreq(50)
    quietly log close f74b
    _f_parse "`lg'.log" k
    frame fpar: quietly count if grp == "g1" & strpos(lev, "low") > 0 & cnt == 5
    frame fpar: assert r(N) == 1
    frame fpar: quietly count if grp == "g2" & strpos(lev, "high") > 0 & cnt == 5
    frame fpar: assert r(N) == 1
    frame drop fpar
}
local rc = _rc
_u_tally `rc' "F7 group labels equal GROUPWISE SUMMARY labels; string and labelled numeric by; labelled categorical levels"

**# F7.5 the call's if, an empty group, a group of only missing, nomissing, by-less byfreq
capture noisily {
    _f_fix
    tempfile lg
    * if removes every row of g3 and g4: those groups are not listed
    quietly log using "`lg'.log", replace text name(f75)
    capture noisily datacheck s if inlist(g, "g1", "g2"), by(g) byfreq maxfreq(50)
    quietly log close f75
    _f_parse "`lg'.log" s
    frame fpar: quietly levelsof grp, local(gl)
    assert `: word count `gl'' == 2
    assert `: list posof "g1" in gl' == 1 & `: list posof "g2" in gl' == 2
    frame fpar: quietly count if grp == "g1" & lev == "a" & cnt == 5
    frame fpar: assert r(N) == 1
    frame drop fpar
    * numeric categorical missing in a whole group: the group's table is its missing level
    _f_fix
    quietly replace k = . if g == "g3"
    quietly log using "`lg'.log", replace text name(f75b)
    capture noisily datacheck k, by(g) byfreq maxfreq(50)
    quietly log close f75b
    _f_parse "`lg'.log" k
    frame fpar: quietly count if grp == "g3" & kind == "cell"
    frame fpar: assert r(N) == 1
    frame fpar: quietly count if grp == "g3" & lev == "." & cnt == 3
    frame fpar: assert r(N) == 1
    frame drop fpar
    * nomissing leaves the frequency tables as they are (it only drops MISSINGNESS)
    _f_fix
    tempfile la lb
    quietly log using "`la'.log", replace text name(f75c)
    capture noisily datacheck s, by(g) byfreq
    quietly log close f75c
    quietly log using "`lb'.log", replace text name(f75d)
    capture noisily datacheck s, by(g) byfreq nomissing
    quietly log close f75d
    _f_parse "`la'.log" s
    frame fpar: local na = _N
    frame drop fpar
    _f_parse "`lb'.log" s
    frame fpar: local nb = _N
    frame drop fpar
    assert `na' == `nb' & `na' > 0
    * byfreq with no by(): refused
    capture datacheck s, byfreq
    assert _rc == 198
    capture datacheck s, over(g) byfreq
    assert _rc == 0
}
local rc = _rc
_u_tally `rc' "F7 call if, all-missing group, nomissing, byfreq without by() refused"

**# F7.6 gatesonly is unaffected; without byfreq the output has no new block
capture noisily {
    _f_fix
    tempfile la lb lc
    quietly log using "`la'.log", replace text name(f76a)
    capture noisily datacheck s, by(g) gatesonly expectn(31)
    quietly log close f76a
    quietly log using "`lb'.log", replace text name(f76b)
    capture noisily datacheck s, by(g) gatesonly expectn(31) byfreq
    quietly log close f76b
    mata: st_local("same", strofreal(_gf_same(st_local("la") + ".log", st_local("lb") + ".log", 0)))
    assert `same' == 1
    quietly log using "`lc'.log", replace text name(f76c)
    capture noisily datacheck s, by(g)
    quietly log close f76c
    mata: c = cat(st_local("lc") + ".log"); st_local("nblk", strofreal(sum(strtrim(c) :== "GROUPWISE FREQUENCIES")))
    assert `nblk' == 0
}
local rc = _rc
_u_tally `rc' "F7 gatesonly output identical with byfreq; no block without byfreq"

sysdir set PLUS "`oldplus'"
sysdir set PERSONAL "`oldpersonal'"
display "RESULT: test_datacheck_v190_groupfreq tests=$TC pass=$PASS fail=$FAIL"
log close main
if $FAIL exit 1
