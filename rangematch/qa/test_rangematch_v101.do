* test_rangematch_v101.do — smoke test for using filename without .dta extension
clear all
set more off

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
quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap

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
save antibiotics.csv.dta, replace

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
local ++TESTS
di as result "PASS T1: using antibiotics.dta yields _N=" _N

* Test 2: using WITHOUT .dta — the new behavior
use `master', clear
rangematch visit_t visit_t_lo visit_t_hi using antibiotics, by(id) closed(both) unmatched(none) stats
assert _N == 3
local ++TESTS
di as result "PASS T2: using antibiotics (no .dta) yields _N=" _N

* Test 3: nonexistent file — should still error with confirm-file rc=601
use `master', clear
cap noisily rangematch visit_t visit_t_lo visit_t_hi using doesnotexist, by(id) closed(both) unmatched(none)
assert _rc == 601
local ++TESTS
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
local ++TESTS
di as result "PASS T4: frame precedence preserved over .dta file on disk"

* Test 5: an explicit extension must be resolved exactly as written.
* antibiotics.csv does not exist; only antibiotics.csv.dta exists. Appending
* .dta here would silently load a different file than the user requested.
use `master', clear
cap noisily rangematch visit_t visit_t_lo visit_t_hi using antibiotics.csv, ///
    by(id) closed(both) unmatched(none)
assert _rc == 601
local ++TESTS
di as result "PASS T5: explicit extension is not rewritten to .csv.dta"

* Test 6: the name is resolved to the file `use' will actually read BEFORE it
* is confirmed. Stata's `use' appends .dta whenever the file name carries no
* extension and never falls back to the bare name, so confirming the raw token
* accepted a name the loader could not open. Both "dual" and "dual.dta" exist
* here and hold DIFFERENT data, so a wrong resolution changes the answer and
* not merely the label: the old code confirmed "dual", loaded dual.dta, and
* reported r(using) as "dual" -- the one file it had not read.
clear
input float id float visit_t
1 10
1 20
2 15
end
save dual.dta, replace
clear
input float id float visit_t
1 10
1 11
1 12
1 13
end
save dual_src.dta, replace
copy dual_src.dta dual, replace
use `master', clear
rangematch visit_t visit_t_lo visit_t_hi using dual, ///
    by(id) closed(both) unmatched(none)
* 3 rows means dual.dta was read; the extensionless file would have given 4
assert _N == 3
assert "`r(using)'" == "dual.dta"
local ++TESTS
di as result "PASS T6: r(using) names the file that was actually read"

* Test 7: an extensionless file that exists as written is still not loadable,
* because `use' will look for <name>.dta regardless. The command must fail on
* the name it will really open rather than confirm one name and load another.
capture erase orphan.dta
copy dual_src.dta orphan, replace
use `master', clear
cap noisily rangematch visit_t visit_t_lo visit_t_hi using orphan, ///
    by(id) closed(both) unmatched(none)
assert _rc == 601
local ++TESTS
di as result "PASS T7: extensionless file with no .dta companion errors 601"

cd "`_orig_pwd'"
* Terminal sentinel (RM-I20): assert-driven, so reaching this line is the
* pass condition and its ABSENCE is what a runner must treat as failure.
display "RESULT: test_rangematch_v101 tests=`TESTS' pass=`TESTS' fail=0"
di as result "ALL TESTS PASSED"
