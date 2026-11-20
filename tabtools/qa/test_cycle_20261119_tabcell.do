* test_cycle_20261119_tabcell.do - regressions for the 2026-11-19 tabcell review cycle
* F1 fixed formats never overflow into e-notation or drop thousands separators
* F2 a variable inside a scalar-path expression is refused, not read at obs 1
* F3 cols() is refused unless the source is matrix()
* F4 level(), digits(), pdp(), highpdp(), mincell() are judged by presence,
*    not by a magic default value

clear all
set more off
set varabbrev off
version 17.0

capture log close _tc1119
log using "test_cycle_20261119_tabcell.log", replace text name(_tc1119)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

**# F1: fixed formats print long numbers in full
**## Scalar path: default %9.2f, digits(), iqr, rate, negative values
local ++test_count
capture noisily {
    tabcell est, b(-123456.78) ll(-200000) ul(1000000)
    assert `"`r(cell)'"' == "-123456.78 (-200000.00, 1000000.00)"
    tabcell est, b(1234567.25) ll(1000000.5) ul(2000000.75) digits(2) local(c1)
    assert `"`c1'"' == "1234567.25 (1000000.50, 2000000.75)"
    assert `"`r(cell)'"' == "1234567.25 (1000000.50, 2000000.75)"
    tabcell est, b(123456789.5) ll(1234567.25) ul(2e9)
    assert `"`r(cell)'"' == "123456789.50 (1234567.25, 2000000000.00)"
    tabcell iqr, median(1500000) q1(1000000) q3(2500000)
    assert `"`r(cell)'"' == "1500000.00 (1000000.00, 2500000.00)"
    tabcell rate, e(5) pt(1e-9) per(1)
    assert !strpos(`"`r(cell)'"', "e+")
    assert substr(`"`r(cell)'"', 1, 13) == "5000000000.0 "
    * ordinary values are unchanged
    tabcell est, b(1) ll(0) ul(2)
    assert `"`r(cell)'"' == "1.00 (0.00, 2.00)"
    tabcell est, b(-0.001) ll(-0.002) ul(0.001)
    assert `"`r(cell)'"' == "0.00 (0.00, 0.00)"
}
if _rc == 0 {
    display as result "  PASS: F1 scalar est/iqr/rate print values >= 1e6 in full"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 scalar est/iqr/rate print values >= 1e6 in full (rc=`=_rc')"
    local ++fail_count
}

**## Counts keep their thousands separators at 1e9 and beyond
local ++test_count
capture noisily {
    tabcell n, n(999999999)
    assert `"`r(cell)'"' == "999,999,999"
    tabcell n, n(1234567890)
    assert `"`r(cell)'"' == "1,234,567,890"
    tabcell np, n(1234567890) d(2000000000)
    assert `"`r(cell)'"' == "1,234,567,890 (61.7)"
    tabcell enp, e(1234567890) n(2000000000)
    assert `"`r(cell)'"' == "1,234,567,890/2,000,000,000 (61.7)"
    tabcell n, n(12345)
    assert `"`r(cell)'"' == "12,345"
}
if _rc == 0 {
    display as result "  PASS: F1 nformat %12.0fc keeps separators on 10-digit counts"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 nformat %12.0fc keeps separators on 10-digit counts (rc=`=_rc')"
    local ++fail_count
}

**## generate() path: the same cells in the variable
local ++test_count
capture noisily {
    clear
    set obs 2
    gen double b = 1234567.25 in 1
    replace b = 2.5 in 2
    gen double nn = 1234567890 in 1
    replace nn = 12 in 2
    tabcell est, b(b) ll(b-1) ul(b+1) generate(g)
    assert g[1] == "1234567.25 (1234566.25, 1234568.25)"
    assert g[2] == "2.50 (1.50, 3.50)"
    tabcell n, n(nn) generate(gn)
    assert gn[1] == "1,234,567,890"
    assert gn[2] == "12"
}
if _rc == 0 {
    display as result "  PASS: F1 generate() cells print long numbers in full"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 generate() cells print long numbers in full (rc=`=_rc')"
    local ++fail_count
}

**## Formats whose width means something are untouched
local ++test_count
capture noisily {
    * zero padding keeps its width
    tabcell est, b(1.5) ll(1) ul(2) format(%09.2f)
    assert `"`r(cell)'"' == "000001.50 (000001.00, 000002.00)"
    * g format: the width sets the digits
    tabcell est, b(1234567.25) ll(1000000.5) ul(2000000.75) format(%9.0g)
    assert `"`r(cell)'"' == "1234567 (1000001, 2000001)"
    * an explicit wide format still works
    tabcell est, b(1234567.25) ll(1000000.5) ul(2000000.75) format(%21.2f)
    assert `"`r(cell)'"' == "1234567.25 (1000000.50, 2000000.75)"
    * a decimal-comma fc format widens too
    tabcell est, b(1234567.25) ll(1000000.5) ul(2000000.75) format(%9,2fc) sep(" to ")
    assert `"`r(cell)'"' == "1.234.567,25 (1.000.000,50 to 2.000.000,75)"
}
if _rc == 0 {
    display as result "  PASS: F1 zero-padded, g, wide and decimal-comma formats"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 zero-padded, g, wide and decimal-comma formats (rc=`=_rc')"
    local ++fail_count
}

**# F2: a variable inside an expression is refused in the scalar path
**## Refusals, and the local() macro is cleared
local ++test_count
capture noisily {
    clear
    set obs 5
    gen double x = _n * 10
    gen double y = x + 1
    local c2 "stale"
    capture tabcell n, n(x+1) local(c2)
    assert _rc == 198
    assert `"`c2'"' == ""
    capture tabcell est, b(x*1) ll(x*0.5) ul(x*2)
    assert _rc == 198
    capture tabcell est, b(1) ll(x*0.5) ul(2)
    assert _rc == 198
    capture tabcell est, b(1) se(sqrt(x))
    assert _rc == 198
    capture tabcell p, p(x/100)
    assert _rc == 198
    capture tabcell np, n(2) d(x)
    assert _rc == 198
    capture tabcell iqr, median(ln(x)) q1(1) q3(5)
    assert _rc == 198
    capture tabcell rate, e(3) pt(x + 0) per(1000)
    assert _rc == 198
    capture tabcell n, n(x[1] + y)
    assert _rc == 198
    capture tabcell n, n((x))
    assert _rc == 198
    * the bare name is still refused
    capture tabcell n, n(x)
    assert _rc == 198
    capture tabcell est, b(x) ll(1) ul(2)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: F2 x+1, ln(x), (x), x[1]+y in a scalar cell are refused"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 x+1, ln(x), (x), x[1]+y in a scalar cell are refused (rc=`=_rc')"
    local ++fail_count
}

**## Legitimate scalar expressions keep working
local ++test_count
capture noisily {
    clear
    set obs 5
    gen double x = _n * 10
    gen double y = 3 * x
    replace y = y + 1 in 1
    replace y = y - 1 in 2
    scalar k = 4
    matrix M = (1, 0.5, 2)
    matrix colnames M = b ll ul
    tabcell n, n(x[2])
    assert `"`r(cell)'"' == "20"
    tabcell n, n(x[_N] + 1)
    assert `"`r(cell)'"' == "51"
    tabcell n, n(_N)
    assert `"`r(cell)'"' == "5"
    tabcell n, n(k + scalar(k))
    assert `"`r(cell)'"' == "8"
    tabcell n, n(colnumb(M, "ul"))
    assert `"`r(cell)'"' == "3"
    tabcell est, b(el(M, 1, 1)) ll(M[1,2]) ul(M[1,3])
    assert `"`r(cell)'"' == "1.00 (0.50, 2.00)"
    tabcell n, n(real("7"))
    assert `"`r(cell)'"' == "7"
    * quoted strings with blanks around them keep their quotes
    tabcell n, n(real( "7" ) + colnumb(M, "ll"))
    assert `"`r(cell)'"' == "9"
    tabcell est, b(el(M, 1, colnumb(M, "b"))) ll(0) ul( 2 )
    assert `"`r(cell)'"' == "1.00 (0.00, 2.00)"
    clear
    set obs 3
    gen double v = _n
    matrix M2 = (1, 2, 3)
    matrix colnames M2 = a b c
    tabcell n, n(v * colnumb(M2, "c")) generate(gv)
    assert gv[2] == "6"
    capture tabcell n, n( )
    assert _rc == 198
    clear
    set obs 5
    gen double x = _n * 10
    gen double y = 3 * x
    replace y = y + 1 in 1
    replace y = y - 1 in 2
    quietly count if x > 20
    tabcell n, n(r(N))
    assert `"`r(cell)'"' == "3"
    quietly regress y x
    local bx = _b[x]
    local sx = _se[x]
    tabcell est, b(_b[x]) se(_se[x])
    assert reldif(r(estimate), `bx') < 1e-12
    assert reldif(r(lb), `bx' - invnormal(0.975) * `sx') < 1e-12
    tabcell est, b(round(_b[x], 1)) ll(1e-1) ul(c(level))
    assert `"`r(cell)'"' == "3.00 (0.10, 95.00)"
}
if _rc == 0 {
    display as result "  PASS: F2 x[2], _N, scalars, matrices, r(), _b[], c() still allowed"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 x[2], _N, scalars, matrices, r(), _b[], c() still allowed (rc=`=_rc')"
    local ++fail_count
}

**# F3: cols() belongs to matrix()
local ++test_count
capture noisily {
    clear
    set obs 20
    set seed 11192026
    gen double x = rnormal()
    gen double y = 1 + 0.5 * x + rnormal()
    quietly regress y x
    capture tabcell est x, cols(1 2 3)
    assert _rc == 198
    capture tabcell est, b(1) ll(0) ul(2) cols(1 2 3)
    assert _rc == 198
    quietly lincom x
    capture tabcell est, lincom cols(1 2 3)
    assert _rc == 198
    capture tabcell n, n(5) cols(1 2 3)
    assert _rc == 198
    capture tabcell p, p(0.5) cols(1 2 3)
    assert _rc == 198
    * with matrix() it still selects the columns
    matrix M = (9, 1, 0.5, 2)
    tabcell est, matrix(M 1) cols(2 3 4)
    assert `"`r(cell)'"' == "1.00 (0.50, 2.00)"
}
if _rc == 0 {
    display as result "  PASS: F3 cols() refused without matrix(), honoured with it"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 cols() refused without matrix(), honoured with it (rc=`=_rc')"
    local ++fail_count
}

**# F4: explicit values equal to the old sentinels are judged as given
local ++test_count
capture noisily {
    capture tabcell est, b(1) ll(0) ul(2) level(-1)
    assert _rc == 198
    capture tabcell est, b(1) se(0.5) level(-1)
    assert _rc == 198
    capture tabcell est, b(1) ll(0) ul(2) digits(-1)
    assert _rc == 198
    capture tabcell n, n(5) pdp(3)
    assert _rc == 198
    capture tabcell n, n(5) highpdp(2)
    assert _rc == 198
    capture tabcell p, p(0.5) mincell(0)
    assert _rc == 198
    capture tabcell est, b(1) se(0.5) level(abc)
    assert _rc == 198
    capture tabcell est, b(1) ll(0) ul(2) digits(1.5)
    assert _rc == 198
    capture tabcell p, p(0.5) pdp(abc)
    assert _rc == 198
    * the owning forms still take them
    tabcell p, p(0.0123) pdp(3) highpdp(2)
    assert `"`r(cell)'"' == "0.012"
    tabcell p, p(0.0123) pdp(2)
    assert `"`r(cell)'"' == "0.01"
    tabcell n, n(3) mincell(0)
    assert `"`r(cell)'"' == "3"
    tabcell n, n(3) mincell(5)
    assert `"`r(cell)'"' == "<5"
    tabcell est, b(1) ll(0) ul(2) digits(0)
    assert `"`r(cell)'"' == "1 (0, 2)"
    * level() absent: c(level); given: used
    tabcell est, b(1) se(0.5)
    assert r(level) == c(level)
    assert `"`r(cell)'"' == "1.00 (0.02, 1.98)"
    tabcell est, b(1) se(0.5) level(90)
    assert r(level) == 90
    assert reldif(r(lb), 1 - invnormal(0.95) * 0.5) < 1e-12
    * sep("") is the default ", " by the package contract (help tabtools##sep)
    tabcell est, b(1) ll(0) ul(2) sep("")
    assert `"`r(cell)'"' == "1.00 (0.00, 2.00)"
}
if _rc == 0 {
    display as result "  PASS: F4 level(-1), digits(-1), pdp(3)/highpdp(2) on n, mincell(0) on p refused"
    local ++pass_count
}
else {
    display as error "  FAIL: F4 level(-1), digits(-1), pdp(3)/highpdp(2) on n, mincell(0) on p refused (rc=`=_rc')"
    local ++fail_count
}

set varabbrev off
display as result "test_cycle_20261119_tabcell: `pass_count' passed, `fail_count' failed"
display "RESULT: test_cycle_20261119_tabcell tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _tc1119
if `fail_count' > 0 exit 1
