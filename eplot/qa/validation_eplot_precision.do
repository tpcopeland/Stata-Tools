*! validation_eplot_precision.do -- precise numerical payload, independent input arithmetic
*! Author: Timothy P Copeland, Karolinska Institutet
* Phase2 S1 probe; no session-hygiene or cosmetic contract claim.
version 16.0
clear all
set more off
capture log close _all
log using "validation_eplot_precision.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
local tests 0
local pass 0
local fail 0
do _eplot_qa_common.do
do _qa_fx_a6.do

**# data raw coefficient CI and p precision
local ++tests
capture noisily {
    qa_fx_a6_estmat, clear seed(37)
    replace term="precise" in 1
    replace term="nearone" in 2
    replace term="tiny" in 3
    replace b=.12345678912345 in 1
    replace b=.999999981 in 2
    replace b=1.2345678912345e-12 in 3
    replace se=.012345678912345 in 1
    replace se=.000000123456789 in 2
    replace se=1.9e-13 in 3
    replace ll=b-invnormal(.975)*se
    replace ul=b+invnormal(.975)*se
    replace p=2*normal(-abs(b/se))
    tempname truth got pv
    mkmat b ll ul p, matrix(`truth') rownames(term)
    gsort -term
    quietly eplot b ll ul, labels(term) pvalue(p) vformat(%21.8f) name(preciseplot, replace)
    matrix `got'=r(table)
    matrix `pv'=r(pvalues)
    assert rowsof(`got')==3 & colsof(`got')==3
    assert rowsof(`pv')==3 & colsof(`pv')==1
    forvalues j=1/3 {
        local terms : rownames `truth'
        local term : word `j' of `terms'
        local row=rownumb(`got',"`term'")
        local prow=rownumb(`pv',"`term'")
        assert !missing(`row',`prow')
        forvalues k=1/3 {
            assert !missing(`got'[`row',`k'],`truth'[`j',`k'])
            assert abs(`got'[`row',`k']-`truth'[`j',`k'])<=max(1e-25,8*c(epsdouble)*abs(`truth'[`j',`k']))
        }
        assert !missing(`pv'[`prow',1],`truth'[`j',4])
        assert abs(`pv'[`prow',1]-`truth'[`j',4])<=max(1e-25,16*c(epsdouble)*abs(`truth'[`j',4]))
    }
    graph drop preciseplot
}
if _rc {
    local ++fail
    display as error "FAIL: data raw coefficient CI and p precision; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: data raw coefficient CI and p precision"
}

**# frame raw coefficient CI and p precision
local ++tests
capture noisily {
    qa_fx_a6_estmat, clear seed(37)
    replace term="precise" in 1
    replace term="nearone" in 2
    replace term="tiny" in 3
    replace b=.12345678912345 in 1
    replace b=.999999981 in 2
    replace b=1.2345678912345e-12 in 3
    replace se=.012345678912345 in 1
    replace se=.000000123456789 in 2
    replace se=1.9e-13 in 3
    replace ll=b-invnormal(.975)*se
    replace ul=b+invnormal(.975)*se
    replace p=2*normal(-abs(b/se))
    tempname truth got pv
    mkmat b ll ul p, matrix(`truth') rownames(term)
    gsort -term
    frame put b ll ul term p, into(preciseinput)
    quietly eplot, frame(preciseinput) estimate(b) ll(ll) ul(ul) labels(term) pvalue(p) vformat(%21.8f) name(preciseplot, replace)
    matrix `got'=r(table)
    matrix `pv'=r(pvalues)
    assert rowsof(`got')==3 & colsof(`got')==3
    assert rowsof(`pv')==3 & colsof(`pv')==1
    forvalues j=1/3 {
        local terms : rownames `truth'
        local term : word `j' of `terms'
        local row=rownumb(`got',"`term'")
        local prow=rownumb(`pv',"`term'")
        assert !missing(`row',`prow')
        forvalues k=1/3 {
            assert !missing(`got'[`row',`k'],`truth'[`j',`k'])
            assert abs(`got'[`row',`k']-`truth'[`j',`k'])<=max(1e-25,8*c(epsdouble)*abs(`truth'[`j',`k']))
        }
        assert !missing(`pv'[`prow',1],`truth'[`j',4])
        assert abs(`pv'[`prow',1]-`truth'[`j',4])<=max(1e-25,16*c(epsdouble)*abs(`truth'[`j',4]))
    }
    graph drop preciseplot
    frame drop preciseinput
}
if _rc {
    local ++fail
    display as error "FAIL: frame raw coefficient CI and p precision; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: frame raw coefficient CI and p precision"
}

**# matrix raw coefficient CI and p precision
local ++tests
capture noisily {
    qa_fx_a6_estmat, clear seed(37)
    replace term="precise" in 1
    replace term="nearone" in 2
    replace term="tiny" in 3
    replace b=.12345678912345 in 1
    replace b=.999999981 in 2
    replace b=1.2345678912345e-12 in 3
    replace se=.012345678912345 in 1
    replace se=.000000123456789 in 2
    replace se=1.9e-13 in 3
    replace ll=b-invnormal(.975)*se
    replace ul=b+invnormal(.975)*se
    replace p=2*normal(-abs(b/se))
    tempname truth got pv
    mkmat b ll ul p, matrix(`truth') rownames(term)
    tempname input
    mkmat b se, matrix(`input') rownames(term)
    quietly eplot, matrix(`input') stars vformat(%21.8f) name(preciseplot, replace)
    matrix `got'=r(table)
    matrix `pv'=r(pvalues)
    assert rowsof(`got')==3 & colsof(`got')==3
    assert rowsof(`pv')==3 & colsof(`pv')==1
    forvalues j=1/3 {
        local terms : rownames `truth'
        local term : word `j' of `terms'
        local row=rownumb(`got',"`term'")
        local prow=rownumb(`pv',"`term'")
        assert !missing(`row',`prow')
        forvalues k=1/3 {
            assert !missing(`got'[`row',`k'],`truth'[`j',`k'])
            assert abs(`got'[`row',`k']-`truth'[`j',`k'])<=max(1e-25,8*c(epsdouble)*abs(`truth'[`j',`k']))
        }
        assert !missing(`pv'[`prow',1],`truth'[`j',4])
        assert abs(`pv'[`prow',1]-`truth'[`j',4])<=max(1e-25,16*c(epsdouble)*abs(`truth'[`j',4]))
    }
    graph drop preciseplot
}
if _rc {
    local ++fail
    display as error "FAIL: matrix raw coefficient CI and p precision; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: matrix raw coefficient CI and p precision"
}

**# estimates raw coefficient CI and p precision
local ++tests
capture noisily {
    qa_fx_a6_estmat, clear seed(37)
    replace term="precise" in 1
    replace term="nearone" in 2
    replace term="tiny" in 3
    replace b=.12345678912345 in 1
    replace b=.999999981 in 2
    replace b=1.2345678912345e-12 in 3
    replace se=.012345678912345 in 1
    replace se=.000000123456789 in 2
    replace se=1.9e-13 in 3
    replace ll=b-invnormal(.975)*se
    replace ul=b+invnormal(.975)*se
    replace p=2*normal(-abs(b/se))
    tempname truth got pv
    mkmat b ll ul p, matrix(`truth') rownames(term)
    tempname B V
    matrix `B'=(b[1],b[2],b[3])
    matrix `V'=diag((se[1]^2,se[2]^2,se[3]^2))
    matrix colnames `B'=precise nearone tiny
    matrix colnames `V'=precise nearone tiny
    matrix rownames `V'=precise nearone tiny
    _qa_fxa6_post `B' `V' 0
    estimates store preciseest
    clear
    quietly eplot preciseest, stars vformat(%21.8f) name(preciseplot, replace)
    matrix `got'=r(table)
    matrix `pv'=r(pvalues)
    assert rowsof(`got')==3 & colsof(`got')==3
    assert rowsof(`pv')==3 & colsof(`pv')==1
    forvalues j=1/3 {
        local terms : rownames `truth'
        local term : word `j' of `terms'
        local row=rownumb(`got',"`term'")
        local prow=rownumb(`pv',"`term'")
        assert !missing(`row',`prow')
        forvalues k=1/3 {
            assert !missing(`got'[`row',`k'],`truth'[`j',`k'])
            assert abs(`got'[`row',`k']-`truth'[`j',`k'])<=max(1e-25,8*c(epsdouble)*abs(`truth'[`j',`k']))
        }
        assert !missing(`pv'[`prow',1],`truth'[`j',4])
        assert abs(`pv'[`prow',1]-`truth'[`j',4])<=max(1e-25,16*c(epsdouble)*abs(`truth'[`j',4]))
    }
    graph drop preciseplot
    estimates drop preciseest
}
if _rc {
    local ++fail
    display as error "FAIL: estimates raw coefficient CI and p precision; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: estimates raw coefficient CI and p precision"
}

_eplot_qa_result validation_eplot_precision, tests(`tests') pass(`pass') fail(`fail') skip(0)
log close
if `fail' exit 1
