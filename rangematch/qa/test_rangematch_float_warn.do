*! test_rangematch_float_warn.do
*! A2: non-fatal float-precision warning. Fires when a matching variable is
*! stored as float with values beyond float's exact-integer range (2^24,
*! e.g. %tc clocks); stays silent for double storage and for small-magnitude
*! floats (e.g. %td dates). The warning never aborts the command.

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
* Run a rangematch call with console captured to a text log, then report
* whether the float warning text appeared. Returns r(warned) and r(rc).
capture program drop _rm_did_warn
program define _rm_did_warn, rclass
    args cmdline
    tempfile lg
    quietly log using "`lg'.txt", replace text name(_fw)
    capture noisily `cmdline'
    local rc = _rc
    quietly log close _fw
    local warned 0
    tempname fh
    file open `fh' using "`lg'.txt", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "stored as float") local warned 1
        file read `fh' line
    }
    file close `fh'
    return scalar warned = `warned'
    return scalar rc = `rc'
end

tempfile U1 U2 U3 M MF

* %tc clock values (~1.9e12, far beyond 2^24)
clear
set obs 5
gen double t = clock("2020-01-0" + string(_n) + " 00:00:00", "YMDhms")
gen float  key_f = t
gen double key_d = t
gen long   uid = _n
keep key_f key_d uid
save "`U1'"

* small-magnitude float key (%td-scale dates ~22000, within 2^24)
clear
set obs 5
gen double d = td(01jan2020) + _n
gen float  key_f = d
gen long   uid = _n
keep key_f uid
save "`U3'"

* master with DOUBLE bounds spanning the %tc range
clear
set obs 1
gen double lo = clock("2019-01-01 00:00:00", "YMDhms")
gen double hi = clock("2021-01-01 00:00:00", "YMDhms")
gen long   mid = 1
save "`M'"

* master with FLOAT %tc bounds
clear
set obs 1
gen double lo_d = clock("2019-01-01 00:00:00", "YMDhms")
gen double hi_d = clock("2021-01-01 00:00:00", "YMDhms")
gen float  lo = lo_d
gen float  hi = hi_d
gen long   mid = 1
drop lo_d hi_d
save "`MF'"

* --- 1: float %tc using key -> WARN, rc 0 (non-fatal)
use "`M'", clear
_rm_did_warn `"rangematch key_f lo hi using "`U1'", keepusing(uid)"'
local ++TESTS
if r(warned) != 1 | r(rc) != 0 {
    di as error "S1 float %tc key: warned=" r(warned) " rc=" r(rc) " (want 1,0)"
    local ++FAIL
}

* --- 2: double %tc using key -> NO warn
use "`M'", clear
_rm_did_warn `"rangematch key_d lo hi using "`U1'", keepusing(uid)"'
local ++TESTS
if r(warned) != 0 {
    di as error "S2 double %tc key: warned=" r(warned) " (want 0)"
    local ++FAIL
}

* --- 3: small-magnitude float key (%td) -> NO warn (within 2^24)
clear
set obs 1
gen double lo = td(01jan2019)
gen double hi = td(01jan2021)
gen long   mid = 1
_rm_did_warn `"rangematch key_f lo hi using "`U3'", keepusing(uid)"'
local ++TESTS
if r(warned) != 0 {
    di as error "S3 small float %td key: warned=" r(warned) " (want 0)"
    local ++FAIL
}

* --- 4: float %tc master bound -> WARN, rc 0
use "`MF'", clear
_rm_did_warn `"rangematch key_d lo hi using "`U1'", keepusing(uid)"'
local ++TESTS
if r(warned) != 1 | r(rc) != 0 {
    di as error "S4 float %tc master bound: warned=" r(warned) " rc=" r(rc) " (want 1,0)"
    local ++FAIL
}

di as txt "{hline 60}"
display "RESULT: float_warn tests=`TESTS' pass=`=`TESTS' - `FAIL'' fail=`FAIL'"
if `FAIL' > 0 {
    di as error "test_rangematch_float_warn: FAILED (`FAIL')"
    exit 9
}
di as result "test_rangematch_float_warn: PASSED"
