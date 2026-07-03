/*
test_setools.do
Package-level dispatcher and installed-user smoke tests for setools.

Run from setools/qa/:
    stata-mp -b do test_setools.do
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
local public_cmds "setools cci_se migrations sustainedss cdp pira"
* Derive the expected version from the flagship .ado header (single source of
* truth) so this literal cannot go stale on a version bump.
tempname _vfh
file open `_vfh' using "`pkg_dir'/setools.ado", read text
file read `_vfh' _vline
file close `_vfh'
local expected_version ""
if regexm(`"`_vline'"', "Version ([0-9]+\.[0-9]+\.[0-9]+)") local expected_version = regexs(1)
assert "`expected_version'" != ""
local expected_all "cci_se migrations sustainedss cdp pira"

**# Fresh Local Install

local ++test_count
capture noisily {
    capture ado uninstall setools
    quietly net install setools, from("`pkg_dir'") replace
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: net install from local package"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' install"
    display as error "  FAIL: net install from local package (error `=_rc')"
}

local ++test_count
capture noisily {
    foreach cmd of local public_cmds {
        which `cmd'
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: all public commands are discoverable after install"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' public_which"
    display as error "  FAIL: all public commands are discoverable after install (error `=_rc')"
}

**# Dispatcher Stored Results

local ++test_count
capture noisily {
    setools
    assert "`r(commands)'" == "`expected_all'"
    assert r(n_commands) == 5
    assert "`r(version)'" == "`expected_version'"
    assert "`r(categories)'" == "all codes migration ms"
    assert "`r(category)'" == "all"
    assert "`r(display)'" == "grouped"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: default dispatcher metadata matches current-version surface"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' dispatcher_default"
    display as error "  FAIL: default dispatcher metadata matches current-version surface (error `=_rc')"
}

local ++test_count
capture noisily {
    setools, category(codes)
    assert "`r(commands)'" == "cci_se"
    assert r(n_commands) == 1
    assert "`r(category)'" == "codes"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: category(codes) exposes cci_se only"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' dispatcher_codes"
    display as error "  FAIL: category(codes) exposes cci_se only (error `=_rc')"
}

local ++test_count
capture noisily {
    setools, category(migration)
    assert "`r(commands)'" == "migrations"
    assert r(n_commands) == 1
    assert "`r(category)'" == "migration"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: category(migration) exposes migrations only"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' dispatcher_migration"
    display as error "  FAIL: category(migration) exposes migrations only (error `=_rc')"
}

local ++test_count
capture noisily {
    setools, category(ms)
    assert "`r(commands)'" == "sustainedss cdp pira"
    assert r(n_commands) == 3
    assert "`r(category)'" == "ms"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: category(ms) exposes sustainedss cdp pira"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' dispatcher_ms"
    display as error "  FAIL: category(ms) exposes sustainedss cdp pira (error `=_rc')"
}

local ++test_count
capture noisily {
    setools, list category(ms)
    assert "`r(display)'" == "list"
    assert "`r(commands)'" == "sustainedss cdp pira"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: list mode stores exact dispatcher metadata"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' dispatcher_list"
    display as error "  FAIL: list mode stores exact dispatcher metadata (error `=_rc')"
}

local ++test_count
capture noisily {
    discard
    setools, detail category(codes)
    assert "`r(display)'" == "detail"
    assert "`r(commands)'" == "cci_se"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: detail mode autoloads dispatcher helper after discard"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' detail_autoload"
    display as error "  FAIL: detail mode autoloads dispatcher helper after discard (error `=_rc')"
}

local ++test_count
capture noisily {
    capture noisily setools, list detail
    assert _rc == 198
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: list and detail conflict is rejected"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' list_detail_conflict"
    display as error "  FAIL: list and detail conflict is rejected (error `=_rc')"
}

local ++test_count
capture noisily {
    capture noisily setools, category(procedures)
    assert _rc == 198
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: invalid category is rejected"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' invalid_category"
    display as error "  FAIL: invalid category is rejected (error `=_rc')"
}

**# Session-State Hygiene

local ++test_count
capture noisily {
    set varabbrev on
    setools, category(ms)
    assert "`c(varabbrev)'" == "on"
    set varabbrev off
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: setools restores varabbrev on success"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' varabbrev_success"
    display as error "  FAIL: setools restores varabbrev on success (error `=_rc')"
}

local ++test_count
capture noisily {
    set varabbrev on
    capture noisily setools, category(bad)
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
    set varabbrev off
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: setools restores varabbrev on error"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' varabbrev_error"
    display as error "  FAIL: setools restores varabbrev on error (error `=_rc')"
}

**# Summary

display as text ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_setools tests=`test_count' pass=`pass_count' fail=`fail_count'"

if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    display as error "SOME TESTS FAILED"
    exit 1
}

display as result "ALL TESTS PASSED"
