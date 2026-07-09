* test_release_integrity.do - Release surface and package metadata checks for codescan

clear all
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local repo_dir "`pkg_dir'/.."

* Install the local copy so a stale installed build cannot shadow it, and so the
* release surface is checked against a package that genuinely net-installs.
capture ado uninstall codescan
quietly net install codescan, from("`pkg_dir'") replace

capture program drop _assert_marker_pass
program define _assert_marker_pass
    version 16.0
    args marker

    tempname fh
    file open `fh' using `"`marker'"', read text
    file read `fh' status
    file close `fh'
    assert strtrim("`status'") == "PASS"
end

**# Tests

local ++test_count
capture noisily {
    confirm file "`pkg_dir'/codescan.ado"
    confirm file "`pkg_dir'/codescan.sthlp"
    confirm file "`pkg_dir'/codescan_describe.ado"
    confirm file "`pkg_dir'/codescan_describe.sthlp"
    confirm file "`pkg_dir'/codescan.pkg"
    confirm file "`pkg_dir'/stata.toc"
    confirm file "`pkg_dir'/README.md"
}
if _rc == 0 {
    display as result "  PASS: release files present"
    local ++pass_count
}
else {
    display as error "  FAIL: release files present (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    tempname fh
    local pkg_files ""
    file open `fh' using "`pkg_dir'/codescan.pkg", read text
    file read `fh' line
    while r(eof) == 0 {
        local trimmed = strtrim(`"`line'"')
        if substr(`"`trimmed'"', 1, 2) == "f " {
            local f = strtrim(substr(`"`trimmed'"', 3, .))
            local pkg_files "`pkg_files' `f'"
            confirm file "`pkg_dir'/`f'"
        }
        file read `fh' line
    }
    file close `fh'

    foreach f in ///
        codescan.ado ///
        _codescan_codefile.ado ///
        _codescan_definitions.ado ///
        _codescan_outputs.ado ///
        _codescan_validate_path.ado ///
        codescan.sthlp ///
        codescan_describe.ado ///
        codescan_describe.sthlp {

        assert strpos(" `pkg_files' ", " `f' ") > 0
    }
}
if _rc == 0 {
    display as result "  PASS: .pkg lists every runtime/help file"
    local ++pass_count
}
else {
    display as error "  FAIL: .pkg runtime/help file list (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    tempfile marker
    shell bash -lc 'cd "$1" && if grep -Fq "codescan Version 2.0.9  2026/07/09" codescan.ado && grep -Fq "codescan_describe Version 2.0.9  2026/07/09" codescan_describe.ado && grep -Fq "_codescan_codefile Version 2.0.9  2026/07/09" _codescan_codefile.ado && grep -Fq "_codescan_outputs Version 2.0.9  2026/07/09" _codescan_outputs.ado && grep -Fq "_codescan_definitions Version 2.0.9  2026/07/09" _codescan_definitions.ado && grep -Fq "_codescan_validate_path Version 2.0.9  2026/07/09" _codescan_validate_path.ado && grep -Fq "{* *! version 2.0.9  09jul2026}" codescan.sthlp && ! grep -Fq "*! version" codescan_describe.sthlp && grep -Fq "**Version 2.0.9** | 2026-07-09" README.md && grep -Fq "d Distribution-Date: 20260709" codescan.pkg; then echo PASS > "$2"; else echo FAIL > "$2"; fi' bash "`pkg_dir'" "`marker'"
    _assert_marker_pass "`marker'"
}
if _rc == 0 {
    display as result "  PASS: version strings synchronized"
    local ++pass_count
}
else {
    display as error "  FAIL: version strings synchronized (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    tempfile marker
    shell bash -lc 'cd "$1" && if grep -Fq "v 3" stata.toc && grep -Fq "d Stata-Tools: codescan" stata.toc && grep -Fq "d Timothy P Copeland, Karolinska Institutet" stata.toc && grep -Fq "d https://github.com/tpcopeland/Stata-Tools" stata.toc && grep -Fq "p codescan" stata.toc && grep -Fq "d Author: Timothy P Copeland, Karolinska Institutet" codescan.pkg && grep -Fq "Timothy P Copeland, Karolinska Institutet" README.md && grep -Fq "Timothy P Copeland, Karolinska Institutet" codescan.sthlp && grep -Fq "Timothy P Copeland, Karolinska Institutet" codescan_describe.sthlp; then echo PASS > "$2"; else echo FAIL > "$2"; fi' bash "`pkg_dir'" "`marker'"
    _assert_marker_pass "`marker'"
}
if _rc == 0 {
    display as result "  PASS: canonical metadata present"
    local ++pass_count
}
else {
    display as error "  FAIL: canonical metadata present (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    tempfile marker
    local p1 = "/home/" + "tpcopeland"
    local p2 = "~/" + "Stata-"
    local p3 = "Stata-" + "Dev"
    local p4 = "." + "claude"
    local p5 = "." + "codex"
    shell bash -lc 'cd "$1" && files=$(git ls-files codescan | grep -Ev "^codescan/demo/.*\\.(xlsx|png)$" || true); if [ -z "$files" ]; then files=$(awk "/^f /{print \"codescan/\" \$2}" codescan/codescan.pkg; printf "%s\n" codescan/codescan.pkg codescan/stata.toc codescan/README.md); files=$(printf "%s\n" "$files" | grep -Ev "^codescan/demo/.*\\.(xlsx|png)$" | sort -u); fi; if [ -n "$files" ] && printf "%s\n" "$files" | xargs rg -n -F -e "$3" -e "$4" -e "$5" -e "$6" -e "$7" > "$2.hits"; then echo FAIL > "$2"; else echo PASS > "$2"; fi' bash "`repo_dir'" "`marker'" "`p1'" "`p2'" "`p3'" "`p4'" "`p5'"
    _assert_marker_pass "`marker'"
}
if _rc == 0 {
    display as result "  PASS: tracked text has no dev-only paths"
    local ++pass_count
}
else {
    display as error "  FAIL: tracked text has dev-only paths (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    tempfile marker
    shell bash -lc 'cd "$1" && files=$(git ls-files codescan || true); if [ -z "$files" ]; then files=$(awk "/^f /{print \"codescan/\" \$2}" codescan/codescan.pkg; printf "%s\n" codescan/codescan.pkg codescan/stata.toc codescan/README.md); fi; if printf "%s\n" "$files" | grep -Ev "^codescan/demo/" | grep -E "\\.(log|smcl|dta|xlsx)$" > "$2.hits"; then echo FAIL > "$2"; else echo PASS > "$2"; fi' bash "`repo_dir'" "`marker'"
    _assert_marker_pass "`marker'"
}
if _rc == 0 {
    display as result "  PASS: no tracked generated debris outside demo allowances"
    local ++pass_count
}
else {
    display as error "  FAIL: tracked generated debris outside demo allowances (error `=_rc')"
    local ++fail_count
}

**# Summary

display ""
display as result "RESULT: test_release_integrity tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
