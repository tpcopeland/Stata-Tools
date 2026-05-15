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

tempfile using_backend sweep_out binary_out sweep_nearest binary_nearest

clear
input int uid double keyval
1 1
2 2
3 3
4 4
5 5
end
save "`using_backend'", replace

**# Sweep/default and forced binary/nosort agree on pair IDs and stats

clear
input int id double(lo hi)
30 3 3
10 1 2
20 2 4
end

rangematch keyval lo hi using "`using_backend'", ///
    keepusing(uid) unmatched(none) stats

assert "`r(backend)'" == "sweep"
local sweep_pairs = r(N_pairs)
local sweep_matched_pairs = r(N_matched_pairs)
local sweep_unmatched = r(N_unmatched)
local sweep_mean = r(mean_matches)
local sweep_median = r(median_matches)
local sweep_p90 = r(p90_matches)
sort id uid
save "`sweep_out'", replace

clear
input int id double(lo hi)
30 3 3
10 1 2
20 2 4
end

rangematch keyval lo hi using "`using_backend'", ///
    keepusing(uid) unmatched(none) stats nosort

assert "`r(backend)'" == "binary"
assert r(N_pairs) == `sweep_pairs'
assert r(N_matched_pairs) == `sweep_matched_pairs'
assert r(N_unmatched) == `sweep_unmatched'
assert reldif(r(mean_matches), `sweep_mean') < 1e-12
assert r(median_matches) == `sweep_median'
assert r(p90_matches) == `sweep_p90'
sort id uid
save "`binary_out'", replace

use "`sweep_out'", clear
merge 1:1 id uid using "`binary_out'"
assert _merge == 3
drop _merge

**# Binary nearest variants remain deterministic against themselves

clear
input int id double(keyval lo hi)
1 2 0 10
2 4 0 10
end

rangematch keyval lo hi using "`using_backend'", ///
    keepusing(uid) unmatched(none) nearest(both) ties(all) stats

assert "`r(backend)'" == "binary"
assert r(N_pairs) == 2
local nearest_pairs = r(N_pairs)
local nearest_mean = r(mean_matches)
sort id uid
save "`sweep_nearest'", replace

clear
input int id double(keyval lo hi)
1 2 0 10
2 4 0 10
end

rangematch keyval lo hi using "`using_backend'", ///
    keepusing(uid) unmatched(none) nearest(both) ties(all) stats nosort

assert "`r(backend)'" == "binary"
assert r(N_pairs) == `nearest_pairs'
assert reldif(r(mean_matches), `nearest_mean') < 1e-12
sort id uid
save "`binary_nearest'", replace

use "`sweep_nearest'", clear
merge 1:1 id uid using "`binary_nearest'"
assert _merge == 3

display as result "ALL RANGEMATCH BACKEND EQUIVALENCE TESTS PASSED"
