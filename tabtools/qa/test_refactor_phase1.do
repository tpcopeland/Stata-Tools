* test_refactor_phase1.do — conditional QA for tabtools refactor Phase 1 helpers

capture log close _refactor_phase1
log using "test_refactor_phase1.log", replace text name(_refactor_phase1)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
tabtools set clear

local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0
local failed_tests ""

local settings_src = 0
capture confirm file "`pkg_dir'/_tabtools_settings.ado"
if _rc == 0 local settings_src = 1

local guard_src = 0
capture confirm file "`pkg_dir'/_tabtools_guard.ado"
if _rc == 0 local guard_src = 1

local settings_installed = 0
capture which _tabtools_settings
if _rc == 0 local settings_installed = 1
capture program list _tabtools_settings_resolve
if _rc == 0 local settings_installed = 1
local settings_helper_ok = 0

local guard_installed = 0
capture which _tabtools_guard
if _rc == 0 local guard_installed = 1
capture program list _tabtools_guard_enter
if _rc == 0 local guard_installed = 1
local guard_wrapper_ok = 0

capture program drop _tt_phase1_settings_probe
program define _tt_phase1_settings_probe, rclass
    version 16.0
    syntax , [THEME(string) BORDERstyle(string) HEADERColor(string) ///
        ZEBRAColor(string) HEADERShade ZEBRA DIGITS(string) BOLDP(string) ///
        HIGHLIGHT(string) PDP(string) HIGHPDP(string)]

    local opts ""
    if "`theme'" != "" {
        local opts `"`opts' theme(`theme')"' 
    }
    if "`borderstyle'" != "" {
        local opts `"`opts' borderstyle(`borderstyle')"' 
    }
    if `"`headercolor'"' != "" {
        local opts `"`opts' headercolor(`"`headercolor'"')"' 
    }
    if `"`zebracolor'"' != "" {
        local opts `"`opts' zebracolor(`"`zebracolor'"')"' 
    }
    if "`headershade'" != "" {
        local opts `"`opts' headershade"' 
    }
    if "`zebra'" != "" {
        local opts `"`opts' zebra"' 
    }
    if "`digits'" != "" {
        local opts `"`opts' digits(`digits')"' 
    }
    if "`boldp'" != "" {
        local opts `"`opts' boldp(`boldp')"' 
    }
    if "`highlight'" != "" {
        local opts `"`opts' highlight(`highlight')"' 
    }
    if "`pdp'" != "" {
        local opts `"`opts' pdp(`pdp')"' 
    }
    if "`highpdp'" != "" {
        local opts `"`opts' highpdp(`highpdp')"' 
    }

    capture program list _tabtools_settings_resolve
    if _rc {
        capture findfile _tabtools_settings.ado
        if _rc exit _rc
        quietly run "`r(fn)'"
    }

    if `"`opts'"' == "" {
        quietly _tabtools_settings_resolve
    }
    else {
        quietly _tabtools_settings_resolve, `opts'
    }

    return local font "`_font'"
    return local fontsize "`_fontsize'"
    return local borderstyle "`_borderstyle'"
    return local hborder "`_hborder'"
    return local headercolor "`_headercolor'"
    return local zebracolor "`_zebracolor'"
    return local headershade "`_headershade'"
    return local zebra "`_zebra'"
    return local digits "`_digits'"
    return local boldp "`_boldp'"
    return local highlight "`_highlight'"
    return local pdp "`_pdp'"
    return local highpdp "`_highpdp'"
end

capture program drop _tt_phase1_guard_error
program define _tt_phase1_guard_error
    version 16.0
    _tabtools_guard enter
    capture noisily {
        error 198
    }
    local rc = _rc
    _tabtools_guard exit, rc(`rc')
end

* =========================================================================
**# Settings helper
* =========================================================================

local ++test_count
if !`settings_src' {
    display as text "  SKIP: P1 settings helper not present in source tree"
    local ++skip_count
}
else if !`settings_installed' {
    display as text "  SKIP: P1 settings helper exists in source but is not install-discoverable yet"
    local ++skip_count
}
else {
    display as result "  PASS: P1 settings helper is discoverable after install"
    local ++pass_count
}

local ++test_count
if !`settings_installed' {
    display as text "  SKIP: P1 settings globals-only contract pending helper availability"
    local ++skip_count
}
else {
    capture noisily {
        tabtools set clear
        global TABTOOLS_FONT "Calibri"
        global TABTOOLS_FONTSIZE 14
        global TABTOOLS_BORDER "thin"
        global TABTOOLS_HEADERCOLOR "10 20 30"
        global TABTOOLS_ZEBRACOLOR "40 50 60"
        global TABTOOLS_DIGITS 4
        global TABTOOLS_BOLDP 0.1

        _tt_phase1_settings_probe

        assert "`r(font)'" == "Calibri"
        assert "`r(fontsize)'" == "14"
        assert "`r(borderstyle)'" == "thin"
        assert "`r(headercolor)'" == "10 20 30"
        assert "`r(zebracolor)'" == "40 50 60"
        assert real("`r(digits)'") == 4
        assert abs(real("`r(boldp)'") - 0.1) < 1e-12
    }
    if _rc == 0 {
        display as result "  PASS: P1 settings helper resolves globals-only values"
        local ++pass_count
        local settings_helper_ok = 1
    }
    else {
        display as error "  FAIL: P1 settings helper globals-only resolution (rc=`=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' settings_globals"
    }
}
tabtools set clear

local ++test_count
if !`settings_installed' {
    display as text "  SKIP: P1 settings theme-precedence contract pending helper availability"
    local ++skip_count
}
else if !`settings_helper_ok' {
    display as text "  SKIP: P1 settings theme-precedence blocked by helper load/resolve failure"
    local ++skip_count
}
else {
    capture noisily {
        tabtools set clear
        global TABTOOLS_FONT "Courier New"
        global TABTOOLS_FONTSIZE 18
        global TABTOOLS_BORDER "thin"

        _tt_phase1_settings_probe, theme(nejm)

        assert "`r(font)'" == "Arial"
        assert "`r(fontsize)'" == "10"
        assert "`r(borderstyle)'" == "academic"
    }
    if _rc == 0 {
        display as result "  PASS: P1 settings helper lets theme override global formatting"
        local ++pass_count
    }
    else {
        display as error "  FAIL: P1 settings helper theme/global precedence (rc=`=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' settings_theme"
    }
}
tabtools set clear

local ++test_count
if !`settings_installed' {
    display as text "  SKIP: P1 settings explicit-option contract pending helper availability"
    local ++skip_count
}
else if !`settings_helper_ok' {
    display as text "  SKIP: P1 settings explicit-option contract blocked by helper load/resolve failure"
    local ++skip_count
}
else {
    capture noisily {
        tabtools set clear
        global TABTOOLS_BORDER "academic"
        global TABTOOLS_HEADERCOLOR "99 99 99"
        global TABTOOLS_ZEBRACOLOR "88 88 88"
        global TABTOOLS_DIGITS 1
        global TABTOOLS_BOLDP 0.2

        _tt_phase1_settings_probe, theme(nejm) borderstyle(medium) ///
            headercolor("1 2 3") zebracolor("4 5 6") digits(3) ///
            boldp(0.05) highlight(0.01)

        assert "`r(borderstyle)'" == "medium"
        assert "`r(headercolor)'" == "1 2 3"
        assert "`r(zebracolor)'" == "4 5 6"
        assert real("`r(digits)'") == 3
        assert abs(real("`r(boldp)'") - 0.05) < 1e-12
        assert abs(real("`r(highlight)'") - 0.01) < 1e-12
    }
    if _rc == 0 {
        display as result "  PASS: P1 settings helper lets explicit options override theme/global state"
        local ++pass_count
    }
    else {
        display as error "  FAIL: P1 settings helper explicit-option precedence (rc=`=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' settings_explicit"
    }
}
tabtools set clear

* =========================================================================
**# Guard helper
* =========================================================================

local ++test_count
if !`guard_src' {
    display as text "  SKIP: P1 guard helper not present in source tree"
    local ++skip_count
}
else if !`guard_installed' {
    display as text "  SKIP: P1 guard helper exists in source but is not install-discoverable yet"
    local ++skip_count
}
else {
    display as result "  PASS: P1 guard helper is discoverable after install"
    local ++pass_count
}

local ++test_count
if !`guard_installed' {
    display as text "  SKIP: P1 guard enter/exit contract pending helper availability"
    local ++skip_count
}
else {
    capture noisily {
        capture program drop _tabtools_validate_path
        set varabbrev on
        _tabtools_guard enter
        assert c(varabbrev) == "off"
        _tabtools_validate_path "phase1.xlsx" "xlsx()"
        _tabtools_guard exit, rc(0)
        assert c(varabbrev) == "on"
        assert "$TABTOOLS_GUARD_VARABBREV" == ""
        assert "$TABTOOLS_GUARD_DATAFILE" == ""
    }
    if _rc == 0 {
        display as result "  PASS: P1 guard enter/exit restores varabbrev and auto-loads helpers"
        local ++pass_count
        local guard_wrapper_ok = 1
    }
    else {
        display as error "  FAIL: P1 guard enter/exit contract (rc=`=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' guard_enter_exit"
    }
}

local ++test_count
if !`guard_installed' {
    display as text "  SKIP: P1 guard savedata contract pending helper availability"
    local ++skip_count
}
else if !`guard_wrapper_ok' {
    display as text "  SKIP: P1 guard savedata contract blocked by guard entry/exit failure"
    local ++skip_count
}
else {
    capture noisily {
        clear
        input byte x
        1
        2
        3
        end

        _tabtools_guard enter, savedata
        assert "$TABTOOLS_GUARD_DATAFILE" != ""
        confirm file "$TABTOOLS_GUARD_DATAFILE"

        drop _all
        use "$TABTOOLS_GUARD_DATAFILE", clear
        assert _N == 3
        assert x[1] == 1
        assert x[3] == 3

        _tabtools_guard exit, rc(0)
        assert "$TABTOOLS_GUARD_DATAFILE" == ""
    }
    if _rc == 0 {
        display as result "  PASS: P1 guard savedata() captures a restorable tempfile"
        local ++pass_count
    }
    else {
        display as error "  FAIL: P1 guard savedata() contract (rc=`=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' guard_savedata"
    }
}

local ++test_count
if !`guard_installed' {
    display as text "  SKIP: P1 guard rc-propagation contract pending helper availability"
    local ++skip_count
}
else if !`guard_wrapper_ok' {
    display as text "  SKIP: P1 guard rc-propagation contract blocked by guard entry/exit failure"
    local ++skip_count
}
else {
    capture noisily {
        set varabbrev on
        capture noisily _tt_phase1_guard_error
        assert _rc == 198
        assert c(varabbrev) == "on"
        assert "$TABTOOLS_GUARD_VARABBREV" == ""
        assert "$TABTOOLS_GUARD_DATAFILE" == ""
    }
    if _rc == 0 {
        display as result "  PASS: P1 guard exit propagates rc and clears globals"
        local ++pass_count
    }
    else {
        display as error "  FAIL: P1 guard rc propagation/cleanup (rc=`=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' guard_rc"
    }
}

display _newline as result "=== Refactor Phase 1 QA: `pass_count' passed, `fail_count' failed, `skip_count' skipped out of `test_count' ==="
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    exit 1
}

log close _refactor_phase1
