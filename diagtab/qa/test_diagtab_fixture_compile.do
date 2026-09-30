*! test_diagtab_fixture_compile.do -- cold strict compile-error cleanup controls
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using test_diagtab_fixture_compile.log,text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_state.do
local tests 0
local pass 0
local fail 0
foreach setting in off on {
foreach source in diagtab _diagtab_common {
    local ++tests
    capture noisily {
        * expect: REFUSED
        qa_fx_a7_labelled, clear seed(37)
        ereturn clear
        tempfile broken
        local filename "`pkg_dir'/`source'.ado"
        python: _p=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("filename")); _s=_p.read_text(); _old='return(out)' if __import__("sfi").Macro.getLocal("source")=='diagtab' else 'return(x)'; assert _old in _s; __import__("pathlib").Path(__import__("sfi").Macro.getLocal("broken")).write_text(_s.replace(_old,'return(qa_intentional_unbound)',1))
        capture program drop diagtab
        mata: mata set matastrict `setting'
        qa_state_snapshot, tag(diag_compile)
        capture noisily run `broken'
        local compile_rc=_rc
        display "COMPILE_RC: `source' `setting' rc=`compile_rc'"
        assert `compile_rc'==3000
        qa_state_compare, tag(diag_compile)
    }
    local outcome=_rc
    if `outcome' {
        local ++fail
        display as error "FAIL: `setting' `source'; rc=" `outcome'
    }
    else {
        local ++pass
        display as result "PASS: `setting' `source'"
    }
}
}
foreach setting in off on {
foreach route in success compile_error {
    local ++tests
    local root ""
    local faultdir ""
    capture noisily {
        qa_fx_a7_files, clear seed(37)
        local root `"`r(root)'"'
        local md `"`macval(root)'/cold.md"'
        if "`route'"=="compile_error" {
            * Throwaway dependency autoload fault, never production source.
            local faultdir `"`macval(root)'/fault"'
            mkdir `"`faultdir'"'
            local original "`pkg_dir'/_diagtab_markdown_write.ado"
            local broken "`faultdir'/_diagtab_markdown_write.ado"
            python: _s=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("original")).read_text(); assert 'return(x)' in _s; __import__("pathlib").Path(__import__("sfi").Macro.getLocal("broken")).write_text(_s.replace('return(x)','@@@ QA_INTENTIONAL_SYNTAX_FAULT',1))
            adopath ++ `"`faultdir'"'
        }
        capture program drop diagtab
        capture program drop _diagtab_markdown_write
        qa_fx_a7_labelled, clear seed(37)
        mata: mata set matastrict `setting'
        qa_state_snapshot, tag(diag_markdown_cold)
        if "`route'"=="success" {
            quietly diagtab x y, cutoff(20.5) markdown(`"`md'"') title("COLD literal")
            assert r(TP)==10 & r(FP)==10 & r(TN)==10 & r(FN)==10
            assert strpos(fileread(`"`md'"'),"### COLD literal")>0
        }
        else {
            * expect: REFUSED
            capture noisily diagtab x y, cutoff(20.5) markdown(`"`md'"')
            assert _rc==3000
            assert r(TP)==10 & r(FP)==10 & r(TN)==10 & r(FN)==10
            capture confirm file `"`md'"'
            assert _rc==601
        }
        qa_state_compare, tag(diag_markdown_cold)
    }
    local outcome=_rc
    if `"`faultdir'"'!="" capture adopath - `"`faultdir'"'
    capture program drop diagtab
    capture program drop _diagtab_markdown_write
    if `"`root'"'!="" {
        capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
        if _rc & !`outcome' local outcome=_rc
    }
    if `outcome' {
        local ++fail
        display as error "FAIL: cold Markdown `setting' `route'; rc=" `outcome'
    }
    else {
        local ++pass
        display as result "PASS: cold Markdown `setting' `route'"
    }
}
}
display "RESULT: test_diagtab_fixture_compile tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
