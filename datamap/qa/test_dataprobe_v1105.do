clear all
set more off
version 16.0
set linesize 255

* test_dataprobe_v1105.do - 1.10.5 regressions: counts a dataprobe by()
* profile prints under maskrare are protected together (secondary
* suppression for linked tables), and failing gates on dates print the
* value at full precision without the mask.
*
* Every test was red on 1.10.4 (the pinned counts, the date-only failure
* messages), except the two guards that say so.  Two oracles independent of
* dataprobe's own audit read the printed text: _dataprobe_oracle_v1105.py
* main() rebuilds the attacker's system from the printed blocks and asks a
* MILP (scipy) for the range of every per-group count; relcheck() checks one
* relation on its own by interval arithmetic.  A count from 1 to 4 (or with
* a complement from 1 to 4) that either pins to one value is a disclosure.

local qa_dir  "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
discard

local test_count = 0
local pass_count = 0
local fail_count = 0

local W "`c(tmpdir)'/v1105"
capture mkdir "`W'"
macro drop DATAMAP_DQ

* the oracles need Stata's Python with scipy; their absence is a failure,
* never a skip
capture python: import scipy.optimize; scipy.optimize.milp
if _rc {
    display as error "test_dataprobe_v1105 needs Stata Python integration with scipy (milp)"
    display as text "RESULT: test_dataprobe_v1105 tests=1 pass=0 fail=1"
    exit 1
}
python: import sys; sys.path.insert(0, r"`qa_dir'")
* the oracle module, fresh from this directory
python: import importlib, _dataprobe_oracle_v1105 as dpo; importlib.reload(dpo)

* lines of a text file that contain a string
capture program drop _v5_count
program define _v5_count, rclass
    args file needle
    mata: _v5_count_m(st_local("file"), st_local("needle"))
    return scalar n = scalar(_v5_cnt)
    scalar drop _v5_cnt
end
mata:
void _v5_count_m(string scalar f, string scalar nd)
{
	real scalar fh, n
	string scalar line
	n = 0
	fh = fopen(f, "r")
	while ((line = fget(fh)) != J(0, 0, "")) {
		if (strpos(line, nd) > 0) n++
	}
	fclose(fh)
	st_numscalar("_v5_cnt", n)
}
end

* the MILP oracle on one log and the data it profiled (variables g and
* the profiled ones, exported as CSV): r(viol) pinned counts
capture program drop _v5_oracle
program define _v5_oracle, rclass
    args log csv out
    python: import _dataprobe_oracle_v1105 as dpo; dpo.main(r"`log'", r"`csv'", 5, r"`out'")
    tempname fh
    local nv = .
    file open `fh' using "`out'", read text
    file read `fh' line
    while r(eof) == 0 {
        display as text "    oracle: `line'"
        if substr(`"`line'"', 1, 10) == "VIOLATIONS" local nv = real(word(`"`line'"', 2))
        file read `fh' line
    }
    file close `fh'
    return scalar viol = `nv'
end

* one relation by interval arithmetic: r(pinned) groups pinned
capture program drop _v5_rel
program define _v5_rel, rclass
    args log pat total cmp
    python: import _dataprobe_oracle_v1105 as dpo; from sfi import Scalar; _r = dpo.relcheck(r"`log'", r"`pat'", `total', {"1": 30, "2": 30, "3": 30}, 5, zero_absent=True, complement=bool(`cmp')); print("    relcheck:", _r); Scalar.setValue("_v5_pin", len(_r))
    return scalar pinned = scalar(_v5_pin)
    scalar drop _v5_pin
end

* three groups of 30; rows 1-4 and 31-34 carry the quantity, group 3 none:
* each of groups 1 and 2 prints <5 and the total 8, which pins both at 4
capture program drop _v5_fx
program define _v5_fx
    clear
    set obs 90
    gen g = cond(_n <= 30, 1, cond(_n <= 60, 2, 3))
    gen byte hit = inlist(_n, 1, 2, 3, 4, 31, 32, 33, 34)
end

* the t12 data: group 1 misses x in 48 of 50 rows, groups 2 and 3 never;
* y is missing in 10 rows of groups 2 and 3
capture program drop _v5_t12
program define _v5_t12
    clear
    set obs 150
    gen g = cond(_n <= 50, 1, cond(_n <= 100, 2, 3))
    gen double x = _n
    replace x = . if _n <= 48
    gen double y = _n
    replace y = . if inrange(_n, 51, 60) | inrange(_n, 101, 110)
end

* ---- L1: the t12 repro, one variable ----
* 1.10.4 printed groups 2 and 3 with MissVars 0, so x's 48 missing were
* group 1's and its 2 nonmissing rows came back (and group 2's complete
* [suppr.] read 50 beside MissVars 0)
local ++test_count
capture noisily {
    _v5_t12
    quietly export delimited g x using "`W'/l1.csv", replace
    capture log close v5
    log using "`W'/l1.log", text replace name(v5)
    dataprobe x, by(g) maskrare
    log close v5
    _v5_oracle "`W'/l1.log" "`W'/l1.csv" "`W'/l1.out"
    assert r(viol) == 0
    * group 3 still prints, exactly
    _v5_count "`W'/l1.log" "  3                          50          50    100.0%        0"
    assert r(n) == 1
    _v5_count "`W'/l1.log" "groups pooled (each <5 rows, or pooled with them): 2"
    assert !missing(r(n)) & r(n) >= 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: L1 t12 (x): no group count is pinned; group 3 still printed"
}
else {
    local ++fail_count
    display as error "  FAIL: L1 t12 (x): no group count is pinned; group 3 still printed"
}

* ---- L2: the t12 repro, two variables ----
* 1.10.4: groups 2 and 3 each listed only y, so x's 48 were group 1's;
* and group 2's complete count was its size minus its one missing count
local ++test_count
capture noisily {
    _v5_t12
    quietly export delimited g x y using "`W'/l2.csv", replace
    capture log close v5
    log using "`W'/l2.log", text replace name(v5)
    dataprobe x y, by(g) maskrare
    log close v5
    _v5_oracle "`W'/l2.log" "`W'/l2.csv" "`W'/l2.out"
    assert r(viol) == 0
    _v5_count "`W'/l2.log" "  3                          50          40     80.0%        1"
    assert r(n) == 1
    _v5_count "`W'/l2.log" "all but <5"
    assert r(n) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: L2 t12 (x y): complete = size minus one missing count no longer pins"
}
else {
    local ++fail_count
    display as error "  FAIL: L2 t12 (x y): complete = size minus one missing count no longer pins"
}

* ---- L3: a variable's group missing counts beside MISSINGNESS ----
* groups 1 and 2 print <5, group 3 has no row (0), MISSINGNESS prints 8
local ++test_count
capture noisily {
    _v5_fx
    gen double x = _n
    replace x = . if hit
    gen double y = _n
    quietly export delimited g x y using "`W'/l3.csv", replace
    capture log close v5
    log using "`W'/l3.log", text replace name(v5)
    dataprobe x y, by(g) maskrare
    log close v5
    _v5_oracle "`W'/l3.log" "`W'/l3.csv" "`W'/l3.out"
    assert r(viol) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: L3 group missing counts against the MISSINGNESS total"
}
else {
    local ++fail_count
    display as error "  FAIL: L3 group missing counts against the MISSINGNESS total"
}

* ---- L4: complete cases per group against the header ----
* one variable: complete 26, 26, 30 print all but <5 twice beside 82
local ++test_count
capture noisily {
    _v5_fx
    gen double x = _n
    replace x = . if hit
    quietly export delimited g x using "`W'/l4.csv", replace
    capture log close v5
    log using "`W'/l4.log", text replace name(v5)
    dataprobe x, by(g) maskrare
    log close v5
    _v5_oracle "`W'/l4.log" "`W'/l4.csv" "`W'/l4.out"
    assert r(viol) == 0
    _v5_rel "`W'/l4.log" "^  (?P<g>\d)\s+30\s+(?P<k>.*?)\s{2,}\S+\s+\d+\s*$" 82 1
    assert r(pinned) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: L4 GROUPWISE complete counts against the header's complete cases"
}
else {
    local ++fail_count
    display as error "  FAIL: L4 GROUPWISE complete counts against the header's complete cases"
}

* ---- L5: byfreq cells against the pooled table and the group sizes ----
* level 4 of c: 4 rows in each of groups 1 and 2, none in group 3; the
* pooled table prints 8
local ++test_count
capture noisily {
    _v5_fx
    gen byte c = 1 + mod(_n, 3)
    replace c = 4 if hit
    quietly export delimited g c using "`W'/l5.csv", replace
    capture log close v5
    log using "`W'/l5.log", text replace name(v5)
    dataprobe c, by(g) byfreq maskrare
    log close v5
    _v5_oracle "`W'/l5.log" "`W'/l5.csv" "`W'/l5.out"
    assert r(viol) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: L5 byfreq cells against the pooled frequency table"
}
else {
    local ++fail_count
    display as error "  FAIL: L5 byfreq cells against the pooled frequency table"
}

* ---- L6-L11: per-group gate counts against a total printed elsewhere ----
local L = 5
foreach t in forbid binary statsum notmiss inrange complete {
    local ++L
    local ++test_count
    capture noisily {
        _v5_fx
        local cmp = 0
        if "`t'" == "forbid" {
            gen byte c = 1 + mod(_n, 2)
            replace c = 9 if hit
            local call "dataprobe c, by(g) forbid(c 9) maskrare warn"
            local pat "by\(g \| g=(?P<g>\d)\): forbid\(c\): (?P<k>.*?) obs"
            local what "forbid() counts against the pooled frequency table"
        }
        if "`t'" == "binary" {
            gen byte flag = mod(_n, 2)
            replace flag = 2 if hit
            local call "dataprobe flag, by(g) binary(flag) maskrare warn"
            local pat "by\(g \| g=(?P<g>\d)\): binary\(flag\): (?P<k>.*?) obs not 0/1"
            local what "binary() not-0/1 counts against the pooled frequency table"
        }
        if "`t'" == "statsum" {
            gen byte flag = hit
            local call "dataprobe flag, by(g) stat(sum flag 0 0) maskrare warn"
            local pat "by\(g \| g=(?P<g>\d)\): stat\(sum flag\): (?P<k>.*?), expected"
            local what "stat(sum) of a 0/1 variable against the pooled frequency table"
        }
        if "`t'" == "notmiss" {
            gen double x = _n
            replace x = . if hit
            local call "dataprobe x, by(g) notmissing(x) maskrare warn"
            local pat "by\(g \| g=(?P<g>\d)\): notmissing: x has (?P<k>.*?) missing"
            local what "notmissing() counts (and the zero verdict) against MISSINGNESS"
        }
        if "`t'" == "inrange" {
            gen d = td(01jan2020) + _n
            replace d = td(01jan2030) if hit
            format d %td
            local call "dataprobe d, by(g) inrange(d td(01jan2019) td(31dec2021)) maskrare warn"
            local pat "by\(g \| g=(?P<g>\d)\): inrange\(d\): (?P<k>.*?) obs outside"
            local what "inrange() of a profiled date against the DATE block"
        }
        if "`t'" == "complete" {
            gen double x = _n
            gen double y = _n
            replace x = . if hit
            local call "dataprobe x y, by(g) complete(x y) maskrare warn"
            local pat "by\(g \| g=(?P<g>\d)\): complete\(x y\): (?P<k>.*?) of"
            local cmp = 1
            local what "complete() counts against the header's complete cases"
        }
        capture log close v5
        log using "`W'/l`L'.log", text replace name(v5)
        `call'
        log close v5
        _v5_rel "`W'/l`L'.log" "`pat'" 8 `cmp'
        assert r(pinned) == 0
    }
    if _rc == 0 {
        local ++pass_count
        display as result "  PASS: L`L' `what'"
    }
    else {
        local ++fail_count
        display as error "  FAIL: L`L' `what'"
    }
}

* ---- L12: groupstat() with the call's by() pools what the profile pools ----
* 1.10.4 printed group 1's n of x as <5 beside group 3's 50, group 2's
* [suppr.] (an exact count, here 50) and the continuous N of 102
local ++test_count
capture noisily {
    _v5_t12
    capture log close v5
    log using "`W'/l12.log", text replace name(v5)
    dataprobe x y, by(g) groupstat(n x y, by(g)) maskrare warn
    log close v5
    _v5_count "`W'/l12.log" "  1                                  <5"
    assert r(n) == 0
    _v5_count "`W'/l12.log" "  2                            [suppr.]"
    assert r(n) == 0
    _v5_count "`W'/l12.log" "  3                                  50           40"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: L12 groupstat() cells of the groups the profile pools are pooled too"
}
else {
    local ++fail_count
    display as error "  FAIL: L12 groupstat() cells of the groups the profile pools are pooled too"
}

* ---- L13: a pooled group's linked gate count reads [suppressed] ----
* groups 3 and 4 (3 rows each) are pooled; each misses x in 2 rows;
* groups 1 and 2 none: 1.10.4 printed <5 for both pooled groups beside
* MISSINGNESS 4, and two counts of 1 to 4 that sum to 4 with group 4 at
* most 3 rows pin nothing alone, but <5 is 1 to 4 and the total of 4
* left group 3 in 1..3; the gate now says only that the count is nonzero
local ++test_count
capture noisily {
    clear
    set obs 66
    gen g = cond(_n <= 30, 1, cond(_n <= 60, 2, cond(_n <= 63, 3, 4)))
    gen double x = _n
    replace x = . if inlist(_n, 61, 62, 64, 65)
    capture log close v5
    log using "`W'/l13.log", text replace name(v5)
    dataprobe x, by(g) notmissing(x) maskrare warn
    log close v5
    _v5_count "`W'/l13.log" "by(g group 3): notmissing: x has [suppressed] missing value(s)"
    assert r(n) == 1
    _v5_count "`W'/l13.log" "by(g group 4): notmissing: x has [suppressed] missing value(s)"
    assert r(n) == 1
    _v5_count "`W'/l13.log" "notmissing: x has <5"
    assert r(n) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: L13 a pooled group's linked gate count says only that it is nonzero"
}
else {
    local ++fail_count
    display as error "  FAIL: L13 a pooled group's linked gate count says only that it is nonzero"
}

* ---- L14: brute force: 30 seeded random by() profiles ----
* two to four groups of 30, x heavily missing in group 1, y and c lightly
* everywhere, c's level 4 frequent in group 2; byfreq on every other one
local ++test_count
capture noisily {
    local tot = 0
    forvalues s = 1/30 {
        clear
        set seed `=1000 + `s''
        local G = 2 + floor(runiform() * 3)
        quietly set obs `=`G' * 30'
        gen g = 1 + mod(_n, `G')
        gen double x = round(runiform() * 100)
        quietly replace x = . if runiform() < cond(g == 1, 0.9, 0.05)
        gen double y = round(runiform() * 100)
        quietly replace y = . if runiform() < 0.06
        gen c = 1 + floor(runiform() * 4)
        quietly replace c = 4 if runiform() < 0.3 & g == 2
        quietly replace c = . if runiform() < 0.05
        local bf = cond(mod(`s', 2), "byfreq", "")
        quietly export delimited g x y c using "`W'/bf`s'.csv", replace nolabel
        capture log close v5
        log using "`W'/bf`s'.log", text replace name(v5)
        dataprobe x y c, by(g) maskrare `bf'
        log close v5
        _v5_oracle "`W'/bf`s'.log" "`W'/bf`s'.csv" "`W'/bf`s'.out"
        assert r(viol) < .
        local tot = `tot' + r(viol)
    }
    display as text "  brute force: `tot' pinned counts over 30 outputs"
    assert `tot' == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: L14 MILP oracle: no group count pinned in 30 random outputs"
}
else {
    local ++fail_count
    display as error "  FAIL: L14 MILP oracle: no group count pinned in 30 random outputs"
}

* ---- L15 (guard): realistic data where nothing needs pooling ----
* nlsw88 by(race): the 1.10.4 output pinned nothing; every group is still
* printed, as before
local ++test_count
capture noisily {
    sysuse nlsw88, clear
    capture log close v5
    log using "`W'/l15.log", text replace name(v5)
    dataprobe, by(race) maskrare
    log close v5
    _v5_count "`W'/l15.log" "groups pooled"
    assert r(n) == 0
    _v5_count "`W'/l15.log" "  White                    1637        1333     81.4%        6"
    assert r(n) == 1
    _v5_count "`W'/l15.log" "  Black                     583    [suppr.]  [masked]        6"
    assert r(n) == 1
    _v5_count "`W'/l15.log" "  Other                      26  all but <5  [masked]        1"
    assert r(n) == 1
    * an all-safe synthetic profile: nothing withheld at all
    clear
    set obs 200
    gen g = 1 + mod(_n, 2)
    gen double x = _n
    replace x = . if mod(_n, 10) == 0
    capture log close v5
    log using "`W'/l15b.log", text replace name(v5)
    dataprobe x, by(g) maskrare
    log close v5
    foreach t in "groups pooled" "[suppr.]" "<5" "[masked]" {
        _v5_count "`W'/l15b.log" "`t'"
        assert r(n) == 0
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: L15 guard: nlsw88 by(race) and an all-safe profile pool nothing"
}
else {
    local ++fail_count
    display as error "  FAIL: L15 guard: nlsw88 by(race) and an all-safe profile pool nothing"
}

* ---- L16 (guard): without the mask the output is unchanged ----
local ++test_count
capture noisily {
    _v5_t12
    capture log close v5
    log using "`W'/l16.log", text replace name(v5)
    dataprobe x y, by(g) groupstat(n x, by(g)) notmissing(x) warn
    log close v5
    _v5_count "`W'/l16.log" "  1                          50           2      4.0%        1"
    assert r(n) == 1
    _v5_count "`W'/l16.log" "  1                   x                            48     96.0%"
    assert r(n) == 1
    _v5_count "`W'/l16.log" "by(g | g=1): notmissing: x has 48 missing value(s)"
    assert r(n) == 1
    _v5_count "`W'/l16.log" "groups pooled"
    assert r(n) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: L16 guard: unmasked by() output prints every group exactly"
}
else {
    local ++fail_count
    display as error "  FAIL: L16 guard: unmasked by() output prints every group exactly"
}

* ---- D1: a failing date stat() at full precision without the mask ----
* the mean is 874.5125 (24may1962 at noon and after); against an upper
* bound of 874 the date alone read as the bound
local ++test_count
capture noisily {
    clear
    set obs 40
    gen double dob = td(01jan1962) + _n * 7
    replace dob = dob + 0.5 in 40
    format dob %td
    capture log close v5
    log using "`W'/d1.log", text replace name(v5)
    dataprobe dob, gatesonly stat(mean dob 0 874) warn
    dataprobe dob, gatesonly stat(mean dob 0 874) maskrare warn
    log close v5
    _v5_count "`W'/d1.log" "stat(mean dob): 874.5125 (24may1962), expected [0, 874]"
    assert r(n) == 1
    _v5_count "`W'/d1.log" "stat(mean dob): 24may1962, expected"
    assert r(n) == 0
    * under the mask: month precision, never the exact value
    _v5_count "`W'/d1.log" "stat(mean dob): 1962-05, expected [0, 874]"
    assert r(n) == 1
    _v5_count "`W'/d1.log" "874.5125"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: D1 a failing date stat() prints the value beside the date; the mask keeps the month"
}
else {
    local ++fail_count
    display as error "  FAIL: D1 a failing date stat() prints the value beside the date; the mask keeps the month"
}

* ---- D2: a %tc value at %21.0g, percentiles too ----
local ++test_count
capture noisily {
    clear
    set obs 41
    gen double tc = clock("2020-01-01 00:00:00", "YMDhms") + _n * 1000 + 123
    format tc %tc
    capture log close v5
    log using "`W'/d2.log", text replace name(v5)
    dataprobe tc, gatesonly stat(p50 tc 0 1893456000000) warn
    log close v5
    _v5_count "`W'/d2.log" "stat(median tc): 1893456021123 (01jan2020 00:00:21), expected"
    assert r(n) == 1
    _v5_count "`W'/d2.log" "e+12"
    assert r(n) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: D2 a failing %tc median prints all 13 digits beside the datetime"
}
else {
    local ++fail_count
    display as error "  FAIL: D2 a failing %tc median prints all 13 digits beside the datetime"
}

* ---- D3: inrange() and coverage() failures on dates ----
* the last date is 08oct1962 at noon (1011.5), past an upper bound of
* 08oct1962; 1.10.4 printed max 08oct1962
local ++test_count
capture noisily {
    clear
    set obs 40
    gen double dob = td(01jan1962) + _n * 7
    replace dob = dob + 0.5 in 40
    replace dob = dob + 0.5 in 1
    format dob %td
    capture log close v5
    log using "`W'/d3.log", text replace name(v5)
    dataprobe dob, gatesonly inrange(dob td(01jan1962) td(08oct1962)) warn
    dataprobe dob, gatesonly coverage(dob 01jan1962 08oct1962, gap(8) tail(1)) warn
    dataprobe dob, gatesonly inrange(dob td(01jan1962) td(08oct1962)) maskrare warn
    log close v5
    _v5_count "`W'/d3.log" "(min 738.5 (08jan1962), max 1011.5 (08oct1962))"
    assert r(n) == 1
    * a coverage() that passes prints no date at full precision
    _v5_count "`W'/d3.log" "first 738.5"
    assert r(n) == 0
    _v5_count "`W'/d3.log" "PASS: 1 gate(s) (coverage), N = 40, 0 violations"
    assert r(n) == 1
    * under the mask the extremes are withheld (p1 and p99 of 40 dates),
    * and the exact value never prints
    _v5_count "`W'/d3.log" "(p1 [suppressed], p99 [suppressed])"
    assert r(n) == 1
    _v5_count "`W'/d3.log" "1011.5"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: D3 a failing inrange() on a date prints its extremes at full precision"
}
else {
    local ++fail_count
    display as error "  FAIL: D3 a failing inrange() on a date prints its extremes at full precision"
}

* ---- D4: coverage(early_start) failure ----
local ++test_count
capture noisily {
    clear
    set obs 40
    gen double dob = td(01jan1962) + 1.5 + _n * 7
    format dob %td
    capture log close v5
    log using "`W'/d4.log", text replace name(v5)
    dataprobe dob, gatesonly coverage(dob 01jan1962 31dec1962, gap(8) tail(1)) warn
    log close v5
    _v5_count "`W'/d4.log" "starts after 09jan1962 = 01jan1962 + 8 days (first 739.5 (09jan1962))"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: D4 a failing coverage(early_start) prints the first date at full precision"
}
else {
    local ++fail_count
    display as error "  FAIL: D4 a failing coverage(early_start) prints the first date at full precision"
}

* ---- D5: a groupstat() band failure on a %tc variable ----
local ++test_count
capture noisily {
    clear
    set obs 40
    gen byte grp = 1 + (_n > 20)
    gen double tc = clock("2020-01-01 00:00:00", "YMDhms") + _n * 1000 + 123
    format tc %tc
    capture log close v5
    log using "`W'/d5.log", text replace name(v5)
    dataprobe tc, gatesonly groupstat(mean tc, by(grp) band(0 1893456000000)) warn
    log close v5
    _v5_count "`W'/d5.log" "e+12"
    assert r(n) == 0
    _v5_count "`W'/d5.log" "1893456010623 (01jan2020 00:00:10)"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: D5 a groupstat() band failure on a %tc variable prints all 13 digits"
}
else {
    local ++fail_count
    display as error "  FAIL: D5 a groupstat() band failure on a %tc variable prints all 13 digits"
}

capture log close v5
macro drop DATAMAP_DQ
local files : dir "`W'" files "*"
foreach f of local files {
    capture erase "`W'/`f'"
}
capture rmdir "`W'"

display as text _newline "RESULT: test_dataprobe_v1105 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
