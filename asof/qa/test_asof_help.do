*! test_asof_help.do - Installed help-render and synopsis-layout contracts
*! Author: Timothy P Copeland, Karolinska Institutet
*! Requires: Stata 16.0+

clear all
set processors 1
set varabbrev off
version 16.0

capture log close _all
log using "test_asof_help.log", replace text nomsg
global ASOF_QA_STATUS "fail"

do "_asof_qa_common.do"
quietly _asof_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _asof_qa_sthlp_render
program define _asof_qa_sthlp_render, rclass
    version 16.0
    syntax anything(name=files id="help files")

    local files = subinstr(`"`files'"', char(34), "", .)
    local nbad = 0
    local badfiles ""

    foreach f of local files {
        capture confirm file "`f'"
        if _rc {
            display as error "render: file not found: `f'"
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
                display as error "literal SMCL: `shown'"
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

capture program drop _asof_qa_synopt_width
program define _asof_qa_synopt_width, rclass
    version 16.0
    syntax using/

    local current_width = .
    local nbad = 0
    tempname fh
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        local setpos = strpos(`"`line'"', "{synoptset ")
        if `setpos' > 0 {
            local payload = substr(`"`line'"', ///
                `setpos' + strlen("{synoptset "), .)
            gettoken width remainder : payload
            local current_width = real("`width'")
        }

        if strpos(`"`line'"', "{synopt:") > 0 {
            local descpos = strpos(`"`line'"', "}}")
            local endpos = strpos(`"`line'"', "{p_end}")
            if `descpos' > 0 & `endpos' > `descpos' & ///
                !missing(`current_width') {
                local description = substr(`"`line'"', `descpos' + 2, ///
                    `endpos' - `descpos' - 2)
                local visible `"`description'"'
                foreach tag in cmd it bf {
                    local visible = subinstr(`"`visible'"', "{`tag':", "", .)
                }
                local visible = subinstr(`"`visible'"', "}", "", .)
                local capacity = 71 - `current_width'
                if strlen(`"`visible'"') > `capacity' {
                    display as error "over-wide synopsis: `visible'"
                    local ++nbad
                }
            }
        }
        file read `fh' line
    }
    file close `fh'

    return scalar nbad = `nbad'
end

**# Installed help renders cleanly and the oracle catches broken SMCL
local ++test_count
capture noisily {
    findfile asof.sthlp
    local installed_help `"`r(fn)'"'
    _asof_qa_sthlp_render `installed_help'
    assert r(nbad) == 0

    tempfile broken
    tempname bfh
    file open `bfh' using "`broken'", write replace text
    file write `bfh' "{smcl}" _n
    file write `bfh' "{title:Render probe}" _n _n
    file write `bfh' "{pstd}" _n
    file write `bfh' "A directive split across a source newline: {bf:broken" _n
    file write `bfh' "directive} renders as literal markup." _n
    file close `bfh'
    _asof_qa_sthlp_render `broken'
    assert r(nbad) == 1
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Synopsis descriptions fit their declared Viewer columns
local ++test_count
capture noisily {
    _asof_qa_synopt_width using "`pkg_dir'/asof.sthlp"
    assert r(nbad) == 0
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_asof_help tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 {
    capture log close _all
    exit 1
}
global ASOF_QA_STATUS "pass"
log close _all
