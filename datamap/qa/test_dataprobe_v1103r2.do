clear all
set more off
version 16.0
set linesize 255

* test_dataprobe_v1103r2.do - regressions for the second 1.10.3 review of
* dataprobe (findings D1-D11 and the suspected items that reproduced, S*).
* Each test names its finding.  Every test was red on the tree before the
* fix except where a comment says it is a guard.

local qa_dir  "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
discard

local test_count = 0
local pass_count = 0
local fail_count = 0

local W "`c(tmpdir)'/v1103r2"
capture mkdir "`W'"

* number of lines of a text file that contain a string
capture program drop _r2_count
program define _r2_count, rclass
    args file needle
    tempname fh
    local n 0
    file open `fh' using `"`file'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', `"`needle'"') local ++n
        file read `fh' line
    }
    file close `fh'
    return scalar n = `n'
end

* number of lines of a text file equal to a string once blanks are trimmed
* and runs of blanks collapsed (a table row such as "1   30" reads "1 30")
capture program drop _r2_eq
program define _r2_eq, rclass
    args file needle
    tempname fh
    local n 0
    file open `fh' using `"`file'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if stritrim(strtrim(`"`macval(line)'"')) == `"`needle'"' local ++n
        file read `fh' line
    }
    file close `fh'
    return scalar n = `n'
end

* Tied groups 1 and 2: exactly one prints the withheld form of a line (@
* stands for the group) and the other the exact form, whichever group the
* pooled-remainder test picks on the tie; r(g) is the withheld group.
* mode is eq (whole line, blanks collapsed) or count (substring).
capture program drop _r2_tie
program define _r2_tie, rclass
    args mode file sup ex
    forvalues gg = 1/2 {
        local s = subinstr(`"`sup'"', "@", "`gg'", .)
        _r2_`mode' "`file'" `"`s'"'
        local ns`gg' = r(n)
        local e = subinstr(`"`ex'"', "@", "`gg'", .)
        _r2_`mode' "`file'" `"`e'"'
        local ne`gg' = r(n)
    }
    assert `ns1' + `ns2' == 1
    local w = cond(`ns1' == 1, 1, 2)
    local o = 3 - `w'
    assert `ne`o'' == 1 & `ne`w'' == 0
    return scalar g = `w'
end

* D1: a sum is a value of its rows -------------------------------------
local ++test_count
capture noisily {
    clear
    set obs 74
    gen long id = _n
    gen double income = 1000 + _n*137.5
    gen byte flag = _n <= 3
    gen double half = 0.5*flag
    gen double inc2 = income if _n == 7
    capture log close r2log
    log using "`W'/d1.log", text replace name(r2log)
    capture noisily dataprobe, gatesonly stat(sum income 0 1 if id==5 \ sum half 0 0.1 \ sum inc2 0 1) maskrare warn
    log close r2log
    * one row's income, a 0.5 flag on 3 rows (1.5 = 3 x 0.5), one nonmissing row
    _r2_count "`W'/d1.log" "stat(sum income): [suppressed]"
    assert r(n) == 1
    _r2_count "`W'/d1.log" "stat(sum half): [suppressed]"
    assert r(n) == 1
    _r2_count "`W'/d1.log" "stat(sum inc2): [suppressed]"
    assert r(n) == 1
    _r2_count "`W'/d1.log" "1687.5"
    assert r(n) == 0
    _r2_count "`W'/d1.log" "1962.5"
    assert r(n) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: D1 stat(sum) of 1..m-1 rows, nonzero rows, or a small value class is [suppressed]"
}
else {
    local ++fail_count
    display as error "  FAIL: D1 stat(sum) of 1..m-1 rows, nonzero rows, or a small value class is [suppressed]"
}

local ++test_count
capture noisily {
    clear
    set obs 74
    gen double income = 1000 + _n*137.5
    gen g = mod(_n, 2)
    gen double inc3 = income if inlist(_n, 7, 8)
    capture log close r2log
    log using "`W'/d1b.log", text replace name(r2log)
    capture noisily dataprobe, gatesonly groupstat(sum inc3, by(g)) maskrare
    log close r2log
    * groupstat(sum) with one nonmissing row per group printed 2100 and 1963
    _r2_eq "`W'/d1b.log" "0 [suppr.]"
    assert r(n) == 1
    _r2_eq "`W'/d1b.log" "1 [suppr.]"
    assert r(n) == 1
    _r2_count "`W'/d1b.log" "2100"
    assert r(n) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: D1 groupstat(sum) cell from one row per group is [suppr.]"
}
else {
    local ++fail_count
    display as error "  FAIL: D1 groupstat(sum) cell from one row per group is [suppr.]"
}

* guard (green before and after): a sum over many nonzero rows still prints
local ++test_count
capture noisily {
    clear
    set obs 74
    gen double income = 1000 + _n*137.5
    capture log close r2log
    log using "`W'/d1g.log", text replace name(r2log)
    capture noisily dataprobe, gatesonly stat(sum income 0 1) groupstat(sum income, by(income)) maskrare warn
    log close r2log
    _r2_count "`W'/d1g.log" "stat(sum income): 455562.5"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: D1 guard: a sum over 74 distinct nonzero rows is still shown"
}
else {
    local ++fail_count
    display as error "  FAIL: D1 guard: a sum over 74 distinct nonzero rows is still shown"
}

* D2: Unique beside N gives back the duplicate count ----------------------
local ++test_count
capture noisily {
    clear
    set obs 74
    gen long id = _n
    replace id = 1 in 2
    gen str8 sid = string(id)
    gen double income = 1000 + _n*137.5
    capture log close r2log
    log using "`W'/d2.log", text replace name(r2log)
    dataprobe id sid income, maskrare
    log close r2log
    * 74 rows, 73 unique: one duplicated id, which KEY STRUCTURE masks
    _r2_eq "`W'/d2.log" "id continuous long 0.0% [masked]"
    assert r(n) == 1
    _r2_count "`W'/d2.log" "unique=[masked]"
    assert r(n) == 1
    _r2_count "`W'/d2.log" "unique=73"
    assert r(n) == 0
    * 74 of 74 unique gives nothing away and is shown
    _r2_eq "`W'/d2.log" "income continuous double 0.0% 74"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: D2 Unique and unique= are [masked] when N minus unique is 1..m-1"
}
else {
    local ++fail_count
    display as error "  FAIL: D2 Unique and unique= are [masked] when N minus unique is 1..m-1"
}

* D3: groupwise counts against the totals printed elsewhere ---------------
local ++test_count
capture noisily {
    clear
    set obs 66
    gen g = cond(_n<=30, 1, cond(_n<=60, 2, cond(_n<=63, 3, 4)))
    gen double x = _n
    replace x = . if inlist(_n, 5,6,7,8,9,10, 35,36,37,38,39,40, 61, 64)
    gen byte c = mod(_n, 3)
    replace c = 9 if _n == 62
    capture log close r2log
    log using "`W'/d3.log", text replace name(r2log)
    dataprobe x c, by(g) byfreq maskrare
    log close r2log
    * complete cases 52 in the header; groups 1 and 2 printed 24 and 24, so
    * the pooled groups held 4.  One of the two is now withheld.
    _r2_tie eq "`W'/d3.log" "@ 30 [suppr.] [masked] 1" "@ 30 24 80.0% 1"
    * missing 14 in MISSINGNESS; groups printed 6 and 6, so 2 pooled
    _r2_tie eq "`W'/d3.log" "@ x [suppr.] [masked]" "@ x 6 20.0%"
    * level 0: 22 pooled, groups 10 and 10 (2 pooled away); group 1's table
    * withholds it and pools the rest
    _r2_eq "`W'/d3.log" "0 10 (33.3%)"
    assert r(n) == 1
    _r2_eq "`W'/d3.log" "[suppressed] suppressed (complement)"
    assert r(n) >= 2 & r(n) < .
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: D3 GROUPWISE SUMMARY/MISSINGNESS/FREQUENCIES pass the pooled-remainder test"
}
else {
    local ++fail_count
    display as error "  FAIL: D3 GROUPWISE SUMMARY/MISSINGNESS/FREQUENCIES pass the pooled-remainder test"
}

* D3 under mincell() alone: no pooled groups, a masked cell recovered as the
* pooled count minus the shown cells
local ++test_count
capture noisily {
    clear
    set obs 60
    gen g = cond(_n <= 30, 1, 2)
    gen byte c = cond(_n <= 28, 0, cond(_n <= 30, 1, cond(_n <= 50, 0, 1)))
    capture log close r2log
    log using "`W'/d3b.log", text replace name(r2log)
    dataprobe c, by(g) byfreq mincell(5)
    log close r2log
    * pooled c=1: 12 (2 + 10); group 1 masks its 2, group 2 printed 10, so
    * 12 - 10 = 2 gave the masked cell back
    _r2_eq "`W'/d3b.log" "1 10 (33.3%)"
    assert r(n) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: D3 byfreq under mincell(): pooled minus shown never recovers a masked cell"
}
else {
    local ++fail_count
    display as error "  FAIL: D3 byfreq under mincell(): pooled minus shown never recovers a masked cell"
}

* D4: counts in a by() group whose size is withheld ---------------------
local ++test_count
capture noisily {
    clear
    set obs 110
    gen g = cond(_n<=3, 1, cond(_n<=10, 2, 3))
    gen x = _n
    gen byte e = 1
    capture log close r2log
    log using "`W'/d4.log", text replace name(r2log)
    capture noisily dataprobe, gatesonly by(g) expectn(1 1000) review("all": 1==1) ///
        stat(n x 0 1) rule("r": x < 0) complete(x) events(e: g, min(1000)) maskrare warn
    log close r2log
    * 110 - 100 - 7 = 3: group 2's 7 rows gave back group 1's size
    _r2_count "`W'/d4.log" "review(all): 7 of"
    assert r(n) == 0
    _r2_count "`W'/d4.log" "by(g group 2): review(all): [suppressed] of [suppressed] rows"
    assert r(n) == 1
    _r2_count "`W'/d4.log" "by(g group 2): stat(n x): [suppressed]"
    assert r(n) == 1
    _r2_count "`W'/d4.log" "by(g group 2): rule(r): [suppressed] obs fail"
    assert r(n) == 1
    _r2_count "`W'/d4.log" "by(g group 2): complete(x): [suppressed] of [suppressed] complete"
    assert r(n) == 1
    _r2_count "`W'/d4.log" "by(g group 2): events(e): g = 2 has [suppressed] events"
    assert r(n) == 1
    * a shown group keeps its counts
    _r2_count "`W'/d4.log" "by(g | g=3): review(all): 100 of 100 rows (100.0%)"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: D4 every count of m or more in a withheld by() group is [suppressed]"
}
else {
    local ++fail_count
    display as error "  FAIL: D4 every count of m or more in a withheld by() group is [suppressed]"
}

* D5: groupstat(n) cells beside the PASS-line N -------------------------
local ++test_count
capture noisily {
    clear
    set obs 63
    gen g = cond(_n<=30, 1, cond(_n<=60, 2, 3))
    gen x = _n
    capture log close r2log
    log using "`W'/d5.log", text replace name(r2log)
    capture noisily dataprobe, gatesonly groupstat(n x, by(g) band(0 1000)) maskrare
    log close r2log
    * 63 - 30 - 30 = 3 gave the pooled-away group back: one of the tied
    * groups is withheld, the other printed
    _r2_tie eq "`W'/d5.log" "@ [suppr.]" "@ 30"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: D5 groupstat(n): N minus the shown cells never leaves 1..m-1 rows"
}
else {
    local ++fail_count
    display as error "  FAIL: D5 groupstat(n): N minus the shown cells never leaves 1..m-1 rows"
}

* D6: a pooled-away group is named by number in a band failure -----------
local ++test_count
capture noisily {
    clear
    set obs 43
    gen str10 site = cond(_n<=20, "Alpha", cond(_n<=40, "Beta", "Tiny"))
    gen double x = _n
    replace x = 1000 if site == "Tiny"
    capture log close r2log
    log using "`W'/d6.log", text replace name(r2log)
    capture noisily dataprobe, gatesonly groupstat(mean x, by(site) band(0 100)) maskrare ///
        warn violations(r2v, replace)
    log close r2log
    _r2_count "`W'/d6.log" "Tiny"
    assert r(n) == 0
    _r2_count "`W'/d6.log" "in group #3"
    assert r(n) == 1
    frame r2v: assert strpos(group[1], "Tiny") == 0
    frame r2v: assert strpos(group[1], "group 3") > 0
    capture frame drop r2v
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: D6 groupstat band failure names a withheld group by number"
}
else {
    local ++fail_count
    display as error "  FAIL: D6 groupstat band failure names a withheld group by number"
}

* D7: exclude() withholds a variable's values in every gate ---------------
local ++test_count
capture noisily {
    sysuse auto, clear
    gen dob = td(01jan1960) + _n*41
    format dob %td
    capture log close r2log
    log using "`W'/d7.log", text replace name(r2log)
    capture noisily dataprobe, gatesonly exclude(price dob rep78) inrange(price 0 1) ///
        stat(p99 price 0 1) coverage(dob 01jan1961 31dec1970, gap(30)) ///
        events(foreign: rep78, min(100)) groupstat(mean price, by(foreign) band(0 1)) warn
    log close r2log
    _r2_count "`W'/d7.log" "stat(p99 price): [excluded]"
    assert r(n) == 1
    _r2_count "`W'/d7.log" "15906"
    assert r(n) == 0
    _r2_count "`W'/d7.log" "(last [excluded])"
    assert r(n) == 1
    _r2_count "`W'/d7.log" "22apr1968"
    assert r(n) == 0
    _r2_count "`W'/d7.log" "rep78 = [excluded] level 3 has"
    assert r(n) == 1
    _r2_count "`W'/d7.log" "rep78 = 3 has"
    assert r(n) == 0
    _r2_count "`W'/d7.log" "mean [excluded] in group"
    assert r(n) == 2
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: D7 stat(), coverage(), events() and groupstat() withhold an excluded variable's values"
}
else {
    local ++fail_count
    display as error "  FAIL: D7 stat(), coverage(), events() and groupstat() withhold an excluded variable's values"
}

* D8: heaping's Jan 1 and 1st shares give back the other 1sts -----------
local ++test_count
capture noisily {
    clear
    set obs 1000
    gen d = mdy(1 + mod(_n,12), 2 + mod(_n, 13), 2010 + mod(_n, 5))
    replace d = td(01jan2012) in 1/50
    replace d = td(01mar2012) in 51/52
    format d %td
    capture log close r2log
    log using "`W'/d8.log", text replace name(r2log)
    dataprobe, gatesonly heaping(d) maskrare
    log close r2log
    * 52 firsts, 50 of them on 1 January: 5.20% - 5.00% of 1000 = 2
    _r2_count "`W'/d8.log" "5.20%"
    assert r(n) == 0
    _r2_eq "`W'/d8.log" "d 1000 5.00%* [masked] 0.00%"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: D8 heaping 1st share is [masked] when the other 1sts are 1..m-1"
}
else {
    local ++fail_count
    display as error "  FAIL: D8 heaping 1st share is [masked] when the other 1sts are 1..m-1"
}

* D9: r(masked) when only frequency cells were suppressed ----------------
local ++test_count
capture noisily {
    sysuse auto, clear
    dataprobe rep78 foreign, maskrare
    assert r(masked) == 1
    dataprobe foreign, maskrare
    assert r(masked) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: D9 r(masked) is 1 when a frequency cell is suppressed"
}
else {
    local ++fail_count
    display as error "  FAIL: D9 r(masked) is 1 when a frequency cell is suppressed"
}

* D10: saving() writes the user's datasignature -------------------------
local ++test_count
capture noisily {
    sysuse auto, clear
    datasignature
    local truesig "`r(datasignature)'"
    capture frame drop r2p
    capture frame drop r2p2
    quietly dataprobe, saving(r2p, replace)
    frame r2p: assert datasignature == "`truesig'"
    quietly dataprobe price mpg if foreign, saving(r2p2, replace) signature
    frame r2p2: assert datasignature == "`truesig'"
    assert r(signature) == "`truesig'"
    capture frame drop r2p
    capture frame drop r2p2
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: D10 saving() datasignature is the loaded data's, not the working copy's"
}
else {
    local ++fail_count
    display as error "  FAIL: D10 saving() datasignature is the loaded data's, not the working copy's"
}

* D11: groupstat date cells print as dates ------------------------------
local ++test_count
capture noisily {
    clear
    set obs 60
    gen g = mod(_n, 2)
    gen dob = td(01jan1950) + _n*97
    format dob %td
    capture log close r2log
    log using "`W'/d11.log", text replace name(r2log)
    dataprobe, gatesonly groupstat(median dob, by(g)) maskrare
    dataprobe, gatesonly groupstat(median dob, by(g))
    log close r2log
    _r2_eq "`W'/d11.log" "0 -645"
    assert r(n) == 0
    _r2_eq "`W'/d11.log" "0 1958-03"
    assert r(n) == 1
    * without the mask, the variable's own format
    _r2_eq "`W'/d11.log" "0 27mar1958"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: D11 groupstat date cells print as dates (month precision under the mask)"
}
else {
    local ++fail_count
    display as error "  FAIL: D11 groupstat date cells print as dates (month precision under the mask)"
}

* S1: sd of a three-valued variable beside its mean and N ----------------
local ++test_count
capture noisily {
    clear
    set obs 100
    gen x = cond(_n<=50, 0, cond(_n<=98, 1, 2))
    gen one = 1
    capture log close r2log
    log using "`W'/s1.log", text replace name(r2log)
    capture noisily dataprobe, gatesonly stat(sd x 0 0) groupstat(sd x, by(one)) maskrare warn
    log close r2log
    * mean .52 and sd .5409 beside N 100 solve to 50, 48 and 2
    _r2_count "`W'/s1.log" "stat(sd x): [suppressed]"
    assert r(n) == 1
    _r2_eq "`W'/s1.log" "1 [suppr.]"
    assert r(n) == 1
    _r2_count "`W'/s1.log" ".5409"
    assert r(n) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: S1 sd of a three-valued variable needs m rows of each value"
}
else {
    local ++fail_count
    display as error "  FAIL: S1 sd of a three-valued variable needs m rows of each value"
}

* S2: a bound of . is missing for a date as for a number ----------------
local ++test_count
capture noisily {
    clear
    set obs 100
    gen d = td(01jan2010) + _n*30
    format d %td
    gen x = _n
    capture dataprobe, gatesonly stat(mean x 0 .)
    assert _rc == 0 & r(n_checks) == 1 & r(n_violations) == 0
    capture dataprobe, gatesonly stat(mean d 0 .)
    assert _rc == 0 & r(n_checks) == 1 & r(n_violations) == 0
    * the open upper bound is a bound, not an ignored gate: a lower bound
    * above the mean still fails
    capture dataprobe, gatesonly stat(mean d 30000 .)
    assert _rc == 9 & r(n_violations) == 1
    capture log close r2log
    log using "`W'/s2.log", text replace name(r2log)
    capture noisily dataprobe, gatesonly coverage(d 01jan2010 ., gap(30))
    local rc1 = _rc
    capture noisily dataprobe, gatesonly coverage(d . 01jan2010, gap(30))
    local rc2 = _rc
    log close r2log
    assert `rc1' == 198 & `rc2' == 198
    _r2_count "`W'/s2.log" "coverage(): upper bound is missing"
    assert r(n) == 1
    _r2_count "`W'/s2.log" "coverage(): lower bound is missing"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: S2 stat() upper bound . is open for a date too; coverage() names a missing bound"
}
else {
    local ++fail_count
    display as error "  FAIL: S2 stat() upper bound . is open for a date too; coverage() names a missing bound"
}

* S3: compare() with a varlist ------------------------------------------
local ++test_count
capture noisily {
    sysuse auto, clear
    capture frame drop r2b
    quietly dataprobe, saving("`W'/r2base.dta", replace)
    capture dataprobe price mpg, compare("`W'/r2base.dta")
    assert _rc == 0
    assert r(compare_dropped) == 0
    drop trunk
    capture dataprobe price mpg, compare("`W'/r2base.dta") warn
    assert r(compare_dropped) == 1 & "`r(compare_dropped_vars)'" == "trunk"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: S3 compare() with a varlist reports only variables gone from the data as dropped"
}
else {
    local ++fail_count
    display as error "  FAIL: S3 compare() with a varlist reports only variables gone from the data as dropped"
}

* X: per-group counts against totals printed in another block -----------
* groups 30, 30, 3, 3 (the last two pooled); 14 missing x: 6, 6, 1, 1
capture program drop _r2_fx
program define _r2_fx
    clear
    set obs 66
    gen g = cond(_n<=30, 1, cond(_n<=60, 2, cond(_n<=63, 3, 4)))
    gen double x = _n
    replace x = . if inlist(_n, 5,6,7,8,9,10, 35,36,37,38,39,40, 61, 64)
    gen byte c = mod(_n, 3)
    replace c = 9 if _n == 62
    gen byte flag = inlist(_n, 1,2,3,4,5,6, 31,32,33,34,35,36, 61,62)
end

local ++test_count
capture noisily {
    _r2_fx
    capture log close r2log
    log using "`W'/x1.log", text replace name(r2log)
    capture noisily dataprobe x, by(g) notmissing(x) maskrare warn
    log close r2log
    * MISSINGNESS prints 14; the gate printed 6 and 6, so the pooled groups
    * held 2.  One group's count is withheld, the same group as in the
    * GROUPWISE MISSINGNESS block.
    _r2_count "`W'/x1.log" "x has 6 missing value(s)"
    assert r(n) == 1
    _r2_tie count "`W'/x1.log" "by(g | g=@): notmissing: x has [suppressed] missing value(s)" ///
        "by(g | g=@): notmissing: x has 6 missing value(s)"
    local w = r(g)
    _r2_tie eq "`W'/x1.log" "@ x [suppr.] [masked]" "@ x 6 20.0%"
    assert r(g) == `w'
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: X1 notmissing() per group never recovers pooled rows beside MISSINGNESS"
}
else {
    local ++fail_count
    display as error "  FAIL: X1 notmissing() per group never recovers pooled rows beside MISSINGNESS"
}

local ++test_count
capture noisily {
    clear
    set obs 63
    gen g = cond(_n<=30, 1, cond(_n<=60, 2, 3))
    gen byte flag = inlist(_n, 1,2,3,4,5,6, 31,32,33,34,35,36, 61,62)
    capture log close r2log
    log using "`W'/x2.log", text replace name(r2log)
    dataprobe flag, groupstat(sum flag, by(g)) maskrare
    log close r2log
    * the CATEGORICAL table prints 14 ones; cells 6 and 6 gave back 2
    _r2_eq "`W'/x2.log" "1 14 (22.2%)"
    assert r(n) == 1
    _r2_tie eq "`W'/x2.log" "@ [suppr.]" "@ 6"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: X2 groupstat(sum) of a 0/1 flag against the pooled frequency table"
}
else {
    local ++fail_count
    display as error "  FAIL: X2 groupstat(sum) of a 0/1 flag against the pooled frequency table"
}

local ++test_count
capture noisily {
    _r2_fx
    capture log close r2log
    log using "`W'/x3.log", text replace name(r2log)
    capture noisily dataprobe x c flag, by(g) byfreq notmissing(x) complete(x) forbid(c 0) ///
        binary(flag) stat(n x 0 1 \ sum flag 0 1) groupstat(sum flag, by(g) \ n x, by(g)) ///
        maskrare warn
    log close r2log
    * every block that prints the withheld group's count of a quantity
    * whose total is printed elsewhere withholds it, the same group in every
    * block (groups 1 and 2 tie; either may be picked); the other group's
    * exact counts leave remainders of 5 or more (14 - 6, 22 - 10, 14 - 6,
    * 52 - 24)
    _r2_tie eq "`W'/x3.log" "@ 30 [suppr.] [masked] 1" "@ 30 24 80.0% 1"
    local w = r(g)
    local o = 3 - `w'
    foreach t in "notmissing: x has [suppressed]" "forbid(c): [suppressed]" ///
        "stat(n x): [suppressed]" "stat(sum flag): [suppressed]" ///
        "complete(x): [suppressed] of 30 complete" {
        _r2_count "`W'/x3.log" `"by(g | g=`w'): `t'"'
        assert r(n) == 1
        _r2_count "`W'/x3.log" `"by(g | g=`o'): `t'"'
        assert r(n) == 0
    }
    _r2_eq "`W'/x3.log" "`w' x [suppr.] [masked]"
    assert r(n) == 1
    _r2_eq "`W'/x3.log" "`o' x 6 20.0%"
    assert r(n) == 1
    * groupstat with the call's by(): n of x and the sum of flag
    _r2_eq "`W'/x3.log" "`w' [suppr.]"
    assert r(n) == 2
    _r2_eq "`W'/x3.log" "`o' [suppr.]"
    assert r(n) == 0
    * no line prints the withheld group's count of 24 complete or 6 missing
    _r2_count "`W'/x3.log" "by(g | g=`w'): notmissing: x has 6"
    assert r(n) == 0
    _r2_count "`W'/x3.log" "by(g | g=`w'): complete(x): 24 of 30"
    assert r(n) == 0
    _r2_count "`W'/x3.log" "24 of 30 (80.0%) complete"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: X3 gates, GROUPWISE blocks, byfreq and groupstat withhold the same group"
}
else {
    local ++fail_count
    display as error "  FAIL: X3 gates, GROUPWISE blocks, byfreq and groupstat withhold the same group"
}

local ++test_count
capture noisily {
    clear
    set obs 66
    gen g = cond(_n<=30, 1, cond(_n<=60, 2, cond(_n<=63, 3, 4)))
    gen d = td(01jan2010) + _n
    replace d = td(01jan1990) if inlist(_n, 5,6,7,8,9,10, 35,36,37,38,39,40, 61, 64)
    format d %td
    capture log close r2log
    log using "`W'/x4.log", text replace name(r2log)
    capture noisily dataprobe d, by(g) inrange(d td(01jan2000) td(31dec2020)) maskrare warn
    log close r2log
    * the DATE block prints 14 outside the window; 6 and 6 gave back 2
    _r2_count "`W'/x4.log" "14 obs outside declared window"
    assert r(n) == 1
    _r2_tie count "`W'/x4.log" "by(g | g=@): inrange(d): [suppressed] obs outside" ///
        "by(g | g=@): inrange(d): 6 obs outside"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: X4 inrange() per group against the DATE block's window count"
}
else {
    local ++fail_count
    display as error "  FAIL: X4 inrange() per group against the DATE block's window count"
}

capture log close r2log
local files : dir "`W'" files "*"
foreach f of local files {
    capture erase "`W'/`f'"
}
capture rmdir "`W'"

display as text _newline "RESULT: test_dataprobe_v1103r2 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
