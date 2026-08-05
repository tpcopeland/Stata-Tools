* test_help_render.do - Render-axis QA for every shipped datamap help file.

clear all
version 16.0
set varabbrev off

capture log close _all
log using "test_help_render.log", replace text nomsg name(help_render)

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

local test_count = 0
local pass_count = 0
local fail_count = 0

* qa-hygiene: no-package-code

capture program drop _datamap_sthlp_render
program define _datamap_sthlp_render, rclass
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

        tempfile render_log
        capture log off
        log using "`render_log'", replace text name(_datamap_render)
        type "`f'", smcl
        log close _datamap_render
        capture log on

        local hits = 0
        local nlines = 0
        tempname fh
        file open `fh' using "`render_log'", read text
        file read `fh' line
        while r(eof) == 0 {
            local ++nlines
            if regexm(`"`line'"', "\{(pstd|phang|pmore|pin|p_end|psee|synopt|p2col|cmd:|it:|bf:|opt |opth |helpb |hline|title:|marker |dlgtab:|break)") {
                local shown = subinstr(`"`line'"', "{", char(1), .)
                local shown = subinstr(`"`shown'"', "}", char(2), .)
                local shown = subinstr(`"`shown'"', char(1), "{c -(}", .)
                local shown = subinstr(`"`shown'"', char(2), "{c )-}", .)
                display as error "  literal SMCL in `f': `shown'"
                local ++hits
            }
            file read `fh' line
        }
        file close `fh'

        if `nlines' == 0 | `hits' > 0 {
            local ++nbad
            local badfiles "`badfiles' `f'"
        }
    }

    return scalar nbad = `nbad'
    return local badfiles "`badfiles'"
end

* T1: every shipped help file renders without literal SMCL.
local ++test_count
capture noisily {
    local sthlps : dir "`pkg_dir'" files "*.sthlp"
    local paths ""
    foreach sthlp of local sthlps {
        local paths "`paths' `pkg_dir'/`sthlp'"
    }
    local n_sthlp : word count `sthlps'
    assert `n_sthlp' == 4
    _datamap_sthlp_render `paths'
    assert r(nbad) == 0
}
if _rc == 0 {
    display as result "  PASS: all four help files render cleanly"
    local ++pass_count
}
else {
    display as error "  FAIL: shipped help render oracle (rc=`=_rc')"
    local ++fail_count
}

* T2: a deliberately split directive is detected.
local ++test_count
capture noisily {
    tempfile broken_help
    tempname broken_fh
    file open `broken_fh' using "`broken_help'", write text replace
    file write `broken_fh' "{smcl}" _n
    file write `broken_fh' "{title:Render probe}" _n _n
    file write `broken_fh' "{pstd}" _n
    file write `broken_fh' "A directive split across a source newline: {bf:broken" _n
    file write `broken_fh' "directive} renders as literal markup." _n
    file close `broken_fh'
    _datamap_sthlp_render `broken_help'
    assert r(nbad) == 1
}
if _rc == 0 {
    display as result "  PASS: broken-SMCL positive control is detected"
    local ++pass_count
}
else {
    display as error "  FAIL: broken-SMCL positive control (rc=`=_rc')"
    local ++fail_count
}

display "RESULT: test_help_render tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close help_render
if `fail_count' > 0 exit 1
