* test_rangematch_missing.do — Missing value and boundary tests

version 16.1

local TESTS 0
quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
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

tempfile miss_master miss_using miss_lo miss_using2 miss_hi ///
    miss_both miss_inverted miss_using3 miss_ext

* -----------------------------------------------------------------------
* Test 1: Missing using key never matches
* -----------------------------------------------------------------------
clear
input int id double(lo hi)
1 1 100
end
save "`miss_master'", replace

clear
input int uid double keyval
1 5
2 .
3 10
end
save "`miss_using'", replace

use "`miss_master'", clear
rangematch keyval lo hi using "`miss_using'"

* uid=2 (keyval=.) should NOT match even though lo=1, hi=100
assert r(N_pairs) == 2 // uid=1(5) and uid=3(10) match
sort keyval
assert keyval[1] == 5
assert keyval[2] == 10

local ++TESTS
display as result "PASS: Test 1 — missing using key never matches"

* -----------------------------------------------------------------------
* Test 2: Missing lower bound = -infinity
* -----------------------------------------------------------------------
clear
input int id double(lo hi)
1 . 5
end
save "`miss_lo'", replace

clear
input int uid double keyval
1 -100
2 0
3 5
4 6
end
save "`miss_using2'", replace

use "`miss_lo'", clear
rangematch keyval lo hi using "`miss_using2'"

* Missing lo = -infinity, hi = 5
* Should match keyval -100, 0, 5 but NOT 6
assert r(N_pairs) == 3
sort keyval
assert keyval[1] == -100
assert keyval[2] == 0
assert keyval[3] == 5

local ++TESTS
display as result "PASS: Test 2 — missing lower bound = -infinity"

* -----------------------------------------------------------------------
* Test 3: Missing upper bound = +infinity
* -----------------------------------------------------------------------
clear
input int id double(lo hi)
1 5 .
end
save "`miss_hi'", replace

use "`miss_hi'", clear
rangematch keyval lo hi using "`miss_using2'"

* lo = 5, missing hi = +infinity
* Should match keyval 5, 6 but NOT -100, 0
assert r(N_pairs) == 2
sort keyval
assert keyval[1] == 5
assert keyval[2] == 6

local ++TESTS
display as result "PASS: Test 3 — missing upper bound = +infinity"

* -----------------------------------------------------------------------
* Test 4: Both bounds missing = match all non-missing
* -----------------------------------------------------------------------
clear
input int id double(lo hi)
1 . .
end
save "`miss_both'", replace

use "`miss_both'", clear
rangematch keyval lo hi using "`miss_using2'"

* Both missing = match all non-missing keys
assert r(N_pairs) == 4

local ++TESTS
display as result "PASS: Test 4 — both bounds missing = match all"

* -----------------------------------------------------------------------
* Test 5: lo > hi = no match
* -----------------------------------------------------------------------
clear
input int id double(lo hi)
1 10 5
2 1 3
end
save "`miss_inverted'", replace

clear
input int uid double keyval
1 2
2 7
end
save "`miss_using3'", replace

use "`miss_inverted'", clear
rangematch keyval lo hi using "`miss_using3'"

* id=1 (lo=10, hi=5): inverted → unmatched
* id=2 (lo=1, hi=3): matches keyval=2
assert r(N_pairs) == 2    // 1 matched + 1 unmatched
assert r(N_unmatched) == 1

sort id
assert uid[1] == .   // id=1 is unmatched (inverted bounds)
assert uid[2] == 1   // id=2 matched uid=1 (keyval=2)

local ++TESTS
display as result "PASS: Test 5 — lo > hi = no match (retained as unmatched)"

* -----------------------------------------------------------------------
* Test 6: Extended missing in bounds treated as system missing
* -----------------------------------------------------------------------
clear
input int id double(lo hi)
1 .a 5
end
save "`miss_ext'", replace

use "`miss_ext'", clear
rangematch keyval lo hi using "`miss_using2'"

* .a in lo should be treated as system missing → -infinity
* Should match keyval -100, 0, 5
assert r(N_pairs) == 3

local ++TESTS
display as result "PASS: Test 6 — extended missing in bounds"

display as result _newline "ALL MISSING VALUE TESTS PASSED"

* Terminal sentinel (RM-I20). This suite is assert-driven: a failed assert
* aborts the do-file, so reaching this line IS the pass condition and the
* absence of this line is what a runner must treat as failure.
display "RESULT: rangematch_missing tests=`TESTS' pass=`TESTS' fail=0"
