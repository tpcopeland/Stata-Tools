*! test_rangematch_v133.do
*! v1.3.3 regressions: complete maxpairs guard, session-object preservation,
*! collision-proof generated labels, by() carry semantics, output-name guard,
*! and analytical returns after a late saving() failure.

clear all
version 16.1

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

local test_count = 0

tempfile point_using overlap_using
clear
input int uid double key
1 99
end
save "`point_using'", replace

clear
input int uid double(ulo uhi)
1 99 100
end
save "`overlap_using'", replace

**# T1: maxpairs caps master-only output in all three backends
local ++test_count
clear
set obs 3
generate double key = _n
capture noisily rangematch key 0 0 using "`point_using'", ///
    unmatched(master) maxpairs(2) count
assert _rc == 198

clear
set obs 3
generate double key = _n
capture noisily rangematch key 0 0 using "`point_using'", ///
    unmatched(master) maxpairs(2) nearest(both) count
assert _rc == 198

clear
set obs 3
generate double lo = _n
generate double hi = _n
capture noisily rangematch lo hi using "`overlap_using'", ///
    overlap(ulo uhi) unmatched(master) maxpairs(2) count
assert _rc == 198
display as result "PASS: maxpairs caps unmatched master rows in every backend"

**# T2: cleanup never drops same-named user matrices
local ++test_count
clear
set obs 1
generate double key = 1
matrix __rm_mi = (42)
matrix __rm_ui = (84)
rangematch key 0 0 using "`point_using'", count
assert el(__rm_mi, 1, 1) == 42
assert el(__rm_ui, 1, 1) == 84
display as result "PASS: user matrices survive cleanup"

**# T3: pre-existing workspace-name frames cause a safe error
local ++test_count
capture frame drop __rm_master
frame create __rm_master
frame __rm_master {
    set obs 1
    generate double sentinel = 42
}
clear
set obs 1
generate double key = 1
local va0 = c(varabbrev)
capture noisily rangematch key 0 0 using "`point_using'", count
assert _rc == 110
assert c(varabbrev) == "`va0'"
frame __rm_master: assert sentinel[1] == 42
capture frame drop __rm_master
display as result "PASS: workspace frame collision preserves user state"

**# T4: verbose timing preserves occupied user timers
local ++test_count
timer clear 91
timer on 91
sleep 10
timer off 91
quietly timer list 91
local timer_before = r(t91)
clear
set obs 1
generate double key = 1
rangematch key 0 0 using "`point_using'", count verbose
quietly timer list 91
assert r(t91) == `timer_before'
timer clear 91
display as result "PASS: verbose preserves occupied user timers"

**# T5: generate() does not overwrite a same-named user value label
local ++test_count
clear
set obs 1
generate double key = 99
generate byte status = 9
label define __rm_merge 9 "original"
label values status __rm_merge
rangematch key 0 0 using "`point_using'", generate(matched) unmatched(none)
decode status, generate(status_text)
decode matched, generate(matched_text)
assert status_text[1] == "original"
assert matched_text[1] == "matched"
display as result "PASS: generated match label cannot replace a user definition"

**# T6: by() variables appear once even when repeated in keepusing()
local ++test_count
tempfile grouped_using
clear
input int(group uid) double key
1 7 1
end
save "`grouped_using'", replace
clear
input int group double(lo hi)
1 0 2
end
rangematch key lo hi using "`grouped_using'", by(group) ///
    keepusing(group uid) all prefix(U_) unmatched(none)
confirm variable group U_uid
capture confirm variable U_group
assert _rc == 111
display as result "PASS: by() variables are not duplicated from keepusing()"

**# T7: invalid prefix/suffix output names fail early and preserve data
local ++test_count
clear
set obs 1
generate double key = 1
generate double sentinel = 42
capture noisily rangematch key 0 0 using "`point_using'", ///
    keepusing(uid) prefix(bad-) all
assert _rc == 198
assert _N == 1
assert sentinel[1] == 42
display as result "PASS: invalid constructed output names fail safely"

**# T8: late saving() failure retains the analytical return payload
local ++test_count
clear
set obs 1
generate double key = 99
generate double sentinel = 42
local badfile "`c(tmpdir)'/__rangematch_missing_dir__/out.dta"
capture noisily rangematch key 0 0 using "`point_using'", ///
    unmatched(none) saving("`badfile'")
assert _rc != 0
assert r(N_pairs) == 1
assert r(N_matched_pairs) == 1
assert "`r(saving)'" == ""
assert _N == 1
assert sentinel[1] == 42
display as result "PASS: saving failure retains analytics and preserves caller data"

display as result "ALL RANGEMATCH 1.3.3 REGRESSION TESTS PASSED"
display "RESULT: test_rangematch_v133 tests=`test_count' pass=`test_count' fail=0"
