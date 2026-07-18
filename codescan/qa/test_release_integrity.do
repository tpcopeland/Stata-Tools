* test_release_integrity.do - Release surface and package metadata checks for codescan

clear all
version 16.0
set varabbrev off

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local repo_dir "`pkg_dir'/.."

* Install the local copy so a stale installed build cannot shadow it, and so the
* release surface is checked against a package that genuinely net-installs.
* Guarded shared bootstrap. Sandboxes PLUS/PERSONAL under c(tmpdir), then
* installs this working copy. Running this suite standalone must not mutate
* the developer's real adopath, which the bare net install here used to do;
* only run_all.do was sandboxed. Idempotent, so the lane re-entering it is
* harmless.
quietly do "`qa_dir'/_codescan_qa_common.do"
_codescan_qa_bootstrap

* Session settings captured for the hygiene check at the end of this suite.
* A suite that leaves c(level) or c(varabbrev) changed silently alters every
* later suite in the lane -- the level-80/99 CI scenarios restored inside a
* captured block, so any assertion failure above them used to leak.
local _qa_level0 = c(level)
local _qa_va0 "`c(varabbrev)'"
local _qa_pwd0 "`c(pwd)'"


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

* Return the first regex capture group found in a file, or "" if the pattern
* never matches. Parsing the fact out of the file that owns it keeps this suite
* from carrying stale literals that must be hand-edited on every release.
capture program drop _cs_extract_first
program define _cs_extract_first, rclass
    version 16.0
    args path pattern

    tempname fh
    local value ""
    file open `fh' using "`path'", read text
    file read `fh' line
    while r(eof) == 0 {
        if ustrregexm(`"`macval(line)'"', "`pattern'") {
            local value = ustrregexs(1)
            continue, break
        }
        file read `fh' line
    }
    file close `fh'
    return local value "`value'"
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
        _codescan_engine.ado ///
        _codescan_codefile.ado ///
        _codescan_definitions.ado ///
        _codescan_outputs.ado ///
        _codescan_parse_filespec.ado ///
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

* Version/date synchronization. Facts are parsed from the surfaces that own
* them and compared only against compatible facts. The previous version of this
* test hardcoded the whole version/date tuple as shell grep literals, which made
* it (a) stale on every release and (b) wrong: it required each .ado's code-edit
* date to equal the package distribution date, which are different facts about
* different events.
local ++test_count
capture noisily {
    * The flagship help file owns the package version.
    _cs_extract_first "`pkg_dir'/codescan.sthlp" "^\{\* \*! version ([0-9]+\.[0-9]+\.[0-9]+)"
    local ver "`r(value)'"
    assert "`ver'" != ""

    * Every .ado header must carry that same version. Their dates are NOT
    * compared to the distribution date.
    foreach f in codescan.ado _codescan_engine.ado codescan_describe.ado ///
        _codescan_codefile.ado _codescan_definitions.ado _codescan_outputs.ado ///
        _codescan_parse_filespec.ado _codescan_validate_path.ado {
        _cs_extract_first "`pkg_dir'/`f'" "^\*! [_a-zA-Z]+ Version ([0-9]+\.[0-9]+\.[0-9]+)"
        if "`r(value)'" != "`ver'" {
            display as error "    `f' version [`r(value)'] != flagship [`ver']"
            exit 9
        }
    }

    * Version numbers live in the flagship help only; a sub-command help file
    * must not carry one.
    _cs_extract_first "`pkg_dir'/codescan_describe.sthlp" "(\*! version)"
    assert "`r(value)'" == ""

    * README header version must match the flagship version.
    _cs_extract_first "`pkg_dir'/README.md" "^\*\*Version ([0-9]+\.[0-9]+\.[0-9]+)\*\*"
    if "`r(value)'" != "`ver'" {
        display as error "    README version [`r(value)'] != flagship [`ver']"
        exit 9
    }

    * Release-date facts: the README header date and the .pkg Distribution-Date
    * describe the same event, so they must agree with each other.
    _cs_extract_first "`pkg_dir'/README.md" "^\*\*Version [0-9.]+\*\* \| ([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])"
    local rdate "`r(value)'"
    _cs_extract_first "`pkg_dir'/codescan.pkg" "^d Distribution-Date: ([0-9]+)"
    local pdate "`r(value)'"
    assert "`rdate'" != ""
    assert "`pdate'" != ""
    if subinstr("`rdate'", "-", "", .) != "`pdate'" {
        display as error "    README date [`rdate'] != .pkg Distribution-Date [`pdate']"
        exit 9
    }
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


**# Settings hygiene

* This suite must not leak a session setting to whatever runs next.
local ++test_count
capture noisily {
    assert c(level) == `_qa_level0'
    assert "`c(varabbrev)'" == "`_qa_va0'"
    assert "`c(pwd)'" == "`_qa_pwd0'"
}
if _rc == 0 {
    display as result "  PASS: no session setting leaked"
    local ++pass_count
}
else {
    display as error "  FAIL: session setting leaked (error `=_rc')"
    local ++fail_count
}


**# Summary

display ""
_codescan_qa_publish "test_release_integrity" `test_count' `pass_count' `fail_count'
display as result "RESULT: test_release_integrity tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
