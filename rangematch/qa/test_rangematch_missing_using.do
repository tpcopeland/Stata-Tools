*! test_rangematch_missing_using.do
*! A3: missing() now governs the USING side symmetrically with the master side.
*!   wildcard (default): point -> missing key never matches; overlap -> missing
*!                       bound open-ended. (Historical behavior, unchanged.)
*!   error            : abort (rc 459) if any using key/bound is missing.
*!   drop             : drop using rows with a missing key/bound before matching.
*! r(N_using_missing) reports the count under every policy.

version 16.1
clear all
set more off

quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
local cwd "`c(pwd)'"
local cwd_len = strlen("`cwd'")
if substr("`cwd'", `cwd_len' - 2, 3) == "/qa" {
    local pkg_dir = substr("`cwd'", 1, `cwd_len' - 3)
}
else {
    local pkg_dir "`cwd'"
}

local FAIL 0
local TESTS 0
tempfile UP MP UO MO

* ============================ POINT MODE ============================
* Using points: 5, ., 15, 25, .   (missing key at uid 2 and 5)
clear
input double key long uid
5  1
.  2
15 3
25 4
.  5
end
save "`UP'"

* Master: single interval [0,30] matches points 0..30
clear
input double mlo double mhi long mid
0 30 1
end
save "`MP'"

* --- wildcard (default), unmatched(none): missing keys never match
use "`MP'", clear
quietly rangematch key mlo mhi using "`UP'", keepusing(uid) unmatched(none)
local ++TESTS
if r(N_matched_pairs) != 3 | r(N_pairs) != 3 | r(N_using_missing) != 2 {
    di as error "POINT wildcard/none: matched=" r(N_matched_pairs) ///
        " pairs=" r(N_pairs) " using_missing=" r(N_using_missing) " (want 3,3,2)"
    local ++FAIL
}

* --- error: aborts
use "`MP'", clear
capture rangematch key mlo mhi using "`UP'", missing(error)
local ++TESTS
if _rc != 459 {
    di as error "POINT error: rc=" _rc " (want 459)"
    local ++FAIL
}

* --- drop, unmatched(none): reduced using, same 3 matches
use "`MP'", clear
quietly rangematch key mlo mhi using "`UP'", keepusing(uid) missing(drop) unmatched(none)
local ++TESTS
if r(N_matched_pairs) != 3 | r(N_using) != 3 | r(N_using_missing) != 2 {
    di as error "POINT drop/none: matched=" r(N_matched_pairs) ///
        " N_using=" r(N_using) " using_missing=" r(N_using_missing) " (want 3,3,2)"
    local ++FAIL
}

* --- wildcard, unmatched(using): the 2 missing-key rows surface as unmatched
use "`MP'", clear
quietly rangematch key mlo mhi using "`UP'", keepusing(uid) unmatched(using)
local ++TESTS
if r(N_pairs) != 5 | r(N_matched_pairs) != 3 {
    di as error "POINT wildcard/using: pairs=" r(N_pairs) ///
        " matched=" r(N_matched_pairs) " (want 5,3 -> 2 unmatched using)"
    local ++FAIL
}

* --- drop, unmatched(using): the 2 missing-key rows are gone, not surfaced
use "`MP'", clear
quietly rangematch key mlo mhi using "`UP'", keepusing(uid) missing(drop) unmatched(using)
local ++TESTS
if r(N_pairs) != 3 | r(N_matched_pairs) != 3 {
    di as error "POINT drop/using: pairs=" r(N_pairs) ///
        " matched=" r(N_matched_pairs) " (want 3,3 -> dropped rows absent)"
    local ++FAIL
}

* ============================ OVERLAP MODE ============================
* Using intervals vs master [10,20]:
*   (12,14) match ; (.,14) open-below match ; (12,.) open-above match ;
*   (.,.) full match ; (50,60) no overlap.  3 rows have a missing bound.
clear
input double ulo double uhi long uid
12 14 1
.  14 2
12 .  3
.  .  4
50 60 5
end
save "`UO'"

clear
input double mlo double mhi long mid
10 20 1
end
save "`MO'"

* --- wildcard (default): open-ended bounds match; 4 matches, 3 flagged missing
use "`MO'", clear
quietly rangematch mlo mhi using "`UO'", overlap(ulo uhi) keepusing(uid) unmatched(none)
local ++TESTS
if r(N_matched_pairs) != 4 | r(N_using_missing) != 3 {
    di as error "OVERLAP wildcard: matched=" r(N_matched_pairs) ///
        " using_missing=" r(N_using_missing) " (want 4,3)"
    local ++FAIL
}

* --- error: aborts
use "`MO'", clear
capture rangematch mlo mhi using "`UO'", overlap(ulo uhi) missing(error)
local ++TESTS
if _rc != 459 {
    di as error "OVERLAP error: rc=" _rc " (want 459)"
    local ++FAIL
}

* --- drop: only (12,14) and (50,60) remain; just (12,14) overlaps [10,20]
use "`MO'", clear
quietly rangematch mlo mhi using "`UO'", overlap(ulo uhi) keepusing(uid) missing(drop) unmatched(none)
local ++TESTS
if r(N_matched_pairs) != 1 | r(N_using) != 2 | r(N_using_missing) != 3 {
    di as error "OVERLAP drop: matched=" r(N_matched_pairs) ///
        " N_using=" r(N_using) " using_missing=" r(N_using_missing) " (want 1,2,3)"
    local ++FAIL
}

di as txt "{hline 60}"
display "RESULT: missing_using tests=`TESTS' pass=`=`TESTS' - `FAIL'' fail=`FAIL'"
if `FAIL' > 0 {
    di as error "test_rangematch_missing_using: FAILED (`FAIL')"
    exit 9
}
di as result "test_rangematch_missing_using: PASSED"
