clear all
set more off
version 16.0
set linesize 255

* test_datamap_v193.do - regressions for the 1.9.3 fixes.
* F1 range bounds are carried exactly: a makespec() spec passes its own data,
*    and a bound written at full precision is the bound tested
* F2 groupstat() count and pmiss cells follow the stat() complement rule;
*    a pooled pmiss beside a masked group is withheld
* F3 datamap missing(pattern): the complete-data line follows the mask of
*    the all-observed pattern
* F4 dataqa refuses a ledger row whose status is not one the writers use
* F5 datamvp graph(patterns) with user variables patid and patorder
* F6 datamap DESCRIPTION compares %th and %ty dates within their own family
* F7 dataqa assert baseline() with a dataset name holding a space
* F8 datamap detect(binary) obeys nofreq
* Oracles: hand-computed counts and shares, exact decimal literals, the
* masked/unmasked pair of each privacy case (the small count must not appear
* masked and must appear unmasked).

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
capture program drop _cv
program define _cv
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

local W "`c(tmpdir)'/v193"
capture mkdir "`W'"

* count lines of a text file holding a needle
capture program drop _v3_count
program define _v3_count, rclass
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

* the cell text of one group row in a logged GROUPSTAT table: the line that
* starts with two spaces and the group label
capture program drop _v3_row
program define _v3_row, rclass
    args file label
    tempname fh
    local row ""
    file open `fh' using `"`file'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if regexm(`"`macval(line)'"', "^  `label'  ") local row `"`macval(line)'"'
        file read `fh' line
    }
    file close `fh'
    return local row `"`row'"'
end

**# F1 exact range bounds
* makespec() writes the observed min and max at full precision; before 1.9.3
* checks() read them back through a 16-digit macro and failed its own data
clear
set seed 12345
quietly set obs 200
generate double y = runiform()
local S1 "`W'/spec1.dta"
capture erase "`S1'"
quietly dataprobe y, makespec("`S1'", replace)
capture noisily dataprobe y, checks("`S1'") gatesonly
_cv `=_rc' "F1 a makespec() spec passes checks() on its own data"
* the spec bound is the observed extreme, not a rounded neighbour
preserve
quietly use "`S1'", clear
quietly keep if check == "inrange" & var == "y"
local a2 = arg2[1]
restore
quietly summarize y
tempname ymax
scalar `ymax' = r(max)
_cv `=!(real("`a2'") == scalar(`ymax'))' "F1 the spec upper bound reads back as the observed max"
* a value one ulp above the bound still fails: the gate is not loosened
preserve
quietly replace y = scalar(`ymax') + epsdouble() * scalar(`ymax') in 1
capture noisily dataprobe y, checks("`S1'") gatesonly
local rcx = _rc
restore
_cv `=!(`rcx' == 9)' "F1 positive control: a value one ulp above the spec max fails (rc 9)"

* a bound written as .30000000000000004 is that double, not .3
clear
quietly set obs 5
generate double y = 0.1 + 0.2
capture noisily dataprobe y, gatesonly inrange(y 0 .30000000000000004)
_cv `=_rc' "F1 inrange() keeps a 17-digit upper bound exactly"
capture noisily dataprobe y, gatesonly inrange(y 0 .3)
_cv `=!(_rc == 9)' "F1 positive control: inrange(y 0 .3) fails for y = .1 + .2"
capture noisily dataprobe y, gatesonly inrange(y .30000000000000004 1)
_cv `=_rc' "F1 inrange() keeps a 17-digit lower bound exactly"
* .3 sits one ulp below that lower bound: a bound rounded to .3 would pass it
generate double y3 = .3
capture noisily dataprobe y3, gatesonly inrange(y3 .30000000000000004 1)
_cv `=!(_rc == 9)' "F1 .3 fails a lower bound of .30000000000000004 (not rounded to .3)"
capture noisily dataprobe y, gatesonly stat(mean y 0 .30000000000000004)
_cv `=_rc' "F1 stat() keeps a 17-digit upper bound exactly"
capture noisily dataprobe y, gatesonly stat(mean y 0 .3)
_cv `=!(_rc == 9)' "F1 positive control: stat(mean y 0 .3) fails for y = .1 + .2"
* the violation text still shows the bounds as the user wrote them
local L1 "`W'/led1.dta"
capture erase "`L1'"
capture noisily dataprobe y, gatesonly inrange(y 0 .1) ledger("`L1'", run(f1))
preserve
quietly use "`L1'", clear
quietly keep if family == "inrange"
local ex1 = expected[1]
local ms1 = message[1]
restore
_cv `=!("`ex1'" == "[0, .1]" & strpos(`"`ms1'"', "[0, .1]") & !strpos(`"`ms1'"', "X"))' ///
    "F1 ledger expected and message print the bounds as written, not as hex"

**# F2 groupstat complement masking
* g = 1: 30 rows, x missing in 29; g = 2: 30 rows, x nonmissing
clear
quietly set obs 60
generate g = cond(_n <= 30, 1, 2)
generate x = cond(_n <= 30 & _n > 1, ., _n)
log using "`W'/f2a.log", text replace name(_v3)
capture noisily dataprobe x, maskrare gatesonly groupstat(pmiss x, by(g))
log close _v3
_v3_row "`W'/f2a.log" "1"
local r1 `"`r(row)'"'
_v3_count "`W'/f2a.log" ".9667"
local n9667 = r(n)
_v3_count "`W'/f2a.log" ".4833"
local npool = r(n)
_cv `=!(`n9667' == 0 & strpos(`"`r1'"', "[suppr.]"))' ///
    "F2 pmiss .9667 (1 nonmissing of 30) is masked under maskrare"
_cv `=!(`npool' == 0)' "F2 the pooled pmiss beside a masked group is withheld"
log using "`W'/f2b.log", text replace name(_v3)
capture noisily dataprobe x, gatesonly groupstat(pmiss x, by(g))
log close _v3
_v3_count "`W'/f2b.log" ".9667"
local c1 = r(n)
_v3_count "`W'/f2b.log" ".4833"
_cv `=!(`c1' >= 1 & r(n) >= 1)' "F2 positive control: unmasked, pmiss .9667 and pooled .4833 print"

* g = 1: x nonmissing in 29 of 30, so n x = 29 leaves 1 behind
clear
quietly set obs 60
generate g = cond(_n <= 30, 1, 2)
generate x = cond(_n == 1, ., _n)
generate z = 1
log using "`W'/f2c.log", text replace name(_v3)
capture noisily dataprobe z x, by(g) maskrare groupstat(n x, by(g))
log close _v3
_v3_row "`W'/f2c.log" "1"
local r1 `"`r(row)'"'
_cv `=!(!regexm(`"`r1'"', " 29$") & strpos(`"`r1'"', "[suppr.]"))' ///
    "F2 n x = 29 of 30 rows is masked as a complement cell"
log using "`W'/f2d.log", text replace name(_v3)
capture noisily dataprobe x, gatesonly groupstat(n x, by(g))
log close _v3
_v3_row "`W'/f2d.log" "1"
_cv `=!regexm(`"`r(row)'"', " 29$")' "F2 positive control: unmasked, n x prints 29"
* distinct is a count too: 29 distinct values among 30 rows
log using "`W'/f2e.log", text replace name(_v3)
capture noisily dataprobe x, maskrare gatesonly groupstat(distinct x, by(g))
log close _v3
_v3_row "`W'/f2e.log" "1"
_cv `=!(!regexm(`"`r(row)'"', " 29$") & strpos(`"`r(row)'"', "[suppr.]"))' ///
    "F2 distinct x = 29 of 30 rows is masked as a complement cell"
* the multi-statistic table keeps its columns apart
log using "`W'/f2f.log", text replace name(_v3)
capture noisily dataprobe x, maskrare gatesonly groupstat(sum n: x, by(g))
log close _v3
_v3_row "`W'/f2f.log" "1"
local r1 `"`r(row)'"'
_cv `=!(regexm(`"`r1'"', " 464 +\[suppr\.\]$"))' ///
    "F2 multi-statistic row: sum shown, n masked, columns separated"
* a large count with a large complement stays shown
_v3_row "`W'/f2f.log" "2"
_cv `=!regexm(`"`r(row)'"', " 30$")' "F2 positive control: group 2 n = 30 (complement 0) prints"

**# F3 complete-data line follows the all-observed pattern mask
* patterns: ++ 20, .+ 2, +. 50; .+ is small, so ++ is complementary and the
* complete-data count (20) would give the 2 back
clear
quietly set obs 72
generate x = cond(inrange(_n, 21, 22), ., 1)
generate y = cond(_n >= 23, ., 1)
local P1 "`W'/pat1.txt"
capture erase "`P1'"
quietly datamap, output("`P1'") missing(pattern)
_v3_count "`P1'" "Observations with complete data: 20"
local nraw = r(n)
_v3_count "`P1'" "Observations with complete data: suppressed (complementary)"
local nsup = r(n)
_v3_count "`P1'" "++: suppressed (complementary)"
_cv `=!(`nraw' == 0 & `nsup' == 1 & r(n) == 1)' ///
    "F3 the complete-data count is withheld when its pattern is complementary"
local P2 "`W'/pat2.txt"
capture erase "`P2'"
quietly datamap, output("`P2'") missing(pattern) mincell(0)
_v3_count "`P2'" "Observations with complete data: 20 (27.8%)"
_cv `=!(r(n) == 1)' "F3 positive control: mincell(0) prints the complete-data count 20"
* a shown all-observed pattern leaves the line shown
clear
quietly set obs 72
generate x = cond(inrange(_n, 21, 30), ., 1)
generate y = cond(_n >= 31, ., 1)
local P3 "`W'/pat3.txt"
capture erase "`P3'"
quietly datamap, output("`P3'") missing(pattern)
_v3_count "`P3'" "Observations with complete data: 20 (27.8%)"
_cv `=!(r(n) == 1)' "F3 positive control: an unmasked pattern table keeps the count"

* layouts with more than ten patterns: pattern k of the list (from 0) has v_b
* missing where bit b of k is set, so the first count is the all-observed one
capture program drop _v3_patdata
program define _v3_patdata
    clear
    local p = 0
    tempfile t
    foreach c of local 0 {
        preserve
        clear
        quietly set obs `c'
        forvalues b = 1/4 {
            quietly generate double v`b' = cond(mod(floor(`p' / 2^(`b' - 1)), 2) == 1, ., 1)
        }
        if `p' > 0 quietly append using "`t'"
        quietly save "`t'", replace
        restore
        local ++p
    }
    quietly use "`t'", clear
end
* (a) the all-observed pattern (20) ranks beyond the printed ten, beside a
* hidden pattern of 2: N 277 - shown 255 - complete 20 would give the 2 back
_v3_patdata 20 30 29 28 27 26 25 24 23 22 21 2
local P4 "`W'/pat4.txt"
capture erase "`P4'"
quietly datamap, output("`P4'") missing(pattern) mincell(5)
_v3_count "`P4'" "Observations with complete data: 20"
local nraw = r(n)
_v3_count "`P4'" "Observations with complete data: suppressed (complementary)"
local nsup = r(n)
_v3_count "`P4'" "2 more pattern(s) not shown"
_cv `=!(`nraw' == 0 & `nsup' == 1 & r(n) == 1)' ///
    "F3 an all-observed pattern beyond the top ten is withheld beside a small hidden one"
* (b) the all-observed pattern (20) is the smallest of the ten shown and the
* one hidden pattern has 2 rows
_v3_patdata 20 30 29 28 27 26 25 24 23 22 2
local P5 "`W'/pat5.txt"
capture erase "`P5'"
quietly datamap, output("`P5'") missing(pattern) mincell(5)
_v3_count "`P5'" "Observations with complete data: 20"
local nraw = r(n)
_v3_count "`P5'" "Observations with complete data: suppressed (complementary)"
local nsup = r(n)
_v3_count "`P5'" "++++: suppressed (complementary)"
_cv `=!(`nraw' == 0 & `nsup' == 1 & r(n) == 1)' ///
    "F3 a shown all-observed pattern withheld as the complement of a small hidden one"
* positive control: a large all-observed pattern prints; the smallest other
* shown pattern (22) is the complement, so N - shown - complete is 24, not 2
_v3_patdata 100 30 29 28 27 26 25 24 23 22 2
local P6 "`W'/pat6.txt"
capture erase "`P6'"
quietly datamap, output("`P6'") missing(pattern) mincell(5)
_v3_count "`P6'" "Observations with complete data: 100 ("
local nraw = r(n)
_v3_count "`P6'" ": 22 ("
_cv `=!(`nraw' == 1 & r(n) == 0)' ///
    "F3 positive control: complete-data count prints; the hidden remainder stays pooled"

**# F4 dataqa refuses an unrecognised ledger status
sysuse auto, clear
local L4 "`W'/led4.dta"
capture erase "`L4'"
quietly dataprobe price mpg, gatesonly isid(make) ledger("`L4'", run(r1))
capture noisily dataqa assert using "`L4'", run(r1)
_cv `=_rc' "F4 positive control: an untouched ledger passes assert"
preserve
quietly use "`L4'", clear
quietly replace status = "bogus"
quietly save "`W'/led4bad.dta", replace
quietly replace status = ""
quietly save "`W'/led4empty.dta", replace
restore
capture noisily dataqa assert using "`W'/led4bad.dta", run(r1)
_cv `=!(_rc == 610)' "F4 assert refuses status bogus with rc 610"
capture noisily dataqa assert using "`W'/led4empty.dta", run(r1)
_cv `=!(_rc == 610)' "F4 assert refuses an empty status with rc 610"
capture noisily dataqa report using "`W'/led4bad.dta", run(r1)
_cv `=!(_rc == 610)' "F4 report refuses status bogus with rc 610"

**# F5 datamvp graph(patterns) beside user patid and patorder
clear
quietly set obs 50
generate patid = _n
generate patorder = 100 + _n
generate x1 = cond(mod(_n, 3) == 0, ., 1)
generate x2 = cond(mod(_n, 5) == 0, ., 1)
capture noisily datamvp x1 x2, graph(patterns) nodraw notable nosummary
local rc5 = _rc
quietly count if patid == _n & patorder == 100 + _n
_cv `=!(`rc5' == 0 & r(N) == 50 & _N == 50)' ///
    "F5 graph(patterns) runs with user patid/patorder and leaves them intact"

**# F6 date span compares one date family
clear
quietly set obs 20
generate h = th(2000h2) + _n - 1
format h %th
generate y = 1990 + _n
format y %ty
local P6 "`W'/span.txt"
capture erase "`P6'"
quietly datamap, output("`P6'")
_v3_count "`P6'" "The data spans from 2000h2 to 2010h1."
local ok6 = r(n)
_v3_count "`P6'" "2965"
_cv `=!(`ok6' == 1 & r(n) == 0)' "F6 %th and %ty are not mixed in the date span"

**# F7 dataqa assert baseline with a dataset name holding a space
tempfile led7
quietly dataqa set ledger("`led7'") run(A)
sysuse auto, clear
quietly dataprobe, gatesonly isid(make) name(b c)
quietly dataqa set ledger("`led7'") run(B) baseline(A)
quietly dataprobe, gatesonly isid(make) name(b c)
capture noisily dataqa assert, run(B)
local rc7 = _rc
macro drop DATAMAP_DQ
_cv `rc7' "F7 a baseline dataset named 'b c' present in both runs passes assert"
* the dataset really is absent: still caught
tempfile led7b
quietly dataqa set ledger("`led7b'") run(A)
quietly dataprobe, gatesonly isid(make) name(b c)
quietly dataqa set ledger("`led7b'") run(B) baseline(A)
quietly dataprobe, gatesonly isid(make) name(d e)
capture noisily dataqa assert, run(B)
local rc7b = _rc
macro drop DATAMAP_DQ
_cv `=!(`rc7b' == 9)' "F7 positive control: dataset 'b c' absent from the run fails (rc 9)"

**# F8 detect(binary) obeys nofreq
sysuse auto, clear
local P8 "`W'/bin1.txt"
capture erase "`P8'"
quietly datamap, output("`P8'") detect(binary) nofreq
_v3_count "`P8'" "Binary Variables"
local nsec = r(n)
_v3_count "`P8'" "  Frequency:"
_cv `=!(`nsec' == 1 & r(n) == 0)' "F8 nofreq drops the binary frequency block"
local P8b "`W'/bin2.txt"
capture erase "`P8b'"
quietly datamap, output("`P8b'") detect(binary)
_v3_count "`P8b'" "  Frequency:"
_cv `=!(r(n) >= 1)' "F8 positive control: without nofreq the binary frequency block prints"

* tidy
local files : dir "`W'" files "*"
foreach f of local files {
    capture erase "`W'/`f'"
}
capture rmdir "`W'"

display as text _newline "RESULT: test_datamap_v193 tests=$TC pass=$PASS fail=$FAIL"
if $FAIL > 0 exit 1
