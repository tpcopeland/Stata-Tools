clear all
set more off
version 16.0
set linesize 255

* test_datacheck_v190_byrule.do - datacheck byrule() (datamap 1.9.0 F5), the
* sort-order note on subscripted rule()/review() (R5) and the idiom map (D4).
* Known answers come from the planted designs (a counted number of corrupted
* rows), from by-group arithmetic done here, and from hand-sorted rule() and
* the old hand-written idioms; verdicts are read from rc and the ledger file.

* === Bootstrap: targeted local reinstall ===
local qa_dir  "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
discard
macro drop DATAMAP_DQ

global TC 0
global PASS 0
global FAIL 0
capture program drop _br
program define _br
    args rc msg
    global TC = $TC + 1
    if `rc' == 0 {
        display as result "  PASS: `msg'"
        global PASS = $PASS + 1
    }
    else {
        display as error "  FAIL (rc=`rc'): `msg'"
        global FAIL = $FAIL + 1
    }
end

* ledger row of one family/label: r(n) rows, r(st) status of the first, r(num) sum of
* observed_num over the rows, r(obs) observed text of the first, r(kind)
capture program drop _br_row
program define _br_row, rclass
    args file fam label
    preserve
    use `"`file'"', clear
    quietly keep if family == "`fam'" & label == "`label'"
    return scalar n = _N
    local st "absent"
    local ob ""
    local kd ""
    local sm = 0
    if _N > 0 {
        local st = status[1]
        local ob = observed[1]
        local kd = kind[1]
        quietly summarize observed_num
        local sm = cond(r(N) == 0, ., r(sum))
    }
    return local st "`st'"
    return local obs "`ob'"
    return local kind "`kd'"
    return scalar num = `sm'
    restore
end

capture program drop _br_count
program define _br_count, rclass
    args file needle
    tempname fh
    local n = 0
    file open `fh' using `"`file'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', `"`needle'"') local ++n
        file read `fh' line
    }
    file close `fh'
    return scalar n = `n'
end

* panel: 30 ids x 4 doses, in id/date order.  plant = 1 corrupts dose_num of
* 3 rows (ids 3, 7, 11 at dose 2) and next_dose of 2 rows (ids 4, 9 at dose 2).
capture program drop _br_panel
program define _br_panel
    args plant
    clear
    quietly set obs 120
    quietly gen long id = ceil(_n / 4)
    quietly gen byte k = mod(_n - 1, 4) + 1
    quietly gen double dose_date = id * 10 + k * 2
    quietly gen byte dose_num = k
    quietly gen double next_dose = cond(k < 4, dose_date + 2, .)
    if `plant' {
        quietly replace dose_num = 5 if k == 2 & inlist(id, 3, 7, 11)
        quietly replace next_dose = 999 if k == 2 & inlist(id, 4, 9)
    }
end

capture program drop _br_shuffle
program define _br_shuffle
    args seed
    set seed `seed'
    tempvar u
    quietly gen double `u' = runiform()
    sort `u'
    quietly drop `u'
end

local W "`c(tmpdir)'/br190"
capture mkdir "`W'"
local DN `"id (dose_date): "dn": dose_num == _n"'
local ND `"id (dose_date): "nd": _n == _N | next_dose == dose_date[_n+1]"'

**## Concept examples: known answers, several row orders
foreach seed in 1 2 3 4 5 {
    _br_panel 1
    _br_shuffle `seed'
    capture erase "`W'/a.dta"
    capture datacheck, gatesonly byrule(`DN' \ `ND') ledger("`W'/a.dta")
    local rc = _rc
    _br_row "`W'/a.dta" byrule dn
    local s1 = r(st)
    local n1 = r(num)
    _br_row "`W'/a.dta" byrule nd
    _br `=!(`rc' == 9 & "`s1'" == "fail" & `n1' == 3 & "`r(st)'" == "fail" & r(num) == 2)' "seed `seed': dose_num == _n flags the 3 planted rows, next-dose rule the 2 (rc 9)"
}
_br_panel 0
_br_shuffle 7
capture datacheck, gatesonly byrule(`DN' \ `ND')
_br `=!(_rc == 0 & r(n_checks) == 1 & r(n_passed) == 1 & r(n_violations) == 0)' "clean shuffled panel: both byrules pass; one family counted and passed"

**## Parity: byrule on unsorted data versus a hand-sorted rule()
local BYX `"id (dose_date): "prev": dose_num == cond(_n == 1, 1, dose_num[_n-1] + 1)"'
local RLX `"prev: dose_num == cond(id == id[_n-1], dose_num[_n-1] + 1, 1)"'
foreach seed in 11 12 13 14 {
    _br_panel 1
    _br_shuffle `seed'
    capture erase "`W'/p1.dta"
    capture datacheck, gatesonly byrule(`BYX') ledger("`W'/p1.dta")
    local rc1 = _rc
    _br_row "`W'/p1.dta" byrule prev
    local v1 = r(num)
    sort id dose_date
    capture erase "`W'/p2.dta"
    capture datacheck, gatesonly rule(`RLX') ledger("`W'/p2.dta")
    local rc2 = _rc
    _br_row "`W'/p2.dta" rule prev
    local v2 = r(num)
    * oracle: each corrupted row and the row after it fails the chained rule
    _br `=!(`rc1' == `rc2' & `rc1' == 9 & `v1' == `v2' & `v1' == 6)' "seed `seed': byrule == hand-sorted rule() (rc `rc1' vs `rc2', violations `v1' vs `v2', oracle 6)"
}
* the same rule() on the shuffled data is order-dependent: it must differ
_br_panel 1
_br_shuffle 11
capture erase "`W'/p3.dta"
capture datacheck, gatesonly rule(`RLX') ledger("`W'/p3.dta")
_br_row "`W'/p3.dta" rule prev
_br `=!(r(num) != 6)' "negative control: the unsorted rule() does not reproduce the by-sorted answer (it reads the shuffled order)"

**## Monotone with (step) only: no groups
clear
quietly set obs 200
quietly gen long step = _n
quietly gen double value = step * 3
foreach s in 20 50 90 150 {
    quietly replace value = value - 1000 if step == `s'
}
_br_shuffle 21
capture erase "`W'/m.dta"
capture datacheck, gatesonly byrule((step): "mono": _n == 1 | value >= value[_n-1]) ledger("`W'/m.dta")
local rc = _rc
_br_row "`W'/m.dta" byrule mono
_br `=!(`rc' == 9 & r(num) == 4)' "monotone with (step) only: the 4 planted drops are flagged"
* oracle: sort by hand and count
sort step
quietly count if step > 1 & value < value[_n-1]
_br `=!(r(N) == 4)' "oracle: hand-sorted count of drops is 4"
quietly replace value = step * 3
_br_shuffle 22
capture datacheck, gatesonly byrule((step): "mono": _n == 1 | value >= value[_n-1])
_br `=!(_rc == 0)' "monotone series passes in a shuffled order"

**## The caller's data and sort order are untouched
_br_panel 1
_br_shuffle 31
quietly gen long rid = _n
quietly datasignature
local sig0 = r(datasignature)
local sb0 : sortedby
capture datacheck, gatesonly byrule(`DN')
local rc = _rc
quietly datasignature
local sig1 "`r(datasignature)'"
local sb1 : sortedby
quietly count if rid != _n
local nmoved = r(N)
_br `=!(`rc' == 9 & "`sig1'" == "`sig0'")' "data byte-identical after byrule (datasignature equal, rc 9)"
_br `=!(`nmoved' == 0 & "`sb1'" == "`sb0'")' "no row moved (saved row id still in order); sortedby unchanged"
sort id dose_date
local sb0 : sortedby
quietly datasignature
local sig0 = r(datasignature)
capture datacheck, gatesonly byrule(`DN' \ id (k): "k": k == _n)
quietly datasignature
local sb1 : sortedby
_br `=!("`sb1'" == "`sb0'" & "`r(datasignature)'" == "`sig0'")' "a sorted caller keeps its sortedby (`sb1') and signature"

**## Ties: the note, and stable order
_br_panel 0
quietly replace dose_date = dose_date[_n-1] if k == 3 & id == 5
quietly replace dose_date = dose_date[_n-1] if k == 3 & id == 5
quietly replace dose_date = dose_date[_n-1] if k == 4 & id == 5
local note "does not uniquely order the rows"
quietly log using "`W'/t1.log", text replace name(t1)
capture noisily datacheck, gatesonly byrule(`DN')
quietly log close t1
_br_count "`W'/t1.log" "`note'"
_br `=!(r(n) == 1)' "tied (id dose_date) with _n in the expression prints the ties note once"
_br_count "`W'/t1.log" "byrule(dn)"
_br `=!(r(n) >= 1)' "the note names the rule"
quietly log using "`W'/t2.log", text replace name(t2)
capture noisily datacheck, gatesonly byrule(id (dose_date): "lvl": dose_date >= 0)
quietly log close t2
_br_count "`W'/t2.log" "`note'"
_br `=!(r(n) == 0)' "ties with an expression that does not use _n, _N or a subscript: no note"
_br_panel 0
quietly log using "`W'/t3.log", text replace name(t3)
capture noisily datacheck, gatesonly byrule(`DN')
quietly log close t3
_br_count "`W'/t3.log" "`note'"
_br `=!(r(n) == 0)' "unique (id dose_date): no note"
quietly log using "`W'/t4.log", text replace name(t4)
capture noisily datacheck, gatesonly maskrare byrule(id (dose_date): "dn": dose_num == _n)
quietly log close t4
_br_count "`W'/t4.log" "`note'"
_br `=!(r(n) == 0)' "no-tie data under maskrare: no note"
* ties keep the caller's order (stable sort): two rows tied on the sort key
clear
input byte id double t byte v
1 5 1
1 5 2
2 7 1
2 7 2
end
capture datacheck, gatesonly byrule(id (t): "o": v == _n)
local rc_a = _rc
quietly gen byte o = -_n
sort o
quietly drop o
capture datacheck, gatesonly byrule(id (t): "o": v == _n)
local rc_b = _rc
_br `=!(`rc_a' == 0 & `rc_b' == 9)' "ties keep the caller's order: v 1,2 passes, the reversed order fails (rc `rc_a' / `rc_b')"

**## Missing byvars, string byvar, if scope, empty scope
clear
input byte id byte t byte v
. 1 1
. 2 2
. 3 3
1 1 1
1 2 2
end
capture datacheck, gatesonly byrule(id (t): "m": v == _n)
_br `=!(_rc == 0)' "missing byvar rows form their own group (v == _n holds in it): pass"
quietly replace v = 3 in 2
capture erase "`W'/ms.dta"
capture datacheck, gatesonly byrule(id (t): "m": v == _n) ledger("`W'/ms.dta")
_br_row "`W'/ms.dta" byrule m
_br `=!(_rc == 9 & r(num) == 1)' "missing-id group: one planted row flagged"
_br_panel 1
quietly gen str6 sid = "s" + string(id)
_br_shuffle 41
capture erase "`W'/s.dta"
capture datacheck, gatesonly byrule(sid (dose_date): "dn": dose_num == _n) ledger("`W'/s.dta")
_br_row "`W'/s.dta" byrule dn
_br `=!(_rc == 9 & r(num) == 3)' "string byvar: the 3 planted rows flagged"
clear
input byte id byte t byte v
1 1 1
1 2 2
1 3 3
end
capture erase "`W'/if.dta"
capture datacheck if v != 2, gatesonly byrule(id (t): "pos": v == _n) ledger("`W'/if.dta")
_br_row "`W'/if.dta" byrule pos
_br `=!(_rc == 9 & r(num) == 1)' "if scope: _n counts in-scope rows (rows 1,3 -> _n 1,2; v 1,3 -> 1 violation)"
capture datacheck if v > 100, gatesonly byrule(id (t): "pos": v == _n)
_br `=!(_rc == 2000)' "empty scope: r(2000), as for rule()"

**## Parse errors and bad inputs
local B1 `"id (t) "x": v == 1"'
local B2 `"(t) id: "x": v == 1"'
local B3 `"id (): "x": v == 1"'
local B4 `": "x": v == 1"'
local B5 `"id (t): : v == 1"'
local B6 `"id (t): "x""'
local B7 `"id (t) id (t): "x": v == 1"'
local B8 `"id t) : "x": v == 1"'
clear
input byte id byte t byte v
1 1 1
end
forvalues i = 1/8 {
    capture datacheck, gatesonly byrule(`B`i'')
    _br `=!(_rc == 198)' "parse error is r(198): form `i' (rc `=_rc')"
}
capture datacheck, gatesonly byrule(nosuch (t): "x": v == 1)
_br `=!(_rc == 111)' "unknown byvar: r(111)"
capture datacheck, gatesonly byrule(id (t): "x": nosuchvar == 1)
_br `=!(_rc == 111)' "expression that cannot be evaluated is an error, not a violation (rc 111)"

**## Integration: ledger, checks(), violations(), by(), maskrare, gatesonly
_br_panel 1
_br_shuffle 51
capture erase "`W'/i.dta"
capture datacheck, gatesonly warn byrule(`DN' \ `ND') ledger("`W'/i.dta") violations(brv)
_br `=!(_rc == 0 & r(n_checks) == 1 & r(n_failed) == 1 & r(n_passed) == 0 & r(n_violations) == 2)' "warn: one byrule family failed, 2 entries violated"
_br_row "`W'/i.dta" byrule dn
_br `=!("`r(kind)'" == "invariant" & "`r(st)'" == "warn" & r(n) == 1)' "ledger row: family byrule, kind invariant"
frame brv: quietly count if check == "byrule"
local nv = r(N)
frame brv: quietly count if check == "byrule" & inlist(variable, "dn", "nd")
_br `=!(`nv' == 2 & r(N) == 2)' "violations() frame holds both byrule entries, labelled"
capture frame drop brv

* checks() row: var = label, values = byspec, pattern = expression
preserve
clear
quietly set obs 2
quietly gen str20 gate = "byrule"
quietly gen str20 var = cond(_n == 1, "dn", "nd")
quietly gen str30 values = "id (dose_date)"
quietly gen str100 pattern = cond(_n == 1, "dose_num == _n", "_n == _N | next_dose == dose_date[_n+1]")
quietly save "`W'/chk.dta", replace
quietly replace values = "" in 2
quietly save "`W'/chk_bad.dta", replace
restore
capture erase "`W'/c.dta"
capture datacheck, gatesonly checks("`W'/chk.dta") ledger("`W'/c.dta")
local rcc = _rc
_br_row "`W'/c.dta" byrule dn
local c1 = r(num)
_br_row "`W'/c.dta" byrule nd
_br `=!(`rcc' == 9 & `c1' == 3 & r(num) == 2)' "checks() byrule rows give the option's verdicts (3 and 2 planted rows)"
capture datacheck, gatesonly checks("`W'/chk_bad.dta")
_br `=!(_rc == 198)' "checks() byrule row without a by spec: r(198)"

* by(): groups tally the same indicator, as rule() does
_br_panel 1
quietly gen str1 site = cond(id <= 8, "A", cond(id <= 20, "B", "C"))
_br_shuffle 52
capture erase "`W'/by.dta"
capture datacheck, gatesonly by(site) byrule(`DN') ledger("`W'/by.dta")
_br_row "`W'/by.dta" byrule dn
* ids 3 and 7 sit in site A, id 11 in site B, none in C
_br `=!(_rc == 9 & r(n) == 3 & r(num) == 3)' "by(site): 3 group rows, summed violations 3"
preserve
use "`W'/by.dta", clear
quietly keep if family == "byrule" & status == "fail"
local nfail = _N
restore
_br `=!(`nfail' == 2)' "by(site): exactly sites A and B fail"

* maskrare: the byrule count is masked like a rule() count
_br_panel 1
_br_shuffle 53
capture erase "`W'/k1.dta"
capture datacheck, gatesonly maskrare byrule(`DN') ledger("`W'/k1.dta")
local rck = _rc
_br_row "`W'/k1.dta" byrule dn
local ob1 "`r(obs)'"
local nm = r(num)
sort id dose_date
capture erase "`W'/k2.dta"
capture datacheck, gatesonly maskrare rule("dn": dose_num == k) ledger("`W'/k2.dta")
_br_row "`W'/k2.dta" rule dn
_br `=!(`rck' == 9 & "`ob1'" == "<5 fail" & "`r(obs)'" == "<5 fail" & missing(`nm'))' "maskrare: 3 planted rows print as '<5 fail' (`ob1'), observed_num missing, same text as rule()"
preserve
use "`W'/k1.dta", clear
quietly keep if family == "byrule"
quietly count if regexm(message, "[ (]3 obs") | regexm(observed, "3")
local leak = r(N)
restore
_br `=!(`leak' == 0)' "maskrare: the digit 3 appears in neither message nor observed"
_br_panel 1
_br_shuffle 54
capture datacheck, warn byrule(`DN') ledger("`W'/pm.dta", run(pm))
local rcp = _rc
capture datacheck, gatesonly warn byrule(`DN') ledger("`W'/go.dta", run(go))
local rcg = _rc
_br_row "`W'/pm.dta" byrule dn
local a1 = r(num)
_br_row "`W'/go.dta" byrule dn
_br `=!(`rcp' == `rcg' & `a1' == r(num) & `a1' == 3)' "profile mode and gatesonly give the same byrule verdict and count"

**## R5: note on subscripted rule()/review() with no sort order
local rn "had no sort order at entry"
local rs "was sorted by"
_br_panel 0
quietly log using "`W'/r1.log", text replace name(r1)
capture noisily datacheck, gatesonly rule("prev": id != id[_n-1] | dose_date > dose_date[_n-1])
quietly log close r1
_br_count "`W'/r1.log" "`rn'"
_br `=!(r(n) == 1)' "R5: subscripted rule() on data with no sort order: note"
_br_count "`W'/r1.log" "byrule()"
_br `=!(r(n) >= 1)' "R5: the note points to byrule()"
quietly log using "`W'/r2.log", text replace name(r2)
capture noisily datacheck, gatesonly review("prev": id == id[_n-1] & dose_date <= dose_date[_n-1])
quietly log close r2
_br_count "`W'/r2.log" "review(prev)"
_br `=!(r(n) >= 1)' "R5: review() gets the note, naming it"
quietly log using "`W'/r3.log", text replace name(r3)
capture noisily datacheck, gatesonly rule("pos": dose_num >= 1) review("c": dose_num == _N)
quietly log close r3
_br_count "`W'/r3.log" "`rn'"
_br `=!(r(n) == 1)' "R5: _N in a review() with no sort order notes; the plain rule() does not"
quietly log using "`W'/r4.log", text replace name(r4)
capture noisily datacheck, gatesonly rule("re": regexm(string(id), "[0-9]") & dose_num >= 1)
quietly log close r4
_br_count "`W'/r4.log" "`rn'"
_br `=!(r(n) == 0)' "R5: a bracket inside a regex string is not a subscript: no note"
* sorted by a variable that is subscripted: no note
sort id dose_date
quietly log using "`W'/r5.log", text replace name(r5)
capture noisily datacheck, gatesonly rule("prev": id != id[_n-1] | dose_date > dose_date[_n-1])
quietly log close r5
_br_count "`W'/r5.log" "note:"
_br `=!(r(n) == 0)' "R5: sorted by the subscripted variable: no note"
* sorted by something else
sort k
quietly log using "`W'/r6.log", text replace name(r6)
capture noisily datacheck, gatesonly rule("prev": id != id[_n-1] | dose_date > dose_date[_n-1])
quietly log close r6
_br_count "`W'/r6.log" "`rs' k"
_br `=!(r(n) == 1)' "R5: sorted by k only, subscripting id and dose_date: note says so"
* _n alone, data sorted: no variable to compare, no note
sort id dose_date
quietly log using "`W'/r7.log", text replace name(r7)
capture noisily datacheck, gatesonly rule("p": _n >= 1)
quietly log close r7
_br_count "`W'/r7.log" "note:"
_br `=!(r(n) == 0)' "R5: _n only on sorted data: no note"
* verdicts identical with and without the note (same rows, same order)
_br_panel 1
capture erase "`W'/v1.dta"
quietly log using "`W'/v1.log", text replace name(v1)
capture noisily datacheck, gatesonly rule("prev": dose_num == cond(id == id[_n-1], dose_num[_n-1] + 1, 1)) ledger("`W'/v1.dta")
quietly log close v1
local rcv1 = _rc
_br_count "`W'/v1.log" "`rn'"
local fired = r(n)
_br_row "`W'/v1.dta" rule prev
local nv1 = r(num)
sort id dose_date
capture erase "`W'/v2.dta"
quietly log using "`W'/v2.log", text replace name(v2)
capture noisily datacheck, gatesonly rule("prev": dose_num == cond(id == id[_n-1], dose_num[_n-1] + 1, 1)) ledger("`W'/v2.dta")
quietly log close v2
local rcv2 = _rc
_br_count "`W'/v2.log" "note:"
local quiet = r(n)
_br_row "`W'/v2.dta" rule prev
_br `=!(`fired' == 1 & `quiet' == 0 & `rcv1' == `rcv2' & `rcv1' == 9 & `nv1' == r(num) & `nv1' == 6)' "R5: same data with and without the note: same rc 9, same 6 violations"

**## D4: idiom pairs give the same verdict on planted data
* 1. rule("flow": _N == n) and expectn(n)
foreach n in 74 73 {
    sysuse auto, clear
    quietly drop if _n > `n'
    capture datacheck, gatesonly rule("flow": _N == 74)
    local ra = _rc
    capture datacheck, gatesonly expectn(74)
    _br `=!(`ra' == _rc & `ra' == cond(`n' == 74, 0, 9))' "idiom flow: N=`n': rule _N == 74 and expectn(74) agree (rc `ra' / `=_rc')"
}
* 2. flag + stat(mean) and coverage(tail): 1000 days in window plus 50 or 200 outside
foreach nout in 50 200 {
    clear
    quietly set obs `=1000 + `nout''
    quietly gen double dt = mdy(1,1,2019) + _n - 1
    format dt %td
    local lo = mdy(1,1,2019)
    local hi = `lo' + 999
    quietly gen byte outside = dt < `lo' | dt > `hi'
    capture datacheck, gatesonly stat(mean outside 0 0.1)
    local ra = _rc
    capture datacheck, gatesonly coverage(dt `lo' `hi', gap(none) tail(0.1))
    _br `=!(`ra' == _rc & `ra' == cond(`nout' == 50, 0, 9))' "idiom egen flag: `nout' outside dates: stat(mean flag) and coverage(tail) agree (rc `ra' / `=_rc')"
}
* 3. bysort egen median + review, and groupstat(band relative)
foreach plant in 0 1 {
    clear
    quietly set obs 100
    quietly gen byte g = ceil(_n / 25)
    quietly gen double x = 10 + mod(_n, 5)
    if `plant' quietly replace x = x * 100 if g == 3
    quietly bysort g: egen double gm = median(x)
    quietly egen double pm = median(x)
    capture erase "`W'/g1.dta"
    capture datacheck, gatesonly review("jump": gm / pm < 0.05 | gm / pm > 20) ledger("`W'/g1.dta")
    _br_row "`W'/g1.dta" review jump
    local rv = (r(num) > 0)
    quietly drop gm pm
    capture datacheck, gatesonly groupstat(median x, by(g) band(0.05 20) relative)
    _br `=!(`rv' == `plant' & (_rc == 9) == `plant')' "idiom median review: planted=`plant': review count>0 is `rv', groupstat rc `=_rc'"
}
* 4. one stat() ... if per group label, and stat() with by()
foreach plant in 0 1 {
    clear
    quietly set obs 40
    quietly gen byte a = 1 + (_n > 20)
    quietly gen byte b = 1 + mod(floor((_n - 1) / 10), 2)
    quietly gen double x = 10 + cond(mod(_n, 2), 1, -1)
    if `plant' quietly replace x = x + 5 if a == 2 & b == 1
    capture datacheck, gatesonly stat(mean x 9 11 if a == 1 & b == 1 \ mean x 9 11 if a == 1 & b == 2 \ mean x 9 11 if a == 2 & b == 1 \ mean x 9 11 if a == 2 & b == 2)
    local ra = _rc
    capture datacheck, gatesonly by(a b) stat(mean x 9 11)
    _br `=!(`ra' == _rc & `ra' == cond(`plant', 9, 0))' "idiom group labels: planted=`plant': per-group stat if and stat by(a b) agree (rc `ra' / `=_rc')"
}
* 5. subscripted rule on sorted data and byrule: covered by the parity block above

* tidy
foreach f in a p1 p2 p3 m i c by k1 k2 pm go ms s if g1 v1 v2 chk chk_bad {
    capture erase "`W'/`f'.dta"
}
foreach f in t1 t2 t3 t4 r1 r2 r3 r4 r5 r6 r7 v1 v2 {
    capture erase "`W'/`f'.log"
}
capture rmdir "`W'"

display as text _newline "RESULT: test_datacheck_v190_byrule tests=$TC pass=$PASS fail=$FAIL"
if $FAIL > 0 exit 1
