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


**# Shared using data for sweep regressions
local ++TESTS

tempfile using_speed
clear
input int uid double keyval
1 1
2 2
3 3
4 4
5 5
end
save "`using_speed'", replace

**# Unsorted master defaults to sorted sweep output
local ++TESTS

clear
input int id double(lo hi)
30 3 3
10 1 2
20 2 4
end

rangematch keyval lo hi using "`using_speed'", ///
    keepusing(uid) unmatched(none)

assert "`r(backend)'" == "sweep"
assert r(N_pairs) == 6
assert r(N_matched_pairs) == 6
assert r(N_unmatched) == 0
assert _N == 6
assert id[1] == 30 & uid[1] == 3
assert id[2] == 10 & uid[2] == 1
assert id[3] == 10 & uid[3] == 2
assert id[4] == 20 & uid[4] == 2
assert id[5] == 20 & uid[5] == 3
assert id[6] == 20 & uid[6] == 4

**# nosort keeps the binary backend for unsorted master intervals
local ++TESTS

clear
input int id double(lo hi)
30 3 3
10 1 2
20 2 4
end

rangematch keyval lo hi using "`using_speed'", ///
    keepusing(uid) unmatched(none) nosort

assert "`r(backend)'" == "binary"
assert "`r(nosort)'" == "nosort"
assert r(N_pairs) == 6
assert _N == 6
assert id[1] == 30 & uid[1] == 3
assert id[2] == 10 & uid[2] == 1
assert id[3] == 10 & uid[3] == 2
assert id[4] == 20 & uid[4] == 2
assert id[5] == 20 & uid[5] == 3
assert id[6] == 20 & uid[6] == 4

**# stats remains sweep-eligible and posts density results
local ++TESTS

clear
input int id double(lo hi)
1  1  2
2  2  4
3 10 11
end

rangematch keyval lo hi using "`using_speed'", ///
    keepusing(uid) stats

assert "`r(backend)'" == "sweep"
assert r(N_master) == 3
assert r(N_using) == 5
assert r(N_pairs) == 6
assert r(N_matched_pairs) == 5
assert r(N_unmatched) == 1
assert r(N_matched_master) == 2
assert r(N_unmatched_master) == 1
assert r(N_matched_using) == 4
assert r(N_unmatched_using) == 1
assert r(max_matches) == 3
assert reldif(r(mean_matches), 5/3) < 1e-12
assert r(median_matches) == 2
assert r(p50_matches) == 2
assert r(p90_matches) == 3
assert r(p99_matches) == 3
assert r(N_empty_groups) == 0
assert r(N_master_groups) == 1

**# assert(using) can run on the sweep path when all using rows match
local ++TESTS

clear
input int uid double keyval
1 1
2 2
3 3
end
tempfile using_assert_all
save "`using_assert_all'", replace

clear
input int id double(lo hi)
1 1 2
2 3 3
end

rangematch keyval lo hi using "`using_assert_all'", ///
    keepusing(uid) unmatched(none) assert(using)

assert "`r(backend)'" == "sweep"
assert "`r(assert)'" == "using"
assert r(N_pairs) == 3
assert r(N_matched_pairs) == 3
assert r(N_unmatched) == 0

clear
input int id double(lo hi)
1 1 2
end

capture noisily rangematch keyval lo hi using "`using_assert_all'", ///
    keepusing(uid) unmatched(none) assert(using)
assert _rc == 9
assert _N == 1

**# unmatched(using) materializes using-only rows from the sweep path
local ++TESTS

clear
input int uid double keyval
1 1
2 2
3 5
end
tempfile using_outer
save "`using_outer'", replace

clear
input int id double(lo hi)
1 1 2
end

rangematch keyval lo hi using "`using_outer'", ///
    keepusing(uid) unmatched(using) generate(_merge)

assert "`r(backend)'" == "sweep"
assert "`r(unmatched)'" == "using"
assert r(N_pairs) == 3
assert r(N_matched_pairs) == 2
assert r(N_unmatched) == 1
assert _N == 3
assert id[1] == 1 & uid[1] == 1 & _merge[1] == 3
assert id[2] == 1 & uid[2] == 2 & _merge[2] == 3
assert missing(id[3]) & uid[3] == 3 & _merge[3] == 2

**# unmatched(both) materializes master-only and using-only rows from sweep
local ++TESTS

clear
input int id double(lo hi)
1  1  2
2 10 11
end

rangematch keyval lo hi using "`using_outer'", ///
    keepusing(uid) unmatched(both) generate(_merge)

assert "`r(backend)'" == "sweep"
assert "`r(unmatched)'" == "both"
assert r(N_pairs) == 4
assert r(N_matched_pairs) == 2
assert r(N_unmatched) == 2
assert _N == 4
assert id[1] == 1 & uid[1] == 1 & _merge[1] == 3
assert id[2] == 1 & uid[2] == 2 & _merge[2] == 3
assert id[3] == 2 & missing(uid[3]) & _merge[3] == 1
assert missing(id[4]) & uid[4] == 3 & _merge[4] == 2

**# count and dryrun use the safe sweep fast path without changing data
local ++TESTS

clear
input int id double(lo hi sentinel)
30 3 3 103
10 1 2 101
20 2 4 102
end

rangematch keyval lo hi using "`using_speed'", ///
    keepusing(uid) unmatched(none) count nosort

assert "`r(backend)'" == "sweep"
assert "`r(count)'" == "count"
assert r(N_pairs) == 6
assert r(N_matched_pairs) == 6
assert r(N_unmatched) == 0
assert _N == 3
assert id[1] == 30 & sentinel[1] == 103
assert id[2] == 10 & sentinel[2] == 101
assert id[3] == 20 & sentinel[3] == 102

capture frame drop dryrun_results
rangematch keyval lo hi using "`using_speed'", ///
    keepusing(uid) unmatched(none) dryrun nosort frame(dryrun_results)

assert "`r(backend)'" == "sweep"
assert "`r(dryrun)'" == "dryrun"
assert r(N_pairs) == 6
assert r(N_matched_pairs) == 6
assert r(N_unmatched) == 0
assert _N == 3
assert id[1] == 30 & sentinel[1] == 103
assert id[2] == 10 & sentinel[2] == 101
assert id[3] == 20 & sentinel[3] == 102
capture frame dryrun_results: describe
assert _rc != 0

display as result "ALL RANGEMATCH SWEEP-OPTION REGRESSION TESTS PASSED"

* Terminal sentinel (RM-I20). This suite is assert-driven: a failed assert
* aborts the do-file, so reaching this line IS the pass condition and the
* absence of this line is what a runner must treat as failure.
display "RESULT: test_rangematch_regress_sweep_options tests=`TESTS' pass=`TESTS' fail=0"
