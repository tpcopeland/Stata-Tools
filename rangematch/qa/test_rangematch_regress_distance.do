quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
clear all
version 16.1
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

**# T1: distance() conformability when using has exactly one row
* Reproduces a pre-release bug: master_key_vals[1x1][mi[matched]] returned a row
* vector under matrix subscripting, causing rc=3200 in the elementwise op.
local ++test_count
tempfile using_one
clear
input int uid double keyval
1 10
end
save "`using_one'", replace

clear
input int id double(keyval lo hi)
1 10 5 15
2 10 5 15
3 10 5 15
end
rangematch keyval lo hi using "`using_one'", ///
    keepusing(uid) unmatched(none) distance(d)
assert _N == 3
assert d[1] == 0 & d[2] == 0 & d[3] == 0
display as result "PASS: distance() with single-row using dataset"

**# T2: distance() conformability when master has exactly one row
local ++test_count
tempfile using_three
clear
input int uid double keyval
1 9
2 11
3 12
end
save "`using_three'", replace

clear
input int id double(keyval lo hi)
1 10 5 15
end
rangematch keyval lo hi using "`using_three'", ///
    keepusing(uid) unmatched(none) distance(d)
assert _N == 3
sort uid
assert d[1] == -1
assert d[2] == 1
assert d[3] == 2
display as result "PASS: distance() with single-row master dataset"

**# T3: distance() with duplicate master-row references
local ++test_count
clear
input int id double(keyval lo hi)
1 10 5 15
2 10 5 15
3 10 5 15
end
rangematch keyval lo hi using "`using_three'", ///
    keepusing(uid) unmatched(none) distance(d)
assert _N == 9
sort id uid
assert d[1] == -1 & d[2] == 1 & d[3] == 2
assert d[4] == -1 & d[5] == 1 & d[6] == 2
assert d[7] == -1 & d[8] == 1 & d[9] == 2
display as result "PASS: distance() with duplicate master indices (fix retained)"

**# T4: sweep backend still selected for compatible monotone workloads
local ++test_count
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

clear
input int id double(lo hi)
1 1 2
2 2 4
end

rangematch keyval lo hi using "`using_speed'", ///
    keepusing(uid) unmatched(none)
assert "`r(backend)'" == "sweep"
assert r(N_pairs) == 5
display as result "PASS: sweep backend retained after the Mata cleanup"

**# T5: maxpairs guard still fires on sweep path after cleanup
local ++test_count
clear
input int id double(lo hi)
1 1 5
2 1 5
end
capture noisily rangematch keyval lo hi using "`using_speed'", ///
    keepusing(uid) unmatched(none) maxpairs(3)
assert _rc == 198
display as result "PASS: maxpairs guard retained on sweep path"

**# T6: nearest() still routes to binary backend
local ++test_count
clear
input int id double(keyval lo hi)
1 2.5 1 5
end
rangematch keyval lo hi using "`using_speed'", ///
    keepusing(uid) unmatched(none) nearest(both)
assert "`r(backend)'" == "binary"
assert r(N_pairs) == 2
display as result "PASS: nearest() routes to binary after cleanup"

display as result "ALL RANGEMATCH DISTANCE REGRESSION TESTS PASSED"
display "RESULT: test_rangematch_v147 tests=`test_count' pass=`test_count' fail=0"
