clear all
set more off
version 16.0
set linesize 255

* test_datacheck_v190_coverage.do - coverage() endq() and gap(none)
* (datamap 1.9.0 R6, U5).  Expected quantiles are computed here with _pctile,
* never read back from the package.  Every gate result is read from the
* ledger() file, whose rows are the observed verdicts.

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

* ledger status of one label: r(st) = pass | fail | absent, r(n) = rows with the label
capture program drop _cv_st
program define _cv_st, rclass
    args file label
    preserve
    use `"`file'"', clear
    quietly count if family == "coverage" & label == "`label'"
    return scalar n = r(N)
    local st "absent"
    if r(N) == 1 {
        quietly keep if family == "coverage" & label == "`label'"
        local st = status[1]
    }
    return local st "`st'"
    restore
end

capture program drop _cv_count
program define _cv_count, rclass
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

* truncated delivery: daily dates 01jan2019-02mar2020 plus one stray record
* 5 days before hi (31dec2020)
capture program drop _cv_trunc
program define _cv_trunc
    clear
    quietly set obs 427
    quietly gen double dt = mdy(1,1,2019) + _n - 1
    quietly set obs 428
    quietly replace dt = mdy(12,26,2020) in 428
    format dt %td
end

* late-start delivery: stray record at 02jan2019, then daily 01jun2019-31dec2020
capture program drop _cv_late
program define _cv_late
    clear
    quietly set obs 580
    quietly gen double dt = mdy(6,1,2019) + _n - 1
    quietly set obs 581
    quietly replace dt = mdy(1,2,2019) in 581
    format dt %td
end

local W "`c(tmpdir)'/cv190"
capture mkdir "`W'"
local hi = mdy(12,31,2020)
local lo = mdy(1,1,2019)

**## R6 endq(): truncated delivery with a stray late record
_cv_trunc
quietly summarize dt
local rawmax = r(max)
quietly _pctile dt, p(99)
local q99 = r(r1)
quietly _pctile dt, p(1)
local q01 = r(r1)

* oracle facts of the planted design
local ok = (`rawmax' >= `hi' - 30) & (`q99' < `hi' - 30)
_cv `=!`ok'' "oracle: raw max passes late_end, _pctile p99 is below hi-gap (q99=`q99', cut=`=`hi'-30')"

capture erase "`W'/a.dta"
capture datacheck, gatesonly coverage(dt 2019-01-01 2020-12-31, gap(30)) ledger("`W'/a.dta")
local rc_a = _rc
_cv_st "`W'/a.dta" late_end
_cv `=!(`rc_a' == 0 & "`r(st)'" == "pass")' "no endq(): late_end passes on the raw maximum (rc 0)"

capture erase "`W'/b.dta"
capture datacheck, gatesonly coverage(dt 2019-01-01 2020-12-31, gap(30) endq(0.01)) ledger("`W'/b.dta")
local rc_b = _rc
_cv_st "`W'/b.dta" late_end
_cv `=!(`rc_b' == 9 & "`r(st)'" == "fail")' "endq(0.01): late_end fails on the p99 (rc 9)"
_cv_st "`W'/b.dta" early_start
_cv `=!("`r(st)'" == "pass")' "endq(0.01): early_start still passes on the p1"

* the printed ledger line names the quantile tested and shows the oracle value
preserve
use "`W'/b.dta", clear
quietly keep if label == "late_end"
local obs = observed[1]
local msg = message[1]
local exp = expected[1]
restore
local want = "p99 " + strtrim(string(`q99', "%td"))
_cv `=!("`obs'" == "last `want'")' "endq(): observed text is 'last p99 <_pctile date>' (`obs')"
_cv `=!(strpos(`"`exp'"', "p99") > 0 & strpos(`"`exp'"', "endq(0.01)") > 0)' "endq(): the expectation text names the quantile and endq()"

* gatesonly parity with profile mode, and metamorphic: endq(0.01) result == raw min/max
* test when the quantile is replaced by the stray's absence
capture datacheck, coverage(dt 2019-01-01 2020-12-31, gap(30) endq(0.01))
_cv `=!(_rc == `rc_b')' "endq(): profile mode and gatesonly return the same rc"
preserve
drop if dt == mdy(12,26,2020)
quietly _pctile dt, p(99)
local q99b = r(r1)
quietly summarize dt
local mx = r(max)
capture datacheck, gatesonly coverage(dt 2019-01-01 2020-12-31, gap(30)) ledger("`W'/m1.dta")
local rc_m1 = _rc
capture datacheck, gatesonly coverage(dt 2019-01-01 2020-12-31, gap(30) endq(0.001)) ledger("`W'/m2.dta")
local rc_m2 = _rc
restore
_cv `=!(`rc_m1' == 9 & `rc_m2' == 9)' "without the stray both forms fail late_end (raw max `=string(`mx',"%td")')"

* a larger endq() keeps working on a clean delivery: no stray, hi - gap reached
clear
quietly set obs 731
quietly gen double dt = mdy(1,1,2019) + _n - 1
format dt %td
capture datacheck, gatesonly coverage(dt 2019-01-01 2020-12-31, gap(60) endq(0.05))
_cv `=!(_rc == 0 & _N == 731)' "endq(0.05) on a complete delivery passes and leaves the data intact"

**## R6 early_start mirror
_cv_late
quietly summarize dt
local rawmin = r(min)
quietly _pctile dt, p(1)
local p1 = r(r1)
_cv `=!(`rawmin' <= `lo' + 30 & `p1' > `lo' + 30)' "oracle: raw min passes early_start, _pctile p1 is above lo+gap (p1=`p1')"
capture erase "`W'/c.dta"
capture datacheck, gatesonly coverage(dt 2019-01-01 2020-12-31, gap(30)) ledger("`W'/c.dta")
_cv_st "`W'/c.dta" early_start
_cv `=!(_rc == 0 & "`r(st)'" == "pass")' "no endq(): early_start passes on the raw minimum"
capture erase "`W'/d.dta"
capture datacheck, gatesonly coverage(dt 2019-01-01 2020-12-31, gap(30) endq(0.01)) ledger("`W'/d.dta")
local rc_d = _rc
_cv_st "`W'/d.dta" early_start
_cv `=!(`rc_d' == 9 & "`r(st)'" == "fail")' "endq(0.01): early_start fails on the p1"
_cv_st "`W'/d.dta" late_end
_cv `=!("`r(st)'" == "pass")' "endq(0.01): late_end still passes (p99 reaches 01dec2020)"
preserve
use "`W'/d.dta", clear
quietly keep if label == "early_start"
local obs = observed[1]
restore
_cv `=!("`obs'" == "first p1 " + strtrim(string(`p1', "%td")))' "early_start observed text names p1 and the _pctile date (`obs')"

**## R6 boundary: the quantile equals hi - gap (late_end) and lo + gap (early_start)
_cv_trunc
quietly _pctile dt, p(99)
local q = r(r1)
local hib = `q' + 30
capture erase "`W'/e.dta"
capture datacheck, gatesonly coverage(dt `lo' `hib', gap(30) endq(0.01) tail(1)) ledger("`W'/e.dta")
_cv_st "`W'/e.dta" late_end
_cv `=!("`r(st)'" == "pass")' "boundary: p99 == hi - gap exactly passes late_end"
local hib1 = `q' + 31
capture erase "`W'/e1.dta"
capture datacheck, gatesonly coverage(dt `lo' `hib1', gap(30) endq(0.01) tail(1)) ledger("`W'/e1.dta")
_cv_st "`W'/e1.dta" late_end
_cv `=!("`r(st)'" == "fail")' "boundary: one day further (p99 == hi - gap - 1) fails late_end"
_cv_late
quietly _pctile dt, p(1)
local q = r(r1)
local lob = `q' - 30
capture erase "`W'/f.dta"
capture datacheck, gatesonly coverage(dt `lob' `hi', gap(30) endq(0.01) tail(1)) ledger("`W'/f.dta")
_cv_st "`W'/f.dta" early_start
_cv `=!("`r(st)'" == "pass")' "boundary: p1 == lo + gap exactly passes early_start"
local lob1 = `q' - 31
capture erase "`W'/f1.dta"
capture datacheck, gatesonly coverage(dt `lob1' `hi', gap(30) endq(0.01) tail(1)) ledger("`W'/f1.dta")
_cv_st "`W'/f1.dta" early_start
_cv `=!("`r(st)'" == "fail")' "boundary: p1 one day beyond lo + gap fails early_start"

**## R6 parse errors: endq outside (0, 0.5), non-numeric
_cv_trunc
local bad ""
foreach e in 0 0.5 0.7 1 -0.1 abc {
    capture erase "`W'/p.dta"
    capture datacheck, gatesonly coverage(dt 2019-01-01 2020-12-31, gap(30) endq(`e')) ledger("`W'/p.dta")
    local r1 = _rc
    * R4: the parse error leaves exactly one error row (rc 198), no gate row
    preserve
    capture quietly use "`W'/p.dta", clear
    local okrow = (_rc == 0)
    if `okrow' local okrow = (_N == 1 & status[1] == "error" & family[1] == "call" & observed_num[1] == 198)
    restore
    if `r1' != 198 | !`okrow' local bad "`bad' `e'(rc=`r1')"
}
_cv `=("`bad'" != "")' "endq(0, 0.5, 0.7, 1, -0.1, abc) give rc 198 and write only an error row, no gate row [`bad']"
capture datacheck, gatesonly coverage(dt 2019-01-01 2020-12-31, gap(30) endq(0.49))
_cv `=!(_rc == 9)' "endq(0.49) is accepted (runs, fails late_end)"
capture datacheck, gatesonly coverage(dt 2019-01-01 2020-12-31, gap(30) endq(0.001))
_cv `=!inlist(_rc, 0, 9)' "endq(0.001) is accepted (runs to a verdict)"

**## R6 maskrare: no unmasked quantile, no raw extreme
_cv_trunc
quietly summarize dt
* the stray (26dec2020) is the raw maximum; neither its day nor the p99 day may be printed
local straystr1 "26dec2020"
local straystr2 "2020-12-26"
quietly _pctile dt, p(99)
local q99d = strtrim(string(r(r1), "%td"))
capture erase "`W'/g.dta"
capture datacheck, gatesonly maskrare mincell(5) coverage(dt 2019-01-01 2020-12-31, gap(30) endq(0.01)) ledger("`W'/g.dta")
local rc_g = _rc
preserve
use "`W'/g.dta", clear
gen all = observed + "|" + message + "|" + expected
quietly count if strpos(all, "`straystr1'") | strpos(all, "`straystr2'") | strpos(all, "`q99d'")
local leak = r(N)
quietly keep if label == "late_end"
local obs = observed[1]
restore
_cv `=!(`rc_g' == 9 & `leak' == 0)' "maskrare: ledger carries neither the raw maximum nor the unmasked p99 day (rc `rc_g', leaks `leak')"
_cv `=!(regexm("`obs'", "^last p99 (2020-0[0-9]|\[suppressed\])$"))' "maskrare: observed shows p99 at month precision or [suppressed] (`obs')"
* mincell above the tail counts: the p99 cannot be shown
capture erase "`W'/h.dta"
capture datacheck, gatesonly maskrare mincell(50) coverage(dt 2019-01-01 2020-12-31, gap(30) endq(0.01)) ledger("`W'/h.dta")
preserve
use "`W'/h.dta", clear
quietly keep if label == "late_end"
local obs = observed[1]
restore
_cv `=!("`obs'" == "last p99 [suppressed]")' "maskrare mincell(50): fewer than 50 dates above p99, so it prints [suppressed] (`obs')"
* the profile-mode console must not show the day either
quietly log using "`W'/console.log", text replace name(cvc)
capture noisily datacheck, maskrare mincell(5) coverage(dt 2019-01-01 2020-12-31, gap(30) endq(0.01))
quietly log close cvc
local leakc = 0
tempname fh
file open `fh' using "`W'/console.log", read text
file read `fh' line
while r(eof) == 0 {
    if strpos(`"`line'"', "`straystr1'") | strpos(`"`line'"', "`q99d'") local ++leakc
    file read `fh' line
}
file close `fh'
_cv `=(`leakc' > 0)' "maskrare: the console shows neither the raw maximum nor the unmasked p99 day (leaks `leakc')"

**## U5 gap(none)
_cv_trunc
capture erase "`W'/n.dta"
capture datacheck, gatesonly coverage(dt 2019-01-01 2020-12-31, gap(none) tail(1)) ledger("`W'/n.dta")
local rc_n = _rc
_cv_st "`W'/n.dta" late_end
local n_le = r(n)
_cv_st "`W'/n.dta" early_start
local n_es = r(n)
_cv_st "`W'/n.dta" outside
local st_out "`r(st)'"
preserve
use "`W'/n.dta", clear
local nrows = _N
restore
_cv `=!(`rc_n' == 0 & `n_le' == 0 & `n_es' == 0 & "`st_out'" == "pass" & `nrows' == 1)' "gap(none): no late_end/early_start ledger row; outside is the only row (rc `rc_n', rows `nrows')"

* the same truncated data with a lag declared does fail: gap(none) is not masking a pass
capture datacheck, gatesonly coverage(dt 2019-01-01 2020-12-31, gap(30) endq(0.01) tail(1))
_cv `=!(_rc == 9)' "control: the same data fails late_end once gap(30) endq(0.01) is declared"

* the verdict counts one gate for gap(none), three for gap(30)
quietly log using "`W'/n.log", text replace name(cvn)
capture noisily datacheck, gatesonly coverage(dt 2019-01-01 2020-12-31, gap(none) tail(1))
capture noisily datacheck, gatesonly coverage(dt 2019-01-01 2020-12-31, gap(30) tail(1) endq(0.4)) warn
quietly log close cvn
_cv_count "`W'/n.log" "late_end and early_start not declared (gap(none))"
_cv `=!(r(n) == 1)' "gap(none): prints 'not declared (gap(none))' once"
_cv_count "`W'/n.log" "PASS: 1 gate(s) (coverage)"
_cv `=!(r(n) == 1)' "gap(none): verdict counts 1 gate (outside only), not 3"

* gap(none) still tests the window: a stray out-of-window record fails
_cv_trunc
quietly replace dt = mdy(12,31,2021) in 428
capture erase "`W'/o.dta"
capture datacheck, gatesonly coverage(dt 2019-01-01 2020-12-31, gap(none)) ledger("`W'/o.dta")
local rc_o = _rc
_cv_st "`W'/o.dta" outside
_cv `=!(`rc_o' == 9 & "`r(st)'" == "fail")' "gap(none): outside still fails on an out-of-window date"
* tail() still applies: 1 of 428 outside is within tail(0.01)
capture datacheck, gatesonly coverage(dt 2019-01-01 2020-12-31, gap(none) tail(0.01))
_cv `=!(_rc == 0)' "gap(none): tail(0.01) allows 1 of 428 outside"

* years still runs under gap(none): rows = outside + year_gap
clear
quietly set obs 100
quietly gen double dt = cond(_n <= 50, mdy(6,1,2018) + _n, mdy(6,1,2020) + _n)
format dt %td
capture erase "`W'/y.dta"
capture datacheck, gatesonly coverage(dt 2018-01-01 2020-12-31, gap(none) years) ledger("`W'/y.dta")
local rc_y = _rc
_cv_st "`W'/y.dta" year_gap
local st_y "`r(st)'"
preserve
use "`W'/y.dta", clear
local ny = _N
restore
_cv `=!(`rc_y' == 9 & "`st_y'" == "fail" & `ny' == 2)' "gap(none) years: empty 2019 fails year_gap; two rows (outside, year_gap)"

* checks() row reads the same declaration
tempfile ck
preserve
clear
input str12 gate str20 var str40 pattern str20 values str12 arg1 str12 arg2 str8 kind
"coverage" "dt" "" "gap(none) tail(1)" "01jan2018" "31dec2020" ""
end
save "`ck'", replace
restore
capture erase "`W'/k.dta"
capture datacheck, gatesonly checks("`ck'") ledger("`W'/k.dta")
_cv_st "`W'/k.dta" late_end
local nk = r(n)
_cv_st "`W'/k.dta" outside
_cv `=!(`nk' == 0 & r(n) == 1)' "checks() coverage row with gap(none): outside row only, no end rows"

* mask: gap(none) under maskrare also posts no end rows
_cv_trunc
capture erase "`W'/mk.dta"
capture datacheck, gatesonly maskrare mincell(5) coverage(dt 2019-01-01 2020-12-31, gap(none) tail(1)) ledger("`W'/mk.dta")
_cv_st "`W'/mk.dta" late_end
_cv `=!(_rc == 0 & r(n) == 0)' "gap(none) with maskrare: no end rows, rc 0"

* gap(none) is case-insensitive, endq() combination and malformed forms are refused
capture datacheck, gatesonly coverage(dt 2019-01-01 2020-12-31, gap(none) endq(0.01))
local rc1 = _rc
capture datacheck, gatesonly coverage(dt 2019-01-01 2020-12-31, gap(none) endq(0.3) tail(1))
local rc2 = _rc
_cv `=!(`rc1' == 198 & `rc2' == 198)' "gap(none) with endq() gives rc 198 (rc `rc1', `rc2')"
capture erase "`W'/q.dta"
capture datacheck, gatesonly coverage(dt 2019-01-01 2020-12-31, gap(none) endq(0.01)) ledger("`W'/q.dta")
preserve
capture quietly use "`W'/q.dta", clear
local okrow = (_rc == 0)
if `okrow' local okrow = (_N == 1 & status[1] == "error" & family[1] == "call")
restore
_cv `=!`okrow'' "gap(none) with endq(): only an error row is written, no gate row"

* gap() is still required: omitting it fails exactly as before
local bad ""
foreach g in "" ", tail(0.1)" ", years" ", endq(0.01)" ", gap()" ", gap(abc)" ", gap(-1)" ", gap(.)" ", gap(nonee)" {
    capture datacheck, gatesonly coverage(dt 2019-01-01 2020-12-31`g')
    if _rc != 198 local bad "`bad' [`g' rc=`=_rc']"
}
_cv `=("`bad'" != "")' "gap() omitted or malformed: rc 198 in every form [`bad']"
capture noisily datacheck, gatesonly coverage(dt 2019-01-01 2020-12-31)
_cv `=!(_rc == 198)' "bare coverage(dt lo hi) with no gap() is r(198)"
* error text for the omitted gap() is unchanged
quietly log using "`W'/err.log", text replace name(cve)
capture noisily datacheck, gatesonly coverage(dt 2019-01-01 2020-12-31, tail(0.1))
quietly log close cve
_cv_count "`W'/err.log" "coverage(): gap() is required, with the delivery lag in days from the plan; tail() and years are optional"
_cv `=!(r(n) == 1)' "omitted gap(): the error message is the existing one"

* numeric gap behaves as before: gap(30) without endq() on the truncated data
_cv_trunc
capture datacheck, gatesonly coverage(dt 2019-01-01 2020-12-31, gap(30))
_cv `=!(_rc == 0)' "gap(30) without endq(): unchanged behaviour on the truncated data (passes via raw max)"
capture datacheck, gatesonly coverage(dt 2019-01-01 2020-12-31, gap(30)) bandwarn
_cv `=!(_rc == 0)' "gap(30) with bandwarn: unchanged"

* tidy
foreach f in a b c d e e1 f f1 g h m1 m2 n o y k mk p q {
    capture erase "`W'/`f'.dta"
}
foreach f in console n err {
    capture erase "`W'/`f'.log"
}
capture rmdir "`W'"

display as text _newline "RESULT: test_datacheck_v190_coverage tests=$TC pass=$PASS fail=$FAIL"
if $FAIL > 0 exit 1
