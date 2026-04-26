clear all
set more off
set varabbrev off
version 16.0

capture log close _sscg
log using "test_ssc_release_gates.log", replace text name(_sscg)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local orig_plus "`c(sysdir_plus)'"
local orig_personal "`c(sysdir_personal)'"
tempname install_id
local install_tag = subinstr("`install_id'", "__", "", .)
local plus_dir "`c(tmpdir)'/tabtools_ssc_plus_`install_tag'"
local personal_dir "`c(tmpdir)'/tabtools_ssc_personal_`install_tag'"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture mkdir "`plus_dir'"
capture mkdir "`personal_dir'"
sysdir set PLUS "`plus_dir'"
sysdir set PERSONAL "`personal_dir'"
discard
capture ado uninstall tabtools
capture noisily net install tabtools, from("`pkg_dir'") replace
local install_rc = _rc
if `install_rc' {
    sysdir set PLUS "`orig_plus'"
    sysdir set PERSONAL "`orig_personal'"
    discard
    capture shell rm -rf "`plus_dir'" "`personal_dir'"
    capture log close _sscg
    exit `install_rc'
}
tabtools set clear

**# Package integrity
**## Required package artifacts exist
local ++test_count
capture noisily {
    foreach f in README.md stata.toc tabtools.pkg ///
        tabtools.ado tabtools.sthlp table1_tc.ado table1_tc.sthlp ///
        regtab.ado regtab.sthlp effecttab.ado effecttab.sthlp ///
        stratetab.ado stratetab.sthlp hrcomptab.ado hrcomptab.sthlp ///
        comptab.ado comptab.sthlp survtab.ado survtab.sthlp ///
        crosstab.ado crosstab.sthlp diagtab.ado diagtab.sthlp ///
        corrtab.ado corrtab.sthlp tabtools_cheatsheet.sthlp ///
        tabtools_cookbook.sthlp {
        confirm file "`pkg_dir'/`f'"
    }
}
if _rc == 0 {
    display as result "  PASS: required package artifacts exist"
    local ++pass_count
}
else {
    display as error "  FAIL: required package artifacts exist (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' artifacts"
}

**## stata.toc and .pkg metadata are present and well formed
local ++test_count
capture noisily {
    tempname toc_fh pkg_fh

    file open `toc_fh' using "`pkg_dir'/stata.toc", read text
    file read `toc_fh' toc1
    file read `toc_fh' toc2
    file read `toc_fh' toc3
    file read `toc_fh' toc4
    file read `toc_fh' toc5
    file close `toc_fh'

    assert strtrim(`"`toc1'"') == "v 3"
    assert strtrim(`"`toc2'"') == "d Stata-Tools: tabtools"
    assert strtrim(`"`toc3'"') == "d Timothy P Copeland, Karolinska Institutet"
    assert strtrim(`"`toc4'"') == "d https://github.com/tpcopeland/Stata-Tools"
    assert strtrim(`"`toc5'"') == "p tabtools"

    local saw_date = 0
    local saw_author = 0
    file open `pkg_fh' using "`pkg_dir'/tabtools.pkg", read text
    file read `pkg_fh' line
    while r(eof) == 0 {
        local raw = strtrim(`"`line'"')
        if regexm(`"`raw'"', "^d Distribution-Date: [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]$") {
            local saw_date = 1
        }
        if strtrim(`"`raw'"') == "d Author: Timothy P Copeland, Karolinska Institutet" {
            local saw_author = 1
        }
        file read `pkg_fh' line
    }
    file close `pkg_fh'

    assert `saw_date' == 1
    assert `saw_author' == 1
}
if _rc == 0 {
    display as result "  PASS: stata.toc and .pkg metadata look well formed"
    local ++pass_count
}
else {
    display as error "  FAIL: stata.toc/.pkg metadata check (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' metadata"
}

**## .pkg manifest matches shipped ado/sthlp files
local ++test_count
capture noisily {
    local pkg_files ""
    tempname fh

    file open `fh' using "`pkg_dir'/tabtools.pkg", read text
    file read `fh' line
    while r(eof) == 0 {
        local raw = strtrim(`"`line'"')
        if substr(`"`raw'"', 1, 2) == "f " {
            local pkg_file = strtrim(substr(`"`raw'"', 3, .))
            capture confirm file "`pkg_dir'/`pkg_file'"
            assert _rc == 0
            local pkg_files : list pkg_files | pkg_file
        }
        file read `fh' line
    }
    file close `fh'

    local ado_files : dir "`pkg_dir'" files "*.ado"
    local sthlp_files : dir "`pkg_dir'" files "*.sthlp"
    local dist_files : list ado_files | sthlp_files

    foreach f of local dist_files {
        local in_pkg : list f in pkg_files
        assert `in_pkg'
    }

    local n_pkg : word count `pkg_files'
    local n_dist : word count `dist_files'
    assert `n_pkg' == `n_dist'
}
if _rc == 0 {
    display as result "  PASS: .pkg manifest matches shipped ado/sthlp files"
    local ++pass_count
}
else {
    display as error "  FAIL: .pkg manifest completeness (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' pkg_manifest"
}

**## Shipped text artifacts do not contain dev-only paths or legacy repo refs
local ++test_count
capture noisily {
    local scan_files "README.md stata.toc tabtools.pkg qa/README.md qa/run_all.do qa/check_tabtools_render.py qa/crossval_tabtools_companion.R qa/baseline/baseline_manifest.tsv demo/demo_tabtools.do"

    local root_ado : dir "`pkg_dir'" files "*.ado"
    foreach f of local root_ado {
        local scan_files `"`scan_files' `f'"'
    }

    local root_sthlp : dir "`pkg_dir'" files "*.sthlp"
    foreach f of local root_sthlp {
        local scan_files `"`scan_files' `f'"'
    }

    foreach sub in _package comptab corrtab crosstab diagtab effecttab ///
        hrcomptab regtab stratetab tabtools tools {
        foreach ext in do py R md {
            local subfiles : dir "`pkg_dir'/qa/`sub'" files "*.`ext'"
            foreach f of local subfiles {
                if "`sub'" == "_package" & "`f'" == "test_ssc_release_gates.do" continue
                local scan_files `"`scan_files' qa/`sub'/`f'"'
            }
        }
    }

    local devref_count = 0
    tempfile _grep_out
    foreach relpath of local scan_files {
        capture confirm file "`pkg_dir'/`relpath'"
        if _rc continue

        shell grep -cE '/home/tpcopeland/|~/Stata-Tools|~/Stata-Dev|\.codex/skills/|_examples/|/Stata-Dev' "`pkg_dir'/`relpath'" > "`_grep_out'" 2>/dev/null
        tempname gfh
        file open `gfh' using "`_grep_out'", read text
        file read `gfh' _gline
        file close `gfh'
        if real("`_gline'") > 0 {
            display as error "  DEV REF: `relpath'"
            local ++devref_count
        }
    }

    assert `devref_count' == 0
}
if _rc == 0 {
    display as result "  PASS: shipped text artifacts are free of dev-only paths"
    local ++pass_count
}
else {
    display as error "  FAIL: shipped text artifacts include dev-only paths (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' dev_refs"
}

**## tabtools.ado package version literal matches the header version
local ++test_count
capture noisily {
    tempname ado_fh
    local header_version ""
    local package_version ""

    file open `ado_fh' using "`pkg_dir'/tabtools.ado", read text
    file read `ado_fh' line
    while r(eof) == 0 {
        if `"`header_version'"' == "" & strpos(`"`line'"', "Version ") > 0 {
            local header_tail = subinstr(`"`line'"', "Version ", "", 1)
            local header_version = word(`"`header_tail'"', 3)
        }
        if `"`package_version'"' == "" & strpos(`"`line'"', "_package_version") > 0 {
            local package_version = subinstr(`"`line'"', "local _package_version ", "", 1)
            local package_version = subinstr(`"`package_version'"', char(34), "", .)
            local package_version = strtrim(`"`package_version'"')
        }
        file read `ado_fh' line
    }
    file close `ado_fh'

    assert `"`header_version'"' != ""
    assert `"`package_version'"' != ""
    assert `"`header_version'"' == `"`package_version'"'
}
if _rc == 0 {
    display as result "  PASS: tabtools.ado header and package version literal match"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools.ado version synchronization (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' tabtools_version_sync"
}

**# Fresh-install discoverability
**## Public commands resolve after net install
local ++test_count
capture noisily {
    foreach cmd in tabtools table1_tc regtab effecttab stratetab hrcomptab ///
        comptab survtab crosstab diagtab corrtab {
        which `cmd'
    }
}
if _rc == 0 {
    display as result "  PASS: public commands resolve after fresh install"
    local ++pass_count
}
else {
    display as error "  FAIL: public command discoverability (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' which"
}

**## Bundled helper ado files are on adopath
local ++test_count
capture noisily {
    foreach helper in _tabtools_common.ado {
        findfile `helper'
    }
}
if _rc == 0 {
    display as result "  PASS: bundled helper ado files resolve after install"
    local ++pass_count
}
else {
    display as error "  FAIL: bundled helper ado files resolve after install (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' helpers"
}

**## Retired refactor helpers are not shipped
local ++test_count
capture noisily {
    foreach helper in _tabtools_guard.ado _tabtools_settings.ado ///
        _tabtools_table_spec.ado _tabtools_render_excel.ado ///
        _tabtools_export.ado _tabtools_collect_bridge.ado {
        capture confirm file "`pkg_dir'/`helper'"
        assert _rc != 0
    }
}
if _rc == 0 {
    display as result "  PASS: retired refactor helpers are absent from the source tree"
    local ++pass_count
}
else {
    display as error "  FAIL: retired refactor helpers still present in source tree (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' retired_helpers"
}

**# Documentation reality
**## README example: crosstab runs as displayed
local ++test_count
capture noisily {
    webuse nhanes2, clear
    capture erase "crosstab.xlsx"
    crosstab diabetes highbp, xlsx("crosstab.xlsx") ///
        or colpct exact ///
        title("Cross-tabulation: Diabetes by Hypertension")
    confirm file "crosstab.xlsx"
}
if _rc == 0 {
    display as result "  PASS: README crosstab example runs unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: README crosstab example (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' readme_crosstab"
}

**## regtab.sthlp example runs as displayed
local ++test_count
capture noisily {
    webuse nhanes2, clear
    collect clear
    collect: logit diabetes age female i.race bmi highbp
    capture erase "regression.xlsx"
    regtab, xlsx(regression.xlsx) sheet("Diabetes") ///
        title("Odds Ratios for Diabetes") coef(OR)
    confirm file "regression.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab.sthlp example runs unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab.sthlp example (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' regtab_sthlp"
}

**## tabtools.sthlp example returns expected filtered command list
local ++test_count
capture noisily {
    tabtools, category(descriptive)
    assert r(n_commands) == 3
    assert strpos("`r(commands)'", "table1_tc") > 0
    assert strpos("`r(commands)'", "crosstab") > 0
    assert strpos("`r(commands)'", "corrtab") > 0
}
if _rc == 0 {
    display as result "  PASS: tabtools.sthlp category example behaves as documented"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools.sthlp category example (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' tabtools_sthlp"
}

**## tabtools set/get/clear cycle behaves for help-file workflow
local ++test_count
capture noisily {
    tabtools set clear
    tabtools set font "Times New Roman"
    assert "$TABTOOLS_FONT" == "Times New Roman"
    tabtools set fontsize 10
    assert "$TABTOOLS_FONTSIZE" == "10"
    tabtools set borderstyle academic
    assert "$TABTOOLS_BORDER" == "academic"
    tabtools get
    tabtools set clear
    assert "$TABTOOLS_FONT" == ""
    assert "$TABTOOLS_FONTSIZE" == ""
    assert "$TABTOOLS_BORDER" == ""
}
if _rc == 0 {
    display as result "  PASS: tabtools help-file set/get/clear workflow works"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools help-file set/get/clear workflow (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' set_get_clear"
}

**# Summary
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

capture erase "crosstab.xlsx"
capture erase "regression.xlsx"
tabtools set clear
capture ado uninstall tabtools
sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
discard
capture shell rm -rf "`plus_dir'" "`personal_dir'"

if `fail_count' > 0 {
    display as error "FAILED TESTS: `failed_tests'"
    display "RESULT: test_ssc_release_gates tests=`test_count' pass=`pass_count' fail=`fail_count'"
    capture log close _sscg
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: test_ssc_release_gates tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _sscg
