* test_v169_regressions.do -- regressions and release-surface gates for psdash 1.6.9
* Usage: cd psdash/qa && stata-mp -b do test_v169_regressions.do

clear all
version 16.0
set varabbrev off

capture log close _all
log using "test_v169_regressions.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"
discard

global V169_TEST_COUNT = 0
global V169_PASS_COUNT = 0
global V169_FAIL_COUNT = 0
global V169_FAILED_TESTS ""

capture program drop _v169_result
program define _v169_result, nclass
    version 16.0
    args test_id rc
    global V169_TEST_COUNT = $V169_TEST_COUNT + 1
    if `rc' == 0 {
        display as result "PASS: `test_id'"
        global V169_PASS_COUNT = $V169_PASS_COUNT + 1
    }
    else {
        display as error "FAIL: `test_id' (rc=`rc')"
        global V169_FAIL_COUNT = $V169_FAIL_COUNT + 1
        global V169_FAILED_TESTS "$V169_FAILED_TESTS `test_id'"
    }
end

capture program drop _v169_binary_data
program define _v169_binary_data, nclass
    version 16.0
    clear
    set obs 60
    generate byte treat = _n > 30
    generate double ps = cond(treat, 0.55 + (_n - 31) / 500, ///
        0.35 + (_n - 1) / 500)
end

capture program drop _v169_multigroup_data
program define _v169_multigroup_data, nclass
    version 16.0
    clear
    set obs 60
    generate byte arm = mod(_n - 1, 3)
    generate double p0 = 0.25 + mod(_n, 5) / 100
    generate double p1 = 0.30 + mod(_n, 7) / 100
    generate double p2 = 1 - p0 - p1
end

capture program drop _v169_render_help
program define _v169_render_help, rclass
    version 16.0
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
        log using "`rlog'", replace text name(_v169render)
        type "`f'", smcl
        log close _v169render
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

**# Global state restoration

capture noisily {
    set varabbrev on
    psdash
    assert "`c(varabbrev)'" == "on"
}
local state_rc = _rc
set varabbrev off
_v169_result "dispatcher_overview_restores_varabbrev" `state_rc'

capture noisily {
    _v169_binary_data
    generate byte use = 1
    set varabbrev on
    _psdash_detect treat ps, samplevar(use)
    assert "`c(varabbrev)'" == "on"
    assert "`_psd_treatment'" == "treat"
    assert "`_psd_psvar'" == "ps"
}
local state_rc = _rc
set varabbrev off
_v169_result "detect_helper_restores_varabbrev" `state_rc'

**# Option contract

capture noisily {
    _v169_binary_data
    capture noisily psdash support treat ps, compare nograph
    assert _rc == 198
}
_v169_result "compare_requires_binary_trimming" `=_rc'

**# Excel string round-trips

local wanted_title `"Reviewer "quoted" title"'

capture noisily {
    _v169_binary_data
    local book "`_qa_sysroot'/overlap_binary_quote.xlsx"
    psdash overlap treat ps, nograph xlsx("`book'") ///
        title(`"`wanted_title'"')
    import excel using "`book'", sheet("Overlap") clear
    assert `"`=A[1]'"' == `"`wanted_title'"'
}
_v169_result "overlap_binary_title_quote_roundtrip" `=_rc'

capture noisily {
    _v169_multigroup_data
    local book "`_qa_sysroot'/overlap_multigroup_quote.xlsx"
    psdash overlap arm, psvars(p0 p1 p2) nograph xlsx("`book'") ///
        title(`"`wanted_title'"')
    import excel using "`book'", sheet("Overlap") clear
    assert `"`=A[1]'"' == `"`wanted_title'"'
}
_v169_result "overlap_multigroup_title_quote_roundtrip" `=_rc'

capture noisily {
    _v169_binary_data
    local book "`_qa_sysroot'/support_binary_quote.xlsx"
    psdash support treat ps, nograph xlsx("`book'") ///
        title(`"`wanted_title'"')
    import excel using "`book'", sheet("Support") clear
    assert `"`=A[1]'"' == `"`wanted_title'"'
}
_v169_result "support_binary_title_quote_roundtrip" `=_rc'

capture noisily {
    _v169_multigroup_data
    local book "`_qa_sysroot'/support_multigroup_quote.xlsx"
    psdash support arm, psvars(p0 p1 p2) nograph xlsx("`book'") ///
        title(`"`wanted_title'"')
    import excel using "`book'", sheet("Support") clear
    assert `"`=A[1]'"' == `"`wanted_title'"'
}
_v169_result "support_multigroup_title_quote_roundtrip" `=_rc'

**# Program-class contracts

capture noisily {
    local classes `"`classes' _psdash_detect.ado:_psdash_detect"'
    local classes `"`classes' _psdash_export_balance.ado:_psdash_export_balance"'
    local classes `"`classes' _psdash_export_kv.ado:_psdash_export_kv"'
    local classes `"`classes' _psdash_graph_export.ado:_psdash_graph_export"'
    local classes `"`classes' _psdash_strip_fv.ado:_psdash_strip_fv"'
    local classes `"`classes' _psdash_validate_levels.ado:_psdash_validate_levels"'
    local classes `"`classes' _psdash_validate_path.ado:_psdash_validate_path"'
    local classes `"`classes' _psdash_verify_producer.ado:_psdash_verify_producer"'
    local classes `"`classes' psdash.ado:_psdash_overview"'
    foreach spec of local classes {
        gettoken file program : spec, parse(":")
        local program = substr("`program'", 2, .)
        assert strpos(fileread("`pkg_dir'/`file'"), ///
            "program define `program', nclass") > 0
    }
}
_v169_result "internal_programs_declare_nclass" `=_rc'

**# Released help render gate

capture noisily {
    local help_files : dir "`pkg_dir'" files "*.sthlp"
    local help_paths ""
    foreach help_file of local help_files {
        local help_paths "`help_paths' `pkg_dir'/`help_file'"
    }
    _v169_render_help `help_paths'
    assert r(nbad) == 0
}
_v169_result "all_shipped_help_renders_cleanly" `=_rc'

capture noisily {
    local broken "`_qa_sysroot'/broken_render_probe.sthlp"
    tempname bfh
    file open `bfh' using "`broken'", write replace text
    file write `bfh' "{smcl}" _n
    file write `bfh' "{title:Render probe}" _n _n
    file write `bfh' "{pstd}" _n
    file write `bfh' "A directive split across a source newline: {bf:broken" _n
    file write `bfh' "directive} renders as literal markup." _n
    file close `bfh'
    _v169_render_help `broken'
    assert r(nbad) == 1
}
_v169_result "help_render_oracle_positive_control" `=_rc'

**# Summary

display as text "RESULT: test_v169_regressions tests=$V169_TEST_COUNT pass=$V169_PASS_COUNT fail=$V169_FAIL_COUNT skip=0"

_psdash_qa_cleanup
capture log close _all

if $V169_FAIL_COUNT > 0 {
    display as error "Failed tests:$V169_FAILED_TESTS"
    macro drop V169_TEST_COUNT V169_PASS_COUNT V169_FAIL_COUNT V169_FAILED_TESTS
    exit 9
}
macro drop V169_TEST_COUNT V169_PASS_COUNT V169_FAIL_COUNT V169_FAILED_TESTS
