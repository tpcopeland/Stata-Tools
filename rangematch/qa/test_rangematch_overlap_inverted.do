*! test_rangematch_overlap_inverted.do
*! v1.3.0: inverted using-interval screen in overlap mode. A using interval
*! with ulow > uhigh (both non-missing) is counted in r(N_using_inverted) and
*! triggers a non-fatal warning; missing bounds are not counted (they are
*! open-ended, not inverted); point mode always reports 0; the warning never
*! aborts the command.

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
* Run a command with the console captured to a text log and report whether the
* inverted-bounds warning appeared. Returns r(warned) and r(rc).
capture program drop _rm_did_warn_inv
program define _rm_did_warn_inv, rclass
    args cmdline
    tempfile lg
    quietly log using "`lg'.txt", replace text name(_iw)
    capture noisily `cmdline'
    local rc = _rc
    quietly log close _iw
    local warned 0
    tempname fh
    file open `fh' using "`lg'.txt", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "inverted bounds") local warned 1
        file read `fh' line
    }
    file close `fh'
    return scalar warned = `warned'
    return scalar rc = `rc'
end

tempfile M U UOK PM PU

* Master interval [100, 200].
clear
input long id double mlo double mhi
1 100 200
end
save "`M'"

* Using intervals: one valid overlap, two inverted (ulo > uhi), one with a
* missing lower bound (open-ended, must NOT count as inverted).
clear
input long urow double ulo double uhi
1 150 250
2 300 250
3 180 120
4    .  150
end
save "`U'"

* Using intervals: all well-formed.
clear
input long urow double ulo double uhi
1 150 250
2  90 130
end
save "`UOK'"

* Point-mode fixtures.
clear
set obs 1
gen double key = 100
gen double lo  = 0
gen double hi  = 200
gen long   mid = 1
save "`PM'"
clear
input double key long uid
110 1
end
save "`PU'"

* --- 1: overlap mode with 2 inverted using intervals -> count 2, warn, rc 0
use "`M'", clear
_rm_did_warn_inv `"rangematch mlo mhi using "`U'", overlap(ulo uhi) keepusing(urow) unmatched(both)"'
local ++TESTS
if r(warned) != 1 | r(rc) != 0 {
    di as error "S1 inverted overlap: warned=" r(warned) " rc=" r(rc) " (want 1, 0)"
    local ++FAIL
}
* Re-run without log capture to read the stored count.
use "`M'", clear
rangematch mlo mhi using "`U'", overlap(ulo uhi) keepusing(urow) ///
    unmatched(both) frame(o1) replace
local ++TESTS
if r(N_using_inverted) != 2 {
    di as error "S1b r(N_using_inverted)=" r(N_using_inverted) " (want 2)"
    local ++FAIL
}

* --- 2: overlap mode with only well-formed intervals -> count 0, no warning
use "`M'", clear
_rm_did_warn_inv `"rangematch mlo mhi using "`UOK'", overlap(ulo uhi) keepusing(urow) unmatched(both)"'
local ++TESTS
if r(warned) != 0 {
    di as error "S2 well-formed overlap: warned=" r(warned) " (want 0)"
    local ++FAIL
}
use "`M'", clear
rangematch mlo mhi using "`UOK'", overlap(ulo uhi) keepusing(urow) ///
    unmatched(both) frame(o2) replace
local ++TESTS
if r(N_using_inverted) != 0 {
    di as error "S2b r(N_using_inverted)=" r(N_using_inverted) " (want 0)"
    local ++FAIL
}

* --- 3: point mode always reports r(N_using_inverted) == 0
use "`PM'", clear
rangematch key lo hi using "`PU'", keepusing(uid) frame(o3) replace
local ++TESTS
if r(N_using_inverted) != 0 {
    di as error "S3 point-mode r(N_using_inverted)=" r(N_using_inverted) " (want 0)"
    local ++FAIL
}

display "RESULT: overlap_inverted tests=`TESTS' pass=`=`TESTS' - `FAIL'' fail=`FAIL'"
if `FAIL' > 0 {
    di as error "test_rangematch_overlap_inverted: FAILED (`FAIL')"
    exit 9
}
di as result "test_rangematch_overlap_inverted: PASSED"
