clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_package_release.log", replace nomsg

* test_package_release.do - Installed help, render, and terminology contracts

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir  "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
do "`qa_dir'/_raincloud_qa_common.do"
_raincloud_qa_bootstrap "`pkg_dir'"

capture program drop _qa_sthlp_render
program define _qa_sthlp_render, rclass
    version 16.0
    syntax anything(name=files id="help files")

    local files = subinstr(`"`files'"', char(34), "", .)
    local nbad 0
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

        local hits 0
        local nlines 0
        tempname fh
        file open `fh' using "`rlog'", read text
        file read `fh' line
        while r(eof) == 0 {
            local ++nlines
            if regexm(`"`line'"', "\{(pstd|phang|pmore|pin|p_end|psee|synopt|p2col|cmd:|it:|bf:|opt |opth |helpb |hline|title:|marker |dlgtab:|break)") {
                local shown = subinstr(`"`line'"',  "{",     char(1), .)
                local shown = subinstr(`"`shown'"', "}",     char(2), .)
                local shown = subinstr(`"`shown'"', char(1), "{c -(}", .)
                local shown = subinstr(`"`shown'"', char(2), "{c )-}", .)
                display as error "  literal SMCL: `shown'"
                local ++hits
            }
            file read `fh' line
        }
        file close `fh'

        if `nlines' == 0 {
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

**# Installed surface

local ++test_count
capture noisily {
    discard
    which raincloud
    help raincloud
    confirm file "`pkg_dir'/raincloud.ado"
    confirm file "`pkg_dir'/raincloud.sthlp"
}
if _rc == 0 {
    display as result "  PASS: installed command and help resolve"
    local ++pass_count
}
else {
    display as error "  FAIL: installed command and help resolve (error `=_rc')"
    local ++fail_count
}

**# Help render with positive control

local ++test_count
capture noisily {
    local help_path "`pkg_dir'/raincloud.sthlp"
    _qa_sthlp_render `help_path'
    assert r(nbad) == 0

    tempfile broken_seed
    local broken "`broken_seed'.sthlp"
    tempname bfh
    file open `bfh' using "`broken'", write replace text
    file write `bfh' "{smcl}" _n
    file write `bfh' "{title:Render probe}" _n _n
    file write `bfh' "{pstd}" _n
    file write `bfh' "A directive split across a source newline: {bf:broken" _n
    file write `bfh' "directive} renders as literal markup." _n
    file close `bfh'
    _qa_sthlp_render `broken'
    assert r(nbad) == 1
    erase "`broken'"
}
if _rc == 0 {
    display as result "  PASS: help render oracle is clean and positive control fires"
    local ++pass_count
}
else {
    display as error "  FAIL: help render oracle is clean and positive control fires (error `=_rc')"
    local ++fail_count
}

**# Mirror terminology matches the cited construction

local ++test_count
capture noisily {
    local found_full 0
    local found_split 0
    foreach doc in "`pkg_dir'/raincloud.sthlp" {
        tempname dfh
        file open `dfh' using "`doc'", read text
        file read `dfh' line
        while r(eof) == 0 {
            local noquotes = subinstr(`"`macval(line)'"', char(34), "", .)
            local lower = lower("`noquotes'")
            if strpos(`"`lower'"', "full mirrored violin") > 0 local found_full = 1
            if strpos(`"`lower'"', "split violin") > 0 local found_split = 1
            file read `dfh' line
        }
        file close `dfh'
    }
    assert `found_full' == 1
    assert `found_split' == 0
}
if _rc == 0 {
    display as result "  PASS: mirror() is documented as a full mirrored violin"
    local ++pass_count
}
else {
    display as error "  FAIL: mirror() is documented as a full mirrored violin (error `=_rc')"
    local ++fail_count
}

**# Summary

local suite_rc = cond(`fail_count' > 0, 1, 0)
display "RESULT: test_package_release tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
exit `suite_rc'
