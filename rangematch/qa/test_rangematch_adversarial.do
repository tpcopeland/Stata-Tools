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

capture program drop _rm_no_internal_frames
program define _rm_no_internal_frames
    foreach fr in __rm_master __rm_using __rm_uwork __rm_out __rm_grp __rm_grp_u {
        capture frame `fr': describe
        assert _rc != 0
    }
end

local test_count = 0
tempfile master using saved_exists

clear
input int id double(keyval lo hi) byte group str1 site str8 arm
1 10   8  12 1 "A" "alpha"
2 20  18  22 1 "A" "beta"
3 30  28  32 2 "B" "gamma"
4 40 100 110 2 "B" "delta"
end
save "`master'", replace

clear
input int uid double keyval byte group str1 site str8 tag
1  9 1 "A" "u1"
2 10 1 "A" "u2"
3 21 1 "A" "u3"
4 29 2 "B" "u4"
5 35 2 "B" "u5"
end
save "`using'", replace

**# touse, varabbrev, and cleanup contracts
local ++test_count
local old_varabbrev = c(varabbrev)
set varabbrev on
use "`master'", clear
rangematch keyval lo hi using "`using'" if id <= 2 in 1/3, ///
    by(group site) keepusing(uid tag) unmatched(none) stats
assert r(N_master) == 2
assert r(N_pairs) == 3
assert r(N_unmatched) == 0
assert r(N_matched_master) == 2
assert "`c(varabbrev)'" == "on"
sort id uid
assert id[1] == 1 & uid[1] == 1
assert id[2] == 1 & uid[2] == 2
assert id[3] == 2 & uid[3] == 3
_rm_no_internal_frames
display as result "PASS: touse filters, varabbrev restore, cleanup"

local ++test_count
use "`master'", clear
capture noisily rangematch keyval lo hi using "`using'", unmatched(bad)
assert _rc == 198
assert "`c(varabbrev)'" == "on"
assert _N == 4
_rm_no_internal_frames
set varabbrev `old_varabbrev'
display as result "PASS: varabbrev restored on parser error"

**# parser arity and invalid option contracts
local ++test_count
use "`master'", clear
capture noisily rangematch keyval lo using "`using'"
assert _rc == 102
capture noisily rangematch keyval lo hi extra using "`using'"
assert _rc == 103
capture noisily rangematch keyval lo not_a_bound using "`using'"
assert _rc == 198
display as result "PASS: positional parser errors"

local ++test_count
use "`master'", clear
foreach opt in "closed(open)" "nearest(side)" "ties(middle)" ///
    "ties(first)" "unmatched(bad)" "tolerance(-1)" "tolerance(.)" ///
    "maxpairs(-1)" "maxpairs(-1000)" {
    capture noisily rangematch keyval lo hi using "`using'", `opt'
    assert _rc == 198
    _rm_no_internal_frames
}
display as result "PASS: invalid matching options rejected"

local ++test_count
use "`master'", clear
capture noisily rangematch keyval lo hi using "`using'", replace
assert _rc == 198
capture noisily rangematch keyval lo hi using "`using'", frame(default)
assert _rc == 198
capture noisily rangematch keyval lo hi using "`using'", frame(__rm_bad)
assert _rc == 198
capture frame drop rm_exists
frame create rm_exists
capture noisily rangematch keyval lo hi using "`using'", frame(rm_exists)
assert _rc == 110
capture frame drop rm_exists
display as result "PASS: frame and replace guards"

local ++test_count
use "`master'", clear
clear
set obs 1
gen byte x = 1
save "`saved_exists'", replace
use "`master'", clear
capture noisily rangematch keyval lo hi using "`using'", saving("`saved_exists'")
assert _rc != 0
assert _N == 4
capture noisily rangematch keyval lo hi using "`using'", saving("`saved_exists'", append)
assert _rc == 198
capture noisily rangematch keyval lo hi using "`using'", saving("`saved_exists'", replace) frame(saved_frame)
assert _rc == 198
capture noisily rangematch keyval lo hi using "`using'", saving("`saved_exists'", replace) dryrun
assert _rc == 198
_rm_no_internal_frames
display as result "PASS: saving() guards"

**# key requirements and using-side validation
local ++test_count
clear
input str3 skey double(lo hi)
"a" 1 3
end
capture noisily rangematch skey -1 1 using "`using'"
assert _rc == 111
capture noisily rangematch skey lo hi using "`using'", nearest(both)
assert _rc == 111
capture noisily rangematch skey lo hi using "`using'", distance(delta)
assert _rc == 111
display as result "PASS: numeric master key requirements"

local ++test_count
tempfile using_bad_type using_no_key
clear
input int uid str2 keyval
1 "10"
end
save "`using_bad_type'", replace
clear
input int uid double other
1 10
end
save "`using_no_key'", replace
use "`master'", clear
capture noisily rangematch keyval lo hi using "`using_bad_type'"
assert _rc == 109
capture noisily rangematch keyval lo hi using "`using_no_key'"
assert _rc == 111
_rm_no_internal_frames
display as result "PASS: using-side key validation"

local ++test_count
use "`master'", clear
capture noisily rangematch keyval lo hi using default
assert _rc == 198
capture frame drop __rm_bad
frame create __rm_bad
capture noisily rangematch keyval lo hi using __rm_bad
assert _rc == 198
capture frame drop __rm_bad
display as result "PASS: using frame guards"

local ++test_count
tempfile using_str_group
clear
input int uid double keyval str1 group
1 10 "1"
end
save "`using_str_group'", replace
use "`master'", clear
capture noisily rangematch keyval lo hi using "`using_str_group'", by(group)
assert _rc == 109
display as result "PASS: by() incompatible storage rejected"

**# output-name collision and naming contracts
local ++test_count
use "`master'", clear
capture noisily rangematch keyval lo hi using "`using'", generate(id)
assert _rc == 110
capture noisily rangematch keyval lo hi using "`using'", distance(id)
assert _rc == 110
capture noisily rangematch keyval lo hi using "`using'", masterid(id)
assert _rc == 110
capture noisily rangematch keyval lo hi using "`using'", usingid(id)
assert _rc == 110
display as result "PASS: generated output names must be new"

local ++test_count
tempfile master_collision using_collision
clear
input int id double(keyval lo hi u_uid)
1 10 8 12 999
end
save "`master_collision'", replace
clear
input int uid double keyval
1 10
end
save "`using_collision'", replace
use "`master_collision'", clear
capture noisily rangematch keyval lo hi using "`using_collision'", ///
    prefix(u_) all
assert _rc == 110
display as result "PASS: prefix()/suffix()/all collision rejected"

local ++test_count
use "`master'", clear
rangematch keyval lo hi using "`using'", ///
    prefix(U_) suffix(_x) all unmatched(none)
confirm variable U_uid_x
confirm variable U_keyval_x
confirm variable U_group_x
assert r(N_pairs) == 4
sort id U_uid_x
assert U_uid_x[1] == 1
assert U_keyval_x[1] == 9
display as result "PASS: all prefix/suffix naming"

local ++test_count
tempfile using_internal_names
clear
input int uid str1 site double keyval long __rm_obs byte __rm_gid
11 "A" 10 901 7
12 "B" 30 902 8
end
save "`using_internal_names'", replace
clear
input int id str1 site double(keyval lo hi) long __rm_obs ///
    double(__rm_low __rm_high __rm_key) byte __rm_gid
1 "A" 10  8 12 101 201 301 401 5
2 "B" 30 28 32 102 202 302 402 6
end
rangematch keyval lo hi using "`using_internal_names'", ///
    by(site) keepusing(uid __rm_obs __rm_gid) unmatched(none) stats
assert r(N_pairs) == 2
assert r(N_matched_pairs) == 2
confirm variable __rm_obs
confirm variable __rm_low
confirm variable __rm_high
confirm variable __rm_key
confirm variable __rm_gid
confirm variable __rm_obs_U
confirm variable __rm_gid_U
sort id uid
assert __rm_obs[1] == 101
assert __rm_obs_U[1] == 901
assert __rm_gid[2] == 6
assert __rm_gid_U[2] == 8
_rm_no_internal_frames
display as result "PASS: user __rm_* variables survive tempvar work frames"

**# unmatched, nearest, ties, assert, and scalar edge contracts
local ++test_count
use "`master'", clear
rangematch keyval lo hi using "`using'", unmatched(using) generate(status) ///
    keepusing(uid)
assert r(N_pairs) == 5
assert r(N_unmatched) == 1
count if status == 1
assert r(N) == 0
count if status == 2
assert r(N) == 1
count if status == 3
assert r(N) == 4
display as result "PASS: unmatched(using) keeps using-only rows only"

local ++test_count
tempfile using_ties
clear
input int uid double keyval
1  8
2  8
3 12
4 12
5 20
end
save "`using_ties'", replace
clear
input int id double(keyval lo hi)
1 10 5 15
2 20 5 25
end
rangematch keyval lo hi using "`using_ties'", ///
    keepusing(uid) unmatched(none) nearest(before) ties(first)
assert r(N_pairs) == 2
sort id uid
assert id[1] == 1 & uid[1] == 1
assert id[2] == 2 & uid[2] == 5
clear
input int id double(keyval lo hi)
1 10 5 15
end
rangematch keyval lo hi using "`using_ties'", ///
    keepusing(uid) unmatched(none) nearest(both) ties(last)
assert r(N_pairs) == 1
assert uid[1] == 4
display as result "PASS: nearest(before) and ties(first/last)"

local ++test_count
tempfile using_assert_both
clear
input int uid double keyval
1  9
2 21
end
save "`using_assert_both'", replace
clear
input int id double(keyval lo hi)
1 10  8 12
2 20 18 22
end
rangematch keyval lo hi using "`using_assert_both'", ///
    unmatched(none) assert(match using)
assert r(N_pairs) == 2
assert "`r(assert)'" == "match using"
display as result "PASS: assert(match using) succeeds when both sides matched"

local ++test_count
clear
input int id double keyval
1 10
2 .
end
rangematch keyval -2 2 using "`using'", keepusing(uid)
assert r(N_pairs) == 3
assert r(N_unmatched) == 1
sort id uid
assert id[1] == 1 & uid[1] == 1
assert id[2] == 1 & uid[2] == 2
assert id[3] == 2 & missing(uid[3])
display as result "PASS: scalar offsets with missing master key"

display as result "ALL RANGEMATCH ADVERSARIAL TESTS PASSED"
display "RESULT: test_rangematch_adversarial tests=`test_count' pass=`test_count' fail=0"
