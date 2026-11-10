clear all
set more off
version 16.0

* test_datamap_v200_upgrade.do - what an upgrade over an installed 1.x leaves
* behind in PLUS (install smoke, datamap 2.0.0 Phase 2)
*
* datadict.ado and datadict.sthlp are deleted at 2.0.0, and Stata's
* "net install, replace" never removes a file the new package no longer lists.
* OBSERVED 2026-11-10 with the pristine 1.10.6 package (snapshot of the
* released tree) installed into an empty PLUS, then the 2.0.0 tree installed
* over it with "net install datamap, from(...) replace":
*   - datadict.ado and datadict.sthlp stay in PLUS/d/
*   - stata.trk gets a SECOND "N datamap.pkg" entry (U 1 and U 2)
*   - the stale 1.10.6 datadict still resolves and RUNS (rc 0)
*   - "ado uninstall datamap" then stops: "criterion matches more than one
*     package", r(111); "ado uninstall [2]" then "[1]" clears both
*   - after "ado uninstall datamap" FIRST and a fresh install, datadict is
*     unrecognized (rc 199)
* The README upgrade line therefore says "ado uninstall datamap" before
* "net install datamap, replace".  These tests pin that, on a small stand-in
* for the old package (same name, same datadict file names, stub bodies,
* written below), so no 1.10.6 source is stored in the repository: Stata's
* file bookkeeping, not the file contents, is what is under test.  The stand-in
* was checked against the real 1.10.6 package in the observation above
* (identical leftover files, second stata.trk entry, r(111), r(199) after a
* clean reinstall).  Every case runs in its own empty PLUS and PERSONAL.

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") replace

do "`qa_dir'/_qa_md.do"

local orig_plus     : sysdir PLUS
local orig_personal : sysdir PERSONAL

* the stand-in for the installed 1.10.6 package
tempfile stub_base
local old_dir "`stub_base'_old1106"
capture mkdir "`old_dir'"
quietly file open fh using "`old_dir'/datamap.pkg", write text replace
file write fh "v 3" _n
file write fh "d 'DATAMAP': stand-in for the 1.10.6 package layout (QA fixture)" _n
file write fh "d Distribution-Date: 20261026" _n
file write fh "f datamap.ado" _n
file write fh "f datamap.sthlp" _n
file write fh "f datadict.ado" _n
file write fh "f datadict.sthlp" _n
file write fh "f _datamap_classify.ado" _n
file close fh
quietly file open fh using "`old_dir'/stata.toc", write text replace
file write fh "v 3" _n
file write fh "d Stata-Tools: datamap (QA stand-in)" _n
file write fh "p datamap" _n
file close fh
foreach p in datamap datadict _datamap_classify {
    quietly file open fh using "`old_dir'/`p'.ado", write text replace
    file write fh "*! `p' Version 1.10.6  2026/10/21 (QA stand-in)" _n
    file write fh "program define `p'" _n
    file write fh "    display " _char(34) "STAND-IN `p' 1.10.6" _char(34) _n
    file write fh "end" _n
    file close fh
}
foreach p in datamap datadict {
    quietly file open fh using "`old_dir'/`p'.sthlp", write text replace
    file write fh "{smcl}" _n
    file write fh "{title:`p' 1.10.6 stand-in}" _n
    file close fh
}

* an empty PLUS and PERSONAL for one case; discard drops cached programs, so
* a datadict that ran in an earlier case cannot answer for a later one
capture program drop _up_sandbox
program define _up_sandbox, rclass
    version 16.0
    syntax , Base(string) Case(string)
    local plus "`base'_`case'_plus"
    local personal "`base'_`case'_personal"
    capture mkdir "`plus'"
    capture mkdir "`personal'"
    sysdir set PLUS "`plus'/"
    sysdir set PERSONAL "`personal'/"
    discard
    return local plus "`plus'/"
end

* 1 = datadict resolves on the adopath, 0 = it does not
capture program drop _up_resolves
program define _up_resolves, rclass
    version 16.0
    syntax , Name(string)
    discard
    capture quietly findfile `name'.ado
    return scalar found = (_rc == 0)
end

capture program drop _up_restore
program define _up_restore
    version 16.0
    syntax , Plus(string) Personal(string)
    sysdir set PLUS "`plus'"
    sysdir set PERSONAL "`personal'"
    discard
end

**# U1: net install, replace over an installed 1.10.6 leaves datadict behind

local ++test_count
capture noisily {
    _up_sandbox, base("`stub_base'") case("u1")
    local plus "`r(plus)'"
    quietly net install datamap, from("`old_dir'") replace
    confirm file "`plus'd/datadict.ado"
    confirm file "`plus'd/datadict.sthlp"
    qa_md_contains using "`plus'stata.trk", needle("N datamap.pkg") exact
    assert r(n) == 1

    quietly net install datamap, from("`pkg_dir'") replace
    * the new package's files are in place ...
    confirm file "`plus'_/_datamap_md_document.ado"
    quietly checksum "`plus'd/datamap.ado"
    local got = r(checksum)
    quietly checksum "`pkg_dir'/datamap.ado"
    assert `got' == r(checksum)
    * ... and so is what the new package no longer ships
    confirm file "`plus'd/datadict.ado"
    confirm file "`plus'd/datadict.sthlp"
    qa_md_contains using "`plus'stata.trk", needle("N datamap.pkg") exact
    assert r(n) == 2
    _up_resolves, name(datadict)
    assert r(found) == 1
    * the stale command still RUNS
    capture noisily datadict
    assert _rc == 0
    * a bare "ado uninstall datamap" is ambiguous with two entries
    capture ado uninstall datamap
    assert _rc == 111
    * both entries are still registered (nothing was removed)
    confirm file "`plus'd/datadict.ado"
    qa_md_contains using "`plus'stata.trk", needle("N datamap.pkg") exact
    assert r(n) == 2
}
local rc_case = _rc
_up_restore, plus("`orig_plus'") personal("`orig_personal'")
if `rc_case' == 0 {
    display as result "  PASS: net install, replace over 1.10.6 leaves datadict behind, adds a second entry, and breaks a bare ado uninstall"
    local ++pass_count
}
else {
    display as error "  FAIL: upgrade over an installed 1.10.6 (error `rc_case')"
    local ++fail_count
}

**# U2: the recovery when an upgrade was done in place

local ++test_count
capture noisily {
    _up_sandbox, base("`stub_base'") case("u2")
    local plus "`r(plus)'"
    quietly net install datamap, from("`old_dir'") replace
    quietly net install datamap, from("`pkg_dir'") replace
    qa_md_contains using "`plus'stata.trk", needle("N datamap.pkg") exact
    assert r(n) == 2
    * highest number first; the numbers shift, so [1] is what remains
    quietly ado uninstall [2]
    qa_md_contains using "`plus'stata.trk", needle("N datamap.pkg") exact
    assert r(n) == 1
    quietly ado uninstall [1]
    qa_md_contains using "`plus'stata.trk", needle("N datamap.pkg") exact
    assert r(n) == 0
    capture confirm file "`plus'd/datadict.ado"
    assert _rc != 0
    capture confirm file "`plus'd/datamap.ado"
    assert _rc != 0
    quietly net install datamap, from("`pkg_dir'") replace
    _up_resolves, name(datadict)
    assert r(found) == 0
    capture datadict
    assert _rc == 199
    _up_resolves, name(datamap)
    assert r(found) == 1
}
local rc_case = _rc
_up_restore, plus("`orig_plus'") personal("`orig_personal'")
if `rc_case' == 0 {
    display as result "  PASS: ado uninstall [2] then [1] clears an in-place upgrade; datadict is then unrecognized"
    local ++pass_count
}
else {
    display as error "  FAIL: recovery from an in-place upgrade (error `rc_case')"
    local ++fail_count
}

**# U3: the README path, ado uninstall datamap FIRST

local ++test_count
capture noisily {
    _up_sandbox, base("`stub_base'") case("u3")
    local plus "`r(plus)'"
    quietly net install datamap, from("`old_dir'") replace
    confirm file "`plus'd/datadict.ado"
    _up_resolves, name(datadict)
    assert r(found) == 1
    ado uninstall datamap
    capture confirm file "`plus'd/datadict.ado"
    assert _rc != 0
    capture confirm file "`plus'd/datadict.sthlp"
    assert _rc != 0

    quietly net install datamap, from("`pkg_dir'") replace
    qa_md_contains using "`plus'stata.trk", needle("N datamap.pkg") exact
    assert r(n) == 1
    capture confirm file "`plus'd/datadict.ado"
    assert _rc != 0
    capture confirm file "`plus'd/datadict.sthlp"
    assert _rc != 0
    * the package's own check: every file the new .pkg lists is installed
    confirm file "`plus'd/datamap.ado"
    confirm file "`plus'_/_datamap_md_document.ado"
    confirm file "`plus'_/_datamap_collect_dataset.ado"
    _up_resolves, name(datadict)
    assert r(found) == 0
    capture datadict
    assert _rc == 199
    * the upgraded command works
    sysuse auto, clear
    local out "`stub_base'_u3.md"
    capture erase "`out'"
    datamap price mpg, output("`out'")
    confirm file "`out'"
    qa_md_contains using "`out'", needle("### Variables")
    assert r(found) == 1
    capture erase "`out'"
}
local rc_case = _rc
_up_restore, plus("`orig_plus'") personal("`orig_personal'")
if `rc_case' == 0 {
    display as result "  PASS: ado uninstall datamap first, then net install: one entry, no datadict, datamap runs"
    local ++pass_count
}
else {
    display as error "  FAIL: uninstall-first upgrade path (error `rc_case')"
    local ++fail_count
}

* the lane's sandbox must still resolve the package tree's datamap
quietly findfile datamap.ado
local ++test_count
if strpos(`"`r(fn)'"', `"`orig_plus'"') == 1 {
    display as result "  PASS: the caller's PLUS is restored and still holds datamap"
    local ++pass_count
}
else {
    display as error "  FAIL: PLUS not restored (datamap.ado resolves to `r(fn)')"
    local ++fail_count
}

display as text "datamap v200 upgrade tests: `pass_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_datamap_v200_upgrade tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 9
}
display as result "ALL TESTS PASSED"
display "RESULT: test_datamap_v200_upgrade tests=`test_count' pass=`pass_count' fail=`fail_count'"
exit 0
