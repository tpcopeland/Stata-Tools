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
do "`qa_dir'/_setools_qa_common.do" setup "`pkg_dir'"
* Code version and distribution date are separate contracts. Derive the code
* version from the flagship header and the release date from setools.pkg.
tempname _vfh
file open `_vfh' using "`pkg_dir'/setools.ado", read text
file read `_vfh' _vline
file close `_vfh'
local version ""
local distdate ""
if regexm(`"`_vline'"', "Version ([0-9]+\.[0-9]+\.[0-9]+)[ ]+([0-9]+)/([0-9]+)/([0-9]+)") {
    local version = regexs(1)
}
assert "`version'" != ""

tempname _pfh
file open `_pfh' using "`pkg_dir'/setools.pkg", read text
file read `_pfh' _pline
while r(eof) == 0 {
    if regexm(`"`_pline'"', "Distribution-Date: ([0-9]+)") {
        local distdate = regexs(1)
    }
    file read `_pfh' _pline
}
file close `_pfh'
assert strlen("`distdate'") == 8
local release_date = substr("`distdate'", 1, 4) + "-" + ///
    substr("`distdate'", 5, 2) + "-" + substr("`distdate'", 7, 2)
local badge_date = subinstr("`release_date'", "-", "--", .)
local top_readme "`pkg_dir'/../README.md"
local public_cmds "setools cci_se migrations sustainedss cdp pira"
local shipped_files "setools.ado setools.sthlp cci_se.ado cci_se.sthlp migrations.ado migrations.sthlp sustainedss.ado sustainedss.sthlp cdp.ado cdp.sthlp pira.ado pira.sthlp _setools_cdp_baseline.ado _setools_cdp_thresh.ado _setools_cdp_confirm.ado _setools_cdp_core.ado _setools_dta_path.ado"
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
    _assert_file_contains "`pkg_dir'/README.md", ///
        pattern("**Version `version'** | `release_date'")
    _assert_file_contains "`top_readme'", pattern("version-`version'-blue")
    _assert_file_contains "`top_readme'", ///
        pattern("updated-`badge_date'-brightgreen")
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
    * Compare the actual root ado/help inventory with every f-line in .pkg in
    * both directions. No hand-curated omission can pass this check.
    local actual_ados : dir "`pkg_dir'" files "*.ado"
    local actual_helps : dir "`pkg_dir'" files "*.sthlp"
    local actual_files "`actual_ados' `actual_helps'"
    local actual_files = subinstr(`"`actual_files'"', `"""', "", .)
    local actual_files : list sort actual_files

    local manifest_files ""
    tempname _mfh
    file open `_mfh' using "`pkg_dir'/setools.pkg", read text
    file read `_mfh' _mline
    while r(eof) == 0 {
        local _mtrim = strtrim(`"`_mline'"')
        if substr(`"`_mtrim'"', 1, 2) == "f " {
            local _mfile = substr(`"`_mtrim'"', 3, .)
            local manifest_files "`manifest_files' `_mfile'"
        }
        file read `_mfh' _mline
    }
    file close `_mfh'
    local manifest_files : list sort manifest_files
    assert "`actual_files'" == "`manifest_files'"
    _assert_file_contains "`pkg_dir'/setools.pkg", pattern("Author: Timothy P Copeland, Karolinska Institutet")
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
    _assert_file_not_contains "`top_readme'", pattern("procedure-code matching")
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

**# Repository Demo And Installed Surface

* Console screenshots/PNG captures were removed from demos and READMEs by
* design; the demo surface is the runnable script only.
local ++test_count
capture noisily {
    confirm file "`pkg_dir'/demo/demo_setools.do"
    _assert_file_not_contains "`pkg_dir'/setools.pkg", pattern("f demo/demo_setools.do")
    foreach cmd of local public_cmds {
        which `cmd'
    }
    findfile _setools_dta_path.ado
    confirm file "`r(fn)'"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: repository demo is unshipped and installed command/helper surface resolves"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' demo_refs"
    display as error "  FAIL: repository-demo or installed-surface contract (error `=_rc')"
}

**# Summary

display as text ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_release_integrity tests=`test_count' pass=`pass_count' fail=`fail_count'"

do "`qa_dir'/_setools_qa_common.do" teardown

if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    display as error "SOME TESTS FAILED"
    exit 1
}

display as result "ALL TESTS PASSED"
