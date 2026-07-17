*! test_rangematch_ties_random.do
*! v1.3.0: ties(random) unbiased tie-break + seed() reproducibility.
*! Covers: ties(all|first|last) determinism baseline, ties(random) picks
*! exactly one tied row, seed() gives reproducible draws, different seeds
*! diverge, the caller's RNG state is restored after a seeded call (and
*! advanced when no seed is given), r(seed)/r(ties) contract, and the
*! seed()-without-ties(random) guard.

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
* Single-group tie block: master key 100, two using rows tie at key 110
* (the nearest key at or after 100), plus a farther in-range row at 150.
tempfile U M UG MG
clear
input double key long urow_id
110 1
110 2
150 3
end
save "`U'"

clear
set obs 1
gen double key = 100
gen double lo  = 0
gen double hi  = 200
gen long   mid = 1
save "`M'"

* --- 1: ties(all) keeps both tied rows
use "`M'", clear
rangematch key lo hi using "`U'", nearest(after) ties(all) ///
    usingid(urow) unmatched(none) frame(o1) replace
local ++TESTS
if r(N_matched_pairs) != 2 {
    di as error "S1 ties(all): N_matched_pairs=" r(N_matched_pairs) " (want 2)"
    local ++FAIL
}

* --- 2: ties(first) keeps the lowest original using row (urow==1)
use "`M'", clear
rangematch key lo hi using "`U'", nearest(after) ties(first) ///
    usingid(urow) unmatched(none) frame(o2) replace
frame o2 {
    quietly count
    local n2 = r(N)
    quietly summarize urow, meanonly
    local pick2 = r(mean)
}
local ++TESTS
if `n2' != 1 | `pick2' != 1 {
    di as error "S2 ties(first): n=`n2' urow=`pick2' (want 1, 1)"
    local ++FAIL
}

* --- 3: ties(last) keeps the highest original using row (urow==2)
use "`M'", clear
rangematch key lo hi using "`U'", nearest(after) ties(last) ///
    usingid(urow) unmatched(none) frame(o3) replace
frame o3 {
    quietly count
    local n3 = r(N)
    quietly summarize urow, meanonly
    local pick3 = r(mean)
}
local ++TESTS
if `n3' != 1 | `pick3' != 2 {
    di as error "S3 ties(last): n=`n3' urow=`pick3' (want 1, 2)"
    local ++FAIL
}

* --- 4: ties(random) keeps exactly one tied row, and it is one of {1,2}
use "`M'", clear
rangematch key lo hi using "`U'", nearest(after) ties(random) seed(12345) ///
    usingid(urow) unmatched(none) frame(o4) replace
* Capture the r() contract before the frame count/summarize below clobber r().
local r4_ties `"`r(ties)'"'
local r4_seed `"`r(seed)'"'
frame o4 {
    quietly count
    local n4 = r(N)
    quietly summarize urow, meanonly
    local pick4 = r(mean)
}
local ++TESTS
if `n4' != 1 | !inlist(`pick4', 1, 2) {
    di as error "S4 ties(random): n=`n4' urow=`pick4' (want 1, in {1,2})"
    local ++FAIL
}
* r(seed)/r(ties) contract
local ++TESTS
if "`r4_ties'" != "random" | "`r4_seed'" != "12345" {
    di as error "S4 contract: ties=`r4_ties' seed=`r4_seed' (want random, 12345)"
    local ++FAIL
}

* Multi-group fixture: 50 by-groups, 2 tied using rows per group at key 110.
* Each master row's random draw is an independent bit, so two runs with the
* same seed must agree row-for-row and two different seeds must differ on at
* least one row (P(identical) = 2^-50).
clear
set obs 100
gen long   g       = ceil(_n / 2)
gen double key      = 110
gen long   urow_id  = _n
save "`UG'"

clear
set obs 50
gen long   g   = _n
gen double key = 100
gen double lo  = 0
gen double hi  = 200
save "`MG'"

* Helper: run a seeded ties(random) join and return the picked using-row
* vector as a space-separated string in r(vec).
capture program drop _rm_pickvec
program define _rm_pickvec, rclass
    args mfile ufile seed
    use "`mfile'", clear
    rangematch key lo hi using "`ufile'", by(g) nearest(after) ///
        ties(random) seed(`seed') usingid(urow) unmatched(none) ///
        frame(_pv) replace
    frame _pv {
        sort g
        local vec ""
        forvalues i = 1/`=_N' {
            local vec "`vec' `=urow[`i']'"
        }
    }
    capture frame drop _pv
    return local vec `"`vec'"'
end

_rm_pickvec "`MG'" "`UG'" 12345
local vecA `"`r(vec)'"'
_rm_pickvec "`MG'" "`UG'" 12345
local vecB `"`r(vec)'"'
_rm_pickvec "`MG'" "`UG'" 99999
local vecC `"`r(vec)'"'

* --- 5: same seed -> identical picks
local ++TESTS
if `"`vecA'"' != `"`vecB'"' {
    di as error "S5 same seed not reproducible"
    local ++FAIL
}
* --- 6: different seed -> at least one differing pick
local ++TESTS
if `"`vecA'"' == `"`vecC'"' {
    di as error "S6 different seeds produced identical picks (astronomically unlikely)"
    local ++FAIL
}

* --- 7: a seeded call restores the caller's RNG state (no leak)
set seed 777
local before = c(rngstate)
use "`M'", clear
rangematch key lo hi using "`U'", nearest(after) ties(random) seed(12345) ///
    usingid(urow) unmatched(none) frame(o7) replace
local after = c(rngstate)
local ++TESTS
if "`before'" != "`after'" {
    di as error "S7 seeded call did not restore c(rngstate)"
    local ++FAIL
}

* --- 8: without seed(), ties(random) uses and advances the current stream
set seed 777
local before8 = c(rngstate)
use "`M'", clear
rangematch key lo hi using "`U'", nearest(after) ties(random) ///
    usingid(urow) unmatched(none) frame(o8) replace
local after8 = c(rngstate)
local ++TESTS
if "`before8'" == "`after8'" {
    di as error "S8 no-seed ties(random) did not advance the RNG stream"
    local ++FAIL
}

* --- 9: seed() without ties(random) is rejected (rc 198)
use "`M'", clear
capture rangematch key lo hi using "`U'", nearest(after) ties(first) seed(1)
local ++TESTS
if _rc != 198 {
    di as error "S9 seed()+ties(first): rc=" _rc " (want 198)"
    local ++FAIL
}
capture rangematch key lo hi using "`U'", seed(1)
local ++TESTS
if _rc != 198 {
    di as error "S9b seed() alone: rc=" _rc " (want 198)"
    local ++FAIL
}

display "RESULT: test_rangematch_ties_random tests=`TESTS' pass=`=`TESTS' - `FAIL'' fail=`FAIL'"
if `FAIL' > 0 {
    di as error "test_rangematch_ties_random: FAILED (`FAIL')"
    exit 9
}
di as result "test_rangematch_ties_random: PASSED"
