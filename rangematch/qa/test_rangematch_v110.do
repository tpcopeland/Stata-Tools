quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
clear all
version 16.1

local TESTS 0
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


**# Scalar offset syntax
local ++TESTS

tempfile using_offsets
clear
input int uid double event_date
1  -25
2  -10
3    0
4   10
5   25
6   31
7   40
8   50
9   80
end
save "`using_offsets'", replace

clear
input int id double event_date
1 0
2 50
end

rangematch event_date -30 30 using "`using_offsets'", ///
    keepusing(uid) unmatched(none)

assert r(N_pairs) == 10
assert _N == 10
sort id uid
assert id[1] == 1 & uid[1] == 1
assert id[2] == 1 & uid[2] == 2
assert id[3] == 1 & uid[3] == 3
assert id[4] == 1 & uid[4] == 4
assert id[5] == 1 & uid[5] == 5
assert id[6] == 2 & uid[6] == 5
assert id[7] == 2 & uid[7] == 6
assert id[8] == 2 & uid[8] == 7
assert id[9] == 2 & uid[9] == 8
assert id[10] == 2 & uid[10] == 9

**# Literal open bound with scalar and variable counterparts
local ++TESTS

clear
input int id double event_date
1 0
2 50
end

rangematch event_date . 0 using "`using_offsets'", ///
    keepusing(uid) unmatched(none)

sort id uid
assert r(N_pairs) == 11
assert _N == 11
assert id[1] == 1 & uid[1] == 1
assert id[2] == 1 & uid[2] == 2
assert id[3] == 1 & uid[3] == 3
assert id[4] == 2 & uid[4] == 1
assert id[5] == 2 & uid[5] == 2
assert id[6] == 2 & uid[6] == 3
assert id[7] == 2 & uid[7] == 4
assert id[8] == 2 & uid[8] == 5
assert id[9] == 2 & uid[9] == 6
assert id[10] == 2 & uid[10] == 7
assert id[11] == 2 & uid[11] == 8

clear
input int id double(event_date high)
1 0 10
2 50 80
end

rangematch event_date . high using "`using_offsets'", ///
    keepusing(uid) unmatched(none)

sort id uid
assert r(N_pairs) == 13
assert _N == 13
assert id[1] == 1 & uid[1] == 1
assert id[2] == 1 & uid[2] == 2
assert id[3] == 1 & uid[3] == 3
assert id[4] == 1 & uid[4] == 4
assert id[5] == 2 & uid[5] == 1
assert id[6] == 2 & uid[6] == 2
assert id[7] == 2 & uid[7] == 3
assert id[8] == 2 & uid[8] == 4
assert id[9] == 2 & uid[9] == 5
assert id[10] == 2 & uid[10] == 6
assert id[11] == 2 & uid[11] == 7
assert id[12] == 2 & uid[12] == 8
assert id[13] == 2 & uid[13] == 9

**# Endpoint closure semantics
local ++TESTS

tempfile using_closed
clear
input int uid double event_date
1 10
2 15
3 20
end
save "`using_closed'", replace

clear
input int id double(event_date lo hi)
1 15 10 20
end

rangematch event_date lo hi using "`using_closed'", ///
    keepusing(uid) unmatched(none) closed(both)
sort uid
assert r(N_pairs) == 3
assert _N == 3
assert uid[1] == 1
assert uid[2] == 2
assert uid[3] == 3

clear
input int id double(event_date lo hi)
1 15 10 20
end

rangematch event_date lo hi using "`using_closed'", ///
    keepusing(uid) unmatched(none) closed(left)
sort uid
assert r(N_pairs) == 2
assert _N == 2
assert uid[1] == 1
assert uid[2] == 2

clear
input int id double(event_date lo hi)
1 15 10 20
end

rangematch event_date lo hi using "`using_closed'", ///
    keepusing(uid) unmatched(none) closed(right)
sort uid
assert r(N_pairs) == 2
assert _N == 2
assert uid[1] == 2
assert uid[2] == 3

clear
input int id double(event_date lo hi)
1 15 10 20
end

rangematch event_date lo hi using "`using_closed'", ///
    keepusing(uid) unmatched(none) closed(none)
assert r(N_pairs) == 1
assert _N == 1
assert uid[1] == 2

**# frame() output and replace contract
local ++TESTS

capture frame drop results
clear
input int id double(event_date lo hi) byte sentinel
1 15 10 20 42
2 99 0 1 43
end

rangematch event_date lo hi using "`using_closed'", ///
    keepusing(uid) unmatched(none) frame(results)

assert "`r(frame)'" == "results"
assert _N == 2
assert sentinel[1] == 42
assert sentinel[2] == 43
frame results: assert _N == 3
frame results: sort uid
frame results: assert uid[1] == 1
frame results: assert uid[2] == 2
frame results: assert uid[3] == 3

capture noisily rangematch event_date lo hi using "`using_closed'", ///
    keepusing(uid) unmatched(none) frame(results)
assert _rc != 0

rangematch event_date lo hi using "`using_closed'", ///
    keepusing(uid) unmatched(none) frame(results) replace
assert "`r(frame)'" == "results"
frame results: assert _N == 3
capture frame drop results

**# stats returns and returned macros
local ++TESTS

tempfile using_stats
clear
input int uid byte group double event_date
1 1 1
2 1 2
end
save "`using_stats'", replace

clear
input int id byte group double(event_date lo hi)
1 1 0 0 5
2 1 100 100 200
3 2 0 0 5
end

rangematch event_date lo hi using "`using_stats'", ///
    by(group) keepusing(uid) stats

assert r(N_master) == 3
assert r(N_using) == 2
assert r(N_pairs) == 4
assert r(N_unmatched) == 2
assert r(max_matches) == 2
assert r(N_matched_master) == 1
assert reldif(r(mean_matches), 2/3) < 1e-12
assert r(N_empty_groups) == 1
assert "`r(cmd)'" == "rangematch"
assert strlen(`"`r(cmdline)'"') > 0
assert strpos(`"`r(cmdline)'"', "rangematch") > 0
assert "`r(using)'" == "`using_stats'"

**# dryrun and count preserve current data and do not create output frame
local ++TESTS

capture frame drop dryrun_results
clear
input int id double(event_date lo hi) byte sentinel
1 15 10 20 42
2 99 0 1 43
end

rangematch event_date lo hi using "`using_closed'", ///
    keepusing(uid) unmatched(none) dryrun frame(dryrun_results)

assert r(N_pairs) == 3
assert r(N_unmatched) == 0
assert _N == 2
assert sentinel[1] == 42
assert sentinel[2] == 43
capture frame dryrun_results: describe
assert _rc != 0

rangematch event_date lo hi using "`using_closed'", ///
    keepusing(uid) unmatched(none) count frame(dryrun_results)

assert r(N_pairs) == 3
assert r(N_unmatched) == 0
assert _N == 2
assert sentinel[1] == 42
assert sentinel[2] == 43
capture frame dryrun_results: describe
assert _rc != 0

**# Dense output succeeds beyond st_matrix row limits
local ++TESTS

tempfile using_dense
clear
set obs 75
gen int uid = _n
gen double event_date = _n
save "`using_dense'", replace

clear
set obs 150
gen int id = _n
gen double event_date = 38
gen double lo = 1
gen double hi = 75

local old_matsize = c(matsize)
capture set matsize 400
capture noisily rangematch event_date lo hi using "`using_dense'", ///
    keepusing(uid) unmatched(none)
local dense_rc = _rc
if `dense_rc' == 0 {
    local dense_pairs = r(N_pairs)
    local dense_N = _N
}
capture set matsize `old_matsize'

assert `dense_rc' == 0
assert `dense_pairs' == 11250
assert `dense_N' == 11250

**# Empty using behavior
local ++TESTS

tempfile using_empty
clear
set obs 0
gen int uid = .
gen double event_date = .
save "`using_empty'", replace

clear
input int id double(event_date lo hi)
1 15 10 20
2 99 0 1
end

rangematch event_date lo hi using "`using_empty'", ///
    keepusing(uid) unmatched(master)

assert r(N_pairs) == 2
assert r(N_unmatched) == 2
assert _N == 2
assert uid[1] == .
assert uid[2] == .

clear
input int id double(event_date lo hi)
1 15 10 20
2 99 0 1
end

rangematch event_date lo hi using "`using_empty'", ///
    keepusing(uid) unmatched(none)

assert r(N_pairs) == 0
assert r(N_unmatched) == 0
capture confirm scalar r(N_matched_master)
assert _rc == 111
assert _N == 0

display as result "ALL RANGEMATCH V1.1.0 TESTS PASSED"

* Terminal sentinel (RM-I20). This suite is assert-driven: a failed assert
* aborts the do-file, so reaching this line IS the pass condition and the
* absence of this line is what a runner must treat as failure.
display "RESULT: rangematch_v110 tests=`TESTS' pass=`TESTS' fail=0"
