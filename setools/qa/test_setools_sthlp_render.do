*! test_setools_sthlp_render.do  1.0.0  2026/08/30
*! Self-contained Viewer-render and synopt-width gates for shipped help.

version 16.0
capture log close _all

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
do "`qa_dir'/_setools_qa_common.do" setup "`pkg_dir'"

local tests = 0
local pass = 0
local fail = 0

* Render through Stata's own SMCL interpreter and reject literal markup.
capture program drop _setools_qa_sthlp_render
program define _setools_qa_sthlp_render, rclass
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

        if `nlines' == 0 | `hits' > 0 {
            local ++nbad
            local badfiles "`badfiles' `f'"
        }
    }

    return scalar nbad = `nbad'
    return local badfiles "`badfiles'"
end

* Measure each rendered synopt description against its active Viewer column.
capture program drop _setools_qa_synopt_width
program define _setools_qa_synopt_width, rclass
    version 16.0
    syntax, SRC(string)

    tempname fh
    local nbad = 0
    local nrow = 0
    local width = 20
    local lineno = 0

    file open `fh' using "`src'", read text
    file read `fh' line
    while r(eof) == 0 {
        local ++lineno
        if regexm(`"`macval(line)'"', "\{synoptset +([0-9]+)") ///
            local width = real(regexs(1))

        if regexm(`"`macval(line)'"', "^\{synopt:") {
            local ++nrow
            local desc `"`macval(line)'"'
            local desc = regexr(`"`macval(desc)'"', "^\{synopt:", "")
            local guard = 0
            while regexm(`"`macval(desc)'"', "\{[a-zA-Z_][^:{}]*:([^{}]*)\}") & `guard' < 40 {
                local ++guard
                local desc = regexr(`"`macval(desc)'"', ///
                    "\{[a-zA-Z_][^:{}]*:([^{}]*)\}", "`=regexs(1)'")
            }
            local guard = 0
            while regexm(`"`macval(desc)'"', "\{[^{}]*\}") & `guard' < 40 {
                local ++guard
                local desc = regexr(`"`macval(desc)'"', "\{[^{}]*\}", "")
            }
            local split = strpos(`"`macval(desc)'"', "}")
            if `split' > 0 local desc = substr(`"`macval(desc)'"', `split' + 1, .)
            local rendered_len = length(`"`macval(desc)'"')
            local cap = 71 - `width'
            if `rendered_len' > `cap' {
                local ++nbad
                display as error "  `src':`lineno' synopt description `rendered_len' > `cap'"
            }
        }
        file read `fh' line
    }
    file close `fh'

    return scalar nbad = `nbad'
    return scalar nrow = `nrow'
end

* All shipped help files render without literal SMCL.
local ++tests
capture noisily {
    local help_files : dir "`pkg_dir'" files "*.sthlp"
    local help_paths ""
    foreach help_file of local help_files {
        local help_paths "`help_paths' `pkg_dir'/`help_file'"
    }
    _setools_qa_sthlp_render `help_paths'
    assert r(nbad) == 0
}
if _rc == 0 local ++pass
else local ++fail

* The literal-render oracle must detect a deliberately split directive.
local ++tests
capture noisily {
    tempfile broken
    tempname bfh
    file open `bfh' using "`broken'", write replace text
    file write `bfh' "{smcl}" _n
    file write `bfh' "{title:Render probe}" _n _n
    file write `bfh' "{pstd}" _n
    file write `bfh' "A directive split across a source newline: {bf:broken" _n
    file write `bfh' "directive} renders as literal markup." _n
    file close `bfh'
    quietly _setools_qa_sthlp_render `broken'
    assert r(nbad) == 1
}
if _rc == 0 local ++pass
else local ++fail

* Every synopt description must fit its active Viewer column.
local ++tests
capture noisily {
    local help_files : dir "`pkg_dir'" files "*.sthlp"
    local total_bad = 0
    local total_rows = 0
    foreach help_file of local help_files {
        _setools_qa_synopt_width, src("`pkg_dir'/`help_file'")
        local total_bad = `total_bad' + r(nbad)
        local total_rows = `total_rows' + r(nrow)
    }
    assert `total_rows' > 50
    assert `total_bad' == 0
}
if _rc == 0 local ++pass
else local ++fail

* The width gate must distinguish the exact boundary from overflowing rows.
local ++tests
capture noisily {
    tempfile width_probe
    tempname wfh
    file open `wfh' using "`width_probe'", write replace text
    file write `wfh' "{smcl}" _n
    file write `wfh' "{synoptset 20 tabbed}{...}" _n
    file write `wfh' "{synopt:{cmd:r(ok)}}123456789012345678901234567890123456789012345678901{p_end}" _n
    file write `wfh' "{synopt:{cmd:r(bad)}}1234567890123456789012345678901234567890123456789012{p_end}" _n
    file write `wfh' "{synopt:{cmd:r(markup)}}1234567890123456789012345678901234567890123456 {cmd:fweight}{p_end}" _n
    file close `wfh'
    quietly _setools_qa_synopt_width, src("`width_probe'")
    assert r(nrow) == 3
    assert r(nbad) == 2
}
if _rc == 0 local ++pass
else local ++fail

display "RESULT: test_setools_sthlp_render tests=`tests' pass=`pass' fail=`fail'"

do "`qa_dir'/_setools_qa_common.do" teardown
if `fail' exit 1
