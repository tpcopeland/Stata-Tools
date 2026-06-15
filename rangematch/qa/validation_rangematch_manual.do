* validation_rangematch_manual.do — validate rangematch against independent,
* manual reference implementations of the same matching logic.
*
* These checks complement validation_rangematch_oracle.do. Where the oracle file
* leans on a joinby brute force for closure modes, randomized joins, full-outer
* accounting, nearest(both), and scalar offsets, this file pins the paths that
* file does not: per-mode unmatched() accounting, nearest(before)/nearest(after)
* with ties(), tolerance() boundary behavior, and multi-variable by(). The
* expected values are derived either from a hand-rolled joinby + inrange brute
* force or from hand-computed known answers, never from rangematch itself.
clear all
version 17.0

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
quietly net install rangematch, from("`pkg_dir'") replace

local test_count = 0

**# 1. Per-mode unmatched() accounting vs brute-force joinby reference
* Build a master and using where the matched-pair, unmatched-master, and
* unmatched-using counts are all nonzero, including a missing using key that
* must surface as an unmatched-using row.
local ++test_count
tempfile master using ufull
clear
input int mid double(lo hi)
1 0 2
2 5 7
3 10 12
end
save "`master'", replace
local N_master = 3

clear
input int uid double ukey
1 1
2 6
3 6
4 100
5 .
end
save "`using'", replace
local N_using_total = 5

* Manual reference: full within-group (single group) cross product, flag the
* in-range matched pairs with the same closed(both) rule rangematch uses.
use "`using'", clear
gen byte _one = 1
save "`ufull'", replace
use "`master'", clear
gen byte _one = 1
joinby _one using "`ufull'"
gen byte _in = (ukey < . & ukey >= lo & ukey <= hi)
quietly count if _in
local e_mp = r(N)
preserve
    quietly keep if _in
    quietly contract mid
    local e_mm = _N
restore
preserve
    quietly keep if _in
    quietly contract uid
    local e_mu = _N
restore
local e_unm_master = `N_master' - `e_mm'
local e_unm_using  = `N_using_total' - `e_mu'

* unmatched(none): only matched pairs
use "`master'", clear
rangematch ukey lo hi using "`using'", keepusing(uid ukey) unmatched(none) stats
assert r(N_matched_pairs) == `e_mp'
assert r(N_pairs)         == `e_mp'
assert r(N_unmatched)     == 0
assert r(N_matched_master) == `e_mm'
assert r(N_unmatched_master) == `e_unm_master'
assert r(N_matched_using)  == `e_mu'
assert r(N_unmatched_using) == `e_unm_using'

* unmatched(master): matched pairs + unmatched master rows
use "`master'", clear
rangematch ukey lo hi using "`using'", keepusing(uid ukey) unmatched(master)
assert r(N_pairs)     == `e_mp' + `e_unm_master'
assert r(N_unmatched) == `e_unm_master'

* unmatched(using): matched pairs + unmatched using rows (incl missing key)
use "`master'", clear
rangematch ukey lo hi using "`using'", keepusing(uid ukey) unmatched(using)
assert r(N_pairs)     == `e_mp' + `e_unm_using'
assert r(N_unmatched) == `e_unm_using'

* unmatched(both): matched pairs + both unmatched sides
use "`master'", clear
rangematch ukey lo hi using "`using'", keepusing(uid ukey) unmatched(both)
assert r(N_pairs)     == `e_mp' + `e_unm_master' + `e_unm_using'
assert r(N_unmatched) == `e_unm_master' + `e_unm_using'
display as result "PASS: per-mode unmatched() accounting matches brute-force reference"

**# 2. nearest(before)/nearest(after) with ties() known answers
* Master key 10 inside [0,20]; using keys 8,8,12,15 all in range.
*   nearest(before) -> keys at/below 10: {8,8} -> both u1,u2 (ties all)
*   nearest(after)  -> keys at/above 10: {12} -> u3
*   nearest(before) ties(first)/ties(last) -> single tied row
local ++test_count
tempfile near_using
clear
input int uid double keyval
1  8
2  8
3 12
4 15
end
save "`near_using'", replace

clear
input int mid double(keyval lo hi)
1 10 0 20
end
rangematch keyval lo hi using "`near_using'", keepusing(uid keyval) ///
    unmatched(none) nearest(before) ties(all) distance(delta)
sort mid uid
assert _N == 2
assert uid[1] == 1 & delta[1] == -2
assert uid[2] == 2 & delta[2] == -2

clear
input int mid double(keyval lo hi)
1 10 0 20
end
rangematch keyval lo hi using "`near_using'", keepusing(uid keyval) ///
    unmatched(none) nearest(after) ties(all) distance(delta)
sort mid uid
assert _N == 1
assert uid[1] == 3 & delta[1] == 2

clear
input int mid double(keyval lo hi)
1 10 0 20
end
rangematch keyval lo hi using "`near_using'", keepusing(uid keyval) ///
    unmatched(none) nearest(before) ties(first)
sort mid uid
assert _N == 1
assert uid[1] == 1

clear
input int mid double(keyval lo hi)
1 10 0 20
end
rangematch keyval lo hi using "`near_using'", keepusing(uid keyval) ///
    unmatched(none) nearest(before) ties(last)
sort mid uid
assert _N == 1
assert uid[1] == 2
display as result "PASS: nearest(before|after) and ties() known answers"

**# 3. tolerance() boundary behavior known answers
* Using keys sit just outside [5,10] on both ends. closed(both), no tolerance:
* neither matches. With tolerance(.001): both fall inside the widened bounds.
local ++test_count
tempfile tol_using
clear
input int uid double ukey
1 4.999
2 10.001
end
save "`tol_using'", replace

clear
input int mid double(lo hi)
1 5 10
end
rangematch ukey lo hi using "`tol_using'", keepusing(uid ukey) ///
    unmatched(none) tolerance(0)
assert r(N_matched_pairs) == 0

clear
input int mid double(lo hi)
1 5 10
end
rangematch ukey lo hi using "`tol_using'", keepusing(uid ukey) ///
    unmatched(none) tolerance(.001)
assert r(N_matched_pairs) == 2
assert r(tolerance) == .001
display as result "PASS: tolerance() boundary behavior known answers"

**# 4. Multi-variable by() vs brute-force joinby reference
local ++test_count
tempfile mby_master mby_using mby_ufull mby_expected mby_actual
clear
input int mid byte(g1 g2) double(lo hi)
1 1 1 0 5
2 1 2 0 5
3 2 1 0 5
4 1 1 10 20
end
save "`mby_master'", replace

clear
input int uid byte(g1 g2) double ukey
1 1 1 3
2 1 1 15
3 1 2 3
4 2 1 99
5 2 2 3
end
save "`mby_using'", replace

* Manual reference: brute-force joinby on the full by() key then inrange filter.
use "`mby_using'", clear
save "`mby_ufull'", replace
use "`mby_master'", clear
joinby g1 g2 using "`mby_ufull'"
keep if ukey < . & ukey >= lo & ukey <= hi
keep mid uid
sort mid uid
save "`mby_expected'", replace

use "`mby_master'", clear
rangematch ukey lo hi using "`mby_using'", by(g1 g2) ///
    keepusing(uid ukey) unmatched(none)
keep mid uid
sort mid uid
save "`mby_actual'", replace

use "`mby_expected'", clear
cf _all using "`mby_actual'"
display as result "PASS: multi-variable by() matches brute-force reference"

display as result "ALL RANGEMATCH MANUAL-REFERENCE VALIDATION TESTS PASSED"
display "RESULT: validation_rangematch_manual tests=`test_count' pass=`test_count' fail=0"
