clear all
set more off
version 16.0
set linesize 255

* test_datamap_v190_review.do - regressions for the independent review of 1.9.0.
* R1  groupstat direction rows under maskrare must not pin withheld small groups
* R2  dataqa assert optional()/expect() take compound-quoted names with spaces
* R3a smallcells() refuses a threshold below 2
* R3b a float by() value reads as a short exact decimal in the ledger text
* Oracles: count if for group sizes, hand-written values, round trip by
* float()/real(), and the dataqa compare pairing of two runs.

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

local W "`c(tmpdir)'/rv190"
capture mkdir "`W'"

* count lines of a text file holding a needle
capture program drop _rv_count
program define _rv_count, rclass
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

* the failing groupstat ledger rows: all observed and message text joined
capture program drop _rv_ledtext
program define _rv_ledtext, rclass
    args file
    preserve
    quietly use `"`file'"', clear
    quietly keep if family == "groupstat" & status == "fail"
    local all ""
    forvalues j = 1/`=_N' {
        local all `"`all' | `=observed[`j']' | `=message[`j']'"'
    }
    return scalar n = _N
    return local txt `"`all'"'
    restore
end

* reproducer data: groups a(30) b(6) c(6) d(6) e(8); b and c fail above the band
capture program drop _rv_data
program define _rv_data
    clear
    quietly set obs 56
    generate str1 g = cond(_n<=30,"a",cond(_n<=36,"b",cond(_n<=42,"c",cond(_n<=48,"d","e"))))
    generate x = 10
    quietly replace x = 100 if inlist(g,"b","c")
    quietly replace x = -50 if g=="d"
    quietly replace g = "d" in 47/48
    quietly replace x = 100 in 47/48
end

**# R1 direction rows under maskrare
_rv_data
quietly count if inlist(g, "b", "c")
local rbc = r(N)
quietly count if g == "d" & x == 100
local rd = r(N)
_cv `=!(`rbc' == 12 & `rd' == 2)' "R1 setup: groups b and c hold 12 rows"
capture erase "`W'/r1.dta"
capture log close _rv
log using "`W'/r1.log", text replace name(_rv)
capture noisily datacheck, gatesonly groupstat(mean x, by(g) band(0 50) min(1)) maskrare mincell(7) ledger("`W'/r1.dta")
local rc1 = _rc
log close _rv
_cv `=!(`rc1' == 9)' "R1 the band fails, exit 9"
_rv_count "`W'/r1.log" "rows 12"
_cv `=!(r(n) == 0)' "R1 console never prints the unmasked row total 12 of two small groups"
_rv_count "`W'/r1.log" "groups above (rows [suppressed])"
_cv `=!(r(n) >= 1)' "R1 console shows the withheld direction as [suppressed]"
_rv_ledtext "`W'/r1.dta"
_cv `=!(r(n) == 2)' "R1 ledger has a failing row per failing group"
local lt `"`r(txt)'"'
_cv `=!(strpos(`"`lt'"', "rows 12") == 0 & strpos(`"`lt'"', "rows [suppressed]") > 0)' "R1 ledger observed and message text withhold the total"
* other digits that a leak could take: either group alone, or the complement
foreach bad in "rows 6" "rows 44" "rows 14" "rows 8)" {
    _cv `=!(strpos(`"`lt'"', "`bad'") == 0)' "R1 ledger text has no `bad'"
}

* control: every contributing group at or above the mask keeps its rows
clear
quietly set obs 50
generate str1 g = cond(_n<=30,"a",cond(_n<=40,"b","c"))
generate x = cond(g == "a", 10, 100)
quietly count if g != "a"
local rbig = r(N)
capture erase "`W'/r1c.dta"
capture log close _rv
log using "`W'/r1c.log", text replace name(_rv)
capture noisily datacheck, gatesonly groupstat(mean x, by(g) band(0 50) min(1)) maskrare mincell(7) ledger("`W'/r1c.dta")
log close _rv
_rv_count "`W'/r1c.log" "2 groups above (rows `rbig')"
_cv `=!(`rbig' == 20 & r(n) >= 1)' "R1 control: two groups of 10 rows each show rows 20"
_rv_ledtext "`W'/r1c.dta"
_cv `=!(strpos(`"`r(txt)'"', "rows 20") > 0)' "R1 control: ledger keeps rows 20"

* mixed: a below-mask group above the band, a large group below it, nothing
* passing; the large group's rows alone would give the small one back
clear
quietly set obs 15
generate str1 g = cond(_n<=6, "b", "f")
generate x = cond(g == "b", 100, -100)
capture log close _rv
capture erase "`W'/r1m.dta"
log using "`W'/r1m.log", text replace name(_rv)
capture noisily datacheck, gatesonly groupstat(mean x, by(g) band(0 50) min(1)) maskrare mincell(7) ledger("`W'/r1m.dta")
log close _rv
_rv_count "`W'/r1m.log" "rows 9)"
_cv `=!(r(n) == 0)' "R1 mixed: the large direction's rows would recover the small group"
_rv_count "`W'/r1m.log" "rows 6)"
_cv `=!(r(n) == 0)' "R1 mixed: the small group's rows are not printed"

**# R2 dataqa assert optional() and expect() with a space in a dataset name
local L "`W'/r2.dta"
capture erase "`L'"
clear
quietly set obs 10
generate long id = _n
quietly datacheck, gatesonly isid(id) name(`"b c"') ledger("`L'", run(b0))
quietly datacheck, gatesonly isid(id) name(d) ledger("`L'", run(b0))
quietly datacheck, gatesonly isid(id) name(d) ledger("`L'", run(r1))
quietly datacheck, gatesonly isid(id) name(`"b c"') ledger("`L'", run(r2))
quietly datacheck, gatesonly isid(id) name(d) ledger("`L'", run(r2))
capture quietly dataqa assert using "`L'", run(r1) baseline(b0)
_cv `=!(_rc == 9)' "R2 a baseline dataset with a space that vanished halts"
capture quietly dataqa assert using "`L'", run(r1) baseline(b0) optional(`"b c"')
_cv `=!(_rc == 0)' "R2 a compound-quoted optional name waives it"
capture quietly dataqa assert using "`L'", run(r1) baseline(b0) optional(`"b c"' d)
_cv `=!(_rc == 0)' "R2 a quoted name beside a plain one in optional()"
capture quietly dataqa assert using "`L'", run(r1) baseline(b0) optional(b c)
_cv `=!(_rc == 9)' "R2 optional(b c) is two names and does not waive b c"
capture quietly dataqa assert using "`L'", run(r1) baseline(b0) optional(`"other name"')
_cv `=!(_rc == 9)' "R2 optional() of another name does not waive b c"
capture quietly dataqa assert using "`L'", run(r2) expect(`"b c"' d)
_cv `=!(_rc == 0)' "R2 expect() with a quoted name finds both datasets"
capture quietly dataqa assert using "`L'", run(r1) expect(`"b c"' d)
local rcx = _rc
local mx `"`r(missing)'"'
_cv `=!(`rcx' == 9)' "R2 expect() of a quoted name absent from the run halts"
capture quietly dataqa assert using "`L'", run(r1) expect(d)
_cv `=!(_rc == 0)' "R2 expect(d) plain name still works"
capture quietly dataqa assert using "`L'", run(r1) expect(nosuch)
_cv `=!(_rc == 9)' "R2 expect() of an absent plain name halts"

**# R3a smallcells() threshold
clear
quietly set obs 4
generate double n1 = 0
foreach t in "mincell(1)" "mincell(0)" "maskrare rare(1)" "maskrare mincell(1)" {
    capture quietly datacheck, gatesonly smallcells(n1) `t'
    _cv `=!(_rc == 198)' "R3a smallcells() with `t' is refused, rc 198"
}
capture quietly datacheck, gatesonly smallcells(n1)
_cv `=!(_rc == 198)' "R3a smallcells() with no threshold, rc 198"
capture quietly datacheck, gatesonly smallcells(n1) mincell(2)
_cv `=!(_rc == 0)' "R3a mincell(2) is the smallest accepted threshold"
replace n1 = 1 in 1
capture quietly datacheck, gatesonly smallcells(n1) mincell(2)
_cv `=!(_rc == 9)' "R3a mincell(2): a count of 1 fails"
capture quietly datacheck, gatesonly smallcells(n1) maskrare rare(2)
_cv `=!(_rc == 9)' "R3a maskrare rare(2): a count of 1 fails"

**# R3b float by() values in the ledger text
* a float value is written as a short decimal that reads back exactly
clear
quietly set obs 400
generate float f = cond(_n <= 100, 0.1, cond(_n <= 200, 0.2, cond(_n <= 300, 1, 2)))
generate double dd = cond(_n <= 200, 1/3, 2/3)
generate int ii = cond(_n <= 200, 2015, 2016)
generate double dm = cond(_n <= 200, -1.5, .a)
generate long id = _n
tempvar gg
quietly egen long `gg' = group(f), missing
quietly _datacheck_gtext f, group(`gg')
_cv `=!(r(G) == 4)' "R3b four float groups"
local ok = 1
local nx = 0
local vals "0.1 0.2 1 2"
forvalues k = 1/4 {
    local led `"`r(led`k')'"'
    local s = substr(`"`led'"', strpos(`"`led'"', "=") + 1, .)
    local v : word `k' of `vals'
    if float(real("`s'")) != float(`v') local ok = 0
    if strpos(`"`led'"', "X") local nx = `nx' + 1
}
_cv `=!(`ok' == 1 & `nx' == 0)' "R3b float 0.1 0.2 1 2 read back with float(real(s)) and no hex"
_cv `=!(`"`r(led1)'"' == "f=.1" & `"`r(led2)'"' == "f=.2" & `"`r(led3)'"' == "f=1" & `"`r(led4)'"' == "f=2")' "R3b float texts are f=.1 f=.2 f=1 f=2"
_cv `=!(`"`r(disp1)'"' == ".1")' "R3b the display form is the same short text"
quietly egen long `gg'2 = group(dd), missing
quietly _datacheck_gtext dd, group(`gg'2)
local s1 = substr(`"`r(led1)'"', 4, .)
local s2 = substr(`"`r(led2)'"', 4, .)
_cv `=!(real("`s1'") == 1/3 & real("`s2'") == 2/3 & strpos(`"`r(led1)'`r(led2)'"', "X") == 0)' "R3b double 1/3 and 2/3 round-trip exactly, no hex"
quietly egen long `gg'3 = group(ii dm), missing
quietly _datacheck_gtext ii dm, group(`gg'3)
_cv `=!(`"`r(led1)'"' == "ii=2015 dm=-1.5" & `"`r(led2)'"' == "ii=2016 dm=.a")' "R3b integer, short decimal and extended missing keep their text"
* a random battery: every float and double value round-trips and none is hex
clear
set seed 190
quietly set obs 300
generate float fr = runiform()
generate double dr = runiform() * 1000
generate long k = _n
local bad = 0
forvalues i = 1/300 {
    foreach v in fr dr {
        quietly _datacheck_gtext `v', row(`i')
        local s `"`r(val)'"'
        if "`v'" == "fr" & float(real("`s'")) != fr[`i'] local ++bad
        if "`v'" == "dr" & real("`s'") != dr[`i'] local ++bad
        if strpos("`s'", "X") local ++bad
    }
}
_cv `=!(`bad' == 0)' "R3b 300 random floats and doubles round-trip exactly and none is hex"

* the ledger grp carries the readable text, and two runs pair in dataqa compare
clear
quietly set obs 40
generate long id = _n
generate float f = cond(_n <= 20, 0.1, 0.3)
local L3 "`W'/r3.dta"
capture erase "`L3'"
quietly datacheck, gatesonly by(f) isid(id) name(cohort) ledger("`L3'", run(p0))
quietly datacheck, gatesonly by(f) isid(id) name(cohort) ledger("`L3'", run(p1))
preserve
quietly use "`L3'", clear
quietly keep if run == "p0"
quietly count if strpos(grp, "f=.1") & strpos(grp, "X") == 0
local n01 = r(N)
quietly count if strpos(grp, "X")
local nhex = r(N)
restore
_cv `=!(`n01' >= 1 & `nhex' == 0)' "R3b ledger grp reads f=.1, no hex"
capture log close _rv
log using "`W'/r3.log", text replace name(_rv)
quietly dataqa compare using "`L3'", run(p1) baseline(p0)
local nfl = r(n_flags)
log close _rv
_rv_count "`W'/r3.log" "absent"
_cv `=!(`nfl' == 0 & r(n) == 0)' "R3b two new-format runs pair group for group in dataqa compare"
* integer group values keep their text, so an existing ledger still pairs
clear
quietly set obs 40
generate long id = _n
generate int yr = cond(_n <= 20, 2015, 2016)
local L4 "`W'/r4.dta"
capture erase "`L4'"
quietly datacheck, gatesonly by(yr) isid(id) name(cohort) ledger("`L4'", run(q0))
preserve
quietly use "`L4'", clear
quietly count if strpos(grp, "yr=2015")
local n15 = r(N)
restore
_cv `=!(`n15' >= 1)' "R3b an integer by() value keeps the text yr=2015"

* tidy
local files : dir "`W'" files "*"
foreach f of local files {
    capture erase "`W'/`f'"
}
capture rmdir "`W'"

display as text _newline "RESULT: test_datamap_v190_review tests=$TC pass=$PASS fail=$FAIL"
if $FAIL > 0 exit 1
