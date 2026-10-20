/*
    File:    test_pkgtransfer_readme_sequence.do
    Purpose: (1) The README Quick Start followed by every Worked Example,
             extracted from the README and run in order in one working
             directory, must execute. Examples used to collide on
             pkgtransfer.do (r(602)) because a run never overwrites an
             existing output without replace.
    Safety:  Runs under sysdir sandboxes with a one-package tracker that
             points at the local checkout, so nothing leaves the machine and
             the caller's ado tree is never touched.
    Author:  Timothy P Copeland, Karolinska Institutet
    Date:    2026-10-13
*/

version 16.0
capture log close _all
set linesize 255

**# Setup

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa/?$", "")
local orig_dir "`c(pwd)'"

run "`qa_dir'/_pkgtransfer_qa_common.do"
_pkgtransfer_qa_setup, pkgdir("`pkg_dir'")
local qa_root "`r(root)'"
local qa_original_plus "`r(original_plus)'"
local qa_original_personal "`r(original_personal)'"
local qa_plus "`r(plus)'"
local work "`r(work)'"

capture program drop pkgtransfer
run "`pkg_dir'/pkgtransfer.ado"

* A tracker with the checkout as the only recorded package source
tempname fh
file open `fh' using "`qa_plus'/stata.trk", write text replace
file write `fh' "* 00000001" _n _n
file write `fh' "S `pkg_dir'" _n
file write `fh' "N pkgtransfer.pkg" _n
file write `fh' "d pkgtransfer" _n
file write `fh' "f p/pkgtransfer.ado" _n
file write `fh' "f p/pkgtransfer.sthlp" _n
file write `fh' "e" _n
file close `fh'

capture mata: mata drop _pt_readme_extract()
mata:
void _pt_readme_extract(string scalar readme, string scalar out)
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

local test_count = 0
local pass_count = 0
local fail_count = 0

**# 1. Quick Start then Worked Examples 1-5 run in order in one directory

local ++test_count
local t "`work'/seq"
capture noisily {
    mkdir "`t'"
    tempfile seq
    mata: _pt_readme_extract("`pkg_dir'/README.md", "`seq'")
    local nblocks = scalar(r_nblocks)
    * Quick Start (1 block) and Examples 1-5 (7 blocks); a block added or
    * dropped must be reflected in the output list below
    assert `nblocks' == 8
    quietly cd "`t'"
    do "`seq'"
    * every example's output exists next to the others
    foreach f in _all_packages.do source_install.do online_bundle.do ///
        online_bundle.zip local_setup.do local_setup.zip all_packages.do one_package.do ///
        without_one.do {
        confirm file "`t'/`f'"
    }
}
local test_rc = _rc
quietly cd "`orig_dir'"
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: README Quick Start + Worked Examples run in sequence"
}
else {
    local ++fail_count
    display as error "  FAIL: README Quick Start + Worked Examples sequence (rc `test_rc')"
}

**# 2. Bundle, install from the bundle, bundle again in the same directory

local ++test_count
local t2 "`work'/again"
capture noisily {
    mkdir "`t2'"
    quietly cd "`t2'"
    pkgtransfer, download(local) limited(pkgtransfer) dofile(first.do) zipfile(first.zip)
    * bundle creation leaves no pkgtransfer_files folder behind
    local leftover : dir "." dirs "pkgtransfer_files"
    assert `"`leftover'"' == ""
    do first.do
    * the installer unpacks into pkgtransfer_files, as documented
    local unpacked : dir "." dirs "pkgtransfer_files"
    assert `"`unpacked'"' != ""
    * a later bundle run in the same directory must not collide with it
    pkgtransfer, download(local) limited(pkgtransfer) dofile(second.do) zipfile(second.zip)
    confirm file "second.zip"
    * and a second run once more, replacing its own outputs
    pkgtransfer, download(local) limited(pkgtransfer) dofile(second.do) zipfile(second.zip) replace
}
local test_rc = _rc
quietly cd "`orig_dir'"
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: bundle, install, bundle again in one directory"
}
else {
    local ++fail_count
    display as error "  FAIL: bundle, install, bundle again in one directory (rc `test_rc')"
}

* guard: staging is expected green at pre-fix ref (HEAD staged in ./pkgtransfer_files and cleaned it; this pins cleanup of whichever staging is used)
**# 3. The temporary staging directory is removed after success and after an error

local ++test_count
local t3 "`work'/stage"
capture noisily {
    mkdir "`t3'"
    quietly cd "`t3'"
    local tmp = subinstr("`c(tmpdir)'", "\", "/", .)
    local before : dir "`tmp'" dirs "*_pkgtransfer", respectcase
    * success
    pkgtransfer, download(local) limited(pkgtransfer) dofile(ok.do) zipfile(ok.zip)
    confirm file "ok.zip"
    local after_ok : dir "`tmp'" dirs "*_pkgtransfer", respectcase
    assert `"`before'"' == `"`after_ok'"'
    * error after staging was created: a tracked file is missing
    tempfile held
    copy "`qa_plus'/p/pkgtransfer.sthlp" "`held'", replace
    erase "`qa_plus'/p/pkgtransfer.sthlp"
    capture noisily pkgtransfer, download(local) limited(pkgtransfer) dofile(bad.do) zipfile(bad.zip)
    local bad_rc = _rc
    copy "`held'" "`qa_plus'/p/pkgtransfer.sthlp", replace
    assert `bad_rc' != 0
    capture confirm file "bad.zip"
    assert _rc == 601
    local after_bad : dir "`tmp'" dirs "*_pkgtransfer", respectcase
    assert `"`before'"' == `"`after_bad'"'
    * and the working directory is intact and has no staging folder
    assert "`c(pwd)'" == "`t3'"
    local leftover : dir "." dirs "pkgtransfer_files"
    assert `"`leftover'"' == ""
}
local test_rc = _rc
quietly cd "`orig_dir'"
if `test_rc' == 0 {
    local ++pass_count
    display as result "  PASS: staging directory removed after success and after an error"
}
else {
    local ++fail_count
    display as error "  FAIL: staging directory removed after success and after an error (rc `test_rc')"
}

**# Cleanup and result

quietly cd "`orig_dir'"
capture quietly _pkgtransfer_cleanup_staging, directory("`t'")
_pkgtransfer_qa_cleanup, root("`qa_root'") ///
    originalplus("`qa_original_plus'") ///
    originalpersonal("`qa_original_personal'")

if `fail_count' > 0 {
    display as error ///
        "RESULT: test_pkgtransfer_readme_sequence tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
    exit 1
}
display as result ///
    "RESULT: test_pkgtransfer_readme_sequence tests=`test_count' pass=`pass_count' fail=0 skip=0"
