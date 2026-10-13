*! test_readme_sequence.do
*! The README Quick Start followed by every Worked Example, run in one
*! session, must execute (frame `analysis` from the Quick Start used to make
*! Worked Example 1 fail with r(198)).
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
quietly log using "test_readme_sequence.log", replace text nomsg
do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"
local tests = 0
local pass = 0
local fail = 0

mata:
void _tv_readme_extract(string scalar readme, string scalar out)
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

**# 1. Quick Start then Worked Examples 1-7 run in sequence
local ++tests
capture noisily {
    tempfile seq
    mata: _tv_readme_extract("`pkg_dir'/README.md", "`seq'")
    local nblocks = scalar(r_nblocks)
    assert `nblocks' >= 9
    capture frame change default
    foreach f in analysis analysis_manifest provenance {
        capture frame drop `f'
    }
    do "`seq'"
}
if _rc == 0 local ++pass
else {
    local ++fail
    display as error "FAIL: README Quick Start + Worked Examples sequence"
}

display "RESULT: test_readme_sequence tests=`tests' pass=`pass' fail=`fail' skip=0"
capture log close _all
if `fail' exit 1
