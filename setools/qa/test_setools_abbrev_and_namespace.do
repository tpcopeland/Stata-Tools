* test_setools_abbrev_and_namespace.do
* Regression tests for the v1.5.2 fixes
*
* Abbreviation contract (A): every minimum abbreviation the .sthlp advertises
* must be accepted at runtime. migrations shipped 1.5.1 with syntax QUIetly
* while migrations.sthlp documented {opt q:uietly}, so the documented minimum
* exited 198. No suite exercised any option at its documented minimum, which is
* why the drift survived: every call spelled its options in full.
*
* Reserved namespace (N): migrations merges the whole master back in and then
* builds _mig_* working variables on it, so a master column in that namespace
* collides. 1.5.1 also used a bare _neg_* prefix and had no preflight, so a
* collision surfaced as a bare r(110) naming an internal variable.
*
* Tests:
*   A1: migrations quietly accepts the documented minimum 'q'
*   A2: migrations quietly still accepts intermediate and full spellings
*   A3: migrations migfile() accepts the documented minimum 'mig'
*   A4: setools accepts the documented minimums 'l', 'd', and 'c()'
*   N1: master column _mig_foo is refused up front with 110
*   N2: real collision _mig_seq is refused and leaves master data intact
*   N3: master with no _mig_* column is not falsely refused
*   N4: _neg_out no longer collides — it was an internal name in 1.5.1

clear all
set more off


* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

do "`qa_dir'/_setools_qa_common.do" setup "`pkg_dir'"

global passed = 0
global failed = 0

capture program drop run_test
program define run_test
    args name result
    if `result' {
        display as result "  [PASS] `name'"
        global passed = $passed + 1
    }
    else {
        display as error "  [FAIL] `name'"
        global failed = $failed + 1
    }
end


* Shared fixture: a two-person cohort and a wide migration file with one
* emigration, so migrations does real work on every abbreviation call.
clear
set obs 2
gen long id = _n
gen long study_start = td(01jan2018)
format study_start %td
tempfile cohort
save `cohort'

clear
set obs 1
gen long id = 2
gen long in_1 = .
gen long out_1 = td(01jun2020)
format in_1 out_1 %td
tempfile migfile
save `migfile'


**# A1: documented minimum abbreviation for quietly

* migrations.sthlp documents {synopt:{opt q:uietly}}, so 'q' is the contract.
use `cohort', clear
capture migrations, migfile("`migfile'") q
local a1_rc = _rc
local t = (`a1_rc' == 0)
run_test "A1: migrations, ... q accepts the documented minimum" `t'


**# A2: intermediate and full spellings still accepted

use `cohort', clear
capture migrations, migfile("`migfile'") qui
local a2_qui = _rc
use `cohort', clear
capture migrations, migfile("`migfile'") quietly
local a2_full = _rc
local t = (`a2_qui' == 0 & `a2_full' == 0)
run_test "A2: 'qui' and 'quietly' both still accepted" `t'


**# A3: documented minimum for migfile()

* migrations.sthlp documents {opt mig:file(filename)}.
use `cohort', clear
capture migrations, mig("`migfile'")
local a3_rc = _rc
local t = (`a3_rc' == 0)
run_test "A3: migrations, mig() accepts the documented minimum" `t'


**# A4: setools documented minimums

capture setools, l
local a4_l = _rc
capture setools, d
local a4_d = _rc
capture setools, c(ms)
local a4_c = _rc
local t = (`a4_l' == 0 & `a4_d' == 0 & `a4_c' == 0)
run_test "A4: setools accepts 'l', 'd', and 'c()'" `t'


**# N1: a _mig_* master column is refused before any work

* _mig_foo is never generated internally, so 1.5.1 ran to completion here.
* The namespace is reserved as a whole, so 1.5.2 refuses it.
use `cohort', clear
gen byte _mig_foo = 1
capture migrations, migfile("`migfile'")
local n1_rc = _rc
local t = (`n1_rc' == 110)
run_test "N1: reserved-namespace column _mig_foo refused with 110" `t'


**# N2: a real collision is refused and leaves the master data intact

* _mig_seq is a genuine internal working variable. Both the old late gen and
* the new preflight exit 110; what this locks is that the user's data survives
* the refusal unchanged, including the offending column.
use `cohort', clear
gen byte _mig_seq = 7
capture migrations, migfile("`migfile'")
local n2_rc = _rc
qui count
local n2_n = r(N)
capture confirm variable _mig_seq
local n2_has_col = (_rc == 0)
qui count if _mig_seq == 7
local n2_intact = (r(N) == 2)
capture confirm variable migration_out_dt
local n2_no_output = (_rc != 0)
local t = (`n2_rc' == 110 & `n2_n' == 2 & `n2_has_col' & `n2_intact' & `n2_no_output')
run_test "N2: real collision refused, master data untouched" `t'


**# N3: no false refusal when the namespace is clear

use `cohort', clear
gen byte migration_history = 1
capture migrations, migfile("`migfile'")
local n3_rc = _rc
capture confirm variable migration_out_dt
local n3_ran = (_rc == 0)
local t = (`n3_rc' == 0 & `n3_ran')
run_test "N3: clear namespace is not falsely refused" `t'


**# N4: _neg_out is no longer an internal name

* 1.5.1 generated a bare _neg_out on the merged master, so a user column of
* that name collided. 1.5.2 moved it to _mig_neg_out, freeing the generic name.
use `cohort', clear
gen byte _neg_out = 3
capture migrations, migfile("`migfile'")
local n4_rc = _rc
qui count if _neg_out == 3
local n4_intact = (r(N) == 2)
local t = (`n4_rc' == 0 & `n4_intact')
run_test "N4: user column _neg_out no longer collides" `t'


* === SUMMARY ===
display _newline "=== ABBREVIATION / NAMESPACE TEST SUMMARY ==="
display "Passed: $passed"
display "Failed: $failed"
display "Total:  " $passed + $failed
display "RESULT: test_setools_abbrev_and_namespace tests=" $passed + $failed ///
    " pass=" $passed " fail=" $failed

if $failed > 0 {
    display as error _newline "FAILED: $failed test(s) failed"
    exit 9
}
else {
    display as result _newline "ALL TESTS PASSED"
}

do "`qa_dir'/_setools_qa_common.do" teardown
