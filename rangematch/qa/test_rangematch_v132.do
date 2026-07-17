*! test_rangematch_v132.do
*! v1.3.2 regression suite. Covers three fixes from the 2026-07-07 audit:
*!   T1-T3  BUG 1: interval-overlap backend gains a per-row (uobs) sort
*!          tiebreaker, so nosort output order is deterministic when several
*!          using intervals share the same (group, lower bound). Without it,
*!          Mata's unstable sort() emits tied rows in an arbitrary order.
*!   T4     BUG 4: maxpairs() overflow message reports "at least" N rows
*!          (N is the count at the point the limit was hit -- a lower bound).
*!   T5     BUG 3: the default-frame output path still restores value labels
*!          after the redundant in-loop reassignment was removed.

version 16.1
clear all
set more off
set varabbrev off

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
discard

local FAIL 0
local TESTS 0
* ---------------------------------------------------------------------------
* Fixture: 8 using intervals, all in the same (single) group, all sharing the
* SAME lower bound ulo=0 (a tied block), with distinct upper bounds. A single
* master interval [10, 20] overlaps every one of them. Original using rows are
* saved in order 1..8. Under nosort the output must list them by original row
* number (ascending) -- the property the uobs tiebreaker guarantees. On the
* pre-fix code Mata's sort() returned this tied block in an arbitrary order
* (empirically e.g. 5 4 2 3 1 ...), so the ascending assertion has teeth.
* ---------------------------------------------------------------------------
tempfile U1 M1
clear
set obs 8
gen double ulo = 0
gen double uhi = 100 + _n
gen long   urid = _n
save "`U1'"

clear
set obs 1
gen double mlo = 10
gen double mhi = 20
gen long   mid = 1
save "`M1'"

* --- T1: nosort overlap, tied-ulo block emits usingid in ascending order
use "`M1'", clear
rangematch mlo mhi using "`U1'", overlap(ulo uhi) usingid(urow) ///
    unmatched(none) frame(v132a) replace nosort
local ok1 1
frame v132a {
    quietly count
    if r(N) != 8 {
        di as error "T1 count=" r(N) " (want 8)"
        local ok1 0
    }
    forvalues i = 1/8 {
        if urow[`i'] != `i' local ok1 0
    }
}
local ++TESTS
if !`ok1' {
    frame v132a: list urow, clean noobs
    di as error "T1 nosort overlap tied-ulo order not ascending by original row"
    local ++FAIL
}

* --- T2: same call twice gives byte-identical nosort output order
capture program drop _v132_ordervec
program define _v132_ordervec, rclass
    args mfile ufile
    use "`mfile'", clear
    rangematch mlo mhi using "`ufile'", overlap(ulo uhi) usingid(urow) ///
        unmatched(none) frame(_v132ord) replace nosort
    frame _v132ord {
        local vec ""
        forvalues i = 1/`=_N' {
            local vec "`vec' `=urow[`i']'"
        }
    }
    capture frame drop _v132ord
    return local vec `"`vec'"'
end

_v132_ordervec "`M1'" "`U1'"
local vecA `"`r(vec)'"'
_v132_ordervec "`M1'" "`U1'"
local vecB `"`r(vec)'"'
local ++TESTS
if `"`vecA'"' != `"`vecB'"' {
    di as error "T2 nosort order not reproducible across runs: [`vecA'] vs [`vecB']"
    local ++FAIL
}
* And the reproducible order is the ascending original-row order.
local ++TESTS
if trim(`"`vecA'"') != "1 2 3 4 5 6 7 8" {
    di as error "T2 order=[`vecA'] (want 1 2 3 4 5 6 7 8)"
    local ++FAIL
}

* --- T3: by-group tied blocks -- within each group usingid is ascending.
* Two groups, each with 6 using intervals sharing ulo=0; one master per group.
tempfile U3 M3
clear
set obs 12
gen long   g    = ceil(_n / 6)
gen double ulo  = 0
gen double uhi  = 50 + _n
gen long   urid = _n
save "`U3'"

clear
set obs 2
gen long   g   = _n
gen double mlo = 5
gen double mhi = 10
save "`M3'"

use "`M3'", clear
rangematch mlo mhi using "`U3'", overlap(ulo uhi) by(g) usingid(urow) ///
    unmatched(none) frame(v132c) replace nosort
local ok3 1
frame v132c {
    quietly count
    if r(N) != 12 local ok3 0
    * Rows for g==1 are original using rows 1..6, for g==2 are 7..12; within
    * each contiguous group block the usingid must be strictly increasing.
    quietly count if g == 1
    local n_g1 = r(N)
    forvalues i = 2/`=_N' {
        if g[`i'] == g[`i'-1] & urow[`i'] <= urow[`i'-1] local ok3 0
    }
}
local ++TESTS
if !`ok3' {
    frame v132c: list g urow, clean noobs sepby(g)
    di as error "T3 by-group nosort tied-ulo order not ascending within group"
    local ++FAIL
}

* --- T4: maxpairs() overflow message reports "at least" (lower-bound wording).
* 3 masters x 4 tied-overlap using rows = 12 pairs; cap at 5 forces overflow.
tempfile U4 M4
clear
set obs 4
gen double ulo = 0
gen double uhi = 100
save "`U4'"
clear
set obs 3
gen double mlo = 1
gen double mhi = 2
save "`M4'"

use "`M4'", clear
capture rangematch mlo mhi using "`U4'", overlap(ulo uhi) ///
    maxpairs(5) frame(v132d) replace
local ++TESTS
if _rc != 198 {
    di as error "T4 maxpairs overflow rc=" _rc " (want 198)"
    local ++FAIL
}
* Replay capturing the display text to confirm the "at least" wording.
capture {
    tempname lf
    log using "v132_maxpairs.log", replace text name(`lf')
    use "`M4'", clear
    capture noisily rangematch mlo mhi using "`U4'", overlap(ulo uhi) ///
        maxpairs(5) frame(v132d) replace
    log close `lf'
}
tempname fh
file open `fh' using "v132_maxpairs.log", read
local found_atleast 0
file read `fh' line
while r(eof) == 0 {
    if strpos(`"`line'"', "would produce at least") local found_atleast 1
    file read `fh' line
}
file close `fh'
capture erase "v132_maxpairs.log"
local ++TESTS
if !`found_atleast' {
    di as error "T4 maxpairs message missing 'would produce at least' wording"
    local ++FAIL
}

* --- T5: default-frame output path still restores value labels (BUG 3).
* Forcing the in-place (default-frame) route: no frame(), no saving(). The
* master carries a value label on a carried variable; it must survive onto the
* output. This exercises the branch where `clear' wipes label definitions and
* _rm_copy_output re-creates them (the block the audit trimmed).
clear
set obs 3
gen double ulo = 0
gen double uhi = 100
gen long   cat = _n
label define catlbl 1 "one" 2 "two" 3 "three"
label values cat catlbl
tempfile U5
save "`U5'"

clear
set obs 1
gen double mlo = 10
gen double mhi = 20
rangematch mlo mhi using "`U5'", overlap(ulo uhi) keepusing(cat) ///
    unmatched(none)
local vl : value label cat
local lbl1 : label (cat) 1
local lbl2 : label (cat) 2
local ++TESTS
if "`vl'" != "catlbl" | "`lbl1'" != "one" | "`lbl2'" != "two" {
    di as error "T5 value label lost on default-frame path: vl=`vl' 1=`lbl1' 2=`lbl2'"
    local ++FAIL
}

* --- T6: Mata-backend version handshake was bumped for the backend change.
* The .ado reloads the backend only when _rm_mata_version() disagrees with the
* required string it hard-codes; the two must move in lockstep or an in-session
* user keeps a stale (buggy) backend after an update. If they had drifted apart
* rangematch would have failed to load (exit 111) at T1 -- so reaching here with
* T1-T5 having run already proves .ado-required == backend. This asserts the
* backend was bumped to this release's version (guards a "forgot to bump the
* handshake after changing the backend" regression).
capture mata: st_local("_mv", _rm_mata_version())
tempname _rm_vfh
file open `_rm_vfh' using "`pkg_dir'/rangematch.ado", read text
file read `_rm_vfh' _rm_header
file close `_rm_vfh'
local _rm_vpos = strpos(`"`_rm_header'"', "Version ")
local _rm_vrest = substr(`"`_rm_header'"', `_rm_vpos' + 8, .)
gettoken _rm_expected : _rm_vrest
local ++TESTS
if "`_mv'" != "`_rm_expected'" {
    di as error "T6 backend version=`_mv' (want `_rm_expected') -- bump _rm_mata_version() and _rm_required_mata_version together"
    local ++FAIL
}

display "RESULT: test_rangematch_v132 tests=`TESTS' pass=`=`TESTS' - `FAIL'' fail=`FAIL'"
if `FAIL' > 0 {
    di as error "test_rangematch_v132: FAILED (`FAIL')"
    exit 9
}
di as result "test_rangematch_v132: PASSED"
