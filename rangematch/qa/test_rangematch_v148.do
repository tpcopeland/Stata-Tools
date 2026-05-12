capture ado uninstall rangematch
clear all
version 17.0

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
quietly run "`pkg_dir'/_rangematch_mata.ado"

local test_count = 0

**# T1: Mata backend version matches package version
local ++test_count
mata: st_local("mata_ver", _rm_mata_version())
tempname fh
file open `fh' using "`pkg_dir'/rangematch.ado", read
file read `fh' line
file close `fh'
local pos = strpos(`"`line'"', "Version ")
local rest = substr(`"`line'"', `pos' + 8, .)
gettoken expected_version : rest
assert "`mata_ver'" == "`expected_version'"
display as result "PASS: Mata version `mata_ver' matches .ado header"

**# T2: Dead Mata functions are absent
local ++test_count
mata: st_local("has_group_range", strofreal(findexternal("_rm_group_range()") != NULL))
assert "`has_group_range'" == "0"
mata: st_local("has_count_empty", strofreal(findexternal("_rm_count_empty_master_groups()") != NULL))
assert "`has_count_empty'" == "0"
mata: st_local("has_count_unique", strofreal(findexternal("_rm_count_unique_groups()") != NULL))
assert "`has_count_unique'" == "0"
display as result "PASS: dead Mata functions removed"

**# T3: Live Mata functions are present and callable
local ++test_count
mata: st_local("has_build_pairs", strofreal(findexternal("_rm_build_pairs()") != NULL))
assert "`has_build_pairs'" == "1"
mata: st_local("has_sweep", strofreal(findexternal("_rm_build_pairs_sweep()") != NULL))
assert "`has_sweep'" == "1"
mata: st_local("has_materialize", strofreal(findexternal("_rm_materialize()") != NULL))
assert "`has_materialize'" == "1"
mata: st_local("has_distance", strofreal(findexternal("_rm_generate_distance()") != NULL))
assert "`has_distance'" == "1"
mata: st_local("has_key_block", strofreal(findexternal("_rm_key_block_uobs()") != NULL))
assert "`has_key_block'" == "1"
display as result "PASS: live Mata functions present"

**# T4: Full range join still works after cleanup
local ++test_count
tempfile using_data
clear
input int uid double keyval
1 5
2 10
3 15
4 20
end
save "`using_data'", replace

clear
input int id double(keyval lo hi)
1 10 5 15
2 20 18 22
end
rangematch keyval lo hi using "`using_data'", ///
    keepusing(uid) unmatched(none) distance(d) stats
assert _N == 4
assert r(N_pairs) == 4
assert r(N_matched_pairs) == 4
assert r(N_matched_master) == 2
assert r(N_unmatched_master) == 0
assert "`r(backend)'" == "sweep"
display as result "PASS: full join with stats and distance after cleanup"

**# T5: nearest() path unaffected by cleanup
local ++test_count
clear
input int id double(keyval lo hi)
1 10 5 15
end
rangematch keyval lo hi using "`using_data'", ///
    keepusing(uid) unmatched(none) nearest(both) distance(d)
assert "`r(backend)'" == "binary"
assert _N == 1
assert uid == 2
assert d == 0
display as result "PASS: nearest(both) unaffected by cleanup"

**# T6: by() grouped matching unaffected
local ++test_count
tempfile using_grouped
clear
input byte group int uid double keyval
1 1 5
1 2 10
2 3 15
2 4 20
end
save "`using_grouped'", replace

clear
input byte group int id double(lo hi)
1 1 4 11
2 2 14 21
end
rangematch keyval lo hi using "`using_grouped'", ///
    by(group) keepusing(uid) unmatched(none) stats
assert _N == 4
assert r(N_pairs) == 4
assert r(N_matched_pairs) == 4
display as result "PASS: grouped matching unaffected by cleanup"

display as result "ALL RANGEMATCH 1.4.8 REGRESSION TESTS PASSED"
display "RESULT: test_rangematch_v148 tests=`test_count' pass=`test_count' fail=0"
