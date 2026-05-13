* test_rangematch_v101.do — smoke test for using filename without .dta extension
clear all
set more off

cap ado uninstall rangematch
adopath ++ "/home/tpcopeland/Stata-Tools/rangematch"

local _orig_pwd "`c(pwd)'"
local tmp "`c(tmpdir)'/rangematch_v101"
cap mkdir "`tmp'"
cd "`tmp'"

* Build a small using dataset on disk
* key variable (visit_t) must exist in using data — see rangematch.sthlp Description
clear
input float id float visit_t
1 10
1 20
2 15
end
save antibiotics.dta, replace

* Build master data
clear
input float id float visit_t float visit_t_lo float visit_t_hi
1 12 8 22
2 18 13 23
end
tempfile master
save `master', replace

* Test 1: using with explicit .dta — baseline (must work)
use `master', clear
rangematch visit_t visit_t_lo visit_t_hi using antibiotics.dta, by(id) closed(both) unmatched(none)
assert _N == 3
di as result "PASS T1: using antibiotics.dta yields _N=" _N

* Test 2: using WITHOUT .dta — the new behavior
use `master', clear
rangematch visit_t visit_t_lo visit_t_hi using antibiotics, by(id) closed(both) unmatched(none) stats
assert _N == 3
di as result "PASS T2: using antibiotics (no .dta) yields _N=" _N

* Test 3: nonexistent file — should still error with confirm-file rc=601
use `master', clear
cap noisily rangematch visit_t visit_t_lo visit_t_hi using doesnotexist, by(id) closed(both) unmatched(none)
assert _rc == 601
di as result "PASS T3: missing file errors with rc=" _rc

* Test 4: frame name still wins over disk file of the same name
use `master', clear
frame create antibiotics
frame antibiotics {
    input float id float visit_t
    1 11
    end
}
rangematch visit_t visit_t_lo visit_t_hi using antibiotics, by(id) closed(both) unmatched(none)
* Frame has only (id=1, visit_t=11); on-disk file has 3 rows for id 1 and 2
* If frame wins, we get only 1 matched row; if file wins, we get 3
* Frame wins → 1 match; if the disk file had won → 3 matches
assert _N == 1
di as result "PASS T4: frame precedence preserved over .dta file on disk"

cd "`_orig_pwd'"
di as result "ALL TESTS PASSED"
