clear all
set more off
version 16.0
set linesize 255

* test_datamap_v1101.do - regression for the 1.10.1 dataset-heading fix.
* A dataset file named with a leading underscore (_demo_cohort.dta) printed
* the heading "## 1.  Demo Cohort" (two spaces) and the TOC entry
* "1. [ Demo Cohort](#1--demo-cohort)".
*   T1 single(): heading, TOC entry and anchor carry no stray space or hyphen
*   T2 a name without a leading underscore is unchanged (guard)
* 2026-11-10 (datamap 2.0.0): ported from datadict to datamap's single
* Markdown writer.  The writer no longer title-cases the file name (1.x
* printed "Under Cohort"): the heading is "## 1. <file name as written>" and
* the anchor keeps the underscore (GitHub's rule: lower case, spaces to
* hyphens, underscores and hyphens kept).  The table of contents is a
* document feature, so a title() makes it appear.  The intent is unchanged:
* no doubled space, no stray hyphen from the leading underscore.

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

* number of lines in a datamap document that equal a string exactly
* (Mata reader: the Source line ends in a backtick, which breaks a macro reader)
do "`qa_dir'/_qa_md.do"
capture program drop _v1101_has
program define _v1101_has, rclass
    args file needle
    qa_md_contains using `"`file'"', needle(`"`needle'"') exact
    return scalar n = r(n)
end

local ++test_count
capture noisily {
    capture erase "`W'/u.md"
    quietly datamap, single("`W'/_under_cohort.dta") output("`W'/u.md") title("T")
    _v1101_has "`W'/u.md" "## 1. _under_cohort"
    assert r(n) == 1
    _v1101_has "`W'/u.md" "1. [_under_cohort](#1-_under_cohort)"
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
    quietly datamap, single("`W'/plain_cohort.dta") output("`W'/p.md") title("T")
    _v1101_has "`W'/p.md" "## 1. plain_cohort"
    assert r(n) == 1
    _v1101_has "`W'/p.md" "1. [plain_cohort](#1-plain_cohort)"
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
