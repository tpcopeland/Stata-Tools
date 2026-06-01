* test_public_inventory_v136.do - package inventory and installed-user aliases
* Covers the v1.3.6 public command surface, including deprecated xlsxcompose.

clear all
set more off
set varabbrev off
version 16.0

capture log close _pubinv
log using "test_public_inventory_v136.log", replace text name(_pubinv)

local cwd "`c(pwd)'"
if regexm("`cwd'", "/qa/_package$") {
    local qa_dir = regexr("`cwd'", "/_package$", "")
}
else if regexm("`cwd'", "/qa$") {
    local qa_dir "`cwd'"
}
else {
    local qa_dir "`cwd'"
}
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

local public_cmds "tabtools table1_tc desctab regtab effecttab stratetab hrcomptab comptab survtab crosstab diagtab corrtab puttab stacktab xlsxcompose"
local advertised_cmds "table1_tc desctab crosstab corrtab regtab effecttab stratetab survtab diagtab comptab hrcomptab puttab stacktab tabtools"

**# Public Inventory

local ++test_count
capture noisily {
    local public_ado ""
    local root_ado : dir "`pkg_dir'" files "*.ado"
    foreach f of local root_ado {
        if substr("`f'", 1, 1) != "_" {
            local public_ado : list public_ado | f
        }
    }

    local n_public : word count `public_ado'
    assert `n_public' == 15

    foreach cmd of local public_cmds {
        local ado_file "`cmd'.ado"
        local help_file "`cmd'.sthlp"
        local has_ado : list ado_file in public_ado
        assert `has_ado'
        confirm file "`pkg_dir'/`help_file'"
    }
}
if _rc == 0 {
    display as result "  PASS: source tree has exact 15-command public inventory"
    local ++pass_count
}
else {
    display as error "  FAIL: source tree public inventory drifted (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' source_inventory"
}

local ++test_count
capture noisily {
    foreach cmd of local public_cmds {
        which `cmd'
        findfile `cmd'.sthlp
    }
}
if _rc == 0 {
    display as result "  PASS: all public commands and help files resolve after net install"
    local ++pass_count
}
else {
    display as error "  FAIL: installed public command/help resolution (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' install_resolution"
}

local ++test_count
capture noisily {
    tempname pkgfh
    local pkg_files ""
    file open `pkgfh' using "`pkg_dir'/tabtools.pkg", read text
    file read `pkgfh' line
    while r(eof) == 0 {
        local raw = strtrim(`"`line'"')
        if substr(`"`raw'"', 1, 2) == "f " {
            local pkg_file = strtrim(substr(`"`raw'"', 3, .))
            local pkg_files : list pkg_files | pkg_file
        }
        file read `pkgfh' line
    }
    file close `pkgfh'

    foreach cmd of local public_cmds {
        local ado_file "`cmd'.ado"
        local help_file "`cmd'.sthlp"
        local has_ado : list ado_file in pkg_files
        local has_help : list help_file in pkg_files
        assert `has_ado'
        assert `has_help'
    }
}
if _rc == 0 {
    display as result "  PASS: .pkg manifest ships every public command and help file"
    local ++pass_count
}
else {
    display as error "  FAIL: .pkg public command manifest completeness (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' pkg_public_manifest"
}

**# Dispatcher Contract

local ++test_count
capture noisily {
    tabtools
    assert r(n_commands) == 14
    local commands " `r(commands)' "
    foreach cmd of local advertised_cmds {
        assert strpos("`commands'", " `cmd' ") > 0
    }
    assert strpos("`commands'", " xlsxcompose ") == 0

    tabtools, category(export)
    assert r(n_commands) == 2
    local export_commands " `r(commands)' "
    assert strpos("`export_commands'", " puttab ") > 0
    assert strpos("`export_commands'", " stacktab ") > 0
    assert strpos("`export_commands'", " xlsxcompose ") == 0
}
if _rc == 0 {
    display as result "  PASS: tabtools advertises 14 current commands and keeps xlsxcompose as alias-only"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools dispatcher inventory contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' dispatcher_inventory"
}

**# Deprecated Alias

local ++test_count
capture noisily {
    tempfile wb
    local book "`wb'.xlsx"
    clear
    input str12 label str8 estimate
    "term" "estimate"
    "age"  "1.20"
    "sex"  "0.95"
    end
    export excel using "`book'", sheet("Source") replace

    xlsxcompose using "`book'", ///
        blocks(sheet(Source) rows(1/3) cols(A-B)) ///
        sheet("Alias") sheetreplace

    assert r(blocks_loaded) == 1
    assert r(rows_written) == 3
    assert "`r(layout)'" == "vstack"

    preserve
    import excel using "`book'", sheet("Alias") cellrange(B2:C4) firstrow clear allstring
    assert term[1] == "age"
    assert estimate[1] == "1.20"
    restore
}
if _rc == 0 {
    display as result "  PASS: deprecated xlsxcompose alias forwards to stacktab and writes expected cells"
    local ++pass_count
}
else {
    display as error "  FAIL: xlsxcompose alias forwarding contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' xlsxcompose_alias"
}

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display as error "Failed tests:`failed_tests'"
    capture log close _pubinv
    exit 1
}

display as result "ALL TESTS PASSED"
capture log close _pubinv
