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


**# masterid(), usingid(), and unmatched(both)
local ++TESTS

tempfile using_outer
clear
input int uid byte group double event_date str5 code
1 1 5  "a"
2 1 50 "b"
3 2 7  "c"
4 3 .  "miss"
end
save "`using_outer'", replace

clear
input int id byte group double(event_date lo hi)
1 1 10 0 10
2 2 100 90 110
end

rangematch event_date lo hi using "`using_outer'", ///
    by(group) keepusing(uid code) unmatched(both) ///
    generate(_merge) masterid(master_row) usingid(using_row) stats

assert r(N_pairs) == 5
assert r(N_unmatched) == 4
assert r(N_matched_master) == 1
assert r(N_unmatched_master) == 1
assert r(N_unmatched_using) == 3

count if _merge == 3
assert r(N) == 1
assert id == 1 if _merge == 3
assert uid == 1 if _merge == 3
assert master_row == 1 if _merge == 3
assert using_row == 1 if _merge == 3

count if _merge == 1
assert r(N) == 1
assert id == 2 if _merge == 1
assert missing(uid) if _merge == 1
assert master_row == 2 if _merge == 1
assert missing(using_row) if _merge == 1

count if _merge == 2
assert r(N) == 3
assert missing(id) if _merge == 2
assert missing(master_row) if _merge == 2
assert !missing(using_row) if _merge == 2
assert group == 3 if uid == 4
assert code == "miss" if uid == 4

**# nearest() and ties()
local ++TESTS

tempfile using_nearest
clear
input int uid double event_date
1 8
2 12
3 12
4 20
5 25
end
save "`using_nearest'", replace

clear
input int id double(event_date lo hi)
1 10 0 30
2 22 0 30
end

rangematch event_date lo hi using "`using_nearest'", ///
    keepusing(uid) unmatched(none) nearest(both) ties(all)

assert r(N_pairs) == 4
assert "`r(nearest)'" == "both"
assert "`r(ties)'" == "all"
sort id uid
assert id[1] == 1 & uid[1] == 1
assert id[2] == 1 & uid[2] == 2
assert id[3] == 1 & uid[3] == 3
assert id[4] == 2 & uid[4] == 4

clear
input int id double(event_date lo hi)
1 10 0 30
2 22 0 30
end

rangematch event_date lo hi using "`using_nearest'", ///
    keepusing(uid) unmatched(none) nearest(after) ties(last)

assert r(N_pairs) == 2
sort id uid
assert id[1] == 1 & uid[1] == 3
assert id[2] == 2 & uid[2] == 5

**# saving() leaves the caller's data unchanged
local ++TESTS

tempfile saved_output
clear
input int id double(event_date lo hi) byte sentinel
1 10 0 15 42
2 22 20 22 43
end

rangematch event_date lo hi using "`using_nearest'", ///
    keepusing(uid) unmatched(none) saving("`saved_output'", replace)

assert _N == 2
assert sentinel[1] == 42
assert sentinel[2] == 43
assert "`r(saving)'" == `"`saved_output'"'
confirm file "`saved_output'"

preserve
use "`saved_output'", clear
assert _N == 4
confirm variable uid
restore

**# Numeric by() precision-hazard guard
local ++TESTS

tempfile using_float_by
clear
input int uid float group double event_date
1 1 5
end
save "`using_float_by'", replace

clear
input int id double group double(event_date lo hi)
1 1 10 0 10
end

capture noisily rangematch event_date lo hi using "`using_float_by'", ///
    by(group) keepusing(uid)
assert _rc == 109

**# Integer by() storage widening remains allowed
local ++TESTS

tempfile using_long_by
clear
input int uid long group double event_date
1 1 5
end
save "`using_long_by'", replace

clear
input int id int group double(event_date lo hi)
1 1 10 0 10
end

rangematch event_date lo hi using "`using_long_by'", ///
    by(group) keepusing(uid) unmatched(none)

assert r(N_pairs) == 1
assert uid[1] == 1

**# Density warning path does not alter results
local ++TESTS

tempfile using_dense_warn
clear
set obs 101
gen int uid = _n
gen double event_date = _n
save "`using_dense_warn'", replace

clear
input int id double(event_date lo hi)
1 50 1 101
end

rangematch event_date lo hi using "`using_dense_warn'", ///
    keepusing(uid) unmatched(none) stats

assert r(N_pairs) == 101
assert r(max_matches) == 101
assert _N == 101

**# Wide numeric materialization smoke test
local ++TESTS

tempfile using_wide
clear
set obs 3
gen int uid = _n
gen double event_date = _n
forvalues j = 1/40 {
    gen double x`j' = _n + `j'
}
gen str3 tag = "u" + string(_n)
save "`using_wide'", replace

clear
input int id double(event_date lo hi)
1 2 1 3
end

rangematch event_date lo hi using "`using_wide'", ///
    keepusing(uid x1 x40 tag) unmatched(none)

assert r(N_pairs) == 3
quietly describe, varlist short
assert "`r(varlist)'" == "id event_date lo hi uid x1 x40 tag"
sort uid
assert x1[1] == 2
assert x40[3] == 43
assert tag[2] == "u2"

display as result "ALL RANGEMATCH V1.2.0 TESTS PASSED"

* Terminal sentinel (RM-I20). This suite is assert-driven: a failed assert
* aborts the do-file, so reaching this line IS the pass condition and the
* absence of this line is what a runner must treat as failure.
display "RESULT: rangematch_v120 tests=`TESTS' pass=`TESTS' fail=0"
