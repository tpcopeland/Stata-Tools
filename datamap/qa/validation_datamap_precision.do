*! validation_datamap_precision.do -- precise numerical payload, independent input arithmetic
*! Author: Timothy P Copeland, Karolinska Institutet
* Phase2 S1 probe; no session-hygiene or cosmetic contract claim.
version 16.0
clear all
set more off
capture log close _all
log using "validation_datamap_precision.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
local tests 0
local pass 0
local fail 0
do _qa_fx_a7.do
python:
import json, math
from pathlib import Path
from sfi import Macro
_dm_precision_truth={'x': {'mean': 0.8672839178397961, 'sd': 1.0814689812015226, 'min': 1.2345678912345e-12, 'max': 2.3456789012345}, 'tiny': {'mean': 6.339197505864e-12, 'sd': 5.608159281661742e-12, 'min': 1.2345678912345e-12, 'max': 1.2345678912345e-11}, 'nearone': {'mean': 0.996913580202775, 'sd': 0.006172838810102508, 'min': 0.98765432198765, 'max': 1.0000000187}, 'big': {'mean': 1234567891240.25, 'sd': 7.325042661991806, 'min': 1234567891234.5, 'max': 1234567891250.625}}
end

**# JSON full stored double numerical summaries
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    keep if id<=4
    keep id x
    replace x=0.12345678912345 in 1
    replace x=0.99999998099999998 in 2
    replace x=1.2345678912345e-12 in 3
    replace x=2.3456789012344998 in 4
    generate double tiny=.
    replace tiny=1.2345678912345e-12 in 1
    replace tiny=1.9e-12 in 2
    replace tiny=9.8765432198764995e-12 in 3
    replace tiny=1.2345678912345e-11 in 4
    generate double nearone=.
    replace nearone=0.99999998099999998 in 1
    replace nearone=0.99999999912344995 in 2
    replace nearone=1.0000000187 in 3
    replace nearone=0.98765432198765002 in 4
    generate double big=.
    replace big=1234567891234.5 in 1
    replace big=1234567891235.75 in 2
    replace big=1234567891240.125 in 3
    replace big=1234567891250.625 in 4
    tempfile output
    quietly datamap, output("`output'") format(json) continuous(x tiny nearone big) mincell(0)
    assert r(nfiles)==1 & r(nobs)==4 & r(nvars)==5
    python: _metadata=json.loads(Path(Macro.getLocal('output')).read_text())['datasets'][0]['variable_metadata']; _found={v['name']:v['summary'] for v in _metadata}; print('UNROUNDED_JSON_DIAGNOSTIC',[(v,field,float(_found[v][field]).hex(),target.hex()) for v,fields in _dm_precision_truth.items() for field,target in fields.items()]); assert all(abs(_found[v][field]-target)<=max(1e-25,32*math.ulp(target)) for v,fields in _dm_precision_truth.items() for field,target in fields.items())
    erase "`output'"

}
if _rc {
    local ++fail
    display as error "FAIL: JSON full stored double numerical summaries; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: JSON full stored double numerical summaries"
}

**# datamap exact numeric metadata double cells
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    keep if id<=4
    keep id x
    replace x=0.12345678912345 in 1
    replace x=0.99999998099999998 in 2
    replace x=1.2345678912345e-12 in 3
    replace x=2.3456789012344998 in 4
    generate double tiny=.
    replace tiny=1.2345678912345e-12 in 1
    replace tiny=1.9e-12 in 2
    replace tiny=9.8765432198764995e-12 in 3
    replace tiny=1.2345678912345e-11 in 4
    generate double nearone=.
    replace nearone=0.99999998099999998 in 1
    replace nearone=0.99999999912344995 in 2
    replace nearone=1.0000000187 in 3
    replace nearone=0.98765432198765002 in 4
    generate double big=.
    replace big=1234567891234.5 in 1
    replace big=1234567891235.75 in 2
    replace big=1234567891240.125 in 3
    replace big=1234567891250.625 in 4
    tempfile output metadata
    quietly datamap, output("`output'") saving("`metadata'", replace) continuous(x tiny nearone big) mincell(0) format(json)
    use "`metadata'", clear
    format mean sd min max %21x
    noisily list variable mean sd min max, noobs
    assert _N==5
    quietly count if variable=="x"
    assert r(N)==1
    assert !missing(mean) & abs(mean-0.86728391783979608)<=3.5527136788005009e-15 if variable=="x"
    assert !missing(sd) & abs(sd-1.0814689812015226)<=7.1054273576010019e-15 if variable=="x"
    assert !missing(min) & abs(min-1.2345678912345e-12)<=1e-25 if variable=="x"
    assert !missing(max) & abs(max-2.3456789012344998)<=1.4210854715202004e-14 if variable=="x"
    quietly count if variable=="tiny"
    assert r(N)==1
    assert !missing(mean) & abs(mean-6.3391975058640001e-12)<=1e-25 if variable=="tiny"
    assert !missing(sd) & abs(sd-5.6081592816617421e-12)<=1e-25 if variable=="tiny"
    assert !missing(min) & abs(min-1.2345678912345e-12)<=1e-25 if variable=="tiny"
    assert !missing(max) & abs(max-1.2345678912345e-11)<=1e-25 if variable=="tiny"
    quietly count if variable=="nearone"
    assert r(N)==1
    assert !missing(mean) & abs(mean-0.99691358020277498)<=3.5527136788005009e-15 if variable=="nearone"
    assert !missing(sd) & abs(sd-0.0061728388101025076)<=2.7755575615628914e-17 if variable=="nearone"
    assert !missing(min) & abs(min-0.98765432198765002)<=3.5527136788005009e-15 if variable=="nearone"
    assert !missing(max) & abs(max-1.0000000187)<=7.1054273576010019e-15 if variable=="nearone"
    quietly count if variable=="big"
    assert r(N)==1
    assert !missing(mean) & abs(mean-1234567891240.25)<=0.0078125 if variable=="big"
    assert !missing(sd) & abs(sd-7.3250426619918061)<=2.8421709430404007e-14 if variable=="big"
    assert !missing(min) & abs(min-1234567891234.5)<=0.0078125 if variable=="big"
    assert !missing(max) & abs(max-1234567891250.625)<=0.0078125 if variable=="big"
    erase "`output'"
    erase "`metadata'"

}
if _rc {
    local ++fail
    display as error "FAIL: datamap exact numeric metadata double cells; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: datamap exact numeric metadata double cells"
}

**# datadict exact numeric metadata double cells
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    keep if id<=4
    keep id x
    replace x=0.12345678912345 in 1
    replace x=0.99999998099999998 in 2
    replace x=1.2345678912345e-12 in 3
    replace x=2.3456789012344998 in 4
    generate double tiny=.
    replace tiny=1.2345678912345e-12 in 1
    replace tiny=1.9e-12 in 2
    replace tiny=9.8765432198764995e-12 in 3
    replace tiny=1.2345678912345e-11 in 4
    generate double nearone=.
    replace nearone=0.99999998099999998 in 1
    replace nearone=0.99999999912344995 in 2
    replace nearone=1.0000000187 in 3
    replace nearone=0.98765432198765002 in 4
    generate double big=.
    replace big=1234567891234.5 in 1
    replace big=1234567891235.75 in 2
    replace big=1234567891240.125 in 3
    replace big=1234567891250.625 in 4
    tempfile output metadata
    quietly datadict, output("`output'") saving("`metadata'", replace) continuous(x tiny nearone big) mincell(0) stats
    use "`metadata'", clear
    format mean sd min max %21x
    noisily list variable mean sd min max, noobs
    assert _N==5
    quietly count if variable=="x"
    assert r(N)==1
    assert !missing(mean) & abs(mean-0.86728391783979608)<=3.5527136788005009e-15 if variable=="x"
    assert !missing(sd) & abs(sd-1.0814689812015226)<=7.1054273576010019e-15 if variable=="x"
    assert !missing(min) & abs(min-1.2345678912345e-12)<=1e-25 if variable=="x"
    assert !missing(max) & abs(max-2.3456789012344998)<=1.4210854715202004e-14 if variable=="x"
    quietly count if variable=="tiny"
    assert r(N)==1
    assert !missing(mean) & abs(mean-6.3391975058640001e-12)<=1e-25 if variable=="tiny"
    assert !missing(sd) & abs(sd-5.6081592816617421e-12)<=1e-25 if variable=="tiny"
    assert !missing(min) & abs(min-1.2345678912345e-12)<=1e-25 if variable=="tiny"
    assert !missing(max) & abs(max-1.2345678912345e-11)<=1e-25 if variable=="tiny"
    quietly count if variable=="nearone"
    assert r(N)==1
    assert !missing(mean) & abs(mean-0.99691358020277498)<=3.5527136788005009e-15 if variable=="nearone"
    assert !missing(sd) & abs(sd-0.0061728388101025076)<=2.7755575615628914e-17 if variable=="nearone"
    assert !missing(min) & abs(min-0.98765432198765002)<=3.5527136788005009e-15 if variable=="nearone"
    assert !missing(max) & abs(max-1.0000000187)<=7.1054273576010019e-15 if variable=="nearone"
    quietly count if variable=="big"
    assert r(N)==1
    assert !missing(mean) & abs(mean-1234567891240.25)<=0.0078125 if variable=="big"
    assert !missing(sd) & abs(sd-7.3250426619918061)<=2.8421709430404007e-14 if variable=="big"
    assert !missing(min) & abs(min-1234567891234.5)<=0.0078125 if variable=="big"
    assert !missing(max) & abs(max-1234567891250.625)<=0.0078125 if variable=="big"
    erase "`output'"
    erase "`metadata'"

}
if _rc {
    local ++fail
    display as error "FAIL: datadict exact numeric metadata double cells; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: datadict exact numeric metadata double cells"
}

**# datacheck dataqa valid masked numeric ledger transport
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    keep if id<=4
    keep id x
    replace x=0.12345678912345 in 1
    replace x=0.99999998099999998 in 2
    replace x=1.2345678912345e-12 in 3
    replace x=2.3456789012344998 in 4
    generate double tiny=.
    replace tiny=1.2345678912345e-12 in 1
    replace tiny=1.9e-12 in 2
    replace tiny=9.8765432198764995e-12 in 3
    replace tiny=1.2345678912345e-11 in 4
    generate double nearone=.
    replace nearone=0.99999998099999998 in 1
    replace nearone=0.99999999912344995 in 2
    replace nearone=1.0000000187 in 3
    replace nearone=0.98765432198765002 in 4
    generate double big=.
    replace big=1234567891234.5 in 1
    replace big=1234567891235.75 in 2
    replace big=1234567891240.125 in 3
    replace big=1234567891250.625 in 4
    * Genuine release-copy masking domain: five copies of each stored IEEE
    * value give twenty rows; means unchanged, sum and sampleSD rederived.
    expand 5
    assert _N==20
    tempfile ledger exported
    quietly datacheck, gatesonly maskrare mincell(5) stat(mean x 0 3 \ sum tiny 0 1 \ sd nearone 0 1) ledger("`ledger'", run(precision)) name(precise)
    * Three stat entries belong to one evaluated gate family.
    assert r(n_checks)==1 & r(n_passed)==1 & r(n_failed)==0
    quietly dataqa export using "`ledger'", run(precision) saving("`exported'") threshold(5)
    local exported_path `"`r(saving)'"'
    use "`exported_path'", clear
    format observed_num %21x
    noisily list family label observed_num status masked, noobs
    assert _N==3 & family=="stat" & status=="pass" & masked==1 & mincell==5 & obs_masked==0 & n_scope==20
    quietly count if label=="mean x"
    assert r(N)==1
    assert !missing(observed_num) & abs(observed_num-0.86728391783979608)<=3.5527136788005009e-15 if label=="mean x"
    quietly count if label=="sum tiny"
    assert r(N)==1
    assert !missing(observed_num) & abs(observed_num-1.2678395011727999e-10)<=8.2718061255302767e-25 if label=="sum tiny"
    quietly count if label=="sd nearone"
    assert r(N)==1
    assert !missing(observed_num) & abs(observed_num-0.005484711212627987)<=2.7755575615628914e-17 if label=="sd nearone"
    erase "`ledger'"
    erase "`exported_path'"

}
if _rc {
    local ++fail
    display as error "FAIL: datacheck dataqa valid masked numeric ledger transport; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: datacheck dataqa valid masked numeric ledger transport"
}

**# datamvp nonterminating missingness counts
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    expand 2 if id==40
    generate double partial=1
    replace partial=. in 1
    tempfile patterns
    quietly datamvp x partial, nodrop save("`patterns'")
    assert r(N)==41 & r(N_complete)==40 & r(N_incomplete)==1 & r(N_patterns)==2
    assert !missing(r(mean_miss)) & abs(r(mean_miss)-1/41)<1e-15
    use "`patterns'",clear
    assert _N==2
    assert freq==40 & nmiss==0 & abs(percent-4000/41)<1e-12 if pattern=="++"
    assert freq==1 & nmiss==1 & abs(percent-100/41)<1e-12 if pattern=="+."
    quietly count if pattern=="++"
    assert r(N)==1
    quietly count if pattern=="+."
    assert r(N)==1
    erase "`patterns'"

}
if _rc {
    local ++fail
    display as error "FAIL: datamvp nonterminating missingness counts; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: datamvp nonterminating missingness counts"
}

display "RESULT: validation_datamap_precision tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 1
