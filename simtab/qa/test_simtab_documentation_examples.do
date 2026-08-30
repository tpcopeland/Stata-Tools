*! test_simtab_documentation_examples.do - executable help examples and SMCL render gate
version 17.0
clear all
set varabbrev off
capture log close _all
log using "test_simtab_documentation_examples.log", replace text name(simtab_docs)

local tests = 0
local pass = 0
local fail = 0
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local example_xlsx "simulation.xlsx"
capture erase "`example_xlsx'"
capture ado uninstall simtab
quietly net install simtab, from("`pkg_dir'") replace

* Compute-mode example: this block mirrors the visible help example.
local ++tests
capture noisily {
    clear
    set obs 40
    gen long sim = ceil(_n / 2)
    bysort sim: gen byte method = _n
    gen double true_value = 0
    gen double estimate = cond(method == 1, 0, .05) + (sim - 10.5) / 100
    gen double se = .10
    capture frame drop sim_plot
    simtab method, estimate(estimate) se(se) true(true_value) sim(sim) ///
        metrics(mean bias empse meanse coverage n) ///
        plotframe(sim_plot, replace) display
    assert r(N_input) == 40
    assert r(N_cells) == 2
    frame sim_plot: assert _N == 2
    simtab method, estimate(estimate) se(se) true(true_value) sim(sim) ///
        metrics(mean bias empse meanse coverage n) ///
        xlsx("simulation.xlsx") sheet("Performance") theme(nejm)
    confirm file "simulation.xlsx"
}
if _rc == 0 local ++pass
else local ++fail
capture frame drop sim_plot
capture erase "`example_xlsx'"

* Summary-mode example: this block mirrors the visible help example.
local ++tests
capture noisily {
    clear
    input str8 method double(mean bias empse meanse coverage n)
    "Method A" 0.01  0.01 0.10 0.11 0.94 500
    "Method B" 0.03  0.03 0.12 0.13 0.91 500
    end
    simtab, from(summary) estimatorvar(method) ///
        measures(mean=mean bias=bias empse=empse meanse=meanse ///
            coverage=coverage n=n) display
    assert r(N_cells) == 2
    assert "`r(source)'" == "summary"
}
if _rc == 0 local ++pass
else local ++fail

* Render help through Stata's SMCL interpreter and fail on literal markup.
capture program drop _qa_sthlp_render
program define _qa_sthlp_render, rclass
    version 17.0
    syntax anything(name=files id="help files")
    local files = subinstr(`"`files'"', char(34), "", .)
    local nbad 0
    local badfiles ""
    foreach f of local files {
        capture confirm file "`f'"
        if _rc {
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

local ++tests
capture noisily {
    _qa_sthlp_render "`pkg_dir'/simtab.sthlp"
    assert r(nbad) == 0

    tempfile broken
    local broken "`broken'.sthlp"
    tempname bfh
    file open `bfh' using "`broken'", write replace text
    file write `bfh' "{smcl}" _n
    file write `bfh' "{title:Render probe}" _n _n
    file write `bfh' "{pstd}" _n
    file write `bfh' "A directive split across a source newline: {bf:broken" _n
    file write `bfh' "directive} renders as literal markup." _n
    file close `bfh'
    _qa_sthlp_render "`broken'"
    assert r(nbad) == 1
}
if _rc == 0 local ++pass
else local ++fail

display "RESULT: test_simtab_documentation_examples tests=`tests' pass=`pass' fail=`fail'"
log close simtab_docs
if `fail' exit 9
