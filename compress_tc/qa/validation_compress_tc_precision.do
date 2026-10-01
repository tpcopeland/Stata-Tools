*! validation_compress_tc_precision.do -- precise numerical payload, independent input arithmetic
*! Author: Timothy P Copeland, Karolinska Institutet
* Phase2 S1 probe; no session-hygiene or cosmetic contract claim.
version 16.0
clear all
set more off
capture log close _all
log using "validation_compress_tc_precision.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
local tests 0
local pass 0
local fail 0
do _qa_fx_a7.do

**# default lossless numeric values and duplicate strings
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    keep id
    generate double precise=.12345678912345
    generate double nearone=.999999981
    generate double tiny=1.2345678912345e-12
    generate double big=1234567891234.5
    generate str200 repeated="repeated numeric-transport scaffold"
    quietly compress_tc, quietly 
    assert _N==40
    assert precise==.12345678912345 & nearone==.999999981 & tiny==1.2345678912345e-12 & big==1234567891234.5
    foreach v in precise nearone tiny big {
        local type : type `v'
        assert "`type'"=="double"
    }
    assert repeated=="repeated numeric-transport scaffold"

}
if _rc {
    local ++fail
    display as error "FAIL: default lossless numeric values and duplicate strings; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: default lossless numeric values and duplicate strings"
}

**# lowmem lossless numeric values and duplicate strings
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    keep id
    generate double precise=.12345678912345
    generate double nearone=.999999981
    generate double tiny=1.2345678912345e-12
    generate double big=1234567891234.5
    generate str200 repeated="repeated numeric-transport scaffold"
    quietly compress_tc, quietly lowmem
    assert _N==40
    assert precise==.12345678912345 & nearone==.999999981 & tiny==1.2345678912345e-12 & big==1234567891234.5
    foreach v in precise nearone tiny big {
        local type : type `v'
        assert "`type'"=="double"
    }
    assert repeated=="repeated numeric-transport scaffold"

}
if _rc {
    local ++fail
    display as error "FAIL: lowmem lossless numeric values and duplicate strings; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: lowmem lossless numeric values and duplicate strings"
}

display "RESULT: validation_compress_tc_precision tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 1
