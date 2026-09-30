*! validation_pyattach_precision.do -- exact stored-value sums and double-rate transport
*! Author: Timothy P Copeland, Karolinska Institutet
* Oracle sums actual declared IEEE32/64 input
* values with Python fsum and pins every raw output field; no state fingerprints.
version 16.0
clear all
set more off
capture log close _all
log using validation_pyattach_precision.log,text replace
local pkg_dir=regexr("`c(pwd)'","/qa$","")
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
local tests 0
local pass 0
local fail 0
python:
from sfi import Macro, Matrix
import struct, math
pairs=[(.1,.2),(1.2345678912345,.999999981),(1.2345678912345e-12,1.9e-12),(1234567891234.5,.12345678912345)]
_pyattach_truth={}
for storage in ('float','double'):
    cast=(lambda x:struct.unpack('f',struct.pack('f',x))[0]) if storage=='float' else float
    rows=[]
    for pair in pairs:
        actual=[cast(x) for x in pair]
        total=math.fsum(actual);maximum=max(actual)
        rows.append([total,maximum,2*365.25/101,max(1e-25,8*math.ulp(total)),max(1e-25,8*math.ulp(maximum))])
    rows.append([0,0,0,1e-25,1e-25])
    _pyattach_truth[storage]=rows
end
foreach storage in float double {
    local ++tests
    capture noisily {
        qa_fx_a7_labelled, clear seed(37)
        keep if id<=5
        keep id date
        tempfile denominator events
        save `denominator'
        keep if id<=4
        expand 2
        sort id
        by id: gen byte member=_n
        gen `storage' amount=.
        replace amount=cond(member==1,.1,.2) if id==1
        replace amount=cond(member==1,1.2345678912345,.999999981) if id==2
        replace amount=cond(member==1,1.2345678912345e-12,1.9e-12) if id==3
        replace amount=cond(member==1,1234567891234.5,.12345678912345) if id==4
        tempname truth
        matrix `truth'=J(5,5,.)
        matrix `truth'[1,2]=0
        python: Matrix.store(Macro.getLocal('truth'),_pyattach_truth[Macro.getLocal('storage')]); assert Matrix.get(Macro.getLocal('truth'))==_pyattach_truth[Macro.getLocal('storage')]
        save `events'
        use `denominator',clear
        gen double stop=date+100
        quietly pygrid, id(id) start(date) end(stop) axis(fixed) origin(date) unit(day) width(101) pyunit(year) keep(date)
        assert _N==5
        assert abs(person_years-101/365.25)<1e-14
        quietly pyattach using `events', id(id) date(date) count(n_events) sum(amount total_amount) max(amount maximum_amount) rate(event_rate)
        assert r(N_attached)==8 & r(N_orphan)==0 & _N==5
        sort id
        forvalues j=1/5 {
            assert id[`j']==`j'
            assert n_events[`j']==cond(`j'<=4,2,0)
            assert !missing(total_amount[`j'],maximum_amount[`j'],event_rate[`j'])
            assert abs(total_amount[`j']-`truth'[`j',1])<=`truth'[`j',4]
            assert abs(maximum_amount[`j']-`truth'[`j',2])<=`truth'[`j',5]
            assert abs(event_rate[`j']-`truth'[`j',3])<1e-12
        }
    }
    local original_rc=_rc
    if `original_rc' {
        local ++fail
        display as error "FAIL: actual `storage' sum/max/rate; rc=" `original_rc'
    }
    else {
        local ++pass
        display as result "PASS: actual `storage' sum/max/rate"
    }
}
display "RESULT: validation_pyattach_precision tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
