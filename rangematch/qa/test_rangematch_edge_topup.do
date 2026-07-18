*! test_rangematch_edge_topup.do
*! A5 + A7: deterministic ties(first|last), and edge cases -- zero-obs using,
*! all-missing master bounds under each missing() policy, maxpairs boundary-exact
*! behavior, and caller-data restore after an erroring call.

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
tempfile UTIE M0 UEMPTY U5

* ===== A5: ties(first|last) pick the lowest/highest original using obs =====
* Two using rows tie at key=10 (distance 0); master key=10, window [0,20].
clear
input double key long uid
10 1
10 2
end
save "`UTIE'"
* nearest() needs the point key in BOTH datasets (distance = u.key - m.key).
clear
input double key double lo double hi long mid
10 0 20 1
end
save "`M0'"

* ties(first) -> uid 1 ; ties(last) -> uid 2
use "`M0'", clear
quietly rangematch key lo hi using "`UTIE'", keepusing(uid) ///
    nearest(both) ties(first) unmatched(none)
quietly summarize uid, meanonly
if r(N) != 1 | r(max) != 1 {
    di as error "A5 ties(first): N=" r(N) " uid=" r(max) " (want 1,1)"
    local ++FAIL
}
use "`M0'", clear
quietly rangematch key lo hi using "`UTIE'", keepusing(uid) ///
    nearest(both) ties(last) unmatched(none)
quietly summarize uid, meanonly
if r(N) != 1 | r(max) != 2 {
    di as error "A5 ties(last): N=" r(N) " uid=" r(max) " (want 1,2)"
    local ++FAIL
}
* ties(all) -> both rows
use "`M0'", clear
quietly rangematch key lo hi using "`UTIE'", keepusing(uid) ///
    nearest(both) ties(all) unmatched(none)
quietly count
if r(N) != 2 {
    di as error "A5 ties(all): N=" r(N) " (want 2)"
    local ++FAIL
}

* ===== A7a: zero-observation using dataset (vars defined, 0 rows) =====
clear
set obs 1
gen double key = .
gen long   uid = .
drop in 1
save "`UEMPTY'"
use "`M0'", clear
capture quietly rangematch key lo hi using "`UEMPTY'", keepusing(uid) unmatched(master)
local rc = _rc
if `rc' != 0 {
    di as error "A7a zero-obs using: rc=" `rc' " (want 0)"
    local ++FAIL
}
else {
    if r(N_pairs) != 1 | r(N_matched_pairs) != 0 | r(N_using) != 0 {
        di as error "A7a zero-obs using: pairs=" r(N_pairs) ///
            " matched=" r(N_matched_pairs) " N_using=" r(N_using) " (want 1,0,0)"
        local ++FAIL
    }
}

* ===== A7b: all-missing master bounds under each missing() policy =====
* 5 using points in [0,40]; master single row with BOTH bounds missing.
clear
set obs 5
gen double key = _n*5
gen long   uid = _n
save "`U5'"
clear
input double lo double hi long mid
. . 1
end
tempfile MNAN
save "`MNAN'"

* wildcard (default): fully open -> matches all 5
use "`MNAN'", clear
quietly rangematch key lo hi using "`U5'", keepusing(uid) unmatched(none)
if r(N_matched_pairs) != 5 {
    di as error "A7b wildcard: matched=" r(N_matched_pairs) " (want 5)"
    local ++FAIL
}
* error: aborts 459
use "`MNAN'", clear
capture rangematch key lo hi using "`U5'", missing(error)
if _rc != 459 {
    di as error "A7b error: rc=" _rc " (want 459)"
    local ++FAIL
}
* drop: removes the only master row; empty-side routing returns normally
use "`MNAN'", clear
capture rangematch key lo hi using "`U5'", missing(drop)
local drop_rc = _rc
if `drop_rc' != 0 | r(N_master) != 0 | r(N_using) != 5 ///
        | r(N_pairs) != 0 | r(N_matched_pairs) != 0 | _N != 0 {
    di as error "A7b drop-empties-master: rc=" `drop_rc' ///
        " N_master=" r(N_master) " N_using=" r(N_using) ///
        " pairs=" r(N_pairs) " matched=" r(N_matched_pairs) ///
        " output N=" _N " (want 0,0,5,0,0,0)"
    local ++FAIL
}

* ===== A7c: maxpairs boundary-exact (==maxpairs ok, >maxpairs aborts) =====
* master [0,100] matches all 5 using points -> 5 pairs.
clear
input double lo double hi long mid
0 100 1
end
tempfile MWIDE
save "`MWIDE'"
use "`MWIDE'", clear
capture quietly rangematch key lo hi using "`U5'", maxpairs(5) unmatched(none)
if _rc != 0 {
    di as error "A7c maxpairs(5)==exact: rc=" _rc " (want 0)"
    local ++FAIL
}
use "`MWIDE'", clear
capture rangematch key lo hi using "`U5'", maxpairs(4) unmatched(none)
if _rc != 198 {
    di as error "A7c maxpairs(4)<needed: rc=" _rc " (want 198)"
    local ++FAIL
}

* ===== A7d: caller data restored after an erroring call =====
use "`MWIDE'", clear
gen double sentinel = 42
local Nbefore = _N
local sent_before = sentinel[1]
capture rangematch key lo hi using "`U5'", maxpairs(4) unmatched(none)
if _rc != 198 {
    di as error "A7d expected error not raised: rc=" _rc
    local ++FAIL
}
capture confirm variable sentinel
if _rc | _N != `Nbefore' | sentinel[1] != `sent_before' {
    di as error "A7d restore failed: N=" _N " sentinel=" sentinel[1] ///
        " (want N=`Nbefore' sentinel=`sent_before', var present)"
    local ++FAIL
}

* ===== A8: astronomical tolerance() + open bound must not overflow to =====
* missing and silently drop a legitimate match (regression for the
* tolerance-shift underflow: mindouble() - tol -> . sorts above every key, so
* lo_search excludes everything). One cell per backend (sweep / binary-nearest
* / overlap). Each SHOULD match; the pre-fix code returned matched=0.
* A single using key at 50 sits inside the open-below master interval [.,100].
clear
input double key long uid
50 1
end
tempfile UA8
save "`UA8'"
* master interval open below, closed at 100
clear
input double key double lo double hi long mid
50 . 100 1
end
tempfile MA8
save "`MA8'"

* A8a sweep (default backend): open-below master, huge tolerance -> still 1 match
use "`MA8'", clear
quietly rangematch key lo hi using "`UA8'", keepusing(uid) ///
    unmatched(none) tolerance(1e300)
if r(N_matched_pairs) != 1 {
    di as error "A8a sweep huge-tol: matched=" r(N_matched_pairs) ///
        " backend=" r(backend) " (want 1)"
    local ++FAIL
}
* A8b binary backend (nearest): master key present, distance 0 -> 1 match
use "`MA8'", clear
quietly rangematch key lo hi using "`UA8'", keepusing(uid) ///
    nearest(both) unmatched(none) tolerance(1e300)
if r(N_matched_pairs) != 1 {
    di as error "A8b nearest huge-tol: matched=" r(N_matched_pairs) ///
        " backend=" r(backend) " (want 1)"
    local ++FAIL
}
* A8c overlap backend: master [.,100] overlaps using [40,60] -> 1 match
clear
input double ulo double uhi long uid
40 60 1
end
tempfile UOA8
save "`UOA8'"
use "`MA8'", clear
quietly rangematch lo hi using "`UOA8'", overlap(ulo uhi) keepusing(uid) ///
    unmatched(none) tolerance(1e300)
if r(N_matched_pairs) != 1 {
    di as error "A8c overlap huge-tol: matched=" r(N_matched_pairs) ///
        " backend=" r(backend) " (want 1)"
    local ++FAIL
}

di as txt "{hline 60}"
if `FAIL' > 0 {
    di as error "test_rangematch_edge_topup: FAILED (`FAIL')"
    di "RESULT: test_rangematch_edge_topup tests=6 pass=" 6-`FAIL' ///
        " fail=" `FAIL'
    exit 9
}
di as result "test_rangematch_edge_topup: PASSED"
di "RESULT: test_rangematch_edge_topup tests=6 pass=6 fail=0"
