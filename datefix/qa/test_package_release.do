*! test_package_release.do — installed, documentation, and demo contracts
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
set varabbrev off
version 16.0

capture log close _all

capture program drop _datefix_sthlp_render
program define _datefix_sthlp_render, rclass
    version 16.0
    syntax anything(name=files id="help files")

    local files = subinstr(`"`files'"', char(34), "", .)
    local nbad = 0
    local badfiles ""

    foreach f of local files {
        capture confirm file "`f'"
        if _rc {
            display as error "  render: file not found: `f'"
            local ++nbad
            local badfiles "`badfiles' `f'"
            continue
        }

        tempfile rlog
        capture log off
        log using "`rlog'", replace text name(_qarender)
        type "`f'", smcl
        log close _qarender
        capture log on

        local hits = 0
        local nlines = 0
        tempname fh
        file open `fh' using "`rlog'", read text
        file read `fh' line
        while r(eof) == 0 {
            local ++nlines
            if regexm(`"`line'"', "\{(pstd|phang|pmore|pin|p_end|psee|synopt|p2col|cmd:|it:|bf:|opt |opth |helpb |hline|title:|marker |dlgtab:|break)") {
                local shown = subinstr(`"`line'"', "{", char(1), .)
                local shown = subinstr(`"`shown'"', "}", char(2), .)
                local shown = subinstr(`"`shown'"', char(1), "{c -(}", .)
                local shown = subinstr(`"`shown'"', char(2), "{c )-}", .)
                display as error "  literal SMCL: `shown'"
                local ++hits
            }
            file read `fh' line
        }
        file close `fh'

        if `nlines' == 0 {
            display as error "  render produced no output for `f'"
            local ++nbad
            local badfiles "`badfiles' `f'"
            continue
        }
        if `hits' > 0 {
            local ++nbad
            local badfiles "`badfiles' `f'"
        }
    }

    return scalar nbad = `nbad'
    return local badfiles "`badfiles'"
end

local qa_dir "`c(pwd)'"
do "`qa_dir'/_datefix_qa_common.do"
quietly _datefix_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Fresh-install command, help, and helper-dependent path

local ++test_count
capture noisily {
    which datefix
    findfile datefix.sthlp
    clear
    input str12 datestr
    "2020/01/15"
    "not-a-date"
    end
    capture noisily datefix datestr, order(YMD) diagnose
    assert _rc == 198
    confirm string variable datestr
}
if _rc == 0 {
    display as result "  PASS: fresh install resolves command, help, and diagnostic helper"
    local ++pass_count
}
else {
    display as error "  FAIL: fresh-install surface (error `=_rc')"
    local ++fail_count
}

**# Help-file render axis, with positive control

local ++test_count
capture noisily {
    local sthlps : dir "`pkg_dir'" files "*.sthlp"
    local paths ""
    foreach s of local sthlps {
        local paths "`paths' `pkg_dir'/`s'"
    }
    _datefix_sthlp_render `paths'
    assert r(nbad) == 0

    tempfile brokenbase
    local broken "`brokenbase'.sthlp"
    tempname bfh
    file open `bfh' using "`broken'", write replace text
    file write `bfh' "{smcl}" _n
    file write `bfh' "{title:Render probe}" _n _n
    file write `bfh' "{pstd}" _n
    file write `bfh' "A directive split across a source newline: {bf:broken" _n
    file write `bfh' "directive} renders as literal markup." _n
    file close `bfh'
    _datefix_sthlp_render `broken'
    assert r(nbad) == 1
}
if _rc == 0 {
    display as result "  PASS: shipped help renders cleanly and the oracle fails closed"
    local ++pass_count
}
else {
    local test_rc = _rc
    capture log close _qarender
    display as error "  FAIL: help render gate (error `test_rc')"
    local ++fail_count
}

**# Help examples are self-contained and executable

local ++test_count
capture noisily {
    local found_setup = 0
    local shown_commands = 0
    tempname hfh
    file open `hfh' using "`pkg_dir'/datefix.sthlp", read text
    file read `hfh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "input str10 dob") local found_setup = 1
        if strpos(`"`line'"', ". datefix") local ++shown_commands
        file read `hfh' line
    }
    file close `hfh'
    assert `found_setup' == 1
    assert `shown_commands' == 5

    clear
    input str10 dob str10 dod str10 visit_date str8 city_founded str10 admission_date
    "2020-01-15" "2024-03-01" "03/14/2020" "07/04/76" "15/06/2024"
    "1990-12-31" "2024-07-04" "11/03/2023" "11/12/84" "01/01/2025"
    end
    datefix dob dod, order(YMD)
    datefix visit_date, newvar(vdate) order(MDY) df(%tdMonth_DD,_CCYY)
    datefix city_founded, order(MDY) topyear(1900)
    datefix admission_date, newvar(admit_dt) drop order(DMY) df(%tdDD/NN/CCYY)
    generate str12 invalid_date = cond(_n == 1, "2020/00/15", "not-a-date")
    capture noisily datefix invalid_date, order(YMD) diagnose
    assert _rc == 198
    assert dob[1] == mdy(1, 15, 2020)
    assert dod[2] == mdy(7, 4, 2024)
    assert vdate[1] == mdy(3, 14, 2020)
    assert city_founded[1] == mdy(7, 4, 1876)
    assert admit_dt[1] == mdy(6, 15, 2024)
}
if _rc == 0 {
    display as result "  PASS: help examples carry and satisfy their own setup"
    local ++pass_count
}
else {
    display as error "  FAIL: help example contract (error `=_rc')"
    local ++fail_count
}

**# Demo installs local source and runs from the repository root

local ++test_count
capture noisily {
    local found_install = 0
    local found_source_run = 0
    tempname dfh
    file open `dfh' using "`pkg_dir'/demo/demo_datefix.do", read text
    file read `dfh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "net install datefix") local found_install = 1
        if strpos(`"`line'"', "run datefix/datefix.ado") local found_source_run = 1
        file read `dfh' line
    }
    file close `dfh'

    local slash = strrpos("`pkg_dir'", "/")
    local repo_dir = substr("`pkg_dir'", 1, `slash' - 1)
    cd "`repo_dir'"
    capture noisily do "datefix/demo/demo_datefix.do"
    local demo_rc = _rc
    capture log close demo
    cd "`qa_dir'"
    capture erase "`pkg_dir'/demo/console_output.log"
    assert `demo_rc' == 0
    assert `found_install' == 1
    assert `found_source_run' == 0
}
if _rc == 0 {
    display as result "  PASS: demo exercises a local install from the repository root"
    local ++pass_count
}
else {
    local test_rc = _rc
    capture log close demo
    capture cd "`qa_dir'"
    capture erase "`pkg_dir'/demo/console_output.log"
    display as error "  FAIL: installed-user demo contract (error `test_rc')"
    local ++fail_count
}

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_package_release tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
