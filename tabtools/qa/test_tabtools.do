* test_tabtools.do - QA for the tabtools suite controller (listing, set/get, profiles)
* Consolidated in v1.7.0 from: test_new_commands.do, test_regression_fixes.do, test_tabtools.do, test_tabtools_v103.do, test_tabtools_v161.do, test_v160_features.do

clear all
set more off
set varabbrev off
version 16.0

capture log close _ttctrl
log using "test_tabtools.log", replace text name(_ttctrl)

local test_count = 0
local pass_count = 0
local fail_count = 0

local n_total = 0
**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local pkg_root "`pkg_dir'"
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
local tools_dir "`qa_dir'/tools"
local checker "`tools_dir'/check_xlsx.py"
local md_checker "`tools_dir'/check_markdown.py"
local summary_tool "`tools_dir'/summarize_xlsx.py"

local python_cmd ""
capture noisily shell python3 --version
if _rc == 0 {
    local python_cmd "python3"
}
else {
    capture noisily shell python --version
    if _rc == 0 local python_cmd "python"
}

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear


**# Migrated: meta-command listing tests

* ============================================================
* tabtools Meta-Command Tests
* ============================================================

* Test: tabtools default listing
capture noisily {
    tabtools
    assert r(n_commands) > 0
}
if _rc == 0 {
    display as result "  PASS: tabtools - default listing"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools - default listing (error `=_rc')"
    local ++fail_count
}

* Test: tabtools with list option
capture noisily {
    tabtools, list
    assert r(n_commands) > 0
}
if _rc == 0 {
    display as result "  PASS: tabtools - list option"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools - list option (error `=_rc')"
    local ++fail_count
}

* Test: tabtools with detail option
capture noisily {
    tabtools, detail
    assert r(n_commands) > 0
}
if _rc == 0 {
    display as result "  PASS: tabtools - detail option"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools - detail option (error `=_rc')"
    local ++fail_count
}

* Test: tabtools category filter
capture noisily {
    tabtools, category(descriptive)
    assert r(n_commands) == 4
    assert strpos("`r(commands)'", "desctab") > 0
    assert strpos("`r(commands)'", "corrtab") > 0
    assert strpos("`r(commands)'", "hrcomptab") == 0
}
if _rc == 0 {
    display as result "  PASS: tabtools - category filter"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools - category filter (error `=_rc')"
    local ++fail_count
}

* Test: tabtools general category excludes corrtab
capture noisily {
    tabtools, category(general)
    assert r(n_commands) == 2
    assert strpos("`r(commands)'", "tabtools") > 0
    assert strpos("`r(commands)'", "tabtools_tips") > 0
    assert strpos("`r(commands)'", "hrcomptab") == 0
    assert strpos("`r(commands)'", "corrtab") == 0
}
if _rc == 0 {
    display as result "  PASS: tabtools - general category inventory"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools - general category inventory (error `=_rc')"
    local ++fail_count
}

* Test: tabtools models category excludes composite commands
capture noisily {
    tabtools, category(models)
    assert r(n_commands) == 2
    assert strpos("`r(commands)'", "regtab") > 0
    assert strpos("`r(commands)'", "effecttab") > 0
    assert strpos("`r(commands)'", "comptab") == 0
    assert strpos("`r(commands)'", "hrcomptab") == 0
}
if _rc == 0 {
    display as result "  PASS: tabtools - models category excludes composite commands"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools - models category inventory (error `=_rc')"
    local ++fail_count
}

* Test: tabtools composite category includes only composite commands
capture noisily {
    tabtools, category(composite)
    assert r(n_commands) == 2
    assert strpos("`r(commands)'", "comptab") > 0
    assert strpos("`r(commands)'", "hrcomptab") > 0
    assert strpos("`r(commands)'", "regtab") == 0
}
if _rc == 0 {
    display as result "  PASS: tabtools - composite category inventory"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools - composite category inventory (error `=_rc')"
    local ++fail_count
}

* Test: tabtools returns version
capture noisily {
    tabtools
    assert "`r(version)'" != ""
}
if _rc == 0 {
    display as result "  PASS: tabtools - returns version"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools - returns version (error `=_rc')"
    local ++fail_count
}


**# Migrated: set/get/subcommand tests

* ============================================================
* tabtools set/get/subcommands Tests
* ============================================================

**# tabtools set/get/subcommands

* Test: tabtools set clear runs without error
tabtools set clear
capture noisily {
    tabtools set clear
    assert "`r(action)'" == "cleared"
}
if _rc == 0 {
    display as result "  PASS: tabtools set clear - returns action=cleared"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools set clear (error `=_rc')"
    local ++fail_count
}

* Test: tabtools set font sets global and returns r(font)
capture noisily {
    tabtools set font Calibri
    assert "$TABTOOLS_FONT" == "Calibri"
    assert "`r(font)'" == "Calibri"
}
if _rc == 0 {
    display as result "  PASS: tabtools set font Calibri - global and r(font) correct"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools set font Calibri (error `=_rc')"
    local ++fail_count
}

* Test: tabtools set fontsize sets global and returns r(fontsize)
capture noisily {
    tabtools set fontsize 11
    assert "$TABTOOLS_FONTSIZE" == "11"
    assert r(fontsize) == 11
}
if _rc == 0 {
    display as result "  PASS: tabtools set fontsize 11 - global and r(fontsize) correct"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools set fontsize 11 (error `=_rc')"
    local ++fail_count
}

* Test: tabtools set borderstyle sets global and returns r(borderstyle)
capture noisily {
    tabtools set borderstyle thin
    assert "$TABTOOLS_BORDER" == "thin"
    assert "`r(borderstyle)'" == "thin"
}
if _rc == 0 {
    display as result "  PASS: tabtools set borderstyle thin - global and r(borderstyle) correct"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools set borderstyle thin (error `=_rc')"
    local ++fail_count
}

* Test: tabtools get returns all three values after set
capture noisily {
    tabtools set font Calibri
    tabtools set fontsize 11
    tabtools set borderstyle thin
    tabtools get
    assert "`r(font)'" == "Calibri"
    assert "`r(fontsize)'" == "11"
    assert "`r(borderstyle)'" == "thin"
}
if _rc == 0 {
    display as result "  PASS: tabtools get - returns font, fontsize, borderstyle"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools get (error `=_rc')"
    local ++fail_count
}

* Test: tabtools get returns effective named-theme values
capture noisily {
    tabtools set clear
    tabtools set theme lancet
    tabtools get
    assert "`r(theme)'" == "lancet"
    assert "`r(font)'" == "Arial"
    assert "`r(fontsize)'" == "9"
    assert "`r(borderstyle)'" == "academic"
}
if _rc == 0 {
    display as result "  PASS: tabtools get - named theme reports effective values"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools get effective named-theme values (error `=_rc')"
    local ++fail_count
}

* Test: tabtools set clear empties all globals
capture noisily {
    tabtools set clear
    tabtools set font Calibri
    tabtools set fontsize 11
    tabtools set borderstyle thin
    tabtools set clear
    assert "$TABTOOLS_FONT" == ""
    assert "$TABTOOLS_FONTSIZE" == ""
    assert "$TABTOOLS_BORDER" == ""
    assert "`r(action)'" == "cleared"
}
if _rc == 0 {
    display as result "  PASS: tabtools set clear - empties all globals"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools set clear - globals not empty (error `=_rc')"
    local ++fail_count
}

* Test: tabtools get returns effective command defaults after clear
capture noisily {
    tabtools set clear
    tabtools get
    assert "`r(font)'" == "Arial"
    assert "`r(fontsize)'" == "10"
    assert "`r(borderstyle)'" == "thin"
    assert `"`r(theme)'"' == ""
}
if _rc == 0 {
    display as result "  PASS: tabtools get - clear resolves to Arial/10/thin"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools get defaults after clear (error `=_rc')"
    local ++fail_count
}

* Test: tabtools set ..., permanent writes a profile and tabtools use reloads it
capture noisily {
    local _profile "`output_dir'/tabtools_profile_roundtrip.do"
    capture erase "`_profile'"
    tabtools set clear
    tabtools set font "Times New Roman", permanent profile("`_profile'")
    assert "`r(permanent)'" == "permanent"
    assert "`r(profile)'" == "`_profile'"
    confirm file "`_profile'"
    tabtools set fontsize 12
    tabtools set digits 3, permanent profile("`_profile'")
    tabtools set clear
    assert "$TABTOOLS_FONT" == ""
    assert "$TABTOOLS_FONTSIZE" == ""
    assert "$TABTOOLS_DIGITS" == ""
    tabtools use using "`_profile'"
    assert "`r(action)'" == "loaded"
    assert "`r(profile)'" == "`_profile'"
    assert "$TABTOOLS_FONT" == "Times New Roman"
    assert "$TABTOOLS_FONTSIZE" == "12"
    assert "$TABTOOLS_DIGITS" == "3"
    capture erase "`_profile'"
}
if _rc == 0 {
    display as result "  PASS: tabtools permanent profile round-trip"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools permanent profile round-trip (error `=_rc')"
    local ++fail_count
}

* Test: permanent custom-theme profile is valid when the first custom option is not font()
capture noisily {
    local _profile "`output_dir'/tabtools_profile_custom.do"
    capture erase "`_profile'"
    tabtools set clear
    tabtools set theme custom, fontsize(12) headercolor("200 220 240") permanent profile("`_profile'")
    confirm file "`_profile'"
    tabtools set clear
    tabtools use, profile("`_profile'")
    assert "$TABTOOLS_THEME" == "custom"
    assert "$TABTOOLS_FONTSIZE" == "12"
    assert "$TABTOOLS_HEADERCOLOR" == "200 220 240"
    capture erase "`_profile'"
}
if _rc == 0 {
    display as result "  PASS: tabtools permanent custom-theme profile reloads"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools custom-theme profile reload (error `=_rc')"
    local ++fail_count
}

* Test: tabtools set profile() without permanent is rejected
capture {
    tabtools set font Calibri, profile("`output_dir'/invalid_profile.do")
}
if _rc == 198 {
    display as result "  PASS: tabtools set profile() without permanent - rc=198"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools set profile() without permanent - expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test: tabtools use missing profile returns Stata file-not-found rc
capture {
    tabtools use using "`output_dir'/missing_tabtools_profile.do"
}
if _rc == 601 {
    display as result "  PASS: tabtools use missing profile - rc=601"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools use missing profile - expected rc=601, got `=_rc'"
    local ++fail_count
}

* Test: tabtools set fontsize below range → rc=198
capture {
    tabtools set fontsize 5
}
if _rc == 198 {
    display as result "  PASS: tabtools set fontsize 5 - rc=198 (out of range)"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools set fontsize 5 - expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test: tabtools set fontsize above range → rc=198
capture {
    tabtools set fontsize 73
}
if _rc == 198 {
    display as result "  PASS: tabtools set fontsize 73 - rc=198 (out of range)"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools set fontsize 73 - expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test: tabtools set fontsize non-integer → rc=198
capture {
    tabtools set fontsize abc
}
if _rc == 198 {
    display as result "  PASS: tabtools set fontsize abc - rc=198 (non-integer)"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools set fontsize abc - expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test: tabtools set invalid borderstyle → rc=198
capture {
    tabtools set borderstyle heavy
}
if _rc == 198 {
    display as result "  PASS: tabtools set borderstyle heavy - rc=198 (invalid)"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools set borderstyle heavy - expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test: tabtools set unknown key → rc=198
capture {
    tabtools set invalidkey somevalue
}
if _rc == 198 {
    display as result "  PASS: tabtools set invalidkey - rc=198 (unknown key)"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools set invalidkey - expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test: tabtools set font/size/border convert named theme to custom before overriding
capture noisily {
    tabtools set clear
    tabtools set theme lancet
    tabtools set font Calibri
    assert "$TABTOOLS_THEME" == "custom"
    assert "$TABTOOLS_FONT" == "Calibri"
    tabtools set theme lancet
    tabtools set fontsize 11
    assert "$TABTOOLS_THEME" == "custom"
    assert "$TABTOOLS_FONTSIZE" == "11"
    tabtools set theme lancet
    tabtools set borderstyle thin
    assert "$TABTOOLS_THEME" == "custom"
    assert "$TABTOOLS_BORDER" == "thin"
}
tabtools set clear
if _rc == 0 {
    display as result "  PASS: tabtools direct setters convert named themes to custom"
    local ++pass_count
}
else {
    tabtools set clear
    display as error "  FAIL: tabtools named-theme setter conversion (error `=_rc')"
    local ++fail_count
}

* Test: tabtools set theme custom rejects invalid borderstyle
capture {
    tabtools set theme custom, borderstyle(garbage)
}
if _rc == 198 {
    display as result "  PASS: tabtools set theme custom invalid borderstyle - rc=198"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools set theme custom invalid borderstyle - expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test: tabtools set theme custom rejects invalid headercolor
capture {
    tabtools set theme custom, headercolor("12 999 5")
}
if _rc == 198 {
    display as result "  PASS: tabtools set theme custom invalid headercolor - rc=198"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools set theme custom invalid headercolor - expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test: tabtools get rejects trailing arguments
capture {
    tabtools get extra
}
if _rc == 198 {
    display as result "  PASS: tabtools get extra - rc=198"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools get extra - expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test: tabtools get rejects display-only options
capture noisily {
    capture noisily tabtools get, list
    assert _rc == 198
    capture noisily tabtools get, detail
    assert _rc == 198
    capture noisily tabtools get, category(models)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tabtools get rejects display-only options"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools get display-only options (error `=_rc')"
    local ++fail_count
}

* Test: tabtools set clear rejects trailing arguments
capture {
    tabtools set clear extra
}
if _rc == 198 {
    display as result "  PASS: tabtools set clear extra - rc=198"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools set clear extra - expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test: tabtools set rejects display-only options
capture noisily {
    capture noisily tabtools set clear, list
    assert _rc == 198
    capture noisily tabtools set clear, detail
    assert _rc == 198
    capture noisily tabtools set clear, category(models)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tabtools set rejects display-only options"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools set display-only options (error `=_rc')"
    local ++fail_count
}

* Test: tabtools rejects theme-builder options in display mode
capture {
    tabtools, font(ComicSans)
}
if _rc == 198 {
    display as result "  PASS: tabtools, font(...) - rc=198 outside set theme custom"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools, font(...) - expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test: tabtools unknown subcommand → rc=198
capture {
    tabtools unknowncmd
}
if _rc == 198 {
    display as result "  PASS: tabtools unknowncmd - rc=198 (unknown subcommand)"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools unknowncmd - expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test: invalid persisted borderstyle fails before workbook creation
capture noisily {
    local _bad_xlsx "`output_dir'/_bad_borderstyle.xlsx"
    capture erase "`_bad_xlsx'"
    global TABTOOLS_BORDER "weird"
    sysuse auto, clear
    capture noisily corrtab price mpg weight, xlsx("`_bad_xlsx'") sheet("BadBorder")
    local _cmd_rc = _rc
    capture confirm file "`_bad_xlsx'"
    local _file_rc = _rc
    global TABTOOLS_BORDER
    assert `_cmd_rc' == 198
    assert `_file_rc' != 0
}
if _rc == 0 {
    display as result "  PASS: invalid persisted borderstyle fails before workbook creation"
    local ++pass_count
}
else {
    global TABTOOLS_BORDER
    display as error "  FAIL: invalid persisted borderstyle gate (error `=_rc')"
    local ++fail_count
}

tabtools set clear


**# Migrated: r(version) matches header

**# 1.1: Fix stale r(version)
* =========================================================================

local ++n_total
capture noisily {
    file open _fh using "`pkg_dir'/tabtools.ado", read text
    file read _fh _line
    file close _fh
    assert regexm(`"`_line'"', "Version ([0-9]+\.[0-9]+\.[0-9]+)")
    local expected_version = regexs(1)

    tabtools
    assert r(version) == "`expected_version'"
}
if _rc == 0 {
    display as result "  PASS: 1.1 — r(version) matches tabtools.ado"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.1 — r(version) wrong (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================

**# Migrated: disk-backed defaults profiles

* Profile tests write tabtools_profile.do into PERSONAL; sandbox the ado
* dirs for this section so the user's real profile is never touched.
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
quietly net install tabtools, from("`pkg_dir'") replace

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
    tabtools get
    assert "`r(headercolor)'" == "200 220 240"
    assert "`r(zebracolor)'" == "245 245 245"
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
* Restore the real ado dirs after the sandboxed profile section.
sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
discard
capture shell rm -rf "`plus_dir'" "`personal_dir'"

**# Migrated: detail re-load after manual drop

* T10: drop tabtools by name only, then call tabtools detail again. Pre-1.0.3
*      this errored with "_tabtools_detail already defined" on the second run.
capture program drop tabtools
capture noisily tabtools, detail cat(all)
if _rc == 0 {
    display as result "  PASS T10: tabtools detail re-loads after manual drop"
    local ++pass_count
}
else {
    display as error "  FAIL T10: tabtools detail re-load (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T10"
}

**# Migrated: detail listing completeness

**# 5. tabtools detail listing — all commands and categories

**## 5a. tabtools returns 16 current commands
capture noisily {
    tabtools
    assert r(n_commands) == 16
}
if _rc == 0 {
    display as result "  PASS: tabtools returns n_commands = 16"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools n_commands != 16 (error `=_rc')"
    local ++fail_count
}

**## 5b. All 9 categories are returned
capture noisily {
    tabtools
    local cats = r(categories)
    assert strpos("`cats'", "descriptive") > 0
    assert strpos("`cats'", "models") > 0
    assert strpos("`cats'", "rates") > 0
    assert strpos("`cats'", "survival") > 0
    assert strpos("`cats'", "diagnostics") > 0
    assert strpos("`cats'", "composite") > 0
    assert strpos("`cats'", "export") > 0
    assert strpos("`cats'", "simulation") > 0
    assert strpos("`cats'", "general") > 0
}
if _rc == 0 {
    display as result "  PASS: tabtools returns all 9 categories"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools missing categories (error `=_rc')"
    local ++fail_count
}

**## 5c. Each category filter returns commands
local t5c_pass = 1
foreach cat in descriptive models rates survival diagnostics composite export simulation general {
    capture noisily {
        tabtools, category(`cat')
        assert r(n_commands) > 0
    }
    if _rc == 0 {
        display as result "  PASS [5c.`cat']: category(`cat') returns commands"
    }
    else {
        display as error "  FAIL [5c.`cat']: category(`cat') failed (error `=_rc')"
        local t5c_pass = 0
    }
}
if `t5c_pass' == 1 {
    display as result "  PASS: all category filters return commands"
    local ++pass_count
}
else {
    display as error "  FAIL: some category filters failed"
    local ++fail_count
}

**## 5d. detail option works for all categories
local t5d_pass = 1
foreach cat in all descriptive models rates survival diagnostics composite export simulation general {
    capture noisily {
        tabtools, detail category(`cat')
    }
    if _rc != 0 {
        display as error "  FAIL [5d.`cat']: tabtools, detail category(`cat') error `=_rc'"
        local t5d_pass = 0
    }
}
if `t5d_pass' == 1 {
    display as result "  PASS: tabtools detail works for all categories"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools detail failed for some categories"
    local ++fail_count
}

**## 5e. r(commands) contains all 16 current command names
local t5e_pass = 1
capture noisily {
    tabtools
    local cmds = r(commands)
}
if _rc != 0 {
    display as error "  FAIL [5e.run]: tabtools error `=_rc'"
    local t5e_pass = 0
}
else {
    foreach cmd in table1_tc desctab crosstab corrtab regtab effecttab stratetab survtab diagtab comptab hrcomptab puttab stacktab simtab tabtools tabtools_tips {
        if strpos("`cmds'", "`cmd'") > 0 {
            display as result "  PASS [5e.`cmd']: `cmd' in r(commands)"
        }
        else {
            display as error "  FAIL [5e.`cmd']: `cmd' missing from r(commands)"
            local t5e_pass = 0
        }
    }
}
if `t5e_pass' == 1 {
    display as result "  PASS: all 16 current commands in r(commands)"
    local ++pass_count
}
else {
    display as error "  FAIL: some commands missing from r(commands)"
    local ++fail_count
}


* Cleanup
capture erase "`output_dir'/_regfix_corrtab_pw.xlsx"
capture erase "`output_dir'/_regfix_corrtab_sp.xlsx"
capture erase "`output_dir'/_regfix_corrtab_complete.xlsx"
capture erase "`output_dir'/_regfix_custom_table1.xlsx"
capture erase "`output_dir'/_regfix_custom_fill.txt"
capture erase "`output_dir'/_regfix_stratetab_badsheet.xlsx"
capture erase "`output_dir'/_regfix_stratetab_star.xlsx"
capture erase "`output_dir'/_regfix_stratetab_long.xlsx"
capture erase "`output_dir'/_regfix_strate_data.dta"
capture erase "`output_dir'/_regfix_strate_data2.dta"
capture erase "`output_dir'/_regfix_strate_data3.dta"
capture erase "`output_dir'/_regfix_crosstab_zebra.xlsx"
capture erase "`output_dir'/_regfix_cross_fill_count.txt"
capture {
    shell rm -rf "`output_dir'/_regfix_cross_inspect"
}
**# Migrated: new commands visible in listing

**# SECTION 1: tabtools listing — new commands visible
* ============================================================

* Test: tabtools default listing includes new commands
capture noisily {
    tabtools
    assert r(n_commands) >= 10
}
if _rc == 0 {
    display as result "  PASS: tabtools listing shows >= 10 commands"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools listing shows too few commands (rc=`=_rc')"
    local ++fail_count
}

* ============================================================

**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_tabtools tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _ttctrl
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_tabtools tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _ttctrl
