* test_rangematch_basic.do — Basic smoke tests for rangematch
* Tests: simple joins, unmatched rows, no-match case

capture ado uninstall rangematch
local cwd "`c(pwd)'"
local cwd_len = strlen("`cwd'")
if substr("`cwd'", `cwd_len' - 2, 3) == "/qa" {
    local qa_dir "`cwd'"
    local pkg_dir = substr("`cwd'", 1, `cwd_len' - 3)
}
else {
    local pkg_dir "`cwd'"
    local qa_dir "`pkg_dir'/qa"
}
adopath ++ "`pkg_dir'"

tempfile master_basic using_basic master_known using_known ///
    master_unmatched using_unmatched master_conflict using_conflict ///
    master_dense using_dense

clear
set obs 5
gen int id = _n
gen double date_low  = mdy(1, 1, 2020) + (_n - 1) * 30
gen double date_high = date_low + 15
format date_low date_high %td
save "`master_basic'", replace

clear
set obs 10
gen int uid = _n
gen double event_date = mdy(1, 1, 2020) + (_n - 1) * 10
format event_date %td
gen double value = runiform()
save "`using_basic'", replace

* -----------------------------------------------------------------------
* Test 1: Simple range join
* -----------------------------------------------------------------------
use "`master_basic'", clear
rangematch event_date date_low date_high ///
    using "`using_basic'"

assert _N > 0
confirm variable id
confirm variable date_low
confirm variable date_high
confirm variable uid
confirm variable value
confirm variable event_date

assert r(N_master) == 5
assert r(N_using)  == 10
assert r(N_pairs) > 0

display as result "PASS: Test 1 — simple range join"

* -----------------------------------------------------------------------
* Test 2: Verify correctness with known data
* -----------------------------------------------------------------------
clear
input int id double(lo hi)
1 1 3
2 5 7
3 10 12
end
save "`master_known'", replace

clear
input int uid double keyval
1 1
2 2
3 5
4 7
5 10
6 15
end
save "`using_known'", replace

use "`master_known'", clear
rangematch keyval lo hi ///
    using "`using_known'"

* id=1, lo=1, hi=3: should match keyval 1, 2
* id=2, lo=5, hi=7: should match keyval 5, 7
* id=3, lo=10, hi=12: should match keyval 10
assert r(N_pairs) == 5
assert r(N_unmatched) == 0

sort id keyval
assert id[1] == 1 & keyval[1] == 1
assert id[2] == 1 & keyval[2] == 2
assert id[3] == 2 & keyval[3] == 5
assert id[4] == 2 & keyval[4] == 7
assert id[5] == 3 & keyval[5] == 10

display as result "PASS: Test 2 — known-data correctness"

* -----------------------------------------------------------------------
* Test 3: Unmatched master rows (default behavior)
* -----------------------------------------------------------------------
clear
input int id double(lo hi)
1 1 3
2 100 200
3 5 7
end
save "`master_unmatched'", replace

clear
input int uid double keyval
1 2
2 6
3 15
end
save "`using_unmatched'", replace

use "`master_unmatched'", clear
rangematch keyval lo hi ///
    using "`using_unmatched'"

* id=1, lo=1, hi=3: matches keyval=2
* id=2, lo=100, hi=200: no match → unmatched row
* id=3, lo=5, hi=7: matches keyval=6
assert r(N_pairs) == 3    // 2 matched + 1 unmatched
assert r(N_unmatched) == 1

sort id
assert id[2] == 2
assert uid[2] == .

display as result "PASS: Test 3 — unmatched master rows"

* -----------------------------------------------------------------------
* Test 4: unmatched(none)
* -----------------------------------------------------------------------
use "`master_unmatched'", clear
rangematch keyval lo hi ///
    using "`using_unmatched'", ///
    unmatched(none)

assert r(N_pairs) == 2
assert r(N_unmatched) == 0
assert _N == 2

display as result "PASS: Test 4 — unmatched(none)"

* -----------------------------------------------------------------------
* Test 5: keepusing()
* -----------------------------------------------------------------------
use "`master_known'", clear
rangematch keyval lo hi ///
    using "`using_known'", ///
    keepusing(uid)

confirm variable uid
* keyval is not in master (master has: id lo hi), and keepusing(uid) was
* specified, so keyval should NOT be in output
capture confirm variable keyval
if _rc == 0 {
    display as error "FAIL: keyval should not be in output with keepusing(uid)"
    error 9
}

display as result "PASS: Test 5 — keepusing()"

* -----------------------------------------------------------------------
* Test 6: generate()
* -----------------------------------------------------------------------
use "`master_unmatched'", clear
rangematch keyval lo hi ///
    using "`using_unmatched'", ///
    generate(_merge)

confirm variable _merge
sort id
assert _merge[2] == 1  // unmatched (id=2 had no match)
assert _merge[1] == 3  // matched
assert _merge[3] == 3  // matched

display as result "PASS: Test 6 — generate()"

* -----------------------------------------------------------------------
* Test 7: Data restored on error
* -----------------------------------------------------------------------
sysuse auto, clear
local orig_N = _N
capture noisily rangematch keyval lo hi ///
    using "nonexistent_file.dta"
assert _rc != 0
assert _N == `orig_N'

display as result "PASS: Test 7 — data restored on error"

* -----------------------------------------------------------------------
* Test 8: suffix() and prefix()
* -----------------------------------------------------------------------
clear
input int id double(lo hi keyval)
1 1 3 99
end
save "`master_conflict'", replace

clear
input int uid double keyval
1 2
end
save "`using_conflict'", replace

* Default suffix _U should resolve conflict
use "`master_conflict'", clear
rangematch keyval lo hi ///
    using "`using_conflict'"

confirm variable keyval      // master's keyval
confirm variable keyval_U    // using's keyval (renamed)
assert keyval[1] == 99       // master value
assert keyval_U[1] == 2      // using value

display as result "PASS: Test 8 — default suffix resolves name conflict"

* -----------------------------------------------------------------------
* Test 9: maxpairs() guard
* -----------------------------------------------------------------------
clear
set obs 100
gen int id = _n
gen double lo = 0
gen double hi = 1000
save "`master_dense'", replace

clear
set obs 100
gen int uid = _n
gen double keyval = _n
save "`using_dense'", replace

use "`master_dense'", clear
capture noisily rangematch keyval lo hi ///
    using "`using_dense'", ///
    maxpairs(50)

assert _rc == 198

display as result "PASS: Test 9 — maxpairs() guard"

display as result _newline "ALL BASIC TESTS PASSED"
