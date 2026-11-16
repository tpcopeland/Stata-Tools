*! test_datamap_v210_by_engine.do Version 1.0.0  2026/11/15
*! datamap 2.1.0 P1 (dataprobe by(): one pass over the rows for every group)
*! and F9(d) (inrange(): rows below lo and above hi, masked as the count)
*! Author: Timothy P Copeland, Karolinska Institutet
*
* P1 changes how dataprobe reaches a by() group's rows (the rows are put in
* group order once and every per-group command reads its group's block),
* not what it reports.  The oracle is the ungrouped code path, which P1 does
* not touch: the same gates run with no by() on each group's rows kept alone
* must give the grouped call's ledger rows, row for row (family, label,
* status, observed, observed_num, expected, n_scope, minshown, obs_masked,
* and the message after the group prefix).
*
*   B1  numeric by() with . and .a groups and a value label, rows of the
*       groups interleaved, 15 gate families: grouped = per-group oracle
*   B2  string by() whose values hold " ' $ ` { }, an if/in sample, and a
*       group with no rows failing: grouped = per-group oracle
*   B3  the same call on rows already in group order and shuffled gives the
*       same ledger rows; the data, their order and sort order are unchanged
*       on exit (preserve)
*   B4  edge cases: one group and an all-missing by() variable equal the
*       ungrouped call; an empty sample stops as the ungrouped call does
*   B5  _dataprobe_byhits: blocks/count/mark/distinct against count, egen
*       tag and the row order; a group variable that is not 1..G is an error
*   B6  the profile path (no gatesonly: egen groups, the rows sorted for
*       the loop) gives the per-group oracle's gate rows; on the gatesonly
*       path without nodups the data are unchanged on exit and an
*       intervals() row equals the ungrouped call's
*   B7  the rows stay in group order after the by() loop: every whole-sample
*       family (jumps with tied times, heaping, sets, constant, intervals,
*       groupstat) gives the ungrouped call's rows on shuffled data, on the
*       gatesonly and the profile path, and the data are unchanged on exit
*   F1  inrange() split without the mask: message, r(), observed unchanged
*   F2  by() and two entries: r() sums and every group's sides equal counts
*   F3  half-open ranges: no split text; r() takes the bounded side
*   F4  maskrare cases, exact strings: a masked side withholds the other,
*       beside a masked total a side prints only 0 or <m
*   F5  privacy property over seeded fixtures with by() and pooled groups:
*       no side 1..m-1 printed, never exactly one exact side beside an exact
*       total, never an exact side beside a masked total, every exact side
*       equals an independent count
*   F6  exclude(): the split prints, the extremes stay withheld
*   F7  missing values are never outside; no r() without inrange(); parse
*       errors unchanged
*   F8  the console violation line and the ledger carry the split; the
*       ledger's variables are the 2.0.0 schema
version 16.0
clear all
set processors 1
set linesize 255
capture log close _all
log using "test_datamap_v210_by_engine.log", replace text name(main)
local pkg_dir = regexr("`c(pwd)'", "/qa$", "")
tempfile base
local W "`base'_v210be"
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
local tests = 0
local pass = 0
local fail = 0
local cwd0 "`c(pwd)'"
macro drop DATAMAP_DQ

**# Helpers

* _be_cmp gfile sfile: the grouped ledger gfile against the per-group
* oracle ledger sfile, row for row
capture program drop _be_cmp
program define _be_cmp
    args gfile sfile
    tempfile sub
    quietly use "`sfile'", clear
    quietly keep family label variable status observed observed_num expected ///
        n_scope minshown obs_masked message grp
    foreach v of varlist _all {
        rename `v' s_`v'
    }
    quietly generate long _row = _n
    quietly save "`sub'"
    quietly use "`gfile'", clear
    quietly keep family label variable status observed observed_num expected ///
        n_scope minshown obs_masked message grp
    quietly generate long _row = _n
    quietly merge 1:1 _row using "`sub'"
    assert _merge == 3
    foreach v in family label variable status observed expected {
        assert `v' == s_`v'
    }
    foreach v in observed_num n_scope minshown obs_masked {
        assert `v' == s_`v' | (missing(`v') & missing(s_`v'))
    }
    // the grouped message is the group prefix, ": ", and the oracle's
    assert substr(message, 1, 3) == "by("
    assert usubstr(message, -ustrlen(s_message) - 2, .) == ": " + s_message
    assert grp != ""
    display as text "  _be_cmp: " _N " ledger rows agree"
end

* the gate list of B1 and B2
local GB1 `"rule("pos": x > -3) inrange(x -2.5 2.5 \ xf -1.2 1.2) stat(mean x -1 1 \ sd x 0 3 \ distinct z 0 10 \ n x 0 1000 \ pmiss x 0 .5 \ sum ev 0 1000 \ median xf -1 1 \ p90 x 0 2 \ mean x -1 1 if y == 1) notmissing(x) isid(id) binary(y) allowed(z 0 1 2 3 4) regex(s ^[ab]) review("neg": x < 0) complete(x y, min(.5)) events(ev: z, min(30)) nodups expectn(100 250) warn"'

* B1/B2 fixture
capture program drop _be_fix
program define _be_fix
    args seed n
    clear
    set seed `seed'
    quietly set obs `n'
    quietly generate double x = rnormal() * 2
    quietly generate float xf = rnormal()
    quietly generate byte y = runiform() < .3
    quietly replace y = 2 in 5
    quietly generate z = floor(runiform() * 6)
    quietly generate byte ev = runiform() < .4
    quietly generate g = 1 + floor(runiform() * 4)
    quietly replace g = . if runiform() < .06
    quietly replace g = .a if runiform() < .04
    label define _beg 1 "one" 2 "two" 4 "four", replace
    label values g _beg
    quietly generate str8 s = word("aa bb cc", 1 + floor(runiform() * 3))
    quietly generate long id = _n
    quietly replace id = id - 1 in 10/12
    quietly replace x = . in 1/20
    quietly generate double _u = runiform()
    sort _u
    drop _u
end

* _be_f4 nbelow nabove ninside expected-split: one entry inrange(x 0 1)
capture program drop _be_f4
program define _be_f4
    args nb na nin want
    clear
    quietly set obs `=`nb' + `na' + `nin''
    quietly generate double x = 0.5
    if `nb' > 0 quietly replace x = -1 in 1/`nb'
    if `na' > 0 quietly replace x = 2 in `=`nb' + 1'/`=`nb' + `na''
    dataprobe, gatesonly inrange(x 0 1) maskrare warn violations(_be_v, replace)
    local rb = r(inrange_n_below)
    local ra = r(inrange_n_above)
    frame _be_v {
        local m = message[1]
        display as text `"  `nb'/`na'/`nin': `m'"'
        assert strpos(message[1], `"`want'"') > 0
        * the 2.0.0 text is unchanged and never shows min or max
        assert strpos(message[1], "min") == 0 & strpos(message[1], "max") == 0
    }
    c_local rb `rb'
    c_local ra `ra'
end

**# B1 numeric by(): grouped equals the per-group oracle
capture noisily {
    foreach f in b1g b1s {
        capture erase "`W'/`f'.dta"
    }
    _be_fix 21015 900
    tempfile fx
    quietly save "`fx'"
    dataprobe, gatesonly by(g) `GB1' ledger("`W'/b1g.dta")
    local ng = r(n_groups)
    assert `ng' == 6
    * the oracle: each group's rows alone, ungrouped, in group order
    quietly egen long _gid = group(g), missing
    quietly summarize _gid, meanonly
    assert r(max) == 6
    forvalues k = 1/6 {
        use "`fx'", clear
        quietly egen long _gid = group(g), missing
        quietly keep if _gid == `k'
        drop _gid
        dataprobe, gatesonly `GB1' ledger("`W'/b1s.dta")
    }
    _be_cmp "`W'/b1g.dta" "`W'/b1s.dta"
    * every family of the gate list is in the comparison, fail and pass rows
    use "`W'/b1g.dta", clear
    foreach fam in rule inrange stat notmissing isid binary allowed regex review complete events nodups expectn {
        quietly count if family == "`fam'"
        assert r(N) >= 6
    }
    quietly count if status == "pass"
    assert r(N) > 0
    quietly count if status == "warn"
    assert r(N) > 0
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: B1 numeric by(): grouped equals the per-group oracle (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: B1 numeric by(): grouped equals the per-group oracle"
}

**# B2 hostile string by(), if/in sample, a group with no failing rows
capture noisily {
    foreach f in b2g b2s {
        capture erase "`W'/`f'.dta"
    }
    _be_fix 7331 700
    quietly generate str20 h = ""
    quietly replace h = `"q"uote"' if mod(_n, 5) == 0
    quietly replace h = "it's" if mod(_n, 5) == 1
    quietly replace h = char(36) + "HOME" + char(96) if mod(_n, 5) == 2
    quietly replace h = "{bf:x}" if mod(_n, 5) == 3
    quietly replace h = "" if mod(_n, 5) == 4
    * the "it's" group has no row failing rule(pos)
    quietly replace x = abs(x) if h == "it's"
    local GB2 `"rule("pos": x > -3) inrange(x -2.5 2.5) stat(mean x -1 1 \ distinct z 0 10 \ p25 xf -1 0) notmissing(x) binary(y) review("neg": x < 0) complete(x y) warn"'
    tempfile fx2
    quietly save "`fx2'"
    dataprobe if z != 5 in 40/650, gatesonly by(h) `GB2' ledger("`W'/b2g.dta")
    assert r(n_groups) == 5
    * the oracle sample: the same if/in rows, then each group alone
    quietly generate byte _t = 0
    quietly replace _t = 1 if z != 5 in 40/650
    quietly keep if _t
    drop _t
    quietly egen long _gid = group(h), missing
    tempfile fx2s
    quietly save "`fx2s'"
    forvalues k = 1/5 {
        use "`fx2s'", clear
        quietly keep if _gid == `k'
        drop _gid
        dataprobe, gatesonly `GB2' ledger("`W'/b2s.dta")
    }
    _be_cmp "`W'/b2g.dta" "`W'/b2s.dta"
    use "`W'/b2g.dta", clear
    * the group with no failing row passes rule(pos)
    quietly count if family == "rule" & status == "pass"
    assert r(N) >= 1
    quietly count if family == "rule" & status == "warn"
    assert r(N) >= 1
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: B2 hostile string by() with an if/in sample equals the oracle (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: B2 hostile string by() with an if/in sample equals the oracle"
}

**# B3 order: sorted and shuffled rows agree; the data are left as they were
capture noisily {
    foreach f in b3a b3b {
        capture erase "`W'/`f'.dta"
    }
    _be_fix 99 500
    quietly generate long _ord = _n
    sort z _ord
    local sb0 : sortedby
    tempfile before
    quietly save "`before'"
    * shuffled by g: the call sorts, then puts the rows back
    dataprobe, gatesonly by(g) `GB1' ledger("`W'/b3a.dta")
    local sb1 : sortedby
    assert "`sb1'" == "`sb0'"
    * the same rows in the same order
    cf _all using "`before'"
    * already in group order: no sort needed, same rows
    sort g _ord
    dataprobe, gatesonly by(g) `GB1' ledger("`W'/b3b.dta")
    use "`W'/b3a.dta", clear
    quietly keep family label status observed observed_num message grp
    tempfile la
    quietly save "`la'"
    use "`W'/b3b.dta", clear
    quietly keep family label status observed observed_num message grp
    cf _all using "`la'"
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: B3 sorted and shuffled rows agree; data and order unchanged (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: B3 sorted and shuffled rows agree; data and order unchanged"
}

**# B4 edge cases: one group, all-missing by(), empty sample
capture noisily {
    foreach f in b4a b4b b4c b4d {
        capture erase "`W'/`f'.dta"
    }
    _be_fix 5 300
    quietly generate byte one = 7
    quietly generate double allmiss = .
    local GB4 `"rule("pos": x > -3) inrange(x -2.5 2.5) stat(mean x -1 1 \ distinct z 0 10) binary(y) complete(x y) warn"'
    dataprobe, gatesonly by(one) `GB4' ledger("`W'/b4a.dta")
    assert r(n_groups) == 1
    dataprobe, gatesonly `GB4' ledger("`W'/b4b.dta")
    _be_cmp "`W'/b4a.dta" "`W'/b4b.dta"
    _be_fix 5 300
    quietly generate double allmiss = .
    dataprobe, gatesonly by(allmiss) `GB4' ledger("`W'/b4c.dta")
    assert r(n_groups) == 1
    dataprobe, gatesonly `GB4' ledger("`W'/b4d.dta")
    _be_cmp "`W'/b4c.dta" "`W'/b4d.dta"
    * an empty sample: the grouped call stops as the ungrouped one does
    _be_fix 5 300
    capture noisily dataprobe if x > 1e6 & !missing(x), gatesonly by(g) `GB4'
    local rcg = _rc
    capture noisily dataprobe if x > 1e6 & !missing(x), gatesonly `GB4'
    local rcu = _rc
    display as text "  empty sample: by() rc `rcg', ungrouped rc `rcu'"
    assert `rcg' == `rcu' & `rcg' == 2000
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: B4 one group, all-missing by(), empty sample (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: B4 one group, all-missing by(), empty sample"
}

**# B5 _dataprobe_byhits against count, egen tag and the row order
capture noisily {
    clear
    set seed 404
    quietly set obs 400
    quietly generate long g = 1 + floor(runiform() * 7)
    quietly generate byte h = runiform() < .2
    quietly replace h = . in 1/5
    quietly generate long r0 = _n
    quietly generate double v = floor(runiform() * 9)
    quietly generate strL sv = "k" + string(floor(runiform() * 5))
    quietly replace sv = "a" + char(34) + "b'c" + char(36) + char(96) + "d{e}" in 7
    * blocks: sorts (stably) and returns each group's first and last row
    _dataprobe_byhits blocks g, order(o) first(f) last(l)
    assert r(sorted) == 1 & r(G) == 7
    assert o == r0
    forvalues k = 1/7 {
        quietly count if g == `k'
        local nk = r(N)
        assert l[`k'] - f[`k'] + 1 == `nk'
        quietly count if g == `k' in `=f[`k']'/`=l[`k']'
        assert r(N) == `nk'
        * stable: the group's rows keep their order
        quietly count if g == `k' & r0 < r0[_n - 1] in `=f[`k'] + 1'/`=l[`k']'
        assert r(N) == 0
        * distinct over the block, against egen tag()
        tempvar t tg
        quietly generate byte `t' = (g == `k' & !missing(v)) in `=f[`k']'/`=l[`k']'
        _dataprobe_byhits distinct v, touse(`t') range(`=f[`k']'/`=l[`k']')
        local dn = r(n)
        quietly egen byte `tg' = tag(v) if g == `k' & !missing(v)
        quietly count if `tg' == 1
        assert `dn' == r(N)
        drop `t' `tg'
        tempvar t
        quietly generate byte `t' = (g == `k') in `=f[`k']'/`=l[`k']'
        _dataprobe_byhits distinct sv, touse(`t') range(`=f[`k']'/`=l[`k']')
        local dn = r(n)
        drop `t'
        tempvar s2 tg2
        quietly generate str40 `s2' = sv
        quietly egen byte `tg2' = tag(`s2') if g == `k'
        quietly count if `tg2' == 1
        assert `dn' == r(N)
        drop `s2' `tg2'
    }
    * an empty range counts nothing
    tempvar t
    quietly generate byte `t' = 1
    _dataprobe_byhits distinct v, touse(`t') range(10/9)
    assert r(n) == 0
    drop `t'
    * already in order: nothing sorted, no order variable
    drop f l
    _dataprobe_byhits blocks g, order(o2) first(f) last(l)
    assert r(sorted) == 0
    capture confirm variable o2
    assert _rc == 111
    * count: rows per group with a nonzero, nonmissing hit
    quietly generate long c = .
    quietly replace g = . in 20/25
    _dataprobe_byhits count g h, into(c)
    forvalues k = 1/7 {
        quietly count if g == `k' & h == 1
        assert c[`k'] == r(N)
    }
    * mark: the listed groups, under if, other rows unchanged
    quietly generate byte m = mod(_n, 3) * 4
    quietly generate byte m0 = m
    _dataprobe_byhits mark g if v > 3, groups(2 5 7) replace(m)
    assert m == cond(inlist(g, 2, 5, 7) & v > 3, 1, m0)
    quietly count if m == 1
    assert r(N) > 0
    * a group variable that is not the blocks 1..G is an error
    quietly replace g = 9 in 30
    sort r0
    drop f l
    capture _dataprobe_byhits blocks g, order(o3) first(f) last(l)
    assert _rc == 459
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: B5 _dataprobe_byhits blocks/count/mark/distinct (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: B5 _dataprobe_byhits blocks/count/mark/distinct"
}

**# B6 profile path; gatesonly without nodups, with and without a family
capture noisily {
    foreach f in b6g b6s b6a b6b {
        capture erase "`W'/`f'.dta"
    }
    local GB6 `"rule("pos": x > -3) inrange(x -2.5 2.5) stat(mean x -1 1 \ distinct z 0 10) binary(y) review("neg": x < 0) events(ev: z, min(30)) warn"'
    _be_fix 606 600
    tempfile fx6
    quietly save "`fx6'"
    * profile mode: the gate rows of the grouped call
    dataprobe x z y, by(g) `GB6' ledger("`W'/b6g.dta")
    forvalues k = 1/6 {
        use "`fx6'", clear
        quietly egen long _gid = group(g), missing
        quietly keep if _gid == `k'
        drop _gid
        dataprobe, gatesonly `GB6' ledger("`W'/b6s.dta")
    }
    _be_cmp "`W'/b6g.dta" "`W'/b6s.dta"
    * gatesonly without nodups: the data are unchanged on exit
    use "`fx6'", clear
    quietly generate long _ord = _n
    tempfile before6
    quietly save "`before6'"
    dataprobe, gatesonly by(g) `GB6'
    cf _all using "`before6'"
    * a whole-sample family after the loop: its row is the ungrouped call's
    quietly generate long pid = ceil(_n / 3)
    quietly bysort pid: generate long t0 = _n * 10
    quietly generate long t1 = t0 + 10
    quietly replace t1 = t0 + 15 in 7
    quietly generate double _u = runiform()
    sort _u
    drop _u
    dataprobe, gatesonly by(g) intervals(pid t0 t1, contiguous) rule("pos": x > -3) warn ledger("`W'/b6a.dta")
    dataprobe, gatesonly intervals(pid t0 t1, contiguous) warn ledger("`W'/b6b.dta")
    use "`W'/b6a.dta", clear
    quietly keep if family == "intervals"
    quietly keep family label status observed observed_num message
    tempfile i6
    quietly save "`i6'"
    use "`W'/b6b.dta", clear
    quietly keep if family == "intervals"
    quietly keep family label status observed observed_num message
    assert _N >= 1
    cf _all using "`i6'"
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: B6 profile path and gatesonly order handling (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: B6 profile path and gatesonly order handling"
}

**# B7 whole-sample families after the by() loop read rows in group order
* No order restore follows the loop, so a whole-sample family that depended
* on the row order would differ from the ungrouped call here: the fixture
* has tied times within id (jumps), shuffled rows, and groups g that cut
* across every family's own keys.
capture noisily {
    foreach f in b7g b7u b7p b7q {
        capture erase "`W'/`f'.dta"
    }
    clear
    set seed 7707
    quietly set obs 600
    quietly generate long id = 1 + floor(runiform() * 40)
    quietly generate int t = 1 + floor(runiform() * 4)
    quietly generate double v = floor(runiform() * 100)
    quietly generate long z = floor(runiform() * 5)
    quietly generate g = 1 + floor(runiform() * 5)
    quietly replace g = . if runiform() < .05
    quietly generate int dt = mdy(1, 1, 2020) + floor(runiform() * 40)
    quietly replace dt = mdy(1, 1, 2020) if runiform() < .2
    format dt %td
    quietly generate double x = rnormal()
    quietly bysort id: generate long pid = _n
    quietly generate long t0 = pid * 10
    quietly generate long t1 = t0 + cond(runiform() < .1, 15, 10)
    quietly generate double _u = runiform()
    sort _u
    drop _u
    quietly generate long _ord = _n
    local sb0 : sortedby
    tempfile before7
    quietly save "`before7'"
    local FAM `"jumps(id t v, ratio(2)) heaping(dt) sets(id z) constant(id: z) intervals(id t0 t1, contiguous) groupstat(n mean: v, by(z))"'
    local GATE `"rule("pos": x > -1.5) inrange(x -2 2)"'
    * gatesonly path: grouped against ungrouped
    dataprobe, gatesonly by(g) `GATE' `FAM' warn ledger("`W'/b7g.dta")
    local sb1 : sortedby
    assert "`sb1'" == "`sb0'"
    cf _all using "`before7'"
    dataprobe, gatesonly `GATE' `FAM' warn ledger("`W'/b7u.dta")
    * profile path: grouped against ungrouped
    dataprobe x v z, by(g) `GATE' `FAM' warn ledger("`W'/b7p.dta")
    cf _all using "`before7'"
    dataprobe x v z, `GATE' `FAM' warn ledger("`W'/b7q.dta")
    foreach pr in "b7g b7u" "b7p b7q" {
        gettoken ga ua : pr
        local ua = strtrim("`ua'")
        use "`W'/`ua'.dta", clear
        quietly keep if inlist(family, "jumps", "heaping", "sets", "constant", "intervals", "groupstat")
        quietly keep family label variable status observed observed_num expected n_scope minshown obs_masked message
        * every family ran
        foreach f in jumps heaping sets constant intervals groupstat {
            quietly count if family == "`f'"
            assert r(N) >= 1
        }
        tempfile u7
        quietly save "`u7'"
        use "`W'/`ga'.dta", clear
        quietly keep if inlist(family, "jumps", "heaping", "sets", "constant", "intervals", "groupstat")
        quietly keep family label variable status observed observed_num expected n_scope minshown obs_masked message
        cf _all using "`u7'"
        display as text "  B7 `ga' = `ua': " _N " whole-sample rows agree"
    }
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: B7 whole-sample families after the by() loop equal the ungrouped call (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: B7 whole-sample families after the by() loop equal the ungrouped call"
}

**# F1 inrange() split without the mask
capture frame drop _be_v
capture noisily {
    clear
    quietly set obs 20
    quietly generate double x = _n
    dataprobe, gatesonly inrange(x 4 15) warn violations(_be_v, replace)
    assert r(inrange_n_below) == 3 & r(inrange_n_above) == 5
    frame _be_v {
        assert _N == 1
        assert message[1] == "inrange(x): 8 obs outside [4, 15] (3 below, 5 above)  (min 1, max 20)"
        * observed is the 2.0.0 text
        assert observed[1] == "8 outside; min 1, max 20"
    }
    * a passing entry: 0 and 0, no split
    dataprobe, gatesonly inrange(x 0 30) warn
    assert r(inrange_n_below) == 0 & r(inrange_n_above) == 0
    * a float variable against a float-rounded bound: 0.1 is not below 0.1
    clear
    quietly set obs 5
    quietly generate float f = 0.1 * _n
    dataprobe, gatesonly inrange(f 0.1 0.3) warn
    assert r(inrange_n_below) == 0 & r(inrange_n_above) == 2
}
local rc = _rc
capture frame drop _be_v
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: F1 inrange() split without the mask (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: F1 inrange() split without the mask"
}

**# F2 by() and two entries: r() sums and every group's sides equal counts
capture noisily {
    capture erase "`W'/f2.dta"
    _be_fix 1234 800
    dataprobe, gatesonly by(g) inrange(x -2 2.5 \ xf -1 1) warn ledger("`W'/f2.dta")
    local rb = r(inrange_n_below)
    local ra = r(inrange_n_above)
    quietly count if x < -2 & !missing(x)
    local ob = r(N)
    quietly count if x > 2.5 & !missing(x)
    local oa = r(N)
    quietly count if xf < float(-1) & !missing(xf)
    local ob = `ob' + r(N)
    quietly count if xf > float(1) & !missing(xf)
    local oa = `oa' + r(N)
    display as text "  r() `rb'/`ra', counted `ob'/`oa'"
    assert `rb' == `ob' & `ra' == `oa'
    * each group's line, against a count in that group
    tempfile fx
    quietly egen long _gid = group(g), missing
    quietly save "`fx'"
    use "`W'/f2.dta", clear
    quietly keep if family == "inrange" & status == "warn"
    assert _N >= 6
    quietly generate long b = .
    quietly generate long a = .
    forvalues i = 1/`=_N' {
        assert ustrregexm(message[`i'], "\(([0-9]+) below, ([0-9]+) above\)")
        quietly replace b = real(ustrregexs(1)) in `i'
        quietly replace a = real(ustrregexs(2)) in `i'
    }
    tempfile lines
    quietly save "`lines'"
    use "`fx'", clear
    local nl = 0
    forvalues k = 1/6 {
        foreach e in "x -2 2.5" "xf -1 1" {
            local v : word 1 of `e'
            local lo : word 2 of `e'
            local hi : word 3 of `e'
            if "`v'" == "xf" {
                quietly count if _gid == `k' & `v' < float(`lo') & !missing(`v')
                local cb = r(N)
                quietly count if _gid == `k' & `v' > float(`hi') & !missing(`v')
                local ca = r(N)
            }
            else {
                quietly count if _gid == `k' & `v' < `lo' & !missing(`v')
                local cb = r(N)
                quietly count if _gid == `k' & `v' > `hi' & !missing(`v')
                local ca = r(N)
            }
            if `cb' + `ca' == 0 continue
            local ++nl
            preserve
            use "`lines'", clear
            assert b[`nl'] == `cb' & a[`nl'] == `ca'
            assert variable[`nl'] == "`v'"
            restore
        }
    }
    preserve
    use "`lines'", clear
    assert _N == `nl'
    restore
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: F2 by() and two entries: sums and per-group sides (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: F2 by() and two entries: sums and per-group sides"
}

**# F3 half-open ranges
capture frame drop _be_v
capture noisily {
    clear
    quietly set obs 20
    quietly generate double x = _n
    dataprobe, gatesonly inrange(x 6 .) warn violations(_be_v, replace)
    assert r(inrange_n_below) == 5 & r(inrange_n_above) == 0
    frame _be_v: assert message[1] == "inrange(x): 5 obs outside [6, .]  (min 1, max 20)"
    dataprobe, gatesonly inrange(x . 17) warn violations(_be_v, replace)
    assert r(inrange_n_below) == 0 & r(inrange_n_above) == 3
    frame _be_v: assert strpos(message[1], "below") == 0 & strpos(message[1], "above") == 0
}
local rc = _rc
capture frame drop _be_v
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: F3 half-open ranges (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: F3 half-open ranges"
}

**# F4 maskrare: exact strings for each case (mincell 5)
capture frame drop _be_v
capture noisily {
    * the test_dataprobe_gates fixture: 4 below, 5 above, 9 shown
    _be_f4 4 5 291 "9 obs outside [0, 1] (<5 below, [suppressed] above)"
    assert missing(`rb') & missing(`ra')
    _be_f4 7 2 291 "9 obs outside [0, 1] ([suppressed] below, <5 above)"
    assert missing(`rb') & missing(`ra')
    * both sides masked beside an exact total: nothing recoverable
    _be_f4 3 3 100 "6 obs outside [0, 1] (<5 below, <5 above)"
    assert missing(`rb') & missing(`ra')
    * a masked total: a side prints only 0 or <m
    _be_f4 0 3 100 "<5 obs outside [0, 1] (0 below, <5 above)"
    assert missing(`rb') & missing(`ra')
    _be_f4 2 1 100 "<5 obs outside [0, 1] (<5 below, <5 above)"
    * all but <m outside: sides of the mask or more are withheld
    _be_f4 50 48 2 "all but <5 obs outside [0, 1] ([suppressed] below, [suppressed] above)"
    _be_f4 0 98 2 "all but <5 obs outside [0, 1] (0 below, [suppressed] above)"
    * both sides of the mask or more: exact, and r() is set
    _be_f4 6 7 100 "13 obs outside [0, 1] (6 below, 7 above)"
    assert `rb' == 6 & `ra' == 7
    _be_f4 0 9 100 "9 obs outside [0, 1] (0 below, 9 above)"
    assert `rb' == 0 & `ra' == 9
}
local rc = _rc
capture frame drop _be_v
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: F4 maskrare split cases (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: F4 maskrare split cases"
}

**# F5 privacy property: seeded fixtures, by() with pooled groups, maskrare
capture noisily {
    local nlines = 0
    local nmasked = 0
    foreach seed in 11 12 13 14 15 16 {
        capture erase "`W'/f5.dta"
        clear
        set seed `seed'
        quietly set obs `=200 + 37 * `seed''
        * a few small groups (pooled under the mask) and large ones
        quietly generate int g = 1 + floor(runiform() * 6)
        quietly replace g = 7 + floor(runiform() * 3) if runiform() < .03
        quietly generate double x = rnormal() * (1 + mod(`seed', 3))
        quietly generate double lo = -1.5 - mod(`seed', 2)
        tempfile fx
        quietly save "`fx'"
        dataprobe, gatesonly by(g) inrange(x -1.6 2.1) maskrare warn ledger("`W'/f5.dta")
        * the pooled-group order of dataprobe is egen group(g)
        quietly egen long _gid = group(g), missing
        quietly save "`fx'", replace
        use "`W'/f5.dta", clear
        quietly keep if family == "inrange"
        local nr = _N
        forvalues i = 1/`nr' {
            use "`W'/f5.dta", clear
            quietly keep if family == "inrange"
            local msg = message[`i']
            local gp = grp[`i']
            if status[`i'] == "pass" continue
            assert ustrregexm(`"`msg'"', "inrange\(x\): (.+?) obs outside \[[^\]]*\] \((\S+) below, (\S+) above\)")
            local T = ustrregexs(1)
            local B = ustrregexs(2)
            local A = ustrregexs(3)
            local ++nlines
            * the group's number: by(g | g=v) names the value, by(g group k) the number
            if ustrregexm(`"`gp'"', "group ([0-9]+)\)") local k = real(ustrregexs(1))
            else {
                assert ustrregexm(`"`gp'"', "g=([0-9]+)\)")
                local gv = real(ustrregexs(1))
                use "`fx'", clear
                quietly summarize _gid if g == `gv', meanonly
                local k = r(min)
            }
            use "`fx'", clear
            quietly count if _gid == `k' & x < -1.6
            local cb = r(N)
            quietly count if _gid == `k' & x > 2.1
            local ca = r(N)
            local Tx = regexm("`T'", "^[0-9]+$")
            local Bx = regexm("`B'", "^[0-9]+$")
            local Ax = regexm("`A'", "^[0-9]+$")
            * (a) no exact side between 1 and 4
            if `Bx' assert real("`B'") == 0 | real("`B'") >= 5
            if `Ax' assert real("`A'") == 0 | real("`A'") >= 5
            * (b) beside an exact total, both sides exact or neither
            if `Tx' assert `Bx' == `Ax'
            * (c) beside a masked total, a side is 0, <5 or [suppressed]
            if !`Tx' {
                assert inlist("`B'", "0", "<5", "[suppressed]")
                assert inlist("`A'", "0", "<5", "[suppressed]")
            }
            * (d) an exact side is the count
            if `Bx' assert real("`B'") == `cb'
            if `Ax' assert real("`A'") == `ca'
            if !`Bx' | !`Ax' local ++nmasked
        }
    }
    display as text "  F5: `nlines' failing lines, `nmasked' with a withheld side"
    assert `nlines' >= 12 & `nmasked' >= 3
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: F5 privacy property of the split (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: F5 privacy property of the split"
}

**# F6 exclude(): the split prints, the extremes stay withheld
capture frame drop _be_v
capture noisily {
    clear
    quietly set obs 40
    quietly generate long pnr = 1000 + _n
    quietly generate double w = _n
    dataprobe, gatesonly exclude(pnr) inrange(pnr 1006 1030) warn violations(_be_v, replace)
    assert r(inrange_n_below) == 5 & r(inrange_n_above) == 10
    frame _be_v {
        assert message[1] == "inrange(pnr): 15 obs outside [1006, 1030] (5 below, 10 above)  (extremes withheld: excluded)"
        assert observed[1] == "15 outside"
    }
}
local rc = _rc
capture frame drop _be_v
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: F6 exclude(): split shown, extremes withheld (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: F6 exclude(): split shown, extremes withheld"
}

**# F7 missing values, no r() without inrange(), parse errors unchanged
capture noisily {
    clear
    quietly set obs 30
    quietly generate double x = .
    quietly replace x = .a in 1/3
    dataprobe, gatesonly inrange(x 0 1) warn
    assert r(inrange_n_below) == 0 & r(inrange_n_above) == 0
    quietly replace x = 5 in 10
    quietly replace x = -5 in 11
    dataprobe, gatesonly inrange(x 0 1) warn
    assert r(inrange_n_below) == 1 & r(inrange_n_above) == 1
    * no inrange(): the two results are not posted
    dataprobe, gatesonly rule("r": x < 100) warn
    local rs : r(scalars)
    assert !strpos(" `rs' ", " inrange_n_below ") & !strpos(" `rs' ", " inrange_n_above ")
    capture dataprobe, gatesonly inrange(x 3 1)
    assert _rc == 198
    capture dataprobe, gatesonly inrange(x . .)
    assert _rc == 198
    capture dataprobe, gatesonly inrange(nosuchvar 0 1)
    assert _rc == 111
    capture dataprobe, gatesonly by(nosuchvar) inrange(x 0 1)
    assert _rc == 111
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: F7 missing values, r() presence, parse errors (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: F7 missing values, r() presence, parse errors"
}

**# F8 the console line and the ledger carry the split; the ledger schema
capture noisily {
    capture erase "`W'/f8.dta"
    clear
    quietly set obs 20
    quietly generate double x = _n
    quietly generate byte g = 1 + (_n > 10)
    capture log close f8
    log using "`W'/f8.log", replace text name(f8)
    dataprobe, gatesonly by(g) inrange(x 4 15) warn ledger("`W'/f8.dta")
    local rb = r(inrange_n_below)
    local ra = r(inrange_n_above)
    log close f8
    assert `rb' == 3 & `ra' == 5
    mata: _be_t = cat(st_local("W") + "/f8.log")
    mata: assert(sum(strpos(_be_t, "by(g | g=1): inrange(x): 3 obs outside [4, 15] (3 below, 0 above)") :> 0) == 1)
    mata: assert(sum(strpos(_be_t, "by(g | g=2): inrange(x): 5 obs outside [4, 15] (0 below, 5 above)") :> 0) == 1)
    mata: mata drop _be_t
    use "`W'/f8.dta", clear
    unab lv : _all
    assert "`lv'" == "run stamp seq dataset scope family label variable grp kind status observed observed_num expected n_scope version signature masked mincell minshown obs_masked message phase"
    quietly count if family == "inrange" & strpos(message, "(3 below, 0 above)")
    assert r(N) == 1
    quietly count if family == "inrange" & observed == "3 outside; min 1, max 10"
    assert r(N) == 1
}
local rc = _rc
capture log close f8
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: F8 console line, ledger message, ledger schema (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: F8 console line, ledger message, ledger schema"
}

quietly cd "`cwd0'"
macro drop DATAMAP_DQ
sysdir set PLUS "`oldplus'"
sysdir set PERSONAL "`oldpersonal'"
display "RESULT: test_datamap_v210_by_engine tests=`tests' pass=`pass' fail=`fail'"
log close main
if `fail' exit 1
