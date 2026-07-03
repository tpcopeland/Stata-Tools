/*
test_release_integrity.do
Package-level release-surface checks for setools.

Run from setools/qa/:
    stata-mp -b do test_release_integrity.do
*/

version 16.0
capture log close _all
set varabbrev off

**# Setup

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'"
local pkg_dir : subinstr local pkg_dir "/qa" "", all
* Derive the package version from the flagship .ado header (single source of
* truth) so this literal cannot go stale on a version bump.
tempname _vfh
file open `_vfh' using "`pkg_dir'/setools.ado", read text
file read `_vfh' _vline
file close `_vfh'
local version ""
local distdate ""
if regexm(`"`_vline'"', "Version ([0-9]+\.[0-9]+\.[0-9]+)[ ]+([0-9]+)/([0-9]+)/([0-9]+)") {
    local version = regexs(1)
    local distdate = regexs(2) + regexs(3) + regexs(4)
}
assert "`version'" != ""
assert "`distdate'" != ""
local public_cmds "setools cci_se migrations sustainedss cdp pira"
local shipped_files "setools.ado setools.sthlp cci_se.ado cci_se.sthlp migrations.ado migrations.sthlp sustainedss.ado sustainedss.sthlp cdp.ado cdp.sthlp pira.ado pira.sthlp _setools_cdp_baseline.ado _setools_cdp_thresh.ado _setools_cdp_confirm.ado _setools_cdp_core.ado"
local metadata_files "README.md setools.pkg stata.toc"

capture program drop _assert_file_contains
program define _assert_file_contains
    gettoken path 0 : 0, parse(",")
    local path = subinstr(`"`path'"', `"""', "", .)
    local path = subinstr(`"`path'"', ",", "", .)
    local path = strtrim(`"`path'"')
    syntax, Pattern(string asis)
    local pattern = subinstr(`"`pattern'"', `"""', "", .)
    tempfile found
    capture erase "`found'"
    shell grep -Fq -- "`pattern'" "`path'" && touch "`found'"
    confirm file "`found'"
end

capture program drop _assert_file_not_contains
program define _assert_file_not_contains
    gettoken path 0 : 0, parse(",")
    local path = subinstr(`"`path'"', `"""', "", .)
    local path = subinstr(`"`path'"', ",", "", .)
    local path = strtrim(`"`path'"')
    syntax, Pattern(string asis)
    local pattern = subinstr(`"`pattern'"', `"""', "", .)
    tempfile clean
    capture erase "`clean'"
    shell grep -Fq -- "`pattern'" "`path'" || touch "`clean'"
    confirm file "`clean'"
end

**# Required Files

local ++test_count
capture noisily {
    foreach f of local shipped_files {
        confirm file "`pkg_dir'/`f'"
    }
    foreach f of local metadata_files {
        confirm file "`pkg_dir'/`f'"
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: required package files exist"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' required_files"
    display as error "  FAIL: required package files exist (error `=_rc')"
}

**# Version Synchronization

local ++test_count
capture noisily {
    _assert_file_contains "`pkg_dir'/setools.ado", pattern("Version `version'")
    _assert_file_contains "`pkg_dir'/setools.sthlp", pattern("version `version'")
    foreach cmd in cci_se migrations sustainedss cdp pira {
        _assert_file_contains "`pkg_dir'/`cmd'.ado", pattern("Version `version'")
        * Sub-command help files must NOT carry a package version line;
        * the version lives in the flagship setools.sthlp only.
        _assert_file_not_contains "`pkg_dir'/`cmd'.sthlp", pattern("*! version")
    }
    _assert_file_contains "`pkg_dir'/README.md", pattern("**Version `version'**")
    capture ado uninstall setools
    quietly net install setools, from("`pkg_dir'") replace
    setools
    assert "`r(version)'" == "`version'"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: version is synchronized across shipped surface"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' version_sync"
    display as error "  FAIL: version is synchronized across shipped surface (error `=_rc')"
}

**# Package Manifest Completeness

local ++test_count
capture noisily {
    foreach f of local shipped_files {
        _assert_file_contains "`pkg_dir'/setools.pkg", pattern("f `f'")
    }
    _assert_file_contains "`pkg_dir'/setools.pkg", pattern("Author: Timothy P Copeland, Karolinska Institutet")
    * Distribution-Date must match the flagship .ado header date (derived
    * above), so this assertion cannot go stale on a version bump.
    _assert_file_contains "`pkg_dir'/setools.pkg", pattern("Distribution-Date: `distdate'")
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: .pkg lists every shipped ado/help file and canonical metadata"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' pkg_manifest"
    display as error "  FAIL: .pkg lists every shipped ado/help file and canonical metadata (error `=_rc')"
}

**# Table Of Contents

local ++test_count
capture noisily {
    _assert_file_contains "`pkg_dir'/stata.toc", pattern("v 3")
    _assert_file_contains "`pkg_dir'/stata.toc", pattern("d Stata-Tools: setools")
    _assert_file_contains "`pkg_dir'/stata.toc", pattern("d Timothy P Copeland, Karolinska Institutet")
    _assert_file_contains "`pkg_dir'/stata.toc", pattern("d https://github.com/tpcopeland/Stata-Tools")
    _assert_file_contains "`pkg_dir'/stata.toc", pattern("p setools")
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: stata.toc matches canonical Stata-Tools surface"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' stata_toc"
    display as error "  FAIL: stata.toc matches canonical Stata-Tools surface (error `=_rc')"
}

**# Active Surface Excludes Removed Commands

local ++test_count
capture noisily {
    foreach f in setools.ado setools.sthlp setools.pkg stata.toc {
        _assert_file_not_contains "`pkg_dir'/`f'", pattern("procmatch")
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: active release surface excludes removed procmatch command"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' removed_surface"
    display as error "  FAIL: active release surface excludes removed procmatch command (error `=_rc')"
}

**# Canonical Author Surface

local ++test_count
capture noisily {
    foreach f of local shipped_files {
        _assert_file_not_contains "`pkg_dir'/`f'", pattern("Tim Copeland")
        _assert_file_not_contains "`pkg_dir'/`f'", pattern("Department of Clinical Neuroscience")
        _assert_file_not_contains "`pkg_dir'/`f'", pattern("Stockholm, Sweden")
    }
    foreach f in `shipped_files' README.md setools.pkg stata.toc {
        _assert_file_contains "`pkg_dir'/`f'", pattern("Timothy P Copeland, Karolinska Institutet")
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: shipped author strings use canonical form"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' author_surface"
    display as error "  FAIL: shipped author strings use canonical form (error `=_rc')"
}

**# Dev-Only Path Leaks

local ++test_count
capture noisily {
    local scan_files "`shipped_files' `metadata_files' demo/demo_setools.do"
    local leak_home "/" + "home/"
    local leak_stata "~/" + "Stata-"
    local leak_dev "Stata-" + "Dev"
    local leak_claude "." + "claude"
    local leak_codex "." + "codex"
    local leak_examples "_" + "examples"
    foreach f of local scan_files {
        _assert_file_not_contains "`pkg_dir'/`f'", pattern("`leak_home'")
        _assert_file_not_contains "`pkg_dir'/`f'", pattern("`leak_stata'")
        _assert_file_not_contains "`pkg_dir'/`f'", pattern("`leak_dev'")
        _assert_file_not_contains "`pkg_dir'/`f'", pattern("`leak_claude'")
        _assert_file_not_contains "`pkg_dir'/`f'", pattern("`leak_codex'")
        _assert_file_not_contains "`pkg_dir'/`f'", pattern("`leak_examples'")
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: shipped surface has no dev-only path leaks"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' path_leaks"
    display as error "  FAIL: shipped surface has no dev-only path leaks (error `=_rc')"
}

**# Demo Assets

* Console screenshots/PNG captures were removed from demos and READMEs by
* design; the demo surface is the runnable script only.
local ++test_count
capture noisily {
    confirm file "`pkg_dir'/demo/demo_setools.do"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: demo script ships with the package"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' demo_refs"
    display as error "  FAIL: README demo image references resolve to shipped files (error `=_rc')"
}

**# Summary

display as text ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_release_integrity tests=`test_count' pass=`pass_count' fail=`fail_count'"

if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    display as error "SOME TESTS FAILED"
    exit 1
}

display as result "ALL TESTS PASSED"
