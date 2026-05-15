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

tempfile using_contract saving_contract

clear
input int uid byte group double keyval int value
1 1 1 11
2 1 2 12
3 1 3 13
4 2 20 20
end
save "`using_contract'", replace

**# Default return surface

clear
input int id byte group double(keyval lo hi)
1 1 2 1 2
2 1 5 4 4
3 2 20 19 21
end

rangematch keyval lo hi using "`using_contract'", ///
    by(group) keepusing(uid value)

assert r(N_master) == 3
assert r(N_using) == 4
assert r(N_pairs) == 4
assert r(N_matched_pairs) == 3
assert r(N_unmatched) == 1
assert r(N_missing_bounds) == 0
assert r(tolerance) == 0
capture confirm scalar r(max_matches)
assert _rc == 111
capture confirm scalar r(N_matched_master)
assert _rc == 111
assert `"`r(cmd)'"' == "rangematch"
assert strpos(`"`r(cmdline)'"', "rangematch keyval lo hi using") > 0
assert `"`r(using)'"' == `"`using_contract'"'
assert "`r(using_source)'" == "file"
assert "`r(key)'" == "keyval"
assert "`r(low)'" == "lo"
assert "`r(high)'" == "hi"
assert "`r(by)'" == "group"
assert "`r(keepusing)'" == "uid value"
assert "`r(suffix)'" == "_U"
assert "`r(unmatched)'" == "master"
assert "`r(closed)'" == "both"
assert "`r(missing)'" == "wildcard"
assert "`r(sort)'" == "sort"
assert "`r(nosort)'" == ""
assert "`r(frame)'" == ""
assert "`r(saving)'" == ""
assert inlist("`r(backend)'", "sweep", "binary")

**# Stats return surface

clear
input int id byte group double(keyval lo hi)
1 1 2 1 2
2 1 5 4 4
3 2 20 19 21
end

rangematch keyval lo hi using "`using_contract'", ///
    by(group) keepusing(uid value) stats

assert r(N_matched_master) == 2
assert r(N_matched_using) == 3
assert r(N_unmatched_master) == 1
assert r(N_unmatched_using) == 1
assert r(max_matches) == 2
assert reldif(r(mean_matches), 1) < 1e-12
assert r(median_matches) == 1
assert r(p50_matches) == 1
assert r(p90_matches) == 2
assert r(p99_matches) == 2
assert r(N_empty_groups) == 0
assert r(N_master_groups) == 2
assert "`r(stats)'" == "stats"

**# dryrun and count return surfaces

clear
input int id byte group double(keyval lo hi) byte sentinel
1 1 2 1 2 42
2 1 5 4 4 43
3 2 20 19 21 44
end

rangematch keyval lo hi using "`using_contract'", ///
    by(group) keepusing(uid value) stats dryrun

assert _N == 3
assert sentinel[1] == 42
assert r(N_pairs) == 4
assert "`r(dryrun)'" == "dryrun"
assert "`r(count)'" == ""
assert "`r(frame)'" == ""
assert "`r(saving)'" == ""
assert r(max_matches) == 2

rangematch keyval lo hi using "`using_contract'", ///
    by(group) keepusing(uid value) count

assert _N == 3
assert sentinel[2] == 43
assert r(N_pairs) == 4
assert "`r(count)'" == "count"
assert "`r(dryrun)'" == ""
assert "`r(frame)'" == ""
assert "`r(saving)'" == ""

**# frame(), saving(), and nearest() conditional locals

capture frame drop return_contract_out
clear
input int id byte group double(keyval lo hi) byte sentinel
1 1 2 1 2 42
2 1 5 4 4 43
3 2 20 19 21 44
end

rangematch keyval lo hi using "`using_contract'", ///
    by(group) keepusing(uid value) frame(return_contract_out) replace

assert _N == 3
assert sentinel[3] == 44
assert "`r(frame)'" == "return_contract_out"
assert "`r(saving)'" == ""
frame return_contract_out: assert _N == 4
capture frame drop return_contract_out

clear
input int id byte group double(keyval lo hi) byte sentinel
1 1 2 1 2 42
2 1 5 4 4 43
3 2 20 19 21 44
end

rangematch keyval lo hi using "`using_contract'", ///
    by(group) keepusing(uid value) saving("`saving_contract'", replace)

assert _N == 3
assert sentinel[1] == 42
assert "`r(frame)'" == ""
assert `"`r(saving)'"' == `"`saving_contract'"'
confirm file "`saving_contract'"

clear
input int id double(keyval lo hi)
1 2 0 5
2 19 0 25
end

rangematch keyval lo hi using "`using_contract'", ///
    keepusing(uid) unmatched(none) nearest(both) ties(first) nosort

assert "`r(nearest)'" == "both"
assert "`r(ties)'" == "first"
assert "`r(nosort)'" == "nosort"
assert "`r(sort)'" == ""
assert "`r(backend)'" == "binary"

display as result "ALL RANGEMATCH RETURN CONTRACT TESTS PASSED"
