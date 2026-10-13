clear all
set more off
version 16.0
set linesize 255

* test_datamap_v1101.do - regression for the 1.10.1 datadict heading fix.
* A dataset file named with a leading underscore (_demo_cohort.dta) printed
* the heading "## 1.  Demo Cohort" (two spaces) and the TOC entry
* "1. [ Demo Cohort](#1--demo-cohort)".
*   T1 single(): heading, TOC entry and anchor carry no stray space or hyphen
*   T2 a name without a leading underscore is unchanged (guard)

local qa_dir  "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
discard

local test_count = 0
local pass_count = 0
local fail_count = 0

local W "`c(tmpdir)'/v1101"
capture mkdir "`W'"

sysuse auto, clear
quietly keep make price mpg
quietly save "`W'/_under_cohort.dta", replace
quietly save "`W'/plain_cohort.dta", replace

* number of lines in a text file that equal a string exactly
capture program drop _v1101_has
program define _v1101_has, rclass
    args file needle
    tempname fh
    local n 0
    file open `fh' using `"`file'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if `"`macval(line)'"' == `"`needle'"' local ++n
        file read `fh' line
    }
    file close `fh'
    return scalar n = `n'
end

local ++test_count
capture noisily {
    capture erase "`W'/u.md"
    quietly datadict, single("`W'/_under_cohort.dta") output("`W'/u.md")
    _v1101_has "`W'/u.md" "## 1. Under Cohort"
    assert r(n) == 1
    _v1101_has "`W'/u.md" "1. [Under Cohort](#1-under-cohort)"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: T1 leading-underscore dataset heading and anchor"
}
else {
    local ++fail_count
    display as error "  FAIL: T1 leading-underscore dataset heading and anchor"
}

* guard: expected green at HEAD (behaviour-preservation: ordinary names are unchanged)
local ++test_count
capture noisily {
    capture erase "`W'/p.md"
    quietly datadict, single("`W'/plain_cohort.dta") output("`W'/p.md")
    _v1101_has "`W'/p.md" "## 1. Plain Cohort"
    assert r(n) == 1
    _v1101_has "`W'/p.md" "1. [Plain Cohort](#1-plain-cohort)"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: T2 ordinary dataset name unchanged"
}
else {
    local ++fail_count
    display as error "  FAIL: T2 ordinary dataset name unchanged"
}

local files : dir "`W'" files "*"
foreach f of local files {
    capture erase "`W'/`f'"
}
capture rmdir "`W'"

display as text _newline "RESULT: test_datamap_v1101 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
