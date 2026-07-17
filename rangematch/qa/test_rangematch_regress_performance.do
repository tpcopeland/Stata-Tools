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


**# Performance-path regressions
local ++TESTS

tempfile using_missing_by
clear
input int uid double group double keyval str8 event_type
1 . 3 "missing"
2 1 3 "observed"
end
save "`using_missing_by'", replace

clear
input int id double group double(lo hi) str8 arm
1 . 1 5 "missgrp"
2 1 1 5 "obsgrp"
end

rangematch keyval lo hi using "`using_missing_by'", ///
    by(group) keepusing(uid event_type) unmatched(none) nosort

assert r(N_pairs) == 2
assert r(N_unmatched) == 0
sort id uid
assert id[1] == 1
assert missing(group[1])
assert uid[1] == 1
assert arm[1] == "missgrp"
assert event_type[1] == "missing"
assert id[2] == 2
assert group[2] == 1
assert uid[2] == 2
assert arm[2] == "obsgrp"
assert event_type[2] == "observed"

tempfile using_strings
clear
input int uid double group double keyval str8 event_type
1 1 3 "rash"
2 2 7 "fatigue"
end
save "`using_strings'", replace

clear
input int id double group double(lo hi) str8 arm
1 1 1 5 "drug_a"
2 2 6 9 "drug_b"
end

rangematch keyval lo hi using "`using_strings'", ///
    by(group) keepusing(uid event_type) unmatched(none) nosort

assert r(N_pairs) == 2
sort id
assert id[1] == 1
assert arm[1] == "drug_a"
assert uid[1] == 1
assert event_type[1] == "rash"
assert id[2] == 2
assert arm[2] == "drug_b"
assert uid[2] == 2
assert event_type[2] == "fatigue"

display as result "ALL RANGEMATCH PERFORMANCE-PATH REGRESSION TESTS PASSED"

* Terminal sentinel (RM-I20). This suite is assert-driven: a failed assert
* aborts the do-file, so reaching this line IS the pass condition and the
* absence of this line is what a runner must treat as failure.
display "RESULT: test_rangematch_regress_performance tests=`TESTS' pass=`TESTS' fail=0"
