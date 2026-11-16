clear all
set more off
version 16.0
set linesize 255

* test_datamap_v210_coverage.do - datamap 2.1.0 coverage brief (F8, P2, R2)
* F8: coverage() sides (outside_low / outside_high), dropoff(#), unit().
* P2: year_gap counted in one tabulate pass, parity with a per-year count.
* R2: keyset() strL keys fail before any count; an empty sample or file and
*     all-missing keys agree with -merge-; snapshot() names a skipped strL.
* Oracles are computed here by a different route (count, collapse,
* summarize/detail medians, -merge-), never read back from the package.
* Gate results are read from the ledger() file.

**# Bootstrap: targeted local reinstall
local qa_dir "`c(pwd)'"
if substr("`qa_dir'", -3, 3) != "/qa" {
    display as error "run this suite from the package qa/ directory"
    exit 198
}
local pkg_dir = substr("`qa_dir'", 1, strlen("`qa_dir'") - 3)
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
discard
macro drop DATAMAP_DQ

global TC 0
global PASS 0
global FAIL 0
capture program drop _t
program define _t
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

* one coverage ledger row: r(st) r(obs) r(msg) r(exp) r(num) r(mins) r(om) r(n)
capture program drop _row
program define _row, rclass
    args file label seq
    if "`seq'" == "" local seq 1
    preserve
    quietly use `"`file'"', clear
    quietly keep if family == "coverage" & label == "`label'" & seq == `seq'
    return scalar n = _N
    if _N == 1 {
        return local st = status[1]
        return local obs = observed[1]
        return local msg = message[1]
        return local exp = expected[1]
        return scalar num = observed_num[1]
        return scalar mins = minshown[1]
        return scalar om = obs_masked[1]
    }
    restore
end

* lines of a text log that contain a needle
capture program drop _cnt
program define _cnt, rclass
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

* daily dates with exact rows per calendar year from y0; the final year's
* rows fall in its first `lastdays' days
capture program drop _years
program define _years
    syntax , Y0(integer) COUNTS(numlist) [LASTdays(integer 365)]
    clear
    local ny : word count `counts'
    local y = `y0'
    local k = 0
    tempfile acc
    foreach c of local counts {
        local ++k
        local span = cond(`k' == `ny', `lastdays', 365)
        quietly {
            clear
            set obs `c'
            generate double dt = mdy(1, 1, `y') + mod((_n - 1) * 7, `span')
            if `k' > 1 append using `acc'
            save `acc', replace
        }
        local ++y
    }
    sort dt
    format dt %td
end

local W "`c(tmpdir)'/dm210cov"
capture mkdir "`W'"

* base fixture: 2,000 dates in 2010-2023, 3 before and 7 after the window
capture program drop _base
program define _base
    clear
    set seed 21001
    quietly set obs 2000
    quietly generate double dt = mdy(1,1,2010) + floor(runiform() * (mdy(12,31,2023) - mdy(1,1,2010) + 1))
    quietly replace dt = mdy(6,1,2009) - _n in 1/3
    quietly replace dt = mdy(6,1,2024) + _n in 4/10
    format dt %td
end

**# F8(a) sides
**## T1 sides: counts equal the oracle, aggregate row unchanged
capture noisily {
    _base
    quietly count if dt < mdy(1,1,2010)
    local olo = r(N)
    quietly count if dt > mdy(12,31,2023) & !missing(dt)
    local ohi = r(N)
    assert `olo' == 3 & `ohi' == 7
    capture erase "`W'/t1a.dta"
    capture erase "`W'/t1b.dta"
    dataprobe, gatesonly coverage(dt 01jan2010 31dec2023, gap(0) tail(0.01)) ledger("`W'/t1a.dta")
    assert missing(r(coverage_outside_low)) & missing(r(coverage_outside_high))
    _row "`W'/t1a.dta" outside
    local st0 "`r(st)'"
    local obs0 "`r(obs)'"
    local num0 = r(num)
    local mins0 = r(mins)
    local msg0 `"`r(msg)'"'
    dataprobe, gatesonly coverage(dt 01jan2010 31dec2023, gap(0) tail(0.01) sides) ledger("`W'/t1b.dta")
    assert r(coverage_outside_low) == `olo'
    assert r(coverage_outside_high) == `ohi'
    _row "`W'/t1b.dta" outside
    assert "`r(st)'" == "`st0'" & r(num) == `num0'
    assert "`r(obs)'" == "`obs0' (3 before 01jan2010, 7 after 31dec2023)"
    assert strpos(`"`r(msg)'"', "outside [01jan2010, 31dec2023] (3 before 01jan2010, 7 after 31dec2023), tail allows 1%") > 0
    * the smallest unmasked count printed is now the low side
    assert r(mins) == 3 & `mins0' == 10
    * without sides the 2.0.0 text is untouched
    assert strpos("`obs0'", "before") == 0
    assert `"`msg0'"' == "coverage(outside): 10 of dt dates (0.5%) outside [01jan2010, 31dec2023], tail allows 1%"
}
local trc = _rc
capture restore
_t `trc' "T1 sides: before/after counts equal count oracles, aggregate verdict and share unchanged, plain call unchanged"

**## T2 sides under maskrare: a small side masks both, no raw count printed
capture noisily {
    _base
    capture erase "`W'/t2.dta"
    capture log close t2
    log using "`W'/t2.log", text replace name(t2)
    dataprobe, gatesonly coverage(dt 01jan2010 31dec2023, gap(0) tail(0.01) sides) maskrare mincell(5) ledger("`W'/t2.dta") bandwarn
    log close t2
    _row "`W'/t2.dta" outside
    assert "`r(obs)'" == "10 dates (0.5%) outside (<5 before 01jan2010, all but <5 after 31dec2023)"
    assert r(om) == 1 & missing(r(num))
    assert r(mins) == 10
    _cnt "`W'/t2.log" "3 before"
    assert r(n) == 0
    _cnt "`W'/t2.log" "7 after"
    assert r(n) == 0
}
local trc = _rc
capture restore
_t `trc' "T2 sides + maskrare: '<5 before', 'all but <5 after', obs_masked 1, minshown stays 10, 3 and 7 never printed"

**## T3 sides when the outside count itself is masked; zero outside
capture noisily {
    _base
    quietly replace dt = mdy(6,1,2015) in 3/10
    capture erase "`W'/t3.dta"
    dataprobe, gatesonly coverage(dt 01jan2010 31dec2023, gap(400) tail(0.01) sides) maskrare mincell(5) ledger("`W'/t3.dta")
    assert r(coverage_outside_low) == 2 & r(coverage_outside_high) == 0
    _row "`W'/t3.dta" outside
    assert "`r(obs)'" == "<5 dates outside (sides withheld)"
    quietly replace dt = mdy(6,1,2015) in 1/2
    capture erase "`W'/t3b.dta"
    dataprobe, gatesonly coverage(dt 01jan2010 31dec2023, gap(400) sides) ledger("`W'/t3b.dta")
    _row "`W'/t3b.dta" outside
    assert "`r(obs)'" == "0 dates (0.0%) outside (0 before 01jan2010, 0 after 31dec2023)"
    assert "`r(st)'" == "pass"
}
local trc = _rc
capture restore
_t `trc' "T3 sides: masked outside count withholds both sides; zero outside prints 0 and 0"

**# F8(b) dropoff
**## T4 dropoff: planted tail drop, deterministic counts
capture noisily {
    _years, y0(2010) counts(100 100 100 100 100 100 100 100 100 100 100 100 40 45)
    capture erase "`W'/t4.dta"
    capture dataprobe, gatesonly coverage(dt 01jan2010 31dec2023, gap(0) dropoff(50)) ledger("`W'/t4.dta")
    assert _rc == 9
    _row "`W'/t4.dta" dropoff
    assert "`r(st)'" == "fail"
    assert "`r(obs)'" == "below 50% of the reference median in 2022 2023"
    assert r(num) == 2
    assert strpos("`r(exp)'", "each year 2013-2023") > 0
    * the other checks are unaffected
    _row "`W'/t4.dta" outside
    assert "`r(st)'" == "pass"
}
local trc = _rc
capture restore
_t `trc' "T4 dropoff(50): 2022 (40) and 2023 (45) against a median of 100 fail, rc 9, years 2013-2023 tested"

**## T5 dropoff boundary: exactly # percent passes, one row fewer fails
capture noisily {
    _years, y0(2010) counts(100 100 100 100 100 100 50)
    capture erase "`W'/t5a.dta"
    dataprobe, gatesonly coverage(dt 01jan2010 31dec2016, gap(400) dropoff(50)) ledger("`W'/t5a.dta")
    _row "`W'/t5a.dta" dropoff
    assert "`r(st)'" == "pass" & r(num) == 0
    _years, y0(2010) counts(100 100 100 100 100 100 49)
    capture erase "`W'/t5b.dta"
    capture dataprobe, gatesonly coverage(dt 01jan2010 31dec2016, gap(400) dropoff(50)) ledger("`W'/t5b.dta")
    assert _rc == 9
    _row "`W'/t5b.dta" dropoff
    assert "`r(obs)'" == "below 50% of the reference median in 2016"
}
local trc = _rc
capture restore
_t `trc' "T5 dropoff boundary: 50 of median 100 passes, 49 fails"

**## T5c dropoff boundary at percentages whose float product overshoots
capture noisily {
    * the pairs (#, median) where # / 100 * median computes above the
    * integer count at exactly #%: the float trap a naive test falls into
    local pairs ""
    local np = 0
    foreach pct in 7 14 28 29 57 7.3 {
        local got = 0
        foreach med in 100 200 300 1000 {
            local w = `pct' * `med' / 100
            if `w' == floor(`w') & `pct' / 100 * `med' > `w' & !`got' {
                local pairs "`pairs' `pct':`med'"
                local ++np
                local got = 1
            }
        }
    }
    display as text "overshooting pairs: `pairs'"
    assert `np' >= 3
    assert strpos("`pairs'", " 7:100") > 0
    * and a decimal percentage at its exact boundary (73 of a median of 1000)
    local pairs "`pairs' 7.3:1000"
    foreach pr of local pairs {
        gettoken pct med : pr, parse(":")
        local med = substr("`med'", 2, .)
        local w = round(`pct' * `med' / 100)
        * exactly #% passes
        _years, y0(2010) counts(`med' `med' `med' `w')
        capture erase "`W'/t5c.dta"
        capture dataprobe, gatesonly coverage(dt 01jan2010 31dec2013, gap(2000) tail(1) dropoff(`pct')) ledger("`W'/t5c.dta")
        assert _rc == 0
        _row "`W'/t5c.dta" dropoff
        assert "`r(st)'" == "pass" & r(num) == 0
        * one row fewer fails
        _years, y0(2010) counts(`med' `med' `med' `=`w' - 1')
        capture erase "`W'/t5c.dta"
        capture dataprobe, gatesonly coverage(dt 01jan2010 31dec2013, gap(2000) tail(1) dropoff(`pct')) ledger("`W'/t5c.dta")
        assert _rc == 9
        _row "`W'/t5c.dta" dropoff
        assert "`r(obs)'" == "below `pct'% of the reference median in 2013"
    }
    * a prorated final year at exactly its threshold: 73 of 365 days is 0.2,
    * 50% of 100 * 0.2 = 10 rows
    _years, y0(2018) counts(100 100 100 10) lastdays(73)
    capture erase "`W'/t5d.dta"
    capture dataprobe, gatesonly coverage(dt 01jan2018 14mar2021, gap(2000) tail(1) dropoff(50)) ledger("`W'/t5d.dta")
    _row "`W'/t5d.dta" dropoff
    assert "`r(st)'" == "pass"
    _years, y0(2018) counts(100 100 100 9) lastdays(73)
    capture erase "`W'/t5d.dta"
    capture dataprobe, gatesonly coverage(dt 01jan2018 14mar2021, gap(2000) tail(1) dropoff(50)) ledger("`W'/t5d.dta")
    _row "`W'/t5d.dta" dropoff
    assert "`r(st)'" == "fail" & "`r(obs)'" == "below 50% of the reference median in 2021"
}
local trc = _rc
capture restore
_t `trc' "T5c dropoff boundary: exactly #% passes at the float-overshooting 7%, 14%, 28%, at 7.3%, and prorated; one row fewer fails"

**## T6 dropoff: a partial final year is prorated by its days in the window
capture noisily {
    * hi = 30jun2023: 181 of 365 days; threshold 0.5 * 100 * 181/365 = 24.79
    local thr = 0.5 * 100 * 181 / 365
    assert 24 < `thr' & `thr' < 25
    _years, y0(2017) counts(100 100 100 100 100 100 25) lastdays(181)
    capture erase "`W'/t6a.dta"
    dataprobe, gatesonly coverage(dt 01jan2017 30jun2023, gap(400) dropoff(50)) ledger("`W'/t6a.dta")
    _row "`W'/t6a.dta" dropoff
    assert "`r(st)'" == "pass"
    assert strpos("`r(exp)'", "2023 prorated to its 181 days inside the window") > 0
    _years, y0(2017) counts(100 100 100 100 100 100 24) lastdays(181)
    capture erase "`W'/t6b.dta"
    capture dataprobe, gatesonly coverage(dt 01jan2017 30jun2023, gap(400) dropoff(50)) ledger("`W'/t6b.dta")
    assert _rc == 9
    _row "`W'/t6b.dta" dropoff
    assert "`r(obs)'" == "below 50% of the reference median in 2023"
    * a partial first year (2016 from 01jul) is neither tested nor a
    * reference year: the first tested year is 2017 + 3 = 2020, not 2019
    _years, y0(2016) counts(1 100 100 100 100 100)
    capture erase "`W'/t6c.dta"
    dataprobe, gatesonly coverage(dt 01jul2016 31dec2021, gap(400) dropoff(50) tail(1)) ledger("`W'/t6c.dta")
    _row "`W'/t6c.dta" dropoff
    assert "`r(st)'" == "pass"
    assert strpos("`r(exp)'", "each year 2020-2021") > 0
}
local trc = _rc
capture restore
_t `trc' "T6 dropoff: partial final year prorated (25 passes, 24 fails), partial first year not a reference year"

**## T7 dropoff against a summarize/detail median oracle on random counts
capture noisily {
    clear
    set seed 21007
    local counts ""
    forvalues y = 2000/2023 {
        local c = 40 + floor(runiform() * 80)
        if inlist(`y', 2008, 2017, 2023) local c = 12
        local counts "`counts' `c'"
    }
    _years, y0(2000) counts(`counts')
    * oracle: rows per year by collapse, medians by summarize, detail
    preserve
    generate int y = year(dt)
    generate byte one = 1
    collapse (sum) c = one, by(y)
    local want ""
    forvalues y = 2003/2023 {
        quietly summarize c if inrange(y, max(2000, `y' - 5), `y' - 1), detail
        local med = r(p50)
        quietly summarize c if y == `y', meanonly
        if `med' > 0 & r(sum) < 0.5 * `med' local want "`want' `y'"
    }
    restore
    local want = strtrim("`want'")
    assert "`want'" != ""
    capture erase "`W'/t7.dta"
    capture dataprobe, gatesonly coverage(dt 01jan2000 31dec2023, gap(0) dropoff(50)) ledger("`W'/t7.dta")
    _row "`W'/t7.dta" dropoff
    assert "`r(obs)'" == "below 50% of the reference median in `want'"
    assert r(num) == `: word count `want''
}
local trc = _rc
capture restore
_t `trc' "T7 dropoff: flagged years equal a collapse + summarize-median oracle on 24 random years"

**## T8 dropoff: a reference median of 0 is not tested; none tested fails
capture noisily {
    _years, y0(2010) counts(100 100 100 100 100)
    capture erase "`W'/t8.dta"
    capture dataprobe, gatesonly coverage(dt 01jan2005 31dec2014, gap(0) dropoff(50) tail(1)) ledger("`W'/t8.dta") bandwarn
    _row "`W'/t8.dta" dropoff
    * 2008-2012 have a reference median of 0; 2013 and 2014 are tested
    assert "`r(st)'" == "pass" & r(num) == 0
    assert "`r(obs)'" == "no year below 50% of its reference median; not tested (reference median 0): 2008 2009 2010 2011 2012"
    assert strpos(`"`r(msg)'"', "falls below") == 0
    assert strpos(`"`r(msg)'"', "(not tested, reference median 0: 2008 2009 2010 2011 2012)") > 0
    capture erase "`W'/t8b.dta"
    dataprobe, gatesonly coverage(dt 01jan2005 31dec2014, gap(0) dropoff(50) tail(1)) ledger("`W'/t8b.dta") bandwarn exclude(dt)
    _row "`W'/t8b.dta" dropoff
    assert "`r(obs)'" == "no year below 50% of its reference median; not tested (reference median 0): 5 year(s) ([excluded])"
    * a real drop after a late start: only the drop is named below
    _years, y0(2010) counts(100 100 100 100 100 10)
    capture erase "`W'/t8c.dta"
    capture dataprobe, gatesonly coverage(dt 01jan2005 31dec2015, gap(0) dropoff(50) tail(1)) ledger("`W'/t8c.dta") bandwarn
    _row "`W'/t8c.dta" dropoff
    assert "`r(st)'" == "warn" & r(num) == 1
    assert "`r(obs)'" == "below 50% of the reference median in 2015; not tested (reference median 0): 2008 2009 2010 2011 2012"
    assert strpos(`"`r(msg)'"', "falls below 50% of the median of the years before it in 2015 (not tested") > 0
    * every tested year has a reference median of 0: fail closed
    _years, y0(2010) counts(100 100 100)
    capture erase "`W'/t8d.dta"
    capture dataprobe, gatesonly coverage(dt 01jan2005 31dec2012, gap(0) dropoff(50) tail(1)) ledger("`W'/t8d.dta")
    assert _rc == 9
    _row "`W'/t8d.dta" dropoff
    assert "`r(st)'" == "fail" & r(num) == 0
    assert "`r(obs)'" == "no year tested; not tested (reference median 0): 2008 2009 2010 2011 2012"
    assert strpos(`"`r(msg)'"', "has no rows in the reference years of any year 2008-2012; not tested") > 0
}
local trc = _rc
capture restore
_t `trc' "T8 dropoff: median-0 years not tested and named, a real drop still fails, all untested fails closed, exclude() counts only"

**## T9 dropoff parse errors, before any output
capture noisily {
    _years, y0(2010) counts(100 100 100)
    foreach bad in "dropoff(0)" "dropoff(101)" "dropoff(abc)" "dropoff(-5)" {
        capture dataprobe, gatesonly coverage(dt 01jan2010 31dec2012, gap(0) `bad')
        assert _rc == 198
    }
    * three complete years leave no tested year
    capture dataprobe, gatesonly coverage(dt 01jan2010 31dec2012, gap(0) dropoff(50))
    assert _rc == 198
    capture dataprobe, gatesonly coverage(dt 01jan2010 31dec2013, gap(0) dropoff(50) tail(1))
    assert _rc == 9 | _rc == 0
}
local trc = _rc
capture restore
_t `trc' "T9 dropoff: 0, 101, abc, -5 and a window with no testable year are r(198); 4 complete years run"

**## T10 empty sample and all-missing dates with dropoff and sides
capture noisily {
    _base
    quietly replace dt = .
    capture erase "`W'/t10.dta"
    capture dataprobe, gatesonly coverage(dt 01jan2010 31dec2023, gap(0) sides dropoff(50) years) ledger("`W'/t10.dta") bandwarn
    assert _rc == 0
    assert missing(r(coverage_outside_low))
    foreach ck in outside late_end early_start year_gap dropoff {
        _row "`W'/t10.dta" `ck'
        assert r(n) == 1 & "`r(st)'" == "warn" & "`r(obs)'" == "no nonmissing dates"
    }
}
local trc = _rc
capture restore
_t `trc' "T10 all-missing dates: every check, dropoff included, fails 'no nonmissing dates', no error"

**## T10b sides sums: missing when any sides entry's outside check did not run
capture noisily {
    _base
    generate long ymd = real(string(dt, "%tdCCYYNNDD"))
    quietly replace ymd = 20101332 in 20
    capture dataprobe, gatesonly coverage(dt 01jan2010 31dec2023, gap(0) tail(1) sides)
    assert r(coverage_outside_low) == 3 & r(coverage_outside_high) == 7
    capture dataprobe, gatesonly coverage(dt 01jan2010 31dec2023, gap(0) tail(1) sides \ ymd 20100101 20231231, gap(0) tail(1) unit(yyyymmdd) sides)
    assert _rc == 9
    assert missing(r(coverage_outside_low)) & missing(r(coverage_outside_high))
    * an entry without sides does not enter the sums
    capture dataprobe, gatesonly coverage(dt 01jan2010 31dec2023, gap(0) tail(1) sides \ ymd 20100101 20231231, gap(0) tail(1) unit(yyyymmdd))
    assert r(coverage_outside_low) == 3 & r(coverage_outside_high) == 7
}
local trc = _rc
capture restore
_t `trc' "T10b sides sums: 3 and 7 alone; missing with an untested sides entry; a non-sides entry adds nothing"

**# F8(c) unit()
**## T11 unit(yyyymmdd): same verdicts as the daily copy, variable untouched
capture noisily {
    _base
    quietly replace dt = . in 11/20
    generate long ymd = real(string(dt, "%tdCCYYNNDD"))
    format ymd %10.0g
    capture erase "`W'/t11a.dta"
    capture erase "`W'/t11b.dta"
    quietly datasignature
    local sig0 "`r(datasignature)'"
    dataprobe, gatesonly coverage(dt 01jan2010 31dec2023, gap(30) tail(0.01) years sides dropoff(50)) ledger("`W'/t11a.dta")
    local lo_a = r(coverage_outside_low)
    dataprobe, gatesonly coverage(ymd 20100101 31dec2023, gap(30) tail(0.01) years sides dropoff(50) unit(yyyymmdd)) ledger("`W'/t11b.dta")
    assert r(coverage_outside_low) == `lo_a'
    quietly datasignature
    assert "`r(datasignature)'" == "`sig0'"
    assert "`: format ymd'" == "%10.0g"
    foreach ck in outside late_end early_start year_gap dropoff {
        _row "`W'/t11a.dta" `ck'
        local s1 "`r(st)'"
        local o1 "`r(obs)'"
        local n1 = r(num)
        _row "`W'/t11b.dta" `ck'
        assert "`r(st)'" == "`s1'" & "`r(obs)'" == "`o1'"
        assert r(num) == `n1' | (missing(r(num)) & missing(`n1'))
    }
}
local trc = _rc
capture restore
_t `trc' "T11 unit(yyyymmdd): five checks match the %td copy (status, observed, numeric); data and format unchanged"

**## T12 unit(yyyymmdd): impossible values fail closed, never printed
capture noisily {
    _base
    generate long ymd = real(string(dt, "%tdCCYYNNDD"))
    quietly replace ymd = 20101332 in 20
    quietly replace ymd = 20100230 in 21
    quietly replace ymd = 20101200 in 22
    capture erase "`W'/t12.dta"
    capture log close t12
    log using "`W'/t12.log", text replace name(t12)
    capture noisily dataprobe, gatesonly coverage(ymd 20100101 20231231, gap(0) tail(1) unit(yyyymmdd) years) ledger("`W'/t12.dta")
    local rc12 = _rc
    log close t12
    assert `rc12' == 9
    foreach ck in outside late_end early_start year_gap {
        _row "`W'/t12.dta" `ck'
        assert "`r(st)'" == "fail" & "`r(obs)'" == "3 values not valid in unit(yyyymmdd)"
        assert r(mins) == 3
    }
    foreach v in 20101332 20100230 20101200 {
        _cnt "`W'/t12.log" "`v'"
        assert r(n) == 0
    }
    * under the mask the count is withheld
    capture erase "`W'/t12b.dta"
    capture dataprobe, gatesonly coverage(ymd 20100101 20231231, gap(0) tail(1) unit(yyyymmdd)) maskrare mincell(5) ledger("`W'/t12b.dta")
    _row "`W'/t12b.dta" outside
    assert "`r(obs)'" == "<5 values not valid in unit(yyyymmdd)" & r(om) == 1
}
local trc = _rc
capture restore
_t `trc' "T12 unit(yyyymmdd): month 13, 30 Feb, day 00 fail every check with the count, no value printed; masked under maskrare"

**## T13 unit() refusals
capture noisily {
    _base
    generate long ymd = real(string(dt, "%tdCCYYNNDD"))
    generate float ymdf = ymd
    generate int yr = year(dt)
    capture dataprobe, gatesonly coverage(ymdf 20100101 20231231, gap(0) unit(yyyymmdd))
    assert _rc == 198
    capture dataprobe, gatesonly coverage(ymd 20100101 20231301, gap(0) unit(yyyymmdd))
    assert _rc == 198
    capture dataprobe, gatesonly coverage(dt 2010 2023, gap(0) unit(year))
    assert _rc == 198
    capture dataprobe, gatesonly coverage(dt 01jan2010 31dec2023, gap(0) unit(yyyymmdd))
    assert _rc == 198
    capture dataprobe, gatesonly coverage(yr 2010 2023, gap(0) unit(month))
    assert _rc == 198
    format yr %tm
    capture dataprobe, gatesonly coverage(yr 2010 2023, gap(0) unit(year))
    assert _rc == 198
    * no unit on an unformatted number keeps the 2.0.0 error, plus a hint
    format yr %8.0g
    capture log close t13
    log using "`W'/t13.log", text replace name(t13)
    capture noisily dataprobe, gatesonly coverage(yr 2010 2023, gap(0))
    local rc13 = _rc
    log close t13
    assert `rc13' == 198
    _cnt "`W'/t13.log" "coverage(): yr must be a daily (%td) date; give it a daily date display format, e.g. format yr %td"
    assert r(n) == 1
    _cnt "`W'/t13.log" "unit(date), unit(year), or unit(yyyymmdd)"
    assert r(n) == 1
}
local trc = _rc
capture restore
_t `trc' "T13 unit(): float yyyymmdd, bad bound, contradicting %td/%tm formats, unknown unit are r(198); no unit keeps its error"

**## T14 unit(year): years, gap in years, invalid years fail closed
capture noisily {
    _base
    generate double yr = year(dt)
    quietly count if yr < 2010
    local olo = r(N)
    quietly count if yr > 2023
    local ohi = r(N)
    capture erase "`W'/t14.dta"
    capture dataprobe, gatesonly coverage(yr 2010 2023, gap(0) tail(0.01) sides years dropoff(50))
    assert _rc == 198
    dataprobe, gatesonly coverage(yr 2010 2023, gap(0) tail(0.01) sides years dropoff(50) unit(year)) ledger("`W'/t14.dta")
    assert r(coverage_outside_low) == `olo' & r(coverage_outside_high) == `ohi'
    _row "`W'/t14.dta" outside
    assert "`r(obs)'" == "10 dates (0.5%) outside (3 before 2010, 7 after 2023)"
    _row "`W'/t14.dta" late_end
    assert "`r(obs)'" == "last 2024" & "`r(st)'" == "pass"
    _row "`W'/t14.dta" dropoff
    assert "`r(st)'" == "pass"
    * gap() in years: data ending 2022 passes gap(1), fails gap(0)
    quietly drop if yr >= 2023
    capture erase "`W'/t14b.dta"
    capture dataprobe, gatesonly coverage(yr 2010 2023, gap(1) tail(1) unit(year)) ledger("`W'/t14b.dta")
    _row "`W'/t14b.dta" late_end
    assert "`r(st)'" == "pass" & strpos("`r(exp)'", "2023 - 1 years (2022)") > 0
    capture erase "`W'/t14c.dta"
    capture dataprobe, gatesonly coverage(yr 2010 2023, gap(0) tail(1) unit(year)) ledger("`W'/t14c.dta")
    assert _rc == 9
    * a year of 2015.5 or 19 is not a year
    quietly replace yr = 2015.5 in 30
    quietly replace yr = 19 in 31
    capture erase "`W'/t14d.dta"
    capture dataprobe, gatesonly coverage(yr 2010 2023, gap(1) tail(1) unit(year)) ledger("`W'/t14d.dta")
    assert _rc == 9
    _row "`W'/t14d.dta" outside
    assert "`r(obs)'" == "2 values not valid in unit(year)"
}
local trc = _rc
capture restore
_t `trc' "T14 unit(year): sides and late_end in years, gap(1) vs gap(0), 2015.5 and 19 fail closed; no unit is r(198)"

**## T15 unit(date) on an unformatted day count equals the %td run
capture noisily {
    _base
    generate double dn = dt
    format dn %10.0g
    capture erase "`W'/t15a.dta"
    capture erase "`W'/t15b.dta"
    dataprobe, gatesonly coverage(dt 01jan2010 31dec2023, gap(30) tail(0.01) years endq(0.01)) ledger("`W'/t15a.dta") bandwarn
    dataprobe, gatesonly coverage(dn 01jan2010 31dec2023, gap(30) tail(0.01) years endq(0.01) unit(date)) ledger("`W'/t15b.dta") bandwarn
    assert "`: format dn'" == "%10.0g"
    foreach ck in outside late_end early_start year_gap {
        _row "`W'/t15a.dta" `ck'
        local o1 "`r(obs)'"
        local s1 "`r(st)'"
        _row "`W'/t15b.dta" `ck'
        assert "`r(obs)'" == "`o1'" & "`r(st)'" == "`s1'"
    }
    * unit(date) on a %td variable is the default exactly
    capture erase "`W'/t15c.dta"
    dataprobe, gatesonly coverage(dt 01jan2010 31dec2023, gap(30) tail(0.01) years endq(0.01) unit(date)) ledger("`W'/t15c.dta") bandwarn
    foreach ck in outside late_end early_start year_gap {
        _row "`W'/t15a.dta" `ck'
        local o1 `"`r(msg)'"'
        _row "`W'/t15c.dta" `ck'
        assert `"`r(msg)'"' == `"`o1'"'
    }
}
local trc = _rc
capture restore
_t `trc' "T15 unit(date): an unformatted day count gives the %td verdicts; unit(date) on %td is identical; format kept"

**# P2 year_gap in one pass
**## T16 year_gap parity with a per-year count oracle
capture noisily {
    clear
    set seed 21016
    quietly set obs 50000
    generate double dt = mdy(1,1,1994) + floor(runiform() * (mdy(12,31,2023) - mdy(1,1,1994) + 1))
    quietly drop if inlist(year(dt), 1995, 2004, 2005, 2021)
    quietly replace dt = . in 1/100
    format dt %td
    * oracle: the 2.0.0 method, one count per year
    quietly summarize dt
    local empty ""
    forvalues y = `=year(r(min))'/`=year(r(max))' {
        quietly count if year(dt) == `y' & !missing(dt)
        if r(N) == 0 local empty "`empty' `y'"
    }
    local empty = strtrim("`empty'")
    assert "`empty'" == "1995 2004 2005 2021"
    capture erase "`W'/t16.dta"
    capture dataprobe, gatesonly coverage(dt 01jan1994 31dec2023, gap(0) years) ledger("`W'/t16.dta")
    _row "`W'/t16.dta" year_gap
    assert "`r(obs)'" == "no rows in `empty'" & r(num) == 4
    * one year only, and no gap
    keep if year(dt) == 2010
    capture erase "`W'/t16b.dta"
    capture dataprobe, gatesonly coverage(dt 01jan2010 31dec2010, gap(400) years) ledger("`W'/t16b.dta")
    _row "`W'/t16b.dta" year_gap
    assert "`r(obs)'" == "no empty year" & "`r(st)'" == "pass"
}
local trc = _rc
capture restore
_t `trc' "T16 P2 year_gap: tabulate pass matches a per-year count oracle (4 planted empty years, missing dates), one-year span"

**## T17 coverage leaves the data and its order unchanged
capture noisily {
    _base
    generate long ymd = real(string(dt, "%tdCCYYNNDD"))
    generate long order = _n
    quietly replace dt = dt[_N - _n + 1]
    quietly datasignature
    local sig0 "`r(datasignature)'"
    capture dataprobe, gatesonly coverage(ymd 20100101 20231231, gap(0) tail(1) sides years dropoff(50) unit(yyyymmdd) \ dt 01jan2010 31dec2023, gap(0) tail(1) years dropoff(50))
    quietly datasignature
    assert "`r(datasignature)'" == "`sig0'"
    assert order == _n
    assert "`: sortedby'" == ""
}
local trc = _rc
capture restore
_t `trc' "T17 coverage with unit(), sides, years, dropoff: data signature and row order unchanged"

**# R2 keyset() and snapshot() strL, empty, missing
**## T18 strL key: merge refuses it; keyset fails before any count
capture noisily {
    clear
    quietly set obs 20
    generate long id = _n
    generate strL sk = "k" + string(_n)
    generate str5 s5 = "k" + string(_n)
    quietly save "`W'/u_strl.dta", replace
    * oracle: merge itself stops with r(106) on a strL key, either side
    capture merge 1:1 sk using "`W'/u_strl.dta", nogenerate
    assert _rc == 106
    capture erase "`W'/t18.dta"
    capture log close t18
    log using "`W'/t18.log", text replace name(t18)
    capture noisily dataprobe, gatesonly keyset(sk using "`W'/u_strl.dta") ledger("`W'/t18.dta")
    local rc18 = _rc
    log close t18
    assert `rc18' == 9
    _cnt "`W'/t18.log" "strL key (sk): merge would stop with r(106); recast str# sk"
    assert r(n) == 1
    _cnt "`W'/t18.log" "matched"
    assert r(n) == 0
    preserve
    quietly use "`W'/t18.dta", clear
    assert _N == 1 & family == "keyset" & status == "fail"
    assert observed == "strL key: sk strL in memory and in u_strl; recast str# before merging"
    restore
    capture noisily dataprobe, gatesonly keyset(sk using "`W'/u_strl.dta") warn
    assert _rc == 0
    assert "`r(keyset_merge)'" == "conflict" & missing(r(keyset_matched))
    * using side only
    preserve
    drop sk
    rename s5 sk
    capture noisily dataprobe, gatesonly keyset(sk using "`W'/u_strl.dta") warn
    assert _rc == 0 & r(n_violations) == 1
    restore
    * a str# key after recast passes and its counts equal merge
    preserve
    quietly use "`W'/u_strl.dta", clear
    quietly recast str5 sk
    quietly save "`W'/u_s5.dta", replace
    restore
    recast str5 sk
    quietly drop in 1/3
    dataprobe, gatesonly keyset(sk using "`W'/u_s5.dta", subset)
    assert r(keyset_matched) == 17 & r(keyset_only_using) == 3
    quietly merge 1:1 sk using "`W'/u_s5.dta"
    quietly count if _merge == 3
    assert r(N) == 17
}
local trc = _rc
capture restore
_t `trc' "T18 keyset strL: merge r(106) oracle; fail with strL message, no count, rc 9 / warn rc 0, using side too; recast passes"

**## T19 strL key with hostile content and a type conflict together
capture noisily {
    clear
    quietly set obs 6
    * a " b ' c $ d ` e { f } g, built from char() so the do-file never expands it
    generate strL sk = "a" + char(34) + "b'c" + char(36) + "d" + char(96) + "e{f}g" + string(_n)
    generate long n = _n
    quietly save "`W'/u_host.dta", replace
    quietly tostring n, replace
    capture erase "`W'/t19.dta"
    capture noisily dataprobe, gatesonly keyset(sk n using "`W'/u_host.dta") ledger("`W'/t19.dta") warn
    assert _rc == 0
    preserve
    quietly use "`W'/t19.dta", clear
    assert _N == 1 & status == "warn"
    assert strpos(observed, "type conflict: n str1 in memory, long in u_host") == 1
    assert strpos(observed, "strL key: sk strL in memory and in u_host") > 0
    assert strpos(observed, char(36) + "d") == 0 & strpos(observed, "e{f}g") == 0
    restore
    capture noisily dataprobe sk, snapshot(s19, replace)
    assert _rc == 0
}
local trc = _rc
capture restore
_t `trc' "T19 keyset: hostile strL content (quote, apostrophe, dollar, backtick, braces) and a type conflict report both, no value printed"

**## T20 empty sample and empty file agree with merge
capture noisily {
    clear
    quietly set obs 20
    generate long id = _n
    quietly save "`W'/u_k.dta", replace
    keep if 0
    quietly save "`W'/u_e.dta", replace
    * before 2.1.0 this was r(111): -by: generate- makes no variable on 0 rows
    capture noisily dataprobe id, keyset(id using "`W'/u_k.dta") snapshot(s20, replace) warn
    assert _rc == 0
    assert r(keyset_matched) == 0 & r(keyset_only_master) == 0 & r(keyset_only_using) == 20
    assert "`r(keyset_merge)'" == "1:1"
    quietly merge 1:1 id using "`W'/u_k.dta"
    quietly count if _merge == 2
    assert r(N) == 20
    quietly use "`W'/u_k.dta", clear
    dataprobe, gatesonly keyset(id using "`W'/u_e.dta", superset)
    assert r(keyset_only_master) == 20 & r(keyset_matched) == 0
    capture dataprobe, gatesonly keyset(id using "`W'/u_e.dta")
    assert _rc == 9
    quietly use "`W'/u_e.dta", clear
    capture noisily dataprobe id, keyset(id using "`W'/u_e.dta") snapshot(s20b, replace)
    assert _rc == 0 & r(n_violations) == 0
}
local trc = _rc
capture restore
_t `trc' "T20 keyset on an empty sample, an empty file, both empty: deterministic, equal to merge, no r(111)"

**## T21 all-missing keys count as one key, as merge does
capture noisily {
    clear
    quietly set obs 20
    generate long id = _n
    quietly save "`W'/u_k.dta", replace
    quietly replace id = .
    generate x = _n
    dataprobe x, gatesonly keyset(id using "`W'/u_k.dta") warn
    assert r(keyset_only_master) == 1 & r(keyset_only_using) == 20 & r(keyset_matched) == 0
    assert "`r(keyset_merge)'" == "m:1"
    quietly merge m:1 id using "`W'/u_k.dta"
    quietly count if _merge == 1
    assert r(N) == 20
    quietly count if _merge == 3
    assert r(N) == 0
}
local trc = _rc
capture restore
_t `trc' "T21 keyset all-missing keys: 1 memory-only key, merge m:1, equal to -merge-"

**## T22 snapshot names a strL it would otherwise have tried as key
capture noisily {
    clear
    quietly set obs 20
    generate strL sk = "k" + string(_n)
    generate x = runiform()
    capture log close t22
    log using "`W'/t22.log", text replace name(t22)
    dataprobe sk x, gatesonly snapshot(s22, replace)
    local k1 "`r(snapshot_key)'"
    log close t22
    assert "`k1'" == "x"
    _cnt "`W'/t22.log" "snapshot: strL not tried as key (merge refuses a strL key; recast str# first): sk"
    assert r(n) == 1
    recast str5 sk
    capture log close t22
    log using "`W'/t22b.log", text replace name(t22)
    dataprobe sk x, gatesonly snapshot(s22, replace)
    local k2 "`r(snapshot_key)'"
    log close t22
    assert "`k2'" == "sk"
    _cnt "`W'/t22b.log" "strL not tried"
    assert r(n) == 0
}
local trc = _rc
capture restore
_t `trc' "T22 snapshot: a qualifying strL is named in a note and never the key; a str5 copy becomes the key, no note"

**## T23 groupstat on an empty sample and all-missing values: deterministic
capture noisily {
    clear
    quietly set obs 20
    generate g = mod(_n, 2)
    generate y = .
    generate x = _n
    capture erase "`W'/t23.dta"
    dataprobe x, gatesonly groupstat(mean y, by(g) band(0 1)) warn ledger("`W'/t23.dta")
    dataprobe x, gatesonly groupstat(n y, by(g) band(0 1)) warn
    assert r(n_violations) == 0
    keep if 0
    capture noisily dataprobe x, groupstat(mean x, by(g) band(0 1)) snapshot(s23, replace) warn
    assert _rc == 0 & r(n_violations) == 1
    preserve
    quietly use "`W'/t23.dta", clear
    quietly keep if family == "groupstat" & status != "review"
    assert _N == 2 & status == "warn"
    assert strpos(observed, "2 groups undefined") > 0
    restore
}
local trc = _rc
capture restore
_t `trc' "T23 groupstat: all-missing groups warn as undefined, n of all-missing is 0, an empty sample warns 'no rows in scope'"

**# Result
display as text _newline "RESULT: test_datamap_v210_coverage tests=$TC pass=$PASS fail=$FAIL"
if $FAIL > 0 exit 1
