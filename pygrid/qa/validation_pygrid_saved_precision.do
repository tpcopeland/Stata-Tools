*! validation_pygrid_saved_precision.do -- exact numeric saved-grid transport proposal
*! Author: Timothy P Copeland, Karolinska Institutet
* Proposed Phase2 writer adapter; unreviewed, unrun, not registered.
version 16.0
clear all
set more off
capture log close _all
log using "validation_pygrid_saved_precision.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
local tests 1
local pass 0
local fail 0

**# saveas fixed-grid full double payload
capture noisily {
    clear
    set obs 5
    generate long id=_n
    generate double date=td(01jan2020)
    generate double stop=date+100
    generate double precise=.12345678912345
    generate double nearone=.999999981
    generate double tiny=1.2345678912345e-12
    generate double big=1234567891234.5
    tempfile saved
    quietly pygrid, id(id) start(date) end(stop) axis(fixed) origin(date) ///
        unit(day) width(101) pyunit(year) keep(precise nearone tiny big) saveas("`saved'")
    use "`saved'",clear
    assert _N==5
    isid id
    assert id==_n & period==1
    assert period_start==td(01jan2020) & period_stop==td(01jan2020)+100
    assert !missing(person_years) & abs(person_years-101/365.25)<1e-14
    assert precise==.12345678912345 & nearone==.999999981 & tiny==1.2345678912345e-12 & big==1234567891234.5
    foreach variable in person_years precise nearone tiny big {
        local type : type `variable'
        assert "`type'"=="double"
    }
    erase "`saved'"
}
if _rc {
    local ++fail
    display as error "FAIL: saveas fixed-grid full double payload; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: saveas fixed-grid full double payload"
}
display "RESULT: validation_pygrid_saved_precision tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 1
