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
* The whole exported surface, not a sample of it. This listed 7 of the 23
* exported functions and omitted the entire overlap backend, the sweep
* preparer, the option-grammar scanner, the .dta-name resolver, the
* value-label resolver, and all four binary searches -- so a name dropped from
* the `mata drop' preamble, or a function deleted outright, was caught only if
* it happened to be one of the seven. Every function defined in
* _rangematch_mata.ado belongs here; add the name when you add the function.
local ++test_count
local mata_surface ///
    _rm_mata_version _rm_blank_quoted _rm_first_empty_opt _rm_dta_name ///
    _rm_prepare_sweep_master _rm_pctile _rm_compute_match_stats ///
    _rm_post_pair_results _rm_build_pairs _rm_build_pairs_sweep ///
    _rm_build_pairs_overlap _rm_interval_nonempty _rm_overlap_count_group ///
    _rm_overlap_emit_group _rm_bsearch_left _rm_bsearch_right ///
    _rm_bsearch_first_gt _rm_bsearch_last_lt _rm_key_block_uobs ///
    _rm_store_indexed _rm_vl_same _rm_vl_candidate _rm_vl_resolve ///
    _rm_materialize _rm_fill_using_only _rm_generate_distance _rm_copy_output
local missing_fn ""
foreach fn of local mata_surface {
    mata: st_local("has_fn", strofreal(findexternal("`fn'()") != NULL))
    if "`has_fn'" != "1" local missing_fn "`missing_fn' `fn'"
}
if "`missing_fn'" != "" {
    display as error "missing Mata functions:`missing_fn'"
}
assert "`missing_fn'" == ""

* And the list itself must stay complete: every `mata drop' entry in the
* preamble is a function this file claims to export, so the two must agree.
* Without this, a new function added to the .ado and to the drop list but not
* to `mata_surface' above leaves the loop asserting nothing about it.
tempname mfh
local declared ""
file open `mfh' using "`pkg_dir'/_rangematch_mata.ado", read text
file read `mfh' mline
while r(eof) == 0 {
    if strpos(`"`mline'"', "capture mata: mata drop ") == 1 {
        local fn = subinstr(`"`mline'"', "capture mata: mata drop ", "", 1)
        local fn = subinstr("`fn'", "()", "", .)
        local fn = strtrim("`fn'")
        local declared "`declared' `fn'"
    }
    file read `mfh' mline
}
file close `mfh'
local not_listed : list declared - mata_surface
if "`not_listed'" != "" {
    display as error "dropped-but-unasserted Mata functions:`not_listed'"
}
assert "`not_listed'" == ""
display as result "PASS: all live Mata functions present and asserted"

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

display as result "ALL RANGEMATCH MATA-SURFACE REGRESSION TESTS PASSED"
display "RESULT: test_rangematch_regress_mata_surface tests=`test_count' pass=`test_count' fail=0"
