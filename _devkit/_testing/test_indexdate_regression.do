// Regression test: ensure existing synthesis still works without indexdate
version 16.0
set more off
set varabbrev off

cap program drop synthdata
run synthdata/synthdata.ado

local test_errors = 0

// TEST: Smart synthesis without indexdate (regression)
di as txt "TEST: Smart synthesis without indexdate (regression test)"
clear
set obs 50
set seed 42
gen double x = rnormal(100, 15)
gen double y = x * 2 + rnormal(0, 5)
gen int cat = ceil(runiform() * 3)
gen double mydate = td(01jan2020) + _n * 7
format mydate %td

synthdata, smart replace
assert _N == 50
confirm variable x
confirm variable y
confirm variable cat
confirm variable mydate
di as txt "PASS: Smart synthesis without indexdate works"

// TEST: Parametric synthesis without indexdate (regression)
di as txt "TEST: Parametric synthesis without indexdate (regression test)"
clear
set obs 50
set seed 43
gen double x = rnormal(100, 15)
gen double mydate = td(01jan2020) + _n * 7
format mydate %td

synthdata, dates(mydate) parametric replace
assert _N == 50
di as txt "PASS: Parametric without indexdate works"

// TEST: Bootstrap synthesis without indexdate (regression)
di as txt "TEST: Bootstrap synthesis without indexdate (regression test)"
clear
set obs 50
set seed 44
gen double x = rnormal(100, 15)
gen double mydate = td(01jan2020) + _n * 7
format mydate %td

synthdata, dates(mydate) bootstrap replace
assert _N == 50
di as txt "PASS: Bootstrap without indexdate works"

// TEST: Sequential synthesis without indexdate (regression)
di as txt "TEST: Sequential synthesis without indexdate (regression test)"
clear
set obs 50
set seed 45
gen double x = rnormal(100, 15)
gen double mydate = td(01jan2020) + _n * 7
format mydate %td

synthdata, dates(mydate) sequential replace
assert _N == 50
di as txt "PASS: Sequential without indexdate works"

if `test_errors' == 0 {
    di as txt _dup(60) "="
    di as txt "ALL REGRESSION TESTS PASSED"
    di as txt _dup(60) "="
}
