* test_rangematch_missing_option_extra.do — v1.1.0 missing() extended coverage
*
* Fills coverage gaps not exercised by test_rangematch_missing_option.do:
*   E1: missing(drop) wipes out all master rows -> rc=2000
*   E2: N_missing_bounds respects if/in (only counts rows in touse)
*   E3: missing() ignores rows already excluded by if/in
*   E4: missing(drop) + scalar offset bound (variable+literal mix)
*   E5: case-insensitive parsing (missing(DROP), missing(Error), missing(WILDCARD))
*   E6: minimum abbreviation miss(drop) accepted
*   E7: missing(drop) + by() that fully eliminates a master group
*   E8: missing(drop) + stats — N_master_groups reflects post-drop master
*   E9: missing(error) + clean if-filter that excludes missing rows -> no error
*   E10: full var-bound + literal `.' on other side, with missing in the variable
*   E11: dryrun + r(missing) macro posted
*   E12: r(N_master) under missing(drop) equals post-drop count and equals
*        pre-drop count - N_missing_bounds (only when those are the only excluded rows)

capture ado uninstall rangematch
clear all
version 17.0

local cwd "`c(pwd)'"
local cwd_len = strlen("`cwd'")
if substr("`cwd'", `cwd_len' - 2, 3) == "/qa" {
    local pkg_dir = substr("`cwd'", 1, `cwd_len' - 3)
}
else {
    local pkg_dir "`cwd'"
}
quietly net install rangematch, from("`pkg_dir'") replace
quietly run "`pkg_dir'/_rangematch_mata.ado"

local test_count = 0

tempfile m_data u_data

* using: 3 events per group across two groups
clear
input int id double event_date
1 100
1 110
1 200
2 100
2 110
2 200
end
save "`u_data'", replace

**# E1: missing(drop) wipes out all master rows -> rc=2000
local ++test_count
clear
input int id double(lo hi)
1 . 115
2 95 .
end
tempfile m_all_miss
save "`m_all_miss'", replace
use "`m_all_miss'", clear
capture noisily rangematch event_date lo hi using "`u_data'", by(id) ///
    unmatched(none) missing(drop) frame(out_e1) replace
assert _rc == 2000
display as result "PASS E`test_count': missing(drop) removing all master rows -> rc=2000"

**# E2: N_missing_bounds respects if/in (only counts rows in touse)
local ++test_count
clear
input int id double(lo hi)
1 95 115
1 .  115
1 95 .
2 95 115
2 .  115
end
tempfile m_e2
save "`m_e2'", replace
use "`m_e2'", clear
* if id==2: only row 4 (clean) and row 5 (lo missing) are in scope
* Expected N_missing_bounds = 1 (only row 5 counted; row 2 and row 3 not in touse)
rangematch event_date lo hi if id == 2 using "`u_data'", by(id) ///
    unmatched(none) frame(out_e2) replace
assert r(N_missing_bounds) == 1
display as result "PASS E`test_count': N_missing_bounds=`r(N_missing_bounds)' respects if/in filter"

**# E3: missing() ignores rows already excluded by if/in (no error fired)
local ++test_count
use "`m_e2'", clear
* if id==1 excludes id==2; rows 2,3 have missing bounds; if we further filter to
* lo<100, rows 2,3 with missing lo are kept (missing < 100 is false in Stata),
* but missing(error) should still fire because they ARE in touse.
* Better test: filter that EXCLUDES the missing rows -> missing(error) no-op
rangematch event_date lo hi if !missing(lo) & !missing(hi) using "`u_data'", ///
    by(id) unmatched(none) missing(error) frame(out_e3) replace
assert r(N_missing_bounds) == 0
display as result "PASS E`test_count': missing(error) is a no-op when if filter pre-excludes missing rows"

**# E4: missing(drop) + scalar offset bound (variable lo + literal scalar high)
local ++test_count
* Master needs the key var present (event_date) for scalar offsets to anchor on.
clear
input int id double(event_date lo)
1 100 95
1 100 .
2 200 95
end
tempfile m_e4
save "`m_e4'", replace
use "`m_e4'", clear
* lo = variable (with one missing), high = literal scalar 50 (key+50 window)
* missing(drop) should drop row 2 (missing lo); literal scalar 50 unaffected.
rangematch event_date lo 50 using "`u_data'", by(id) ///
    unmatched(none) missing(drop) frame(out_e4) replace
* Row 1: lo=95, key=100, high=150 -> match id=1 in [95,150] -> {100,110} = 2
* Row 2: dropped
* Row 3: lo=95, key=200, high=250 -> match id=2 in [95,250] -> {100,110,200} = 3
* Total = 5
assert r(N_pairs) == 5
assert r(N_missing_bounds) == 1
assert r(N_master) == 2
display as result "PASS E`test_count': missing(drop) + scalar-offset high (no missing on literal side)"

**# E5: case-insensitive parsing
local ++test_count
clear
input int id double(lo hi)
1 95 115
1 .  115
end
tempfile m_e5
save "`m_e5'", replace

use "`m_e5'", clear
rangematch event_date lo hi using "`u_data'", by(id) ///
    unmatched(none) missing(WILDCARD) frame(out_e5a) replace
assert "`r(missing)'" == "wildcard"

use "`m_e5'", clear
rangematch event_date lo hi using "`u_data'", by(id) ///
    unmatched(none) missing(Drop) frame(out_e5b) replace
assert "`r(missing)'" == "drop"

use "`m_e5'", clear
capture noisily rangematch event_date lo hi using "`u_data'", by(id) ///
    unmatched(none) missing(ERROR) frame(out_e5c) replace
assert _rc == 459

display as result "PASS E`test_count': case-insensitive parsing of WILDCARD/Drop/ERROR"

**# E6: minimum abbreviation miss(drop) accepted
local ++test_count
use "`m_e5'", clear
rangematch event_date lo hi using "`u_data'", by(id) ///
    unmatched(none) miss(drop) frame(out_e6) replace
assert "`r(missing)'" == "drop"
assert r(N_missing_bounds) == 1
display as result "PASS E`test_count': minimum abbreviation miss(drop) accepted"

**# E7: missing(drop) + by() that fully eliminates a master group
local ++test_count
clear
input int id double(lo hi)
1 95 115
2 .  115
2 95 .
end
tempfile m_e7
save "`m_e7'", replace
use "`m_e7'", clear
* missing(drop) removes both id=2 rows. id=2 group is now master-empty.
* unmatched(both): id=2 using rows should surface as unmatched using.
* id=1 row matches {100,110} (2 pairs)
* id=2 using rows (3) come back as unmatched using -> 3
rangematch event_date lo hi using "`u_data'", by(id) ///
    unmatched(both) missing(drop) frame(out_e7) replace
assert r(N_matched_pairs) == 2
* Unmatched output:
*   - 0 master-only (dropped rows do not surface as unmatched)
*   - 1 using-only from id=1 (event_date=200, outside lo=95 hi=115)
*   - 3 using-only from id=2 (whole group: master empty after drop)
* Total unmatched = 4; total output = 6
assert r(N_unmatched) == 4
assert r(N_pairs) == 6
assert r(N_master) == 1
display as result "PASS E`test_count': missing(drop) emptying a by-group surfaces using-only rows"

**# E8: missing(drop) + stats — N_master_groups reflects POST-drop master groups
local ++test_count
use "`m_e7'", clear
* stats counts master groups based on the post-drop master frame. id=2 group
* is gone from master, so N_master_groups should be 1 (only id=1).
rangematch event_date lo hi using "`u_data'", by(id) ///
    unmatched(none) missing(drop) stats frame(out_e8) replace
assert r(N_master_groups) == 1
assert r(N_matched_master) == 1
display as result "PASS E`test_count': missing(drop) + stats: N_master_groups=`r(N_master_groups)' reflects post-drop"

**# E9: missing(error) + clean if-filter that excludes missing rows -> no error
local ++test_count
clear
input int id double(lo hi)
1 95 115
1 .  115
2 95 .
end
tempfile m_e9
save "`m_e9'", replace
use "`m_e9'", clear
* if !missing(lo, hi) keeps only row 1; missing(error) should not fire.
rangematch event_date lo hi if !missing(lo) & !missing(hi) using "`u_data'", ///
    by(id) unmatched(none) missing(error) frame(out_e9) replace
assert r(N_missing_bounds) == 0
assert r(N_pairs) == 2
display as result "PASS E`test_count': missing(error) + pre-filtering if-clause yields no abort"

**# E10: var-bound with missing + literal `.' on the other side
local ++test_count
clear
input int id double(lo hi)
1 95 115
1 .  115
end
tempfile m_e10
save "`m_e10'", replace
use "`m_e10'", clear
* Test 1: variable lo (with missing in row 2) + literal `.' for high
* (open-ended high regardless). missing(error) should fire because lo is var
* with missing value, regardless of high being a literal `.'.
capture noisily rangematch event_date lo . using "`u_data'", by(id) ///
    unmatched(none) missing(error) frame(out_e10a) replace
assert _rc == 459

* Test 2: variable hi (with missing in test row) + literal `.' for low.
* Same setup but swap: pass missing-bound row through as variable hi.
clear
input int id double(lo hi)
1 95 .
end
tempfile m_e10b
save "`m_e10b'", replace
use "`m_e10b'", clear
capture noisily rangematch event_date . hi using "`u_data'", by(id) ///
    unmatched(none) missing(error) frame(out_e10b) replace
assert _rc == 459

display as result "PASS E`test_count': missing(error) fires on var-side missing even when other side is literal `.'"

**# E11: dryrun + r(missing) macro posted
local ++test_count
use "`m_e5'", clear
rangematch event_date lo hi using "`u_data'", by(id) ///
    unmatched(none) missing(drop) dryrun
assert "`r(missing)'" == "drop"
assert r(N_missing_bounds) == 1
display as result "PASS E`test_count': r(missing)=`r(missing)' posted in dryrun mode"

**# E12: r(N_master) under missing(drop) equals pre-drop count minus N_missing_bounds
local ++test_count
clear
input int id double(lo hi)
1 95 115
1 95 200
1 .  115
1 95 .
2 95 200
2 .  .
end
tempfile m_e12
save "`m_e12'", replace
use "`m_e12'", clear
* Pre-drop count = 6. Missing-bound rows = 3 (rows 3, 4, 6). Post-drop = 3.
rangematch event_date lo hi using "`u_data'", by(id) ///
    unmatched(none) missing(drop) frame(out_e12) replace
assert r(N_master) == 3
assert r(N_missing_bounds) == 3
* Invariant: pre-drop = post-drop + N_missing_bounds (when those are the only exclusions)
local pre_drop = r(N_master) + r(N_missing_bounds)
assert `pre_drop' == 6
display as result "PASS E`test_count': N_master=`r(N_master)' + N_missing_bounds=`r(N_missing_bounds)' = pre-drop 6"

**# E13: row with BOTH low and high missing — counted once, wildcards under
**#      missing(wildcard), dropped under missing(drop)
local ++test_count
clear
input int id double(lo hi)
1 95 115
1 .  .
2 95 115
end
tempfile m_e13
save "`m_e13'", replace

* (a) wildcard default: the both-missing row wildcards every id=1 using row.
*     Row 1 (95,115) matches event_date in [95,115] for id=1 -> {100,110} = 2
*     Row 2 (.,.)    matches every id=1 using row regardless of key   -> 3
*     Row 3 (95,115) matches id=2 events in [95,115]                  -> {100,110} = 2
*     Total matched = 7. N_missing_bounds = 1 (the both-missing row counted once).
use "`m_e13'", clear
rangematch event_date lo hi using "`u_data'", by(id) ///
    unmatched(none) frame(out_e13a) replace
assert r(N_missing_bounds) == 1
assert r(N_matched_pairs) == 7

* (b) drop: the both-missing row is removed.
*     Surviving master = rows 1 and 3. Each matches 2 using rows -> 4.
use "`m_e13'", clear
rangematch event_date lo hi using "`u_data'", by(id) ///
    unmatched(none) missing(drop) frame(out_e13b) replace
assert r(N_master) == 2
assert r(N_missing_bounds) == 1
assert r(N_matched_pairs) == 4

display as result "PASS E`test_count': both-bounds-missing row counted once, wildcards under default, dropped under missing(drop)"

display as result _newline "test_rangematch_missing_option_extra.do: `test_count'/`test_count' PASS"
