*! test_datamap_v182.do Version 1.0.0  2026/10/01
*! Regressions for 1.8.2: datacheck by() groupwise counts from one pass,
*! deterministic frequency-table and pattern-graph ties, datadict reuse of
*! classifier counts with gated percentiles, datamvp correlate on weighted
*! patterns, legacy globals and saving() notes kept literally
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set processors 1
set linesize 255
capture log close _all
log using "test_datamap_v182.log", replace text name(main)
local pkg_dir = regexr("`c(pwd)'", "/qa$", "")
tempfile base
* tempfile names repeat across suites in one runner session: own suffix
local work "`base'_v182work"
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
local tests = 0
local pass = 0
local fail = 0

* 12 rows in three by() groups: site A (5), B (4), and missing site (3).
*   x  (double): A has . and .a, the missing-site group has one .
*   s  (str):    A one "", B two ""
*   sl (strL):   B one ""
*   z:           missing in all of B; excluded, so never reported
capture program drop _v182_groups
program define _v182_groups
    clear
    quietly set obs 12
    gen str1 site = cond(_n <= 5, "A", cond(_n <= 9, "B", ""))
    gen double x = _n
    quietly replace x = . in 2
    quietly replace x = .a in 3
    quietly replace x = . in 10
    gen str1 s = lower(site)
    quietly replace s = "m" in 10/12
    quietly replace s = "" in 3
    quietly replace s = "" in 7/8
    gen strL sl = "v" + string(_n)
    quietly replace sl = "" in 9
    gen double z = cond(inrange(_n, 6, 9), ., 1)
end

* Lines of a text log between a header line and the next blank line
capture program drop _v182_block
program define _v182_block, rclass
    args file header
    tempname fh
    local n = 0
    local on = 0
    file open `fh' using `"`file'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if `on' {
            if strtrim(`"`macval(line)'"') == "" | substr(`"`macval(line)'"', 1, 1) == "." {
                local on = 0
            }
            else if substr(`"`macval(line)'"', 1, 3) == "   " | substr(`"`macval(line)'"', 1, 2) == "  " {
                local ++n
                return local l`n' `"`macval(line)'"'
            }
        }
        if strtrim(`"`macval(line)'"') == "`header'" local on = 1
        file read `fh' line
    }
    file close `fh'
    return scalar n = `n'
end

**# B01 GROUPWISE MISSINGNESS and SUMMARY match count-loop oracles

* Oracle: one -count if- per group and variable on the fixture, the route
* datacheck took before 1.8.2.
capture noisily {
    _v182_groups
    tempvar g
    egen long `g' = group(site), label missing
    quietly levelsof `g', local(gl)
    local glab : value label `g'
    local exp_m = 0
    local exp_s = 0
    foreach gg of local gl {
        local lab : label `glab' `gg'
        * egen labels a blank string group with its number; the display
        * names it (blank) (1.9.0)
        quietly count if `g' == `gg' & site == ""
        if r(N) > 0 local lab "(blank)"
        local lab = substr(`"`lab'"', 1, 20)
        quietly count if `g' == `gg'
        local on`gg' = r(N)
        quietly count if `g' == `gg' & !missing(x) & s != "" & sl != ""
        local oc`gg' = r(N)
        local omv`gg' = 0
        foreach v in x s sl {
            quietly count if `g' == `gg' & missing(`v')
            if r(N) > 0 {
                local ++exp_m
                local em`exp_m' "`lab'|`v'|`r(N)'"
                local ++omv`gg'
            }
        }
        local ++exp_s
        local es`exp_s' "`lab'|`on`gg''|`oc`gg''|`omv`gg''"
    }
    * the fixture's own design, independent of the egen route
    assert `exp_m' == 5
    local f "`work'/b01.log"
    log using "`f'", replace text name(b01)
    datacheck x s sl z, by(site) exclude(z)
    * log close clears r(): read the returns first
    local gmv "`r(group_missing_vars)'"
    local ngmv = r(n_group_missing_vars)
    log close b01
    assert "`gmv'" == "x s sl"
    assert `ngmv' == 3

    _v182_block "`f'" "GROUPWISE MISSINGNESS"
    * header row + one row per (group, variable) with a missing value
    assert r(n) == `exp_m' + 1
    forvalues k = 1/`exp_m' {
        local L `"`r(l`=`k' + 1')'"'
        local got = strtrim(substr(`"`L'"', 3, 20)) + "|" + ///
            strtrim(substr(`"`L'"', 23, 22)) + "|" + strtrim(substr(`"`L'"', 45, 9))
        assert `"`got'"' == `"`em`k''"'
    }
    _v182_block "`f'" "GROUPWISE SUMMARY"
    * "by:" line + header row + one row per group
    assert r(n) == `exp_s' + 2
    forvalues k = 1/`exp_s' {
        local L `"`r(l`=`k' + 2')'"'
        local got = strtrim(substr(`"`L'"', 3, 20)) + "|" + ///
            strtrim(substr(`"`L'"', 23, 9)) + "|" + strtrim(substr(`"`L'"', 32, 12)) + ///
            "|" + strtrim(substr(`"`L'"', -9, 9))
        assert `"`got'"' == `"`es`k''"'
    }
}
local rc = _rc
capture log close b01
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: B01 groupwise counts match the count-loop oracle (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: B01 groupwise counts match the count-loop oracle"
}

**# B02 by() with every profiled variable excluded

* 1.8.2 development regression: the groupwise frame had no n/c columns when
* no variable was left to count, and GROUPWISE SUMMARY exited r(111).
capture noisily {
    _v182_groups
    local f "`work'/b02.log"
    log using "`f'", replace text name(b02)
    datacheck z, by(site) exclude(z)
    local ngmv = r(n_group_missing_vars)
    log close b02
    assert `ngmv' == 0
    _v182_block "`f'" "GROUPWISE SUMMARY"
    assert r(n) == 5
    local Nsum = 0
    forvalues k = 3/5 {
        local L `"`r(l`k')'"'
        local Nsum = `Nsum' + real(strtrim(substr(`"`L'"', 23, 9)))
    }
    assert `Nsum' == 12
}
local rc = _rc
capture log close b02
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: B02 by() with all variables excluded (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: B02 by() with all variables excluded"
}

**# B03 no frame is left behind by by(), and the data are unchanged

capture noisily {
    _v182_groups
    gen long _ord = _n
    quietly frames dir
    local fr0 "`r(frames)'"
    datasignature
    local sig0 "`r(datasignature)'"
    quietly datacheck x s sl z, by(site) exclude(z) maskrare mincell(3)
    quietly frames dir
    assert "`r(frames)'" == "`fr0'"
    datasignature
    assert "`r(datasignature)'" == "`sig0'"
    assert _ord == _n
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: B03 by() leaves frames, data, and order unchanged (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: B03 by() leaves frames, data, and order unchanged"
}

**# T01 frequency-table ties list in level order, whatever the row order

* Thirty string levels: odd levels 6 rows, even levels 4.  Before 1.8.2
* equal counts printed in arbitrary order (gsort without a tie key; every
* seed below scrambled them), so the levels shown at the maxfreq(20) cut,
* which falls inside the tied 4s, changed from run to run.
local want ""
forvalues k = 1(2)29 {
    local want "`want' l`: display %02.0f `k''"
}
forvalues k = 2(2)10 {
    local want "`want' l`: display %02.0f `k''"
}
capture noisily {
    forvalues seed = 1/5 {
        clear
        quietly set obs 30
        gen str3 lev = "l" + string(_n, "%02.0f")
        quietly expand cond(mod(_n, 2), 6, 4)
        set seed `seed'
        gen double _u = runiform()
        sort _u
        drop _u
        local f "`work'/t01_`seed'.log"
        log using "`f'", replace text name(t01)
        datacheck lev, maxfreq(20)
        log close t01
        tempname fh
        local got ""
        file open `fh' using "`f'", read text
        file read `fh' line
        while r(eof) == 0 {
            if regexm(`"`macval(line)'"', "^    (l[0-9][0-9]) +[46] ") {
                local got "`got' `=regexs(1)'"
            }
            file read `fh' line
        }
        file close `fh'
        assert strtrim("`got'") == strtrim("`want'")
    }
}
local rc = _rc
capture log close t01
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: T01 tied counts list in level order across 5 row orders (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: T01 tied counts list in level order across 5 row orders"
}

**# D01 datadict rows that reuse classifier counts and skip percentiles

* Oracle: missing, distinct, and range computed here by hand on the fixture.
capture noisily {
    clear
    quietly set obs 20
    gen double hd = mdy(1, 1, 2000) + _n
    format hd %td
    quietly replace hd = . in 4/5
    gen str2 nm = cond(mod(_n, 3) == 0, "", "n" + string(mod(_n, 4)))
    gen byte arm = 1 + (_n > 10)
    label define _v182_arm 1 "Control" 2 "Treated"
    label values arm _v182_arm
    gen double y = _n / 4
    local f "`work'/d01.md"
    datadict, output("`f'") stats missing mincell(0)
    * datadict's default date display is %tdCCYY/NN/DD
    local want_hd = "N=18<br>Range: " + string(mdy(1, 1, 2000) + 1, "%tdCCYY/NN/DD") + ///
        " to " + string(mdy(1, 1, 2000) + 20, "%tdCCYY/NN/DD")
    * nm: 14 non-empty values over 4 distinct strings n0..n3; "" is missing
    quietly count if nm != ""
    local nvalid = r(N)
    tempname fh
    local ok_hd = 0
    local ok_nm = 0
    local ok_arm = 0
    file open `fh' using "`f'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "| `hd` |") {
            if strpos(`"`macval(line)'"', "2 (10.0%)") & strpos(`"`macval(line)'"', "`want_hd'") local ok_hd = 1
        }
        if strpos(`"`macval(line)'"', "| `nm` |") {
            if strpos(`"`macval(line)'"', "6 (30.0%)") & strpos(`"`macval(line)'"', "N=`nvalid'; 4 unique values") local ok_nm = 1
        }
        if strpos(`"`macval(line)'"', "| `arm` |") {
            if strpos(`"`macval(line)'"', "Control (10; 50.0%)") & strpos(`"`macval(line)'"', "Treated (10; 50.0%)") local ok_arm = 1
        }
        file read `fh' line
    }
    file close `fh'
    assert `nvalid' == 14
    assert `ok_hd' & `ok_nm' & `ok_arm'
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: D01 datadict date, string, and labelled rows (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: D01 datadict date, string, and labelled rows"
}

**# D02 saving() still posts percentiles for every numeric row

* The percentile gate keeps summarize, detail whenever saving() is set: a
* categorical row's posted p50/p25 must equal summarize's, bit for bit.
capture noisily {
    clear
    quietly set obs 30
    gen byte arm = 1 + (_n > 7) + (_n > 25)
    gen double y = sqrt(_n)
    quietly summarize arm, detail
    local w50 = r(p50)
    local w25 = r(p25)
    local wmean : display %21x r(mean)
    local f "`work'/d02.md"
    local m "`work'/d02_meta.dta"
    datadict, output("`f'") saving("`m'", replace) mincell(0)
    use "`m'", clear
    quietly keep if variable == "arm"
    assert _N == 1
    assert class == "categorical"
    assert p50 == `w50' & p25 == `w25'
    local gmean : display %21x mean[1]
    assert "`gmean'" == "`wmean'"
    assert missing == 0 & unique == 3 & unique_capped == 0
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: D02 saving() posts categorical percentiles (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: D02 saving() posts categorical percentiles"
}

**# M01 datamvp correlate equals tetrachoric on the full indicators

* Oracle: tetrachoric (or, when it fails, correlate) on 0/1 missingness
* indicators over every in-sample row, as datamvp computed it before 1.8.2.
* Covers an if() sample, a zero cell, a duplicated indicator, and the
* Pearson fallback (an all-missing variable makes tetrachoric refuse).
capture noisily {
    clear
    set seed 182
    quietly set obs 3000
    forvalues j = 1/5 {
        gen double v`j' = rnormal()
        quietly replace v`j' = . if runiform() < 0.1 * `j'
    }
    gen double v6 = v1
    gen double v7 = cond(missing(v2) & missing(v3), ., 1)
    gen byte grp = runiform() < 0.7
    quietly frames dir
    local fr0 "`r(frames)'"
    foreach spec in "v1 v2 v3 v4 v5 v6 v7|" "v1 v2 v3 v4 v5|if grp" "v1 v2 v3|in 1/2000" {
        gettoken vl cond : spec, parse("|")
        local cond = substr("`cond'", 2, .)
        local mlist ""
        foreach v of local vl {
            tempvar m_`v'
            quietly gen byte `m_`v'' = missing(`v') `=cond("`cond'" == "", "", "`cond'")'
            local mlist "`mlist' `m_`v''"
        }
        capture tetrachoric `mlist' `cond'
        assert _rc == 0
        matrix W = r(Rho)
        quietly datamvp `vl' `cond', notable correlate
        matrix G = r(corr_miss)
        assert mreldif(W, G) == 0
        drop `mlist'
    }
    * v9 is missing everywhere: its indicator is constant, tetrachoric
    * refuses, and datamvp falls back to Pearson on the same indicators
    gen double v9 = .
    tempvar a b c
    quietly gen byte `a' = missing(v1)
    quietly gen byte `b' = missing(v2)
    quietly gen byte `c' = missing(v9)
    capture tetrachoric `a' `b' `c'
    assert _rc != 0
    quietly correlate `a' `b' `c'
    matrix W = r(C)
    quietly datamvp v1 v2 v9, notable correlate
    matrix G = r(corr_miss)
    * the fallback is Pearson on the full data, unchanged in 1.8.2; its
    * summation order moves the last bit, so: the same missing cells, and
    * the rest equal to 1e-12
    mata: W = st_matrix("W"); G = st_matrix("G")
    mata: assert((W :>= .) == (G :>= .))
    mata: assert(mreldif(editmissing(W, 0), editmissing(G, 0)) < 1e-12)
    assert rowsof(G) == 3
    quietly frames dir
    assert "`r(frames)'" == "`fr0'"
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: M01 datamvp correlate equals the full-data oracle (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: M01 datamvp correlate equals the full-data oracle"
}

**# G01 pattern graphs name the table's first pattern when counts tie

* Six patterns of 6 rows (four with one missing, two with two) and "++++"
* with 4.  The table orders by frequency, then fewest missing, then the
* pattern string ("+" sorts before "."), so P1 is "+++.".  Before 1.8.2 the
* graphs sorted on frequency alone and named any of the six.
capture noisily {
    forvalues seed = 1/5 {
        clear
        quietly set obs 7
        gen str4 p = ""
        quietly replace p = ".+++" in 1
        quietly replace p = "+.++" in 2
        quietly replace p = "++.+" in 3
        quietly replace p = "+++." in 4
        quietly replace p = "..++" in 5
        quietly replace p = "++.." in 6
        quietly replace p = "++++" in 7
        quietly expand cond(_n == 7, 4, 6)
        foreach k in 1 2 3 4 {
            gen double v`k' = cond(substr(p, `k', 1) == ".", ., `k')
        }
        quietly expand 2
        gen byte grp = mod(_n, 2)
        set seed `seed'
        gen double _u = runiform()
        sort _u
        drop _u p
        quietly datamvp v1 v2 v3 v4, notable graph(patterns) nodraw
        assert `"`.Graph.note.text[1]'"' == "P1=+++."
        quietly datamvp v1 v2 v3 v4, notable graph(patterns) gby(grp) nodraw
        * a by() graph carries the note on each subgraph
        assert `"`.Graph.graphs[1].note.text[1]'"' == "P1=+++."
        assert `"`.Graph.graphs[2].note.text[1]'"' == "P1=+++."
    }
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: G01 pattern graphs name the table's first tied pattern (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: G01 pattern graphs name the table's first tied pattern"
}

**# S01 the caller's S_1, S_FN, and S_FNDATE come back byte for byte

* datamap, datadict, and datacheck save these legacy globals and put them
* back on exit.  The put-back was a one-line -if- around -global-, which
* expands its command a second time: a value holding $name or `name' came
* back rewritten (here "$V182G" became "G182" and `vname' became "").  On
* entry, all four commands (datamvp too) tested the saved value inside
* compound quotes, so S_FNDATE -- cut to 17 characters, here ending in an
* unmatched ` -- stopped each one with r(132) before it began.  Success and
* refusal paths of each command.
global V182G "G182"
capture noisily {
    sysuse auto, clear
    local s01dta "`work'/s01_auto.dta"
    quietly save "`s01dta'", replace
    * the scratch path has no spaces, so the paths go unquoted inside the
    * stored command strings
    local c1 "datamap, single(`s01dta') output(`work'/s01.txt)"
    local c2 "datamap, output(`work'/s01|bad.txt) format(json)"
    local c3 "datadict, single(`s01dta') output(`work'/s01.md)"
    local c4 "datadict, single(`work'/s01_none) output(`work'/s01_b.md)"
    local c5 "datacheck price mpg"
    local c6 "datacheck price, expectn(1)"
    local c7 "datacheck s01_no_such_var"
    local c8 "datamvp rep78 price, notable"
    local c9 "datamvp s01_no_such_var"
    forvalues k = 1/9 {
        use "`s01dta'", clear
        * set after -use-, which writes S_FN and S_FNDATE itself
        foreach g in S_1 S_FN S_FNDATE {
            mata: st_global(st_local("g"), st_local("g") + " " + char(36) + ///
                "V182G " + char(96) + "vname" + char(39) + " " + char(34) + " Å")
        }
        mata: _s01_before = st_global("S_1") + "|" + st_global("S_FN") + "|" + st_global("S_FNDATE")
        capture quietly `c`k''
        local crc = _rc
        mata: st_local("same", strofreal(_s01_before == ///
            st_global("S_1") + "|" + st_global("S_FN") + "|" + st_global("S_FNDATE")))
        if !`same' display as error `"S01 case `k' (rc=`crc') changed the legacy globals: `c`k''"'
        assert `same'
        * each case ran down the path it names
        if inlist(`k', 1, 3, 5, 8) assert `crc' == 0
        else assert `crc' != 0
    }
}
local rc = _rc
macro drop V182G
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: S01 legacy globals survive all four commands (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: S01 legacy globals survive all four commands"
}

**# S02 saving() metadata keeps a note and a characteristic literally

* _datamap_post_metadata_rows built the first note and characteristic with a
* one-line -if-, so $name and `name' in them were expanded: `vname' became the
* variable's own name in the datamap and datacheck saving() rows.
global V182G "G182"
capture noisily {
    sysuse auto, clear
    local lit = "N " + char(36) + "V182G " + char(96) + "vname" + char(39) + " end"
    mata: st_global("price[note1]", st_local("lit")); st_global("price[note0]", "1")
    mata: st_global("price[src]", st_local("lit"))
    local s02dta "`work'/s02_auto.dta"
    quietly save "`s02dta'", replace
    quietly datamap, single("`s02dta'") output("`work'/s02.txt") saving("`work'/s02_dm.dta", replace)
    use "`s02dta'", clear
    quietly datacheck price mpg, saving("`work'/s02_dc.dta", replace)
    foreach m in s02_dm s02_dc {
        use "`work'/`m'.dta", clear
        quietly keep if variable == "price"
        assert _N == 1
        mata: st_local("okn", strofreal(st_sdata(1, "notes") == st_local("lit")))
        mata: st_local("okc", strofreal(st_sdata(1, "characteristics") == "src=" + st_local("lit")))
        assert `okn' & `okc'
    }
}
local rc = _rc
macro drop V182G
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: S02 saving() notes and characteristics are literal (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: S02 saving() notes and characteristics are literal"
}

sysdir set PLUS "`oldplus'"
sysdir set PERSONAL "`oldpersonal'"
display "RESULT: test_datamap_v182 tests=`tests' pass=`pass' fail=`fail'"
log close main
if `fail' exit 1
