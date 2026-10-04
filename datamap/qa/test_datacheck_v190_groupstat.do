*! test_datacheck_v190_groupstat.do Version 1.0.0  2026/10/03
*! 1.9.0 B1: datacheck <one variable>, by(g) no longer fails r(3202) (1x1 select()
*! into invtokens() in _datacheck_groupmiss); GROUPWISE SUMMARY / MISSINGNESS
*! tables and returns are checked against count-if oracles.
*! 1.9.0 U4: groupstat(stat stat ...: var, by(g)) one table, a column per
*! statistic; ledger rows are checked against the single-statistic entries.
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set processors 1
set linesize 255
capture log close _all
log using "test_datacheck_v190_groupstat.log", replace text name(main)
local pkg_dir = regexr("`c(pwd)'", "/qa$", "")
tempfile base
local work "`base'_v190gs"
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

* Indented lines under a header line, up to the next blank or command line
capture program drop _u_block
program define _u_block, rclass
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
            else if substr(`"`macval(line)'"', 1, 2) == "  " {
                local ++n
                return local l`n' `"`macval(line)'"'
            }
        }
        if strtrim(`"`macval(line)'"') == `"`header'"' local on = 1
        file read `fh' line
    }
    file close `fh'
    return scalar n = `n'
end

* 63 rows: groups A 30, B 20, C 7, D 3, E 3; gn is the same grouping with E missing
* (datacheck by() keeps a missing group as its own level, label ".")
capture program drop _u_fix
program define _u_fix
    clear
    quietly set obs 63
    gen double x = _n
    gen str1 g = cond(_n <= 30, "A", cond(_n <= 50, "B", cond(_n <= 57, "C", ///
        cond(_n <= 60, "D", "E"))))
    gen byte gn = cond(_n <= 30, 1, cond(_n <= 50, 2, cond(_n <= 57, 3, cond(_n <= 60, 4, .))))
    label define gnl 1 "Alpha" 2 "Beta" 3 "Gamma" 4 "Delta"
    label values gn gnl
    gen double y = mod(_n * 7, 23) + _n / 10
    quietly replace y = . in 3
    quietly replace y = . in 4
    quietly replace y = . in 33
    quietly replace y = . in 52
    quietly replace y = . in 59
    quietly replace y = .a in 62
    gen str3 s = "v"
    quietly replace s = "" in 2
    quietly replace s = "" in 31/36
    quietly replace s = "" in 58
    gen double xnm = _n + 0.5
    gen str3 snm = "w"
end

* GROUPWISE oracle: datacheck `vars', by(`by') `opts' vs count-if.  Passing
* mask > 0 means the call carries maskrare mincell(mask).
capture program drop _u_miss
program define _u_miss
    args by vars mask opts
    tempfile lg
    local lgf "`lg'.log"
    local isstr = (substr("`: type `by''", 1, 3) == "str")
    local opt2 "`opts'"
    if `mask' > 0 local opt2 "`opt2' maskrare mincell(`mask')"
    quietly log using "`lgf'", replace text name(umiss)
    capture noisily datacheck `vars', by(`by') `opt2'
    local drc = _rc
    local gmv "`r(group_missing_vars)'"
    local ngmv = r(n_group_missing_vars)
    local ngr = r(n_groups)
    quietly log close umiss
    assert `drc' == 0
    * oracle
    quietly levelsof `by', local(lvs) missing
    local nl : word count `lvs'
    local k = 0
    local expmv ""
    local nexp_m = 0
    foreach lv of local lvs {
        local ++k
        if `isstr' local cnd `"`by' == "`lv'""'
        else local cnd "`by' == `lv'"
        if `isstr' local lab "`lv'"
        else local lab : label (`by') `lv'
        local lab`k' "`lab'"
        quietly count if `cnd'
        local on`k' = r(N)
        local cc`k' = r(N)
        local nmv`k' = 0
        local cm`k' ""
        foreach v of local vars {
            if substr("`: type `v''", 1, 3) == "str" quietly count if `cnd' & `v' == ""
            else quietly count if `cnd' & missing(`v')
            local m`k'_`v' = r(N)
            if r(N) > 0 {
                local ++nmv`k'
                if !`: list v in expmv' local expmv "`expmv' `v'"
                local ++nexp_m
            }
            local cm`k' "`cm`k'' `v'"
        }
        * complete cases: no profiled variable missing
        local cnd2 "`cnd'"
        foreach v of local vars {
            if substr("`: type `v''", 1, 3) == "str" local cnd2 `"`cnd2' & `v' != """'
            else local cnd2 "`cnd2' & !missing(`v')"
        }
        quietly count if `cnd2'
        local cc`k' = r(N)
    }
    local expmv : list vars & expmv
    assert `ngr' == `nl'
    assert "`gmv'" == "`expmv'"
    assert `ngmv' == `: word count `expmv''
    * GROUPWISE MISSINGNESS block
    quietly _u_block "`lgf'" "GROUPWISE MISSINGNESS"
    local nblk = r(n)
    local nshown = 0
    if `nblk' > 0 {
        forvalues i = 2/`nblk' {
            local L `"`r(l`i')'"'
            local gtxt = strtrim(substr(`"`L'"', 3, 20))
            local vtxt = strtrim(substr(`"`L'"', 23, 22))
            local ctxt = strtrim(substr(`"`L'"', 45, 9))
            if substr(`"`gtxt'"', 1, 6) == "groups" continue
            local ++nshown
            local hit = 0
            forvalues k = 1/`nl' {
                if `"`gtxt'"' == `"`lab`k''"' {
                    local hit = `k'
                }
            }
            assert `hit' > 0
            assert `: list vtxt in vars'
            local exact = `m`hit'_`vtxt''
            assert `exact' > 0
            if substr("`ctxt'", 1, 1) == "<" {
                * masked: the true count is positive and below the mask
                assert `mask' > 0 & `exact' < `mask'
                assert "`ctxt'" == "<`mask'"
            }
            else {
                assert real("`ctxt'") == `exact'
                * no small cell is ever printed unmasked
                assert `mask' == 0 | `exact' >= `mask'
            }
        }
    }
    if `mask' == 0 {
        assert `nshown' == `nexp_m'
        if `nexp_m' == 0 assert `nblk' == 0
    }
    else assert `nshown' <= `nexp_m'
    * GROUPWISE SUMMARY block: header "by:" line + column header + groups
    quietly _u_block "`lgf'" "GROUPWISE SUMMARY"
    local nblk = r(n)
    local nsum = 0
    forvalues i = 3/`nblk' {
        local L `"`r(l`i')'"'
        local gtxt = strtrim(substr(`"`L'"', 3, 20))
        if substr(`"`gtxt'"', 1, 6) == "groups" continue
        local ++nsum
        local hit = 0
        forvalues k = 1/`nl' {
            if `"`gtxt'"' == `"`lab`k''"' local hit = `k'
        }
        assert `hit' > 0
        local ntxt = strtrim(substr(`"`L'"', 23, 9))
        local ctxt = strtrim(substr(`"`L'"', 32, 12))
        local mvtxt = strtrim(substr(`"`L'"', -9, 9))
        assert real("`ntxt'") == `on`hit''
        if substr("`ctxt'", 1, 3) == "all" {
            assert `mask' > 0 & (`on`hit'' - `cc`hit'') >= 1 & (`on`hit'' - `cc`hit'') < `mask'
        }
        else assert real("`ctxt'") == `cc`hit''
        assert real("`mvtxt'") == `nmv`hit''
    }
    if `mask' == 0 assert `nsum' == `nl'
    else assert `nsum' <= `nl'
end

**# B1 original reproducer: sysuse auto
capture noisily {
    sysuse auto, clear
    _u_miss foreign mpg 0 ""
    _u_miss foreign mpg 0 "nomissing"
    _u_miss foreign rep78 0 ""
    _u_miss foreign "mpg price" 0 ""
    _u_miss foreign make 0 ""
    _u_miss foreign mpg 30 ""
}
local rc = _rc
_u_tally `rc' "B1 auto: mpg by(foreign) and neighbours match count-if oracle"

**# B1 numeric one variable, missing-free, by string group
capture noisily {
    _u_fix
    _u_miss g xnm 0 ""
    _u_miss g xnm 0 "nomissing"
    _u_miss g xnm 5 ""
    _u_miss g xnm 5 "nomissing"
}
local rc = _rc
_u_tally `rc' "B1 numeric no-missing variable, string by(), +/- nomissing, +/- maskrare"

**# B1 string one variable, missing-free
capture noisily {
    _u_fix
    _u_miss g snm 0 ""
    _u_miss g snm 0 "nomissing"
    _u_miss g snm 5 ""
    _u_miss gn snm 0 ""
}
local rc = _rc
_u_tally `rc' "B1 string no-missing variable, string and numeric by()"

**# B1 numeric one variable with missing (incl. extended missing)
capture noisily {
    _u_fix
    _u_miss g y 0 ""
    _u_miss g y 0 "nomissing"
    _u_miss g y 5 ""
    _u_miss g y 5 "nomissing"
    _u_miss gn y 0 ""
    _u_miss gn y 5 ""
}
local rc = _rc
_u_tally `rc' "B1 numeric variable with . and .a missing: counts exact, masked cells small"

**# B1 string one variable with missing
capture noisily {
    _u_fix
    _u_miss g s 0 ""
    _u_miss g s 0 "nomissing"
    _u_miss g s 5 ""
    _u_miss g s 5 "nomissing"
    _u_miss gn s 0 ""
}
local rc = _rc
_u_tally `rc' "B1 string variable with blanks: counts exact, masked cells small"

**# B1 several variables mixed
capture noisily {
    _u_fix
    _u_miss g "xnm y" 0 ""
    _u_miss g "xnm snm" 0 ""
    _u_miss g "y s xnm snm" 0 ""
    _u_miss g "y s xnm snm" 5 ""
}
local rc = _rc
_u_tally `rc' "B1 multi-variable by(): missvars only the variables with missing values"

**# B1 helper contract: r(missvars) empty with and without missing
capture noisily {
    _u_fix
    gen byte cc = !missing(xnm)
    _datacheck_groupmiss xnm, group(gn) complete(cc) frame(u_zz)
    assert r(G) == 4
    assert `"`r(missvars)'"' == ""
    frame u_zz {
        assert _N == 4
        assert m1[1] == 0 & m1[2] == 0 & m1[3] == 0 & m1[4] == 0
    }
    frame drop u_zz
    replace cc = !missing(y)
    _datacheck_groupmiss y, group(gn) complete(cc) frame(u_zz)
    assert `"`r(missvars)'"' == "y"
    frame u_zz {
        assert n[1] == 30 & n[2] == 20 & n[3] == 7 & n[4] == 3
        assert m1[1] == 2 & m1[2] == 1 & m1[3] == 1 & m1[4] == 1
    }
    frame drop u_zz
    _datacheck_groupmiss y s xnm, group(gn) complete(cc) frame(u_zz)
    assert `"`r(missvars)'"' == "y s"
    frame drop u_zz
}
local rc = _rc
capture frame drop u_zz
_u_tally `rc' "B1 _datacheck_groupmiss returns r(missvars) for 1 and 3 variables"

**# B1 negative control: the old pattern really fails (documents the defect)
capture noisily {
    mata: v = ("a"); mm = (0); r = select(v, mm); assert(rows(r) * cols(r) == 0)
    capture mata: invtokens(select(v, mm))
    assert _rc == 3202
}
local rc = _rc
_u_tally `rc' "B1 control: select() of a 1x1 with a 0 mask into invtokens() is r(3202)"

**# U4 helpers

* Output of the two logs from the first GROUPSTAT line to the log-close
* banner, line by line: returns the line count of the first and how many
* lines differ (the logs differ in their command echo and banner only)
capture program drop _u_logdiff
program define _u_logdiff, rclass
    args fa fb
    local k = 0
    foreach f in a b {
        tempname h
        local n`f' = 0
        local on = 0
        file open `h' using `"`f`f''"', read text
        file read `h' line
        while r(eof) == 0 {
            if substr(`"`macval(line)'"', 1, 5) == "-----" local on = 0
            if substr(`"`macval(line)'"', 1, 9) == "GROUPSTAT" local on = 1
            if `on' {
                local ++n`f'
                local `f'_`n`f'' `"`macval(line)'"'
            }
            file read `h' line
        }
        file close `h'
    }
    local nd = (`na' != `nb')
    forvalues i = 1/`=min(`na', `nb')' {
        if `"`macval(a_`i')'"' != `"`macval(b_`i')'"' local ++nd
    }
    return scalar n = `na'
    return scalar nd = `nd'
end

* Ledger rows of one datacheck call's groupstat family, stamp dropped
capture program drop _u_led
program define _u_led
    args file out
    quietly use `"`file'"', clear
    quietly keep if family == "groupstat"
    capture drop stamp
    quietly save `"`out'"', replace
end

* Two _u_led files hold the same rows: every column equal, observed_num to
* 1e-12 relative (a float mean is summed in the data's current sort order,
* so the last bit moves between runs on identical data)
capture program drop _u_cfled
program define _u_cfled
    args fa fb nosig
    tempfile ta tb
    quietly use `"`fa'"', clear
    generate long _row = _n
    rename observed_num _on_a
    quietly save `"`ta'"'
    quietly use `"`fb'"', clear
    generate long _row = _n
    rename observed_num _on_b
    quietly save `"`tb'"'
    quietly use `"`ta'"', clear
    quietly merge 1:1 _row using `"`tb'"', nogenerate assert(match)
    assert (_on_a == _on_b) | reldif(_on_a, _on_b) < 1e-12 | (missing(_on_a) & missing(_on_b))
    quietly use `"`fa'"', clear
    drop observed_num
    if "`nosig'" != "" drop signature
    quietly save `"`ta'"', replace
    quietly use `"`fb'"', clear
    drop observed_num
    if "`nosig'" != "" drop signature
    quietly cf _all using `"`ta'"'
end

* Run a gatesonly call writing its ledger, its log kept for table parsing
capture program drop _u_run
program define _u_run, rclass
    args logfile ledger gs
    capture erase `"`ledger'_l.dta"'
    quietly log using `"`logfile'"', replace text name(urun)
    capture noisily datacheck, gatesonly `gs' ledger("`ledger'_l.dta")
    local drc = _rc
    local rmask = r(masked)
    quietly log close urun
    return scalar rc = `drc'
    return scalar masked = `rmask'
end

* Cell text of statistic column j (multi table) for a row line
capture program drop _u_cell
program define _u_cell, rclass
    args line j
    return local c = strtrim(substr(`"`line'"', 19 + 10 * (`j' - 1), 10))
    return local g = strtrim(substr(`"`line'"', 3, 16))
end

* Metamorphic check: multi form vs one single-statistic entry per statistic.
* Compares ledger rows (all columns but stamp) and every table cell.
capture program drop _u_meta
program define _u_meta
    args stats var by extra mask cells
    if "`cells'" == "" local cells 1
    _u_fix
    local mopt ""
    if `mask' > 0 local mopt " maskrare mincell(`mask')"
    local multi `"groupstat(`stats': `var', by(`by')`extra')"'
    local singles ""
    foreach s of local stats {
        if `"`singles'"' != "" local singles `"`singles' \ "'
        local singles `"`singles'`s' `var', by(`by')`extra'"'
    }
    local singles `"groupstat(`singles')"'
    tempfile la lb lga lgb
    _u_run "`lga'.log" "`la'" `"`multi'`mopt'"'
    local rca = r(rc)
    local ma = r(masked)
    _u_run "`lgb'.log" "`lb'" `"`singles'`mopt'"'
    local rcb = r(rc)
    local mb = r(masked)
    assert `rca' == 0 & `rcb' == 0
    assert `ma' == `mb'
    _u_led "`la'_l.dta" "`la'_g.dta"
    _u_led "`lb'_l.dta" "`lb'_g.dta"
    quietly use "`la'_g.dta", clear
    local nstat : word count `stats'
    assert _N == `nstat'
    * labels, one row per statistic in order
    local j = 0
    foreach s of local stats {
        local ++j
        local sn = cond("`s'" == "p50", "median", "`s'")
        assert label[`j'] == "`sn' `var'"
    }
    _u_cfled "`la'_g.dta" "`lb'_g.dta"
    if !`cells' exit
    * cells: multi table column j vs the single table of statistic j
    local hdrA = "GROUPSTAT `stats': `var' by(`by')"
    local nsl = 0
    quietly _u_block "`lga'.log" "`hdrA'"
    local nA = r(n)
    assert `nA' >= 4
    forvalues i = 1/`nA' {
        local LA`i' `"`r(l`i')'"'
    }
    local j = 0
    foreach s of local stats {
        local ++j
        local sn = cond("`s'" == "p50", "median", "`s'")
        quietly _u_block "`lgb'.log" "GROUPSTAT `sn' by(`by')"
        local nB = r(n)
        assert `nB' >= 4
        forvalues i = 1/`nB' {
            local LB`i' `"`r(l`i')'"'
        }
        * single table: header row, group rows, pooled, optional small line
        * multi table: same rows, same order
        assert `nB' == `nA'
        forvalues i = 2/`nB' {
            local LBi `"`LB`i''"'
            if substr(strtrim(`"`LBi'"'), 1, 6) == "groups" {
                assert strtrim(`"`LA`i''"') == strtrim(`"`LBi'"')
                continue
            }
            local gB = strtrim(substr(`"`LBi'"', 3, 24))
            local cB = strtrim(substr(`"`LBi'"', 27, 13))
            _u_cell `"`LA`i''"' `j'
            assert `"`r(g)'"' == substr(`"`gB'"', 1, 16)
            assert `"`r(c)'"' == `"`cB'"'
        }
    }
end

**# U4 table content vs summarize/_pctile oracle (no mask)
capture noisily {
    _u_fix
    tempfile lg
    quietly log using "`lg'.log", replace text name(u1)
    datacheck, gatesonly groupstat(n mean p1 median p99: y, by(g))
    local drc = _rc
    quietly log close u1
    assert `drc' == 0
    quietly _u_block "`lg'.log" "GROUPSTAT n mean p1 median p99: y by(g)"
    assert r(n) == 1 + 5 + 1
    forvalues i = 1/7 {
        local LL`i' `"`r(l`i')'"'
    }
    local ng = 0
    foreach lv in A B C D E {
        local ++ng
        local L `"`LL`=`ng' + 1''"'
        quietly count if g == "`lv'" & !missing(y)
        local en = strtrim(string(r(N), "%10.4g"))
        quietly summarize y if g == "`lv'"
        local em = strtrim(string(r(mean), "%10.4g"))
        quietly _pctile y if g == "`lv'", p(1 50 99)
        local e1 = strtrim(string(r(r1), "%10.4g"))
        local e50 = strtrim(string(r(r2), "%10.4g"))
        local e99 = strtrim(string(r(r3), "%10.4g"))
        local exp "`en'|`em'|`e1'|`e50'|`e99'"
        local got ""
        forvalues j = 1/5 {
            _u_cell `"`L'"' `j'
            local got "`got'`=cond(`j' == 1, "", "|")'`r(c)'"
        }
        _u_cell `"`L'"' 1
        assert `"`r(g)'"' == "`lv'"
        * the cells here are in column order n mean p1 median p99
        assert "`got'" == "`exp'"
    }
    * pooled over the whole scope, including rows whose group is missing
    quietly count if !missing(y)
    local en = strtrim(string(r(N), "%10.4g"))
    quietly summarize y
    local em = strtrim(string(r(mean), "%10.4g"))
    quietly _pctile y, p(1 50 99)
    local exp "`en'|`em'|`=strtrim(string(r(r1), "%10.4g"))'|`=strtrim(string(r(r2), "%10.4g"))'|`=strtrim(string(r(r3), "%10.4g"))'"
    assert strtrim(substr(`"`LL7'"', 3, 16)) == "pooled"
    local got ""
    forvalues j = 1/5 {
        _u_cell `"`LL7'"' `j'
        local got "`got'`=cond(`j' == 1, "", "|")'`r(c)'"
    }
    assert "`got'" == "`exp'"
}
local rc = _rc
_u_tally `rc' "U4 five-statistic table equals summarize/_pctile oracle per group"

**# U4 metamorphic: multi form == one single-statistic entry per statistic
capture noisily {
    _u_meta "n mean" y g "" 0
    _u_meta "n mean p1 median p99" y g "" 0
    _u_meta "sd sum distinct pmiss ess" y g "" 0
    _u_meta "n mean" y gn "" 0
    _u_meta "n p50 mean" x g "" 5
}
local rc = _rc
_u_tally `rc' "U4 metamorphic: per-group cells and ledger rows equal the single-statistic entries"

capture noisily {
    _u_meta "n mean median" y g " min(2)" 5
    _u_meta "n mean sd" y g "" 5
    _u_meta "n mean" y g " min(8)" 0
    _u_meta "n mean" y g " if x > 10" 0
    _u_meta "n mean sd" y g " min(1) if x > 45" 5
    _u_meta "n distinct" s g "" 0
}
local rc = _rc
_u_tally `rc' "U4 metamorphic under maskrare, min(), the entry's own if, and a string variable"

* a scope with no rows: ledger rows still equal the single entries
capture noisily {
    _u_meta "n mean" y g " if x > 1000" 0 0
}
local rc = _rc
_u_tally `rc' "U4 metamorphic: entry scope with no rows gives the single-entry review rows"

**# U4 ledger shape: one row per (statistic, variable), review status
capture noisily {
    _u_fix
    tempfile la
    _u_run "`la'.log" "`la'" "groupstat(n mean median p99: y, by(g))"
    assert r(rc) == 0
    quietly count if !missing(y)
    local npool = r(N)
    quietly use "`la'_l.dta", clear
    quietly keep if family == "groupstat"
    assert _N == 4
    assert label[1] == "n y" & label[2] == "mean y" & label[3] == "median y" & label[4] == "p99 y"
    assert variable == "y"
    assert kind == "review"
    * each observed is "pooled <value>", the pooled value of the statistic
    assert observed[1] == "pooled `npool'"
}
local rc = _rc
_u_tally `rc' "U4 ledger: one review row per statistic with the pooled value"

**# U4 grammar: colon with one statistic is byte-identical to today's form
capture noisily {
    foreach gs in "mean y, by(g)" "n y, by(gn) min(4)" "p99 y, by(g) band(0 100)" ///
        "mean y, by(g) band(1 2) if x > 10" "median x, by(g) band(0.5 3) relative" {
        _u_fix
        local colon = word("`gs'", 1) + ": " + substr("`gs'", strpos("`gs'", " ") + 1, .)
        tempfile la lb lga lgb
        _u_run "`lga'.log" "`la'" "groupstat(`gs') maskrare mincell(5)"
        local rca = r(rc)
        _u_run "`lgb'.log" "`lb'" "groupstat(`colon') maskrare mincell(5)"
        assert `rca' == r(rc)
        _u_logdiff "`lga'.log" "`lgb'.log"
        display "  case `gs': lines=`r(n)' differing=`r(nd)' rc=`rca'"
        assert r(n) > 4
        assert r(nd) == 0
        _u_led "`la'_l.dta" "`la'_g.dta"
        _u_led "`lb'_l.dta" "`lb'_g.dta"
        quietly use "`la'_g.dta", clear
        assert _N >= 1
        _u_cfled "`la'_g.dta" "`lb'_g.dta"
    }
}
local rc = _rc
_u_tally `rc' "U4 colon with one statistic: identical output and ledger rows to the plain form"

**# U4 refusals
capture noisily {
    _u_fix
    set varabbrev on
    local bad `""n mean: y, by(g) band(0 100)" "n mean: y, by(g) relative" "n mean: x y, by(g)" "n n: y, by(g)" "median p50: y, by(g)" "mean MEAN: y, by(g)" "n bogus: y, by(g)" "n mean sd p1 p5 p10 p25: y, by(g)" "n mean sd p1 p5 p10: y, by(g)""'
    * the last one has six statistics: allowed; the one before has seven: refused
    local nbad = 0
    foreach e of local bad {
        local ++nbad
        capture datacheck, gatesonly groupstat(`e')
        if `nbad' < 9 assert _rc == 198
        else assert _rc == 0
        assert c(varabbrev) == "on"
    }
    capture datacheck, gatesonly groupstat(: y, by(g))
    assert _rc == 198
    capture datacheck, gatesonly groupstat(n mean:, by(g))
    assert _rc == 198
    capture datacheck, gatesonly groupstat(n mean: y)
    assert _rc == 198
    capture datacheck, gatesonly groupstat(n mean: y, by(g) bogus)
    assert _rc == 198
    capture datacheck, gatesonly groupstat(n mean: nosuch, by(g))
    assert _rc == 111
    capture datacheck, gatesonly groupstat(n mean: y, by(nosuch))
    assert _rc == 111
    capture datacheck, gatesonly groupstat(n mean: s, by(g))
    assert _rc == 109
    capture datacheck, gatesonly groupstat(n distinct: s, by(g))
    assert _rc == 0
    * a multi-statistic entry has no band, so it is not valid inside bands()
    capture datacheck, gatesonly bands(groupstat(n mean: y, by(g)))
    assert _rc == 198
    capture datacheck, gatesonly bands(groupstat(mean: y, by(g) band(0 100)))
    assert _rc == 0
    set varabbrev off
}
local rc = _rc
set varabbrev off
_u_tally `rc' "U4 refusals: band/relative, several variables, duplicates, unknown, >6 statistics, bad grammar"

**# U4 masking cell by cell against count-if oracles
capture noisily {
    _u_fix
    tempfile lg
    quietly log using "`lg'.log", replace text name(u5)
    datacheck, gatesonly groupstat(n mean sd median: y, by(g) min(2)) maskrare mincell(5)
    quietly log close u5
    quietly _u_block "`lg'.log" "GROUPSTAT n mean sd median: y by(g)"
    local nb = r(n)
    forvalues i = 1/`nb' {
        local LL`i' `"`r(l`i')'"'
    }
    local nsup = 0
    forvalues i = 2/`=`nb' - 2' {
        _u_cell `"`LL`i''"' 1
        local lv "`r(g)'"
        if "`lv'" == "pooled" continue
        local cn1 = strtrim(substr(`"`LL`i''"', 19, 10))
        quietly count if g == "`lv'" & !missing(y)
        local cnt = r(N)
        quietly summarize y if g == "`lv'"
        local mu = r(mean)
        local sdv = r(sd)
        quietly count if g == "`lv'" & y <= `mu' & !missing(y)
        local le = r(N)
        quietly count if g == "`lv'" & y >= `mu' & !missing(y)
        local ge = r(N)
        quietly _pctile y if g == "`lv'", p(50)
        local md = r(r1)
        quietly count if g == "`lv'" & y <= `md' & !missing(y)
        local lem = r(N)
        quietly count if g == "`lv'" & y >= `md' & !missing(y)
        local gem = r(N)
        * n: a count of 1..4 prints as <5
        local e1 = cond(`cnt' >= 1 & `cnt' < 5, "<5", strtrim(string(`cnt', "%10.4g")))
        * mean: withheld unless five on each side of it
        local e2 = cond(`le' < 5 | `ge' < 5, "[suppr.]", strtrim(string(`mu', "%10.4g")))
        * sd: withheld below five observations
        local e3 = cond(`cnt' < 5, "[suppr.]", strtrim(string(`sdv', "%10.4g")))
        local e4 = cond(`lem' < 5 | `gem' < 5, "[suppr.]", strtrim(string(`md', "%10.4g")))
        forvalues j = 1/4 {
            _u_cell `"`LL`i''"' `j'
            assert `"`r(c)'"' == `"`e`j''"'
            if "`r(c)'" == "[suppr.]" | "`r(c)'" == "<5" local ++nsup
            * no shown count is below the mask
            if `j' == 1 & substr("`r(c)'", 1, 1) != "<" assert real("`r(c)'") >= 5
        }
    }
    * the planted small groups (D has 2 values, E has 2) are masked
    assert `nsup' >= 6
    * n pooled value is withheld when a group cell is masked
    _u_cell `"`LL`=`nb' - 1''"' 1
    assert strtrim(substr(`"`LL`=`nb' - 1''"', 3, 16)) == "pooled" | strtrim(substr(`"`LL`nb''"', 3, 16)) == "pooled"
}
local rc = _rc
_u_tally `rc' "U4 maskrare: each cell follows its statistic's rule (count-if oracle), no small count shown"

**# U4 min() suppresses small groups once for the whole table
capture noisily {
    _u_fix
    tempfile lg
    quietly log using "`lg'.log", replace text name(u6)
    datacheck, gatesonly groupstat(n mean: y, by(g) min(10))
    quietly log close u6
    quietly _u_block "`lg'.log" "GROUPSTAT n mean: y by(g)"
    * header, A, B, pooled, small-group line (C, D, E have fewer than 10 rows)
    assert r(n) == 5
    assert strtrim(`"`r(l5)'"') == "groups with fewer than 10 rows: 3"
    assert strtrim(substr(`"`r(l2)'"', 3, 16)) == "A"
    assert strtrim(substr(`"`r(l3)'"', 3, 16)) == "B"
}
local rc = _rc
_u_tally `rc' "U4 min(): groups below it pooled into one line"

**# U4 display width and column header for the largest entry
capture noisily {
    _u_fix
    tempfile lg
    quietly log using "`lg'.log", replace text name(u7)
    datacheck, gatesonly groupstat(n mean sd median p1 p99: y, by(gn))
    quietly log close u7
    quietly _u_block "`lg'.log" "GROUPSTAT n mean sd median p1 p99: y by(gn)"
    assert r(n) >= 6
    forvalues i = 1/`r(n)' {
        assert length(`"`r(l`i')'"') <= 80
    }
    assert strtrim(substr(`"`r(l1)'"', 3, 16)) == "Group"
    assert strtrim(substr(`"`r(l2)'"', 3, 16)) == "Alpha"
}
local rc = _rc
_u_tally `rc' "U4 six-statistic table fits in 80 columns, value-labelled groups"

**# U4 profile mode and gatesonly write the same rows; data order does not matter
capture noisily {
    _u_fix
    tempfile la lb
    capture erase "`la'_l.dta"
    capture erase "`lb'_l.dta"
    quietly datacheck, gatesonly groupstat(n mean p99: y, by(g)) ledger("`la'_l.dta")
    quietly datacheck y, groupstat(n mean p99: y, by(g)) ledger("`lb'_l.dta")
    _u_led "`la'_l.dta" "`la'_g.dta"
    _u_led "`lb'_l.dta" "`lb'_g.dta"
    quietly use "`la'_g.dta", clear
    assert _N == 3
    _u_cfled "`la'_g.dta" "`lb'_g.dta" nosig
    * reorder the data: same rows
    _u_fix
    set seed 20261003
    gen double u = runiform()
    sort u
    drop u
    capture erase "`lb'_l.dta"
    quietly datacheck, gatesonly groupstat(n mean p99: y, by(g)) ledger("`lb'_l.dta")
    _u_led "`lb'_l.dta" "`lb'_g.dta"
    _u_cfled "`la'_g.dta" "`lb'_g.dta" nosig
}
local rc = _rc
_u_tally `rc' "U4 profile-mode and gatesonly ledger rows agree; row order of the data is irrelevant"

sysdir set PLUS "`oldplus'"
sysdir set PERSONAL "`oldpersonal'"
display "RESULT: test_datacheck_v190_groupstat tests=$TC pass=$PASS fail=$FAIL"
log close main
if $FAIL exit 1
