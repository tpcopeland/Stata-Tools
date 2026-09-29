* Help render contract, 2026-09-29
* Author: Timothy P Copeland, Karolinska Institutet
version 16.0
local pkg_dir "`c(pwd)'/.."
capture ado uninstall consort
quietly net install consort, from("`pkg_dir'") replace
capture program drop _qa_sthlp_render
program define _qa_sthlp_render, rclass
    version 16.0
    syntax anything(name=files id="help files")

    * Tolerate a quoted list. `anything' keeps the surrounding quotes, so a
    * quoted call collapses the whole space-separated list into one filename;
    * the program then reports "file not found" and fails closed. Failing
    * closed is right, but it means the render never ran.
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
        * Pause the enclosing QA log, render into a private named log, resume.
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
                * Park the braces on control chars first: the SMCL escapes
                * {c -(} and {c )-} themselves contain braces, so substituting
                * them in place corrupts each other. Without this, `display`
                * renders the markup away and the log shows a line that looks
                * perfectly fine -- hiding the very defect being reported.
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

        * An oracle that did not run must never read as clean.
        if `nlines' == 0 {
            display as error "  render produced no output for `f' -- FAILING"
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
local pass_count 0
local fail_count 0
capture noisily {
    _qa_sthlp_render ../consort.sthlp
    assert r(nbad) == 0
    tempfile broken
    tempname fh
    file open `fh' using "`broken'", write replace text
    file write `fh' "{smcl}" _n "{pstd}" _n "{bf:broken" _n "directive}" _n
    file close `fh'
    _qa_sthlp_render `broken'
    assert r(nbad) == 1
}
if _rc local ++fail_count
else local ++pass_count
display "RESULT: test_consort_help tests=1 pass=`pass_count' fail=`fail_count'"
if `fail_count' exit 1
