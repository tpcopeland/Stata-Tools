* test_iivw_readme_sequence.do
* The README Quick Start followed by every Worked Example, extracted from the
* README and run in order in one session, must execute. Example 2 leaves
* FIPTIW weights stabilized on treated; Example 5's models omit treated, so
* without a reweighting line the sequence stopped there with r(198).
* budget: 90
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_readme_sequence.do
*
* The suite runs under sysdir sandboxes (iivw_qa_bootstrap), so it never
* touches the caller's ado tree, and it works in a scratch directory so the
* workbook the README writes lands outside the repository.

clear all
set varabbrev off
version 16.0

capture log close _all
tempfile test_log
log using "`test_log'", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
do "`qa_dir'/_iivw_qa_common.do"
* iivw_qa_bootstrap always creates a fresh nested sandbox for this suite
* (also under run_all); it is removed at the end, after PLUS is restored
iivw_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"
local sandbox "`r(sandbox)'"

capture mata: mata drop _iivw_readme_extract()
mata:
void _iivw_readme_extract(string scalar readme, string scalar out)
{
    real scalar fh, fo, infence, run, nblocks
    string scalar line, fence
    fence = char(96) + char(96) + char(96)
    fh = fopen(readme, "r")
    fo = fopen(out, "w")
    infence = 0
    run = 0
    nblocks = 0
    while ((line = fget(fh)) != J(0, 0, "")) {
        if (substr(line, 1, 3) == "## ") {
            run = (line == "## Quick Start" | line == "## Worked Examples")
        }
        if (run) {
            if (line == fence + "stata") {
                infence = 1
                nblocks++
            }
            else if (line == fence) infence = 0
            else if (infence) fput(fo, line)
        }
    }
    fclose(fh)
    fclose(fo)
    st_numscalar("r_nblocks", nblocks)
}
end

**# 1. Quick Start then Worked Examples 1-5 (and the reporting block) in sequence
local ++test_count
local here "`c(pwd)'"
capture noisily {
    tempfile seq
    mata: _iivw_readme_extract("`pkg_dir'/README.md", "`seq'")
    local nblocks = scalar(r_nblocks)
    * Quick Start, Examples 1-4, Example 5 and its reporting block
    assert `nblocks' >= 7
    tempfile stub
    local work "`stub'_readme"
    mkdir "`work'"
    quietly cd "`work'"
    do "`seq'"
    confirm file "iivw_reporting_exports.xlsx"
}
local seq_rc = _rc
quietly cd "`here'"
if `seq_rc' == 0 {
    local ++pass_count
    display as result "PASS: README Quick Start + Worked Examples run in sequence"
}
else {
    local ++fail_count
    display as error "FAIL: README Quick Start + Worked Examples sequence (rc=`seq_rc')"
}

if "`work'" != "" capture shell rm -rf "`work'"
iivw_qa_sandbox_restore
if "`sandbox'" != "" capture shell rm -rf "`sandbox'"

iivw_qa_summary, name("test_iivw_readme_sequence") tests(`test_count') pass(`pass_count') fail(`fail_count')
