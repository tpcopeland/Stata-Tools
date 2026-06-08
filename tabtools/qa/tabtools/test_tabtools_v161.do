* test_tabtools_v161.do - Regression tests for v1.6.1 tabtools profiles
* Generated: 2026-06-08
* Covers:
*   - tabtools set ..., permanent writes runnable disk profiles
*   - tabtools use loads default and project-specific profiles
*   - profile defaults survive a fresh Stata process
*   - generated profiles are ordinary non-recursive tabtools set commands

clear all
set more off
set varabbrev off
version 16.0

capture log close _v161
log using "test_tabtools_v161.log", replace text name(_v161)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
local tools_dir "`qa_dir'/tools"
capture mkdir "`output_dir'"

local orig_plus "`c(sysdir_plus)'"
local orig_personal "`c(sysdir_personal)'"
tempname install_id
local install_tag = subinstr("`install_id'", "__", "", .)
local plus_dir "`c(tmpdir)'/tabtools_v161_plus_`install_tag'"
local personal_dir "`c(tmpdir)'/tabtools_v161_personal_`install_tag'"
capture mkdir "`plus_dir'"
capture mkdir "`personal_dir'"
sysdir set PLUS "`plus_dir'"
sysdir set PERSONAL "`personal_dir'"
discard
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

local default_profile "`personal_dir'/tabtools_profile.do"
local project_profile "`output_dir'/tabtools_v161_project_profile.do"
local spaced_profile "`output_dir'/tabtools v161 spaced profile.do"
local reader_do "`output_dir'/tabtools_v161_reader.do"
local reader_log "`output_dir'/tabtools_v161_reader.log"
local reader_marker "`output_dir'/tabtools_v161_reader_marker.txt"

foreach f in "`default_profile'" "`project_profile'" "`spaced_profile'" ///
    "`reader_do'" "`reader_log'" "`reader_marker'" {
    capture erase "`f'"
}

**# Profile Helpers

capture program drop _v161_pass
program define _v161_pass
    args label
    display as result "  PASS `label'"
end

capture program drop _v161_fail
program define _v161_fail
    args label rc
    display as error "  FAIL `label' (rc=`rc')"
end

**# Disk Profile Semantics

* T1: default PERSONAL profile writes, reloads, and posts exact returns
local ++test_count
capture noisily {
    tabtools set clear
    tabtools set theme custom, font("Times New Roman") fontsize(11) ///
        headercolor("200 220 240") zebracolor("245 245 245") ///
        borderstyle(academic) permanent
    assert "`r(permanent)'" == "permanent"
    assert "`r(profile)'" == "`default_profile'"
    confirm file "`default_profile'"

    tabtools set digits 3, permanent
    tabtools set boldp 0.025, permanent
    confirm file "`default_profile'"

    tabtools set clear
    assert "$TABTOOLS_THEME" == ""
    assert "$TABTOOLS_FONT" == ""
    assert "$TABTOOLS_DIGITS" == ""
    assert "$TABTOOLS_BOLDP" == ""

    tabtools use
    assert "`r(action)'" == "loaded"
    assert "`r(profile)'" == "`default_profile'"
    assert "$TABTOOLS_THEME" == "custom"
    assert "$TABTOOLS_FONT" == "Times New Roman"
    assert "$TABTOOLS_FONTSIZE" == "11"
    assert "$TABTOOLS_HEADERCOLOR" == "200 220 240"
    assert "$TABTOOLS_ZEBRACOLOR" == "245 245 245"
    assert "$TABTOOLS_BORDER" == "academic"
    assert "$TABTOOLS_DIGITS" == "3"
    assert "$TABTOOLS_BOLDP" == "0.025"
}
if _rc == 0 {
    _v161_pass "T1: default PERSONAL profile round-trip"
    local ++pass_count
}
else {
    _v161_fail "T1: default PERSONAL profile round-trip" `=_rc'
    local ++fail_count
    local failed_tests "`failed_tests' T1"
}

* T2: generated default profile contains ordinary set commands and no recursion
local ++test_count
capture noisily {
    confirm file "`default_profile'"
    local saw_clear = 0
    local saw_custom = 0
    local saw_digits = 0
    local saw_boldp = 0
    local saw_permanent = 0
    tempname fh
    file open `fh' using "`default_profile'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "tabtools set clear") > 0 local saw_clear = 1
        if strpos(`"`line'"', `"tabtools set theme custom"') > 0 local saw_custom = 1
        if strpos(`"`line'"', "tabtools set digits 3") > 0 local saw_digits = 1
        if strpos(`"`line'"', "tabtools set boldp 0.025") > 0 local saw_boldp = 1
        if strpos(`"`line'"', "permanent") > 0 local saw_permanent = 1
        file read `fh' line
    }
    file close `fh'
    assert `saw_clear' == 1
    assert `saw_custom' == 1
    assert `saw_digits' == 1
    assert `saw_boldp' == 1
    assert `saw_permanent' == 0
}
if _rc == 0 {
    _v161_pass "T2: default profile content is runnable and non-recursive"
    local ++pass_count
}
else {
    _v161_fail "T2: default profile content is runnable and non-recursive" `=_rc'
    local ++fail_count
    local failed_tests "`failed_tests' T2"
}

* T3: explicit project profile supports spaces in filenames and using syntax
local ++test_count
capture noisily {
    tabtools set clear
    tabtools set font "Courier New", permanent profile("`spaced_profile'")
    tabtools set fontsize 13, permanent profile("`spaced_profile'")
    tabtools set borderstyle thin, permanent profile("`spaced_profile'")
    confirm file "`spaced_profile'"

    tabtools set clear
    tabtools use using "`spaced_profile'"
    assert "`r(profile)'" == "`spaced_profile'"
    assert "$TABTOOLS_FONT" == "Courier New"
    assert "$TABTOOLS_FONTSIZE" == "13"
    assert "$TABTOOLS_BORDER" == "thin"
}
if _rc == 0 {
    _v161_pass "T3: project profile with spaces reloads through using"
    local ++pass_count
}
else {
    _v161_fail "T3: project profile with spaces reloads through using" `=_rc'
    local ++fail_count
    local failed_tests "`failed_tests' T3"
}

* T4: profile() syntax on tabtools use works and refuses duplicate path sources
local ++test_count
capture noisily {
    tabtools set clear
    tabtools set theme lancet, permanent profile("`project_profile'")
    local default_saw_lancet = 0
    tempname dfh
    file open `dfh' using "`default_profile'", read text
    file read `dfh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "tabtools set theme lancet") > 0 local default_saw_lancet = 1
        file read `dfh' line
    }
    file close `dfh'
    assert `default_saw_lancet' == 0

    tabtools set clear
    tabtools use, profile("`project_profile'")
    assert "$TABTOOLS_THEME" == "lancet"
    assert "`r(profile)'" == "`project_profile'"

    capture noisily tabtools use using "`project_profile'", profile("`project_profile'")
    assert _rc == 198
}
if _rc == 0 {
    _v161_pass "T4: profile() load works and duplicate path sources rejected"
    local ++pass_count
}
else {
    _v161_fail "T4: profile() load works and duplicate path sources rejected" `=_rc'
    local ++fail_count
    local failed_tests "`failed_tests' T4"
}

* T5: unsupported option surfaces reject cleanly
local ++test_count
capture noisily {
    capture noisily tabtools get, permanent
    assert _rc == 198
    capture noisily tabtools, profile("`project_profile'")
    assert _rc == 198
    capture noisily tabtools use, permanent
    assert _rc == 198
    capture noisily tabtools use extra
    assert _rc == 198
    capture noisily tabtools set font Arial, profile("`project_profile'")
    assert _rc == 198
}
if _rc == 0 {
    _v161_pass "T5: invalid permanent/profile surfaces return rc=198"
    local ++pass_count
}
else {
    _v161_fail "T5: invalid permanent/profile surfaces return rc=198" `=_rc'
    local ++fail_count
    local failed_tests "`failed_tests' T5"
}

* T6: generated profile works after a fresh Stata process restart
local ++test_count
capture noisily {
    tabtools set clear
    tabtools set theme custom, font("Times New Roman") fontsize(11) ///
        headercolor("200 220 240") zebracolor("245 245 245") ///
        borderstyle(academic) permanent
    tabtools set digits 3, permanent
    tabtools set boldp 0.025, permanent
    confirm file "`default_profile'"

    capture erase "`reader_marker'"
    capture erase "`reader_log'"

    mata:
    fh = fopen(st_local("reader_do"), "w")
    fput(fh, "clear all")
    fput(fh, "set more off")
    fput(fh, "set varabbrev off")
    fput(fh, sprintf(`"sysdir set PLUS "%s""', st_local("plus_dir")))
    fput(fh, sprintf(`"sysdir set PERSONAL "%s""', st_local("personal_dir")))
    fput(fh, "discard")
    fput(fh, "tabtools use")
    fput(fh, `"assert "$TABTOOLS_THEME" == "custom""')
    fput(fh, `"assert "$TABTOOLS_FONT" == "Times New Roman""')
    fput(fh, `"assert "$TABTOOLS_FONTSIZE" == "11""')
    fput(fh, `"assert "$TABTOOLS_HEADERCOLOR" == "200 220 240""')
    fput(fh, `"assert "$TABTOOLS_ZEBRACOLOR" == "245 245 245""')
    fput(fh, `"assert "$TABTOOLS_BORDER" == "academic""')
    fput(fh, `"assert "$TABTOOLS_DIGITS" == "3""')
    fput(fh, `"assert "$TABTOOLS_BOLDP" == "0.025""')
    fput(fh, sprintf(`"file open m using "%s", write text replace"', st_local("reader_marker")))
    fput(fh, `"file write m "loaded" _n"')
    fput(fh, "file close m")
    fput(fh, "exit")
    fclose(fh)
    end

    capture shell cd "`output_dir'" && stata-mp -b do "tabtools_v161_reader.do"
    local _shell_rc = _rc
    confirm file "`reader_log'"
    confirm file "`reader_marker'"
    display as text "  child shell rc: `_shell_rc'"
}
if _rc == 0 {
    _v161_pass "T6: default profile survives fresh Stata process"
    local ++pass_count
}
else {
    _v161_fail "T6: default profile survives fresh Stata process" `=_rc'
    local ++fail_count
    local failed_tests "`failed_tests' T6"
}

**# Cleanup

tabtools set clear
foreach f in "`default_profile'" "`project_profile'" "`spaced_profile'" ///
    "`reader_do'" "`reader_marker'" {
    capture erase "`f'"
}
if `fail_count' == 0 {
    local reader_logs : dir "`output_dir'" files "tabtools_v161_reader*.log"
    foreach f of local reader_logs {
        capture erase "`output_dir'/`f'"
    }
}

capture ado uninstall tabtools
sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
discard
capture shell rm -rf "`plus_dir'" "`personal_dir'"

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED: `failed_tests'"
    display "RESULT: test_tabtools_v161 tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _v161
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_tabtools_v161 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _v161
