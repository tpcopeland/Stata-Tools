*! test_fixture_compile.do — actual interval-engine deliberate compilation refusal
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using "test_fixture_compile.log", replace text nomsg
local qa_dir "`c(pwd)'"
local pkg_dir=regexr("`qa_dir'","/qa$","")
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
tempfile broken
mata: _fx_break_compile(st_local("pkg_dir")+"/_tvmerge_mata.ado",st_local("broken"))
tempfile fault_library private_ado
mkdir "`private_ado'"
mata: _fx_break_compile(st_local("pkg_dir")+"/_tvexpose_mata.ado",st_local("fault_library"))
copy "`fault_library'" "`private_ado'/_tvexpose_mata.ado"
local pass=0
local fail=0
foreach strict in off on {
    clear all
    do _qa_state.do
    mata: mata set matastrict `strict'
    capture noisily {
        qa_state_snapshot, tag(tv_compile)
        capture noisily do "`broken'"
        local call_rc=_rc
        assert `call_rc'==3000
        assert c(matastrict)=="`strict'"
        qa_state_compare, tag(tv_compile)
        di "ORACLE TV compile fault strict=`strict': original3000 and full state"
    }
    if _rc==0 local ++pass
    else local ++fail
}
* Reuse the exact source-copy helper for a cold public dispatch fault.
* Only the private autoloaded engine is changed; the dispatcher is real.
adopath ++ "`pkg_dir'"
adopath ++ "`private_ado'"
foreach strict in off on {
    clear all
    do _qa_state.do
    set obs 2
    generate double marker=_n
    set matastrict `strict'
    capture noisily {
        findfile _tvexpose_mata.ado
        assert "`r(fn)'"=="`private_ado'/_tvexpose_mata.ado"
        qa_state_snapshot, tag(tv_public_compile)
        capture noisily tvexpose using "never_loaded.dta", id(marker) start(marker) exposure(marker) reference(0) entry(marker) exit(marker)
        local call_rc=_rc
        assert `call_rc'==3000
        assert c(matastrict)=="`strict'"
        qa_state_compare, tag(tv_public_compile)
        display "ORACLE TV public compile fault strict=`strict': exact autoloaded source injection, original3000 and non-r caller state"
    }
    if _rc==0 local ++pass
    else local ++fail
}
adopath - "`private_ado'"
erase "`private_ado'/_tvexpose_mata.ado"
rmdir "`private_ado'"
di "RESULT: test_fixture_compile tests=4 pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
