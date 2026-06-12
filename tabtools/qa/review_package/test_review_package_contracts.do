clear all
set more off
set varabbrev off
version 16.0

capture log close _review_package
log using "test_review_package_contracts.log", replace text name(_review_package)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa/review_package", "", 1)
if "`pkg_dir'" == "`qa_dir'" {
    local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
}
local orig_plus "`c(sysdir_plus)'"
local orig_personal "`c(sysdir_personal)'"
tempname install_id
local install_tag = subinstr("`install_id'", "__", "", .)
local plus_dir "`c(tmpdir)'/tabtools_review_plus_`install_tag'"
local personal_dir "`c(tmpdir)'/tabtools_review_personal_`install_tag'"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture mkdir "`plus_dir'"
capture mkdir "`personal_dir'"
sysdir set PLUS "`plus_dir'"
sysdir set PERSONAL "`personal_dir'"
discard

ado dir
capture ado uninstall tabtools
capture noisily net install tabtools, from("`pkg_dir'") replace
local install_rc = _rc
if `install_rc' {
    sysdir set PLUS "`orig_plus'"
    sysdir set PERSONAL "`orig_personal'"
    discard
    capture shell rm -rf "`plus_dir'" "`personal_dir'"
    capture log close _review_package
    exit `install_rc'
}

local public_commands tabtools table1_tc desctab regtab effecttab stratetab ///
    hrcomptab comptab survtab crosstab diagtab corrtab puttab stacktab ///
    simtab tabtools_tips
local helper_files _tabtools_common.ado _tabtools_xlsx_write.ado ///
    _tabtools_xlsx_read.ado _tabtools_collect_render.ado ///
    _tabtools_markdown_write.ado _tabtools_simtab_ingest.ado ///
    _tabtools_xlsx_apply_styles.ado _tabtools_xlsx_build_styles.ado ///
    _tabtools_table1_fast_collect.ado

**# Release Manifest Contracts
**## .pkg explicitly ships every public command ado/help file and backend helper
local ++test_count
capture noisily {
    local pkg_entries ""
    tempname fh
    file open `fh' using "`pkg_dir'/tabtools.pkg", read text
    file read `fh' line
    while r(eof) == 0 {
        local raw = strtrim(`"`line'"')
        if substr(`"`raw'"', 1, 2) == "f " {
            local entry = strtrim(substr(`"`raw'"', 3, .))
            local pkg_entries : list pkg_entries | entry
        }
        file read `fh' line
    }
    file close `fh'

    foreach cmd of local public_commands {
        local ado_file "`cmd'.ado"
        local help_file "`cmd'.sthlp"
        local has_ado : list ado_file in pkg_entries
        local has_help : list help_file in pkg_entries
        assert `has_ado'
        assert `has_help'
    }
    foreach helper of local helper_files {
        local has_helper : list helper in pkg_entries
        assert `has_helper'
    }
}
if _rc == 0 {
    display as result "  PASS: .pkg ships every public command and backend helper"
    local ++pass_count
}
else {
    display as error "  FAIL: .pkg public command/helper manifest (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' pkg_manifest_public_surface"
}

**# Installed-User Contracts
**## Fresh install resolves every public command and backend helper
local ++test_count
capture noisily {
    foreach cmd of local public_commands {
        which `cmd'
    }
    foreach helper of local helper_files {
        findfile `helper'
    }
}
if _rc == 0 {
    display as result "  PASS: fresh install resolves all public commands and helpers"
    local ++pass_count
}
else {
    display as error "  FAIL: fresh-install public command/helper resolution (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' installed_resolution"
}

**# Dispatcher And Documentation Contracts
**## tabtools dispatcher exposes the export category and its public commands
local ++test_count
capture noisily {
    quietly tabtools, category(export)
    assert r(n_commands) == 2
    assert strpos("`r(commands)'", "puttab") > 0
    assert strpos("`r(commands)'", "stacktab") > 0

    quietly tabtools
    assert strpos("`r(categories)'", "export") > 0
    assert strpos("`r(commands)'", "puttab") > 0
    assert strpos("`r(commands)'", "stacktab") > 0
}
if _rc == 0 {
    display as result "  PASS: tabtools dispatcher exposes export category"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools export-category dispatcher contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' dispatcher_export"
}

**## tabtools.sthlp documents every dispatcher category returned by r(categories)
local ++test_count
capture noisily {
    quietly tabtools
    local categories "`r(categories)'"

    tempname hf
    file open `hf' using "`pkg_dir'/tabtools.sthlp", read text
    file read `hf' line
    local help_text ""
    while r(eof) == 0 {
        local help_text `"`help_text' `line'"'
        file read `hf' line
    }
    file close `hf'

    foreach cat of local categories {
        assert strpos(`"`help_text'"', "{cmd:`cat'}") > 0
    }
}
if _rc == 0 {
    display as result "  PASS: tabtools.sthlp documents returned categories"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools.sthlp returned-category documentation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' sthlp_categories"
}

**# Summary
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

capture ado uninstall tabtools
sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
discard
capture shell rm -rf "`plus_dir'" "`personal_dir'"

if `fail_count' > 0 {
    display as error "FAILED TESTS: `failed_tests'"
    display "RESULT: test_review_package_contracts tests=`test_count' pass=`pass_count' fail=`fail_count'"
    capture log close _review_package
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: test_review_package_contracts tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _review_package
