*! test_fixture_compile.do — intentional package Mata compilation errors
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
capture log close _all
log using "test_fixture_compile.log", replace text nomsg
local qa_dir "`c(pwd)'"
local pkg_dir=regexr("`qa_dir'","/qa$","")
adopath ++ "`pkg_dir'"
* Mutate private temporary copies only; shipped definitions remain untouched.
mata:
void _fx_break_compile(string scalar src, string scalar dest)
{
    real scalar fi, fo
    string matrix line
    fi=fopen(src,"r");fo=fopen(dest,"w")
    while(1) {
        line=fget(fi)
        if(rows(line)==0) break
        fput(fo,line)
        if(line=="mata set matastrict on") fput(fo,"void __fixture_broken( {")
    }
    fclose(fi);fclose(fo)
}
end
tempfile broken1
mata: _fx_break_compile(st_local("pkg_dir")+"/_rangematch_mata.ado",st_local("broken1"))
local tests=0
local pass=0
local fail=0
foreach strict in off on {
    clear all
    do "`qa_dir'/_qa_state.do"
    mata: mata set matastrict `strict'
    local ++tests
    capture noisily {
        qa_state_snapshot, tag(compile_error)
        capture noisily do "`broken1'"
        local compile_rc=_rc
        di "ORACLE compile fault _rangematch_mata strict=`strict' rc=`compile_rc'"
        assert `compile_rc'==3000
        assert c(matastrict)=="`strict'"
        qa_state_compare, tag(compile_error)
    }
    if _rc==0 local ++pass
    else {
        local ++fail
        di as error "FAIL compile fault _rangematch_mata strict=`strict' rc=`=_rc'"
    }
}
di "RESULT: test_fixture_compile tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
