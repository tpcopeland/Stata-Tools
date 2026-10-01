*! validation_massdesas_precision.do -- precise numerical payload, independent input arithmetic
*! Author: Timothy P Copeland, Karolinska Institutet
* Phase2 S1 probe; no session-hygiene or cosmetic contract claim.
version 16.0
clear all
set more off
capture log close _all
log using "validation_massdesas_precision.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
local tests 0
local pass 0
local fail 0
do _massdesas_qa_common.do
_massdesas_qa_bootstrap
* Real SAS binary written by haven. Native import checks all double values
* before invoking massdesas; stand-in discovery files are never used here.

**# default actual SAS double conversion
local ++tests
capture noisily {
    tempfile stem
    local directory "`stem'_sas"
    mkdir "`directory'"
    shell Rscript "tools/write_massdesas_precision.R" "`directory'/precise.sas7bdat"
    import sas using "`directory'/precise.sas7bdat", clear
    assert _N==4 & ID==_n
    assert Precise[1]==.12345678912345 & Precise[2]==.999999981 & Precise[3]==1.2345678912345e-12 & Precise[4]==1234567891234.5
    clear
    quietly massdesas, directory("`directory'") 
    assert r(n_converted)==1 & r(n_failed)==0
    use "`directory'/precise.dta", clear
    assert _N==4 & ID==_n
    assert Precise[1]==.12345678912345 & Precise[2]==.999999981 & Precise[3]==1.2345678912345e-12 & Precise[4]==1234567891234.5
    local type : type Precise
    assert "`type'"=="double"
    erase "`directory'/precise.sas7bdat"
    erase "`directory'/precise.dta"
    rmdir "`directory'"

}
if _rc {
    local ++fail
    display as error "FAIL: default actual SAS double conversion; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: default actual SAS double conversion"
}

**# lower actual SAS double conversion
local ++tests
capture noisily {
    tempfile stem
    local directory "`stem'_sas"
    mkdir "`directory'"
    shell Rscript "tools/write_massdesas_precision.R" "`directory'/precise.sas7bdat"
    import sas using "`directory'/precise.sas7bdat", clear
    assert _N==4 & ID==_n
    assert Precise[1]==.12345678912345 & Precise[2]==.999999981 & Precise[3]==1.2345678912345e-12 & Precise[4]==1234567891234.5
    clear
    quietly massdesas, directory("`directory'") lower
    assert r(n_converted)==1 & r(n_failed)==0
    use "`directory'/precise.dta", clear
    assert _N==4 & id==_n
    assert precise[1]==.12345678912345 & precise[2]==.999999981 & precise[3]==1.2345678912345e-12 & precise[4]==1234567891234.5
    local type : type precise
    assert "`type'"=="double"
    erase "`directory'/precise.sas7bdat"
    erase "`directory'/precise.dta"
    rmdir "`directory'"

}
if _rc {
    local ++fail
    display as error "FAIL: lower actual SAS double conversion; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: lower actual SAS double conversion"
}

display "RESULT: validation_massdesas_precision tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 1
