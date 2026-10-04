*! test_datamap_v180.do Version 1.0.0  2026/09/30
*! Known-answer regressions for the 1.8.0 review: date-string bounds,
*! compare masking, groupstat bands under masking, dataqa register, export,
*! and compare, jumps() order invariance, zero counts, ledger() quoting
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set processors 1
set linesize 255
capture log close _all
log using "test_datamap_v180.log", replace text name(main)
local pkg_dir = regexr("`c(pwd)'", "/qa$", "")
tempfile base
* tempfile names repeat across suites in one runner session: own suffix
local work "`base'_v180work"
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

* Dates across 2019 and 2020: 12 monthly dates from 15jan2019, 12 from 15jan2020
capture program drop _v180_dates
program define _v180_dates
    clear
    set obs 24
    gen long id = _n
    gen dt = mdy(mod(_n - 1, 12) + 1, 15, 2019 + (_n > 12))
    format dt %td
    gen mo = mofd(dt)
    format mo %tm
    gen double tc = cofd(dt) + 3600000
    format tc %tc
end

* Rows "id t v | id t v | ..." as a dataset (input cannot run inside a
* capture block or a loop)
capture program drop _v180_rows
program define _v180_rows
    args spec
    clear
    local n = 0
    local rest `"`spec'"'
    while `"`rest'"' != "" {
        gettoken row rest : rest, parse("|")
        if `"`row'"' == "|" continue
        local ++n
        local r`n' `"`row'"'
    }
    quietly set obs `n'
    generate long id = .
    generate double t = .
    generate double v = .
    forvalues i = 1/`n' {
        local j = 0
        foreach c in id t v {
            local ++j
            quietly replace `c' = real("`: word `j' of `r`i'''") in `i'
        }
    }
end

* Observed number of the single ledger row of the last call
capture program drop _v180_obsnum
program define _v180_obsnum, rclass
    args file
    preserve
    quietly use `"`file'"', clear
    quietly summarize seq, meanonly
    quietly keep if seq == r(max)
    assert _N == 1
    return scalar num = observed_num[1]
    return local observed = observed[1]
    return local status = status[1]
    restore
end

**## B01 ISO and slash date bounds are dates, not arithmetic
foreach b in "2020-01-01" "2020/01/01" "01jan2020" "td(01jan2020)" {
    local ++tests
    capture noisily {
        _v180_dates
        * oracle: the rows before 1 January 2020, counted directly
        quietly count if dt < mdy(1, 1, 2020)
        local expect = r(N)
        assert `expect' == 12
        capture erase "`work'/led_b01.dta"
        capture datacheck, gatesonly inrange(dt `b' .) ledger("`work'/led_b01.dta")
        assert _rc == 9
        _v180_obsnum "`work'/led_b01.dta"
        assert r(num) == `expect'
        assert "`r(status)'" == "fail"
    }
    local rc = _rc
    if `rc' {
        local ++fail
        display as error "FAIL: B01 inrange(dt `b' .) counts the 2019 rows (rc=`rc')"
    }
    else {
        local ++pass
        display as result "PASS: B01 inrange(dt `b' .) counts the 2019 rows"
    }
}

**## B02 stat() band and coverage() bounds written as ISO dates
local ++tests
capture noisily {
    _v180_dates
    quietly summarize dt, detail
    * the median lies in [01jun2019, 01jun2021]; as arithmetic the band
    * would be [2012, 2014], i.e. 1965
    assert inrange(r(p50), mdy(6, 1, 2019), mdy(6, 1, 2021))
    datacheck, gatesonly stat(median dt 2019-06-01 2021-06-01)
    assert r(n_errors) == 0
    capture datacheck, gatesonly stat(median dt 2021-01-01 2021-06-01)
    assert _rc == 9
    * as arithmetic lo 2017 > hi 1977 and the call errors r(198)
    datacheck, gatesonly coverage(dt 2019-01-01 2020-12-31, gap(60))
    assert r(n_errors) == 0
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: B02 stat() and coverage() ISO bounds (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: B02 stat() and coverage() ISO bounds"
}

**## B03 %tm and %tc date strings in the variable's own unit
local ++tests
capture noisily {
    _v180_dates
    capture erase "`work'/led_b03.dta"
    capture datacheck, gatesonly inrange(mo 2020-01 .) ledger("`work'/led_b03.dta")
    assert _rc == 9
    _v180_obsnum "`work'/led_b03.dta"
    assert r(num) == 12
    * %tc: 01jan2020 is clock time, not 21915 milliseconds
    capture datacheck, gatesonly inrange(tc 01jan2020 .) ledger("`work'/led_b03.dta")
    assert _rc == 9
    _v180_obsnum "`work'/led_b03.dta"
    assert r(num) == 12
    datacheck, gatesonly inrange(tc 01jan2019 31dec2020)
    assert r(n_errors) == 0
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: B03 %tm and %tc date bounds (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: B03 %tm and %tc date bounds"
}

**## B04 a bound naming a variable is refused, a plain number is kept
local ++tests
capture noisily {
    _v180_dates
    * as an expression, id would be id[1] = 1 and the gate would pass
    capture datacheck, gatesonly inrange(id 0 dt)
    assert _rc == 198
    capture datacheck, gatesonly stat(mean id 0 dt)
    assert _rc == 198
    datacheck, gatesonly inrange(id 1e0 24)
    assert r(n_errors) == 0
    capture datacheck, gatesonly inrange(id 1e0 23)
    assert _rc == 9
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: B04 variable-name bound refused (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: B04 variable-name bound refused"
}

**## B05 unmasked inrange() message prints date extremes in date format
local ++tests
capture noisily {
    _v180_dates
    capture erase "`work'/led_b05.dta"
    capture datacheck, gatesonly inrange(dt 01jan2020 .) ledger("`work'/led_b05.dta")
    assert _rc == 9
    _v180_obsnum "`work'/led_b05.dta"
    local o `"`r(observed)'"'
    assert strpos(`"`o'"', "min 15jan2019") > 0
    assert strpos(`"`o'"', "max 15dec2020") > 0
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: B05 date extremes in date format (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: B05 date extremes in date format"
}

**## C01 SCHEMA COMPARE never prints two Ns beside a masked delta
local ++tests
capture noisily {
    sysuse auto, clear
    preserve
    quietly drop in 1/2
    quietly save "`work'/base72.dta", replace
    restore
    capture log close c01
    log using "`work'/c01.log", replace text name(c01)
    capture noisily datacheck mpg price, compare("`work'/base72.dta") maskrare nomissing
    local crc = _rc
    log close c01
    assert `crc' == 9
    local t = fileread("`work'/c01.log")
    assert strpos(`"`t'"', "delta <5 (masked)") > 0
    * 74 - 72 = 2 would be recovered from the two printed counts
    assert strpos(`"`t'"', "baseline 72") == 0
    assert strpos(`"`t'"', "baseline [suppressed]") > 0
    * without masking both counts print
    log using "`work'/c01b.log", replace text name(c01)
    capture noisily datacheck mpg price, compare("`work'/base72.dta") nomissing
    log close c01
    local t = fileread("`work'/c01b.log")
    assert strpos(`"`t'"', "N: current 74, baseline 72, delta 2") > 0
}
local rc = _rc
capture log close c01
if `rc' {
    local ++fail
    display as error "FAIL: C01 compare N masking (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: C01 compare N masking"
}

**## C02 a small current N withholds the delta
local ++tests
capture noisily {
    sysuse auto, clear
    quietly save "`work'/base74.dta", replace
    keep in 1/3
    capture log close c02
    log using "`work'/c02.log", replace text name(c02)
    capture noisily datacheck mpg price, compare("`work'/base74.dta") maskrare nomissing
    log close c02
    local t = fileread("`work'/c02.log")
    assert strpos(`"`t'"', "N: current <5, baseline [suppressed], delta [suppressed]") > 0
    assert strpos(`"`t'"', "-71") == 0
}
local rc = _rc
capture log close c02
if `rc' {
    local ++fail
    display as error "FAIL: C02 small current N withholds the delta (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: C02 small current N withholds the delta"
}

**## G01 groupstat band verdict does not depend on maskrare
local ++tests
capture noisily {
    clear
    set obs 40
    gen g = cond(_n <= 3, 1, cond(_n <= 20, 2, 3))
    gen x = 10
    replace x = 1000 if g == 1
    * oracle: group 1 has 3 rows, mean 1000, outside [5, 15]
    quietly summarize x if g == 1
    assert r(N) == 3 & r(mean) == 1000
    capture datacheck, gatesonly groupstat(mean x, by(g) band(5 15))
    assert _rc == 9
    capture erase "`work'/led_g01.dta"
    capture datacheck, gatesonly groupstat(mean x, by(g) band(5 15)) maskrare ///
        ledger("`work'/led_g01.dta")
    assert _rc == 9
    preserve
    use "`work'/led_g01.dta", clear
    quietly keep if status == "fail"
    assert _N == 1
    * the small group's value stays masked
    assert regexm(observed, "^mean [[]suppressed[]](;|$)")
    assert missing(observed_num) & obs_masked == 1
    restore
    * an explicit min() leaves the small group out by choice
    datacheck, gatesonly groupstat(mean x, by(g) band(5 15) min(5)) maskrare
    assert r(n_errors) == 0
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: G01 groupstat band under maskrare (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: G01 groupstat band under maskrare"
}

**## Q01 dataqa report: the clean row names the dataset's own run
local ++tests
capture noisily {
    capture erase "`work'/led_q01.dta"
    sysuse auto, clear
    datacheck, gatesonly isid(make) ledger("`work'/led_q01.dta", run(A)) name(cars)
    datacheck, gatesonly isid(make) ledger("`work'/led_q01.dta", run(B)) name(trucks)
    datacheck, gatesonly isid(make) ledger("`work'/led_q01.dta", run(B)) name(cars)
    dataqa report using "`work'/led_q01.dta", markdown("`work'/q01.md") replace
    assert r(n_rows) == 2
    local t = fileread("`work'/q01.md")
    assert strpos(`"`t'"', "| B | trucks |") > 0
    assert strpos(`"`t'"', "| A | trucks |") == 0
    assert strpos(`"`t'"', "| A, B | cars |") > 0
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: Q01 report run attribution (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: Q01 report run attribution"
}

**## Q02 dataqa export names only the reasons that apply
local ++tests
capture noisily {
    capture erase "`work'/led_q02.dta"
    sysuse auto, clear
    datacheck, gatesonly isid(make) ledger("`work'/led_q02.dta", run(U))
    datacheck, gatesonly isid(make) maskrare mincell(3) ledger("`work'/led_q02.dta", run(L))
    capture log close q02
    log using "`work'/q02.log", replace text name(q02)
    capture noisily dataqa export using "`work'/led_q02.dta", run(U) saving("`work'/rel.dta") replace
    local e1 = _rc
    capture noisily dataqa export using "`work'/led_q02.dta", run(L) saving("`work'/rel.dta") replace
    local e2 = _rc
    log close q02
    assert `e1' == 459 & `e2' == 459
    * a house threshold above the mask names the low mask
    datacheck, gatesonly isid(make) maskrare ledger("`work'/led_q02.dta", run(M))
    log using "`work'/q02b.log", replace text name(q02)
    capture noisily dataqa export using "`work'/led_q02.dta", run(M) saving("`work'/rel.dta") replace threshold(10)
    local e3 = _rc
    log close q02
    assert `e3' == 459
    local t3 = fileread("`work'/q02b.log")
    assert strpos(`"`t3'"', "1 row(s) were masked below the house threshold of 10") > 0
    assert strpos(`"`t3'"', "not run under maskrare") == 0
    local t = fileread("`work'/q02.log")
    * run U: unmasked only; run L: masked below the threshold (and so
    * not masked in the export sense)
    assert strpos(`"`t'"', "1 row(s) come from calls not run under maskrare") > 0
    local n1 = (length(`"`t'"') - length(subinstr(`"`t'"', "were masked below the house threshold", "", .))) / ///
        length("were masked below the house threshold")
    assert `n1' == 0
}
local rc = _rc
capture log close q02
if `rc' {
    local ++fail
    display as error "FAIL: Q02 export refusal reasons (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: Q02 export refusal reasons"
}

**## J01 jumps() does not depend on the order of the data
local ++tests
capture noisily {
    local seen ""
    forvalues s = 1/12 {
        _v180_rows "1 1 1 | 1 1 100 | 1 2 100 | 2 1 5 | 2 2 6 | 2 3 7"
        * a different input order and sort seed each round
        set seed `s'
        generate double u = runiform()
        sort u
        drop u
        set sortseed `s'
        capture erase "`work'/led_j01.dta"
        datacheck, gatesonly jumps(id t v) ledger("`work'/led_j01.dta")
        _v180_obsnum "`work'/led_j01.dta"
        local seen "`seen' `r(num)'"
    }
    * oracle: same-time values in ascending order: 1 -> 100 is the one jump
    * (ratio 100 > 10); 100 -> 100 and id 2 have none
    local useen : list uniq seen
    display "jump counts seen: `seen'"
    assert "`useen'" == "1"
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: J01 jumps() order invariance (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: J01 jumps() order invariance"
}

**## J02 jumps() skips missing measures and names same-time ties
local ++tests
capture noisily {
    _v180_rows "1 1 10 | 1 2 . | 1 3 1000 | 2 1 5 | 2 . 500 | 2 2 6"
    capture erase "`work'/led_j02.dta"
    datacheck, gatesonly jumps(id t v) ledger("`work'/led_j02.dta")
    _v180_obsnum "`work'/led_j02.dta"
    * oracle: 10 -> 1000 once the missing value is skipped; id 2's row with
    * a missing time is not a measure, so 5 -> 6 only
    assert r(num) == 1
    use "`work'/led_j02.dta", clear
    assert strpos(message[1], "same-time") == 0
    _v180_rows "1 1 10 | 1 1 10"
    datacheck, gatesonly jumps(id t v) ledger("`work'/led_j02.dta")
    use "`work'/led_j02.dta", clear
    assert strpos(message[_N], "same-time measures in 1 persons ordered by value") > 0
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: J02 jumps() missing measures and ties (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: J02 jumps() missing measures and ties"
}

**## Z01 a zero count prints as 0 under masking, even beside a small total
local ++tests
capture noisily {
    clear
    set obs 3
    generate x = .
    generate y = _n
    capture log close z01
    log using "`work'/z01.log", replace text name(z01)
    datacheck x y, maskrare nomissing
    datamvp x y, maskrare nodrop
    log close z01
    local t = fileread("`work'/z01.log")
    * datacheck header: 0 complete cases of 3 rows
    assert strpos(`"`t'"', "(complete cases: 0 = 0.0%)") > 0
    assert strpos(`"`t'"', "all but") == 0
    * datamvp summary and variable table: y has 0 missing, x has 3
    assert regexm(`"`t'"', "Complete cases: +0  \(  0\.0%\)")
    assert regexm(`"`t'"', "y +[|] +[a-z]+ +<5 +0 +0\.0")
    * x: all 3 missing; Obs 0 prints as 0 beside the masked Miss
    assert regexm(`"`t'"', "x +[|] +[a-z]+ +0 +<5 +[.]")
}
local rc = _rc
capture log close z01
if `rc' {
    local ++fail
    display as error "FAIL: Z01 zero counts under masking (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: Z01 zero counts under masking"
}

**## L01 ledger(): quoted filename with a comma, and run() inside the quotes
local ++tests
capture noisily {
    sysuse auto, clear
    capture erase "`work'/a, b.dta"
    datacheck, gatesonly isid(make) ledger("`work'/a, b.dta", run(A))
    confirm file "`work'/a, b.dta"
    preserve
    use "`work'/a, b.dta", clear
    assert run[1] == "A"
    restore
    capture log close l01
    log using "`work'/l01.log", replace text name(l01)
    capture noisily datacheck, gatesonly isid(make) ledger("`work'/l01.dta, run(A)")
    local lrc = _rc
    log close l01
    assert `lrc' == 198
    local t = fileread("`work'/l01.log")
    assert strpos(`"`t'"', `"run() belongs outside the quoted filename; type ledger("`work'/l01.dta", run(A))"') > 0
    confirm new file "`work'/l01.dta"
}
local rc = _rc
capture log close l01
if `rc' {
    local ++fail
    display as error "FAIL: L01 ledger() quoting (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: L01 ledger() quoting"
}

**## L02 dataqa set refuses datacheck's ledger(file, run()) form
local ++tests
capture noisily {
    macro drop DATAMAP_DQ
    capture noisily dataqa set ledger("`work'/l02.dta", run(A))
    assert _rc == 198
    assert `"$DATAMAP_DQ"' == ""
    dataqa set ledger("`work'/l02.dta") run(A)
    assert strpos(`"$DATAMAP_DQ"', "run(A)") > 0
    dataqa set clear
}
local rc = _rc
macro drop DATAMAP_DQ
if `rc' {
    local ++fail
    display as error "FAIL: L02 dataqa set ledger() run() form (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: L02 dataqa set ledger() run() form"
}

**## C03 dataqa compare flags a count or stat() withheld in one run only
local ++tests
capture noisily {
    capture erase "`work'/led_c03.dta"
    sysuse auto, clear
    preserve
    keep in 1/3
    * 3 rows: n_scope and the mean are withheld under the mask
    datacheck, gatesonly isid(make) stat(mean price 0 100000) maskrare ///
        name(cars) ledger("`work'/led_c03.dta", run(B0))
    restore
    datacheck, gatesonly isid(make) stat(mean price 0 100000) maskrare ///
        name(cars) ledger("`work'/led_c03.dta", run(R1))
    capture log close c03
    log using "`work'/c03.log", replace text name(c03)
    dataqa compare using "`work'/led_c03.dta", run(R1) baseline(B0)
    local nf = r(n_flags)
    log close c03
    local t = fileread("`work'/c03.log")
    * two gate entries, each with n_scope withheld in B0; the mean too
    assert `nf' == 3
    assert strpos(`"`t'"', "withheld -> 74 (withheld under the mask in one run)") > 0
    assert regexm(`"`t'"', "stat\(mean price\): masked -> 6165")
    * the withheld 3 is never printed
    assert strpos(`"`t'"', "3 -> 74") == 0
}
local rc = _rc
capture log close c03
if `rc' {
    local ++fail
    display as error "FAIL: C03 compare one-sided withheld values (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: C03 compare one-sided withheld values"
}

**## C04 dataqa compare against a baseline N of 0
local ++tests
capture noisily {
    capture erase "`work'/led_c04.dta"
    sysuse auto, clear
    datacheck, gatesonly isid(make) name(cars) ledger("`work'/led_c04.dta", run(B0))
    datacheck, gatesonly isid(make) name(cars) ledger("`work'/led_c04.dta", run(R1))
    * a ledger edited or written elsewhere: the baseline N is 0
    preserve
    use "`work'/led_c04.dta", clear
    replace n_scope = 0 if run == "B0"
    save "`work'/led_c04.dta", replace
    restore
    capture log close c04
    log using "`work'/c04.log", replace text name(c04)
    dataqa compare using "`work'/led_c04.dta", run(R1) baseline(B0)
    local nf = r(n_flags)
    log close c04
    assert `nf' == 1
    local t = fileread("`work'/c04.log")
    assert strpos(`"`t'"', "0 -> 74 (baseline 0)") > 0
}
local rc = _rc
capture log close c04
if `rc' {
    local ++fail
    display as error "FAIL: C04 compare baseline N of 0 (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: C04 compare baseline N of 0"
}

sysdir set PLUS "`oldplus'"
sysdir set PERSONAL "`oldpersonal'"
display "RESULT: test_datamap_v180 tests=`tests' pass=`pass' fail=`fail'"
log close main
if `fail' exit 1
