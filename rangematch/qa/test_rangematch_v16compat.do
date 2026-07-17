* test_rangematch_v16compat.do — Stata 16.1 compatibility probe
*
* Purpose: provide evidence that the rangematch package honors its declared
* `version 16.1` floor. Three probes:
*
*   Probe 1: caller's Stata is >= 16.1
*   Probe 2: static scan of rangematch.ado and _rangematch_mata.ado for
*            command/function names that did not exist in Stata 16.1
*            (collect, didregress, xtdidregress, frameput, jdbc, geoplot)
*   Probe 3: smoke calls (basic, by(), unmatched(both)) made from inside a
*            `version 16.1` do-file. Because rangematch.ado and
*            _rangematch_mata.ado both declare `version 16.1`, the internal
*            parser frame matches what an actual Stata 16.1 user would hit
*            — modulo any post-16.1 functions silently present in the host
*            binary that would fail to resolve on a real 16.1.
*
* Limitation: this runs on whatever Stata binary is installed locally (not
* an actual 16.1). The `version 16.1` declarations cap the syntax interpreter
* but do not strip newer functions from the binary. To fully verify on real
* 16.1, install Stata 16.1 and run the QA suite there.

version 16.1

local TESTS 0
quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
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

* ---------------------------------------------------------------------------
* Probe 1: caller's Stata supports version 16.1
* ---------------------------------------------------------------------------
if c(stata_version) < 16.1 {
    display as error "test_rangematch_v16compat requires Stata 16.1+ (have " c(stata_version) ")"
    exit 9
}
local ++TESTS
display as result "v16compat probe 1: caller Stata is " c(stata_version) " (>= 16.1) -- PASS"

* ---------------------------------------------------------------------------
* Probe 2: static scan for symbols that didn't exist in Stata 16.1
* ---------------------------------------------------------------------------
local v17_only_cmds collect didregress xtdidregress frameput jdbc geoplot

local files rangematch.ado _rangematch_mata.ado
local hits 0
local hit_detail ""
foreach f of local files {
    capture confirm file "`pkg_dir'/`f'"
    if _rc {
        display as error "v16compat probe 2: missing file `pkg_dir'/`f'"
        exit 9
    }
    tempname fh
    file open `fh' using "`pkg_dir'/`f'", read text
    local lineno = 0
    file read `fh' line
    while r(eof) == 0 {
        local ++lineno
        * Skip whole-line comments (* or //) to reduce false positives
        if !regexm(`"`macval(line)'"', "^[ \t]*\*") & !regexm(`"`macval(line)'"', "^[ \t]*//") {
            foreach c of local v17_only_cmds {
                if regexm(`"`macval(line)'"', "(^|[^A-Za-z0-9_])`c'($|[^A-Za-z0-9_])") {
                    local ++hits
                    local hit_detail `"`hit_detail' `f':`lineno'(`c')"'
                }
            }
        }
        file read `fh' line
    }
    file close `fh'
}
if `hits' > 0 {
    display as error "v16compat probe 2: found `hits' Stata-17-only symbol(s):`hit_detail'"
    exit 9
}
local ++TESTS
display as result "v16compat probe 2: no Stata-17-only command names referenced in `: word count `files'' file(s) -- PASS"

* ---------------------------------------------------------------------------
* Probe 2b: each .ado must declare `version 16.1` (the documented floor) and
* must NOT declare a lower `version 16.0`. This locks the code's parser-frame
* floor to the minimum advertised in the help file, README, and .pkg, so the
* probe-3 smoke calls below genuinely exercise the 16.1 syntax interpreter.
* ---------------------------------------------------------------------------
foreach f of local files {
    tempname fh
    file open `fh' using "`pkg_dir'/`f'", read text
    local saw_161 = 0
    local saw_old = 0
    file read `fh' line
    while r(eof) == 0 {
        if regexm(`"`macval(line)'"', "^[ \t]*version[ \t]+16\.1([^0-9]|$)") {
            local saw_161 = 1
        }
        if regexm(`"`macval(line)'"', "^[ \t]*version[ \t]+16\.0([^0-9]|$)") {
            local saw_old = 1
        }
        file read `fh' line
    }
    file close `fh'
    if `saw_old' {
        display as error ///
            "v16compat probe 2b: `f' declares 'version 16.0' but the documented floor is 16.1"
        exit 9
    }
    if !`saw_161' {
        display as error ///
            "v16compat probe 2b: `f' does not declare 'version 16.1' (the documented floor)"
        exit 9
    }
}
local ++TESTS
display as result "v16compat probe 2b: both .ado files declare 'version 16.1' and none declares '16.0' -- PASS"

* ---------------------------------------------------------------------------
* Probe 3: smoke call rangematch from inside a version-16.1 do-file
* ---------------------------------------------------------------------------
tempfile usingF
clear
set obs 6
gen int uid = _n
gen double event_date = mdy(1, 1, 2020) + (_n - 1) * 5
gen byte g = mod(_n - 1, 2)
gen double y = uid * 1.0
save "`usingF'", replace

clear
set obs 3
gen int mid = _n
gen double lo = mdy(1, 1, 2020) + (_n - 1) * 10
gen double hi = lo + 7
gen byte g = mod(_n - 1, 2)
tempfile master_v16
save "`master_v16'", replace

* basic
use "`master_v16'", clear
rangematch event_date lo hi using "`usingF'", keepusing(y) ///
    masterid(mrow) usingid(urow) generate(matched)
qui count
local n1 = r(N)

* by()
use "`master_v16'", clear
rangematch event_date lo hi using "`usingF'", by(g) ///
    keepusing(y) masterid(mrow) usingid(urow) generate(matched)
qui count
local n2 = r(N)

* unmatched(both)
use "`master_v16'", clear
rangematch event_date lo hi using "`usingF'", ///
    keepusing(y) generate(matched) unmatched(both)
qui count
local n3 = r(N)

if `n1' <= 0 | `n2' <= 0 | `n3' <= 0 {
    display as error "v16compat probe 3: rangematch produced no rows (n1=`n1' n2=`n2' n3=`n3')"
    exit 9
}
local ++TESTS
display as result "v16compat probe 3: rangematch callable from a v16.1 caller (basic=`n1' by=`n2' unmatched=`n3') -- PASS"

* Terminal sentinel (RM-I20): assert-driven, so reaching this line is the
* pass condition and its ABSENCE is what a runner must treat as failure.
display "RESULT: test_rangematch_v16compat tests=`TESTS' pass=`TESTS' fail=0"
display as result _newline "test_rangematch_v16compat: ALL PROBES PASSED"
