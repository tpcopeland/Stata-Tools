clear all
version 16.1
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

local test_count = 0

**# Closure rules against brute-force joinby oracle
local ++test_count
tempfile master using expected actual
clear
input int mid byte group double(lo hi)
1 1 1 3
2 1 3 5
3 2 0 0
4 3 10 8
end
save "`master'", replace

clear
input int uid byte group double ukey
1 1 1
2 1 3
3 1 5
4 2 0
5 2 .
6 9 2
end
save "`using'", replace

foreach closed in both left right none {
    use "`master'", clear
    joinby group using "`using'", unmatched(none)
    keep if ukey < .
    if "`closed'" == "both" {
        keep if ukey >= lo & ukey <= hi
    }
    else if "`closed'" == "left" {
        keep if ukey >= lo & ukey < hi
    }
    else if "`closed'" == "right" {
        keep if ukey > lo & ukey <= hi
    }
    else {
        keep if ukey > lo & ukey < hi
    }
    keep mid uid
    sort mid uid
    save "`expected'", replace

    use "`master'", clear
    rangematch ukey lo hi using "`using'", by(group) ///
        keepusing(uid ukey) unmatched(none) closed(`closed')
    keep mid uid
    sort mid uid
    save "`actual'", replace

    use "`expected'", clear
    cf _all using "`actual'"
}
display as result "PASS: closed() modes match brute-force oracle"

**# Randomized grouped range joins against brute-force joinby oracle
local ++test_count
tempfile random_master random_using random_expected random_actual
set seed 121943
clear
set obs 40
gen int mid = _n
gen byte group = mod(_n, 7) + 1
gen double lo = floor(runiform() * 80) - 10
gen double width = floor(runiform() * 12)
gen double hi = lo + width
replace hi = lo - 1 if mod(mid, 13) == 0
drop width
save "`random_master'", replace

clear
set obs 55
gen int uid = _n
gen byte group = mod(_n * 3, 7) + 1
gen double ukey = floor(runiform() * 100) - 15
replace ukey = . if mod(uid, 17) == 0
gen double shuffle = runiform()
sort shuffle
drop shuffle
save "`random_using'", replace

use "`random_master'", clear
joinby group using "`random_using'", unmatched(none)
keep if ukey < . & ukey >= lo & ukey <= hi
keep mid uid
sort mid uid
save "`random_expected'", replace

use "`random_master'", clear
rangematch ukey lo hi using "`random_using'", by(group) ///
    keepusing(uid ukey) unmatched(none)
keep mid uid
sort mid uid
save "`random_actual'", replace

use "`random_expected'", clear
cf _all using "`random_actual'"
display as result "PASS: randomized grouped range join matches oracle"

**# Full-outer accounting, including missing using keys
local ++test_count
tempfile outer_master outer_using
clear
input int mid byte group double(lo hi)
1 1 1 3
2 1 9 10
3 2 0 2
end
save "`outer_master'", replace

clear
input int uid byte group double ukey
1 1 2
2 1 20
3 2 .
4 3 1
end
save "`outer_using'", replace

use "`outer_master'", clear
rangematch ukey lo hi using "`outer_using'", by(group) ///
    keepusing(uid ukey) unmatched(both) generate(status) ///
    masterid(master_row) usingid(using_row) stats
assert r(N_pairs) == 6
assert r(N_matched_pairs) == 1
assert r(N_unmatched) == 5
assert r(N_matched_master) == 1
assert r(N_unmatched_master) == 2
assert r(N_matched_using) == 1
assert r(N_unmatched_using) == 3
count if status == 1
assert r(N) == 2
count if status == 2
assert r(N) == 3
count if status == 3
assert r(N) == 1
count if status == 2 & uid == 3 & missing(ukey)
assert r(N) == 1
assert master_row == mid if status == 1
assert using_row == uid if status == 2
display as result "PASS: unmatched(both) full-outer accounting"

**# Nearest, ties, and signed distance known answers
local ++test_count
tempfile near_using
clear
input int uid double keyval
1  8
2  8
3 12
4 12
5 20
end
save "`near_using'", replace

clear
input int mid double(keyval lo hi)
1 10 5 15
2 20 5 25
3 30 26 35
end
rangematch keyval lo hi using "`near_using'", ///
    keepusing(uid) unmatched(master) nearest(both) ties(all) ///
    distance(delta) generate(status) stats
assert r(N_pairs) == 6
assert r(N_matched_pairs) == 5
assert r(N_unmatched_master) == 1
sort mid uid
assert mid[1] == 1 & uid[1] == 1 & delta[1] == -2
assert mid[2] == 1 & uid[2] == 2 & delta[2] == -2
assert mid[3] == 1 & uid[3] == 3 & delta[3] == 2
assert mid[4] == 1 & uid[4] == 4 & delta[4] == 2
assert mid[5] == 2 & uid[5] == 5 & delta[5] == 0
assert mid[6] == 3 & missing(uid[6]) & missing(delta[6])
assert status[6] == 1
display as result "PASS: nearest(), ties(all), and distance() known answers"

**# Scalar offset equivalence to explicit bounds
local ++test_count
tempfile offset_using offset_actual offset_expected
clear
input int uid double event_date
1  90
2 100
3 105
4 111
5 200
end
save "`offset_using'", replace

clear
input int mid double event_date
1 100
2 110
end
rangematch event_date -10 0 using "`offset_using'", ///
    keepusing(uid) unmatched(none)
keep mid uid
sort mid uid
save "`offset_actual'", replace

clear
input int mid int uid
1 1
1 2
2 2
2 3
end
sort mid uid
save "`offset_expected'", replace

use "`offset_expected'", clear
cf _all using "`offset_actual'"
display as result "PASS: scalar offset bounds match explicit oracle"

display as result "ALL RANGEMATCH VALIDATION TESTS PASSED"
display "RESULT: validation_rangematch_oracle tests=`test_count' pass=`test_count' fail=0"
