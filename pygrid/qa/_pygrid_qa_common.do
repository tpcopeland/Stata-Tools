*! _pygrid_qa_common.do Version 1.0.1  2026/08/30
*! Shared sandbox, fixtures, assertions, and result accounting for pygrid QA
*! Author: Timothy P Copeland, Karolinska Institutet

version 16.0

capture program drop _pygrid_qa_bootstrap
program define _pygrid_qa_bootstrap
    version 16.0

    * Relocatable: derive the package root from the working directory. Suites
    * are run from <package>/qa/, so never hardcode a machine path.
    local qa_dir "`c(pwd)'"
    local pkg_dir = regexr("`qa_dir'", "/qa$", "")

    * Isolate PLUS/PERSONAL so an installed GitHub or SSC copy earlier in the
    * adopath cannot shadow the local development copy.
    tempfile sysbase
    local plus "`sysbase'_plus"
    local personal "`sysbase'_personal"
    capture mkdir "`plus'"
    capture mkdir "`personal'"
    sysdir set PLUS "`plus'"
    sysdir set PERSONAL "`personal'"

    capture ado uninstall pygrid
    quietly net install pygrid, from("`pkg_dir'") replace
    discard
end

capture program drop _pygrid_result
program define _pygrid_result
    version 16.0
    args name tests pass fail skip

    if "`skip'" == "" local skip = 0

    * A runner that lies about its own totals must not be able to report a
    * green result. qa run hard-fails on this mismatch; catching it here names
    * the suite that drifted.
    if `tests' != `pass' + `fail' + `skip' {
        display as error "RESULT arithmetic mismatch in `name': tests=`tests' but pass+fail+skip=" `pass' + `fail' + `skip'
        display "RESULT: `name' tests=`tests' pass=`pass' fail=`fail' skip=`skip'"
        exit 9
    }

    display as result "Results: `pass'/`tests' passed, `fail' failed, `skip' skipped"
    if `fail' > 0 {
        display as error "SOME TESTS FAILED"
        display "RESULT: `name' tests=`tests' pass=`pass' fail=`fail' skip=`skip'"
        exit 1
    }
    display "RESULT: `name' tests=`tests' pass=`pass' fail=`fail' skip=`skip'"
end

capture program drop _pygrid_record
program define _pygrid_record
    version 16.0
    syntax , RC(integer) NAME(string) TESTS(integer) PASSES(integer) FAILS(integer)

    local ++tests
    if `rc' == 0 {
        local ++passes
        display as result `"  PASS: `name'"'
    }
    else {
        local ++fails
        display as error `"  FAIL: `name' (rc=`rc')"'
    }
    c_local test_count `tests'
    c_local pass_count `passes'
    c_local fail_count `fails'
end

capture program drop _pygrid_assert_data_equal
program define _pygrid_assert_data_equal
    version 16.0
    syntax using/ [, ORDER]

    * cf _all checks only variables present in memory. Compare the exact
    * schema first so a check cannot pass after silently dropping a variable,
    * then compare values and attributes. order additionally pins variable
    * order for rollback and no-mutation contracts.
    tempname compare_frame
    local frame_open = 0
    capture noisily {
        unab current_vars : _all
        frame create `compare_frame'
        local frame_open = 1
        frame `compare_frame': quietly use `using', clear
        frame `compare_frame': unab using_vars : _all
        if "`order'" == "" {
            local current_schema : list sort current_vars
            local using_schema : list sort using_vars
        }
        else {
            local current_schema "`current_vars'"
            local using_schema "`using_vars'"
        }
        assert `"`current_schema'"' == `"`using_schema'"'
        cf `current_vars' using `using', all
    }
    local rc = _rc
    if `frame_open' capture frame drop `compare_frame'
    if `rc' exit `rc'
end

capture program drop _pygrid_make_calendar
program define _pygrid_make_calendar
    version 16.0
    syntax , N(integer) START(real) END(real)

    clear
    quietly set obs `n'
    generate long id = _n
    generate double window_start = `start'
    generate double window_end = `end'
    format window_start window_end %td
end

capture program drop _pygrid_qa_render_help
program define _pygrid_qa_render_help, rclass
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

        tempfile render_log
        capture log off
        log using "`render_log'", replace text name(_pygrid_render)
        type "`f'", smcl
        log close _pygrid_render
        capture log on

        local hits = 0
        local nlines = 0
        tempname fh
        file open `fh' using "`render_log'", read text
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
