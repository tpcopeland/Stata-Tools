*! validation_tabtools_fixture_numeric_primitives.do -- actual named counts/correlations/means
*! Author: Timothy P Copeland, Karolinska Institutet
* Pearson centred-sum oracle: Stata [R] correlate Methods fetched2026-09-30,
* https://www.stata.com/manuals/rcorrelate.pdf. The alternating20-row design
* gives corr(y,Y)=1, corr(longA,longB)=-1, corr(y,longA)=-1/sqrt(133).
version 16.0
clear all
set more off
capture log close _all
log using validation_tabtools_fixture_numeric_primitives.log, text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_hostile.do
do _qa_fx_a7.do
do _qa_state.do
local tests 0
local pass 0
local fail 0

**# crosstab case twins
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_names, clear
    tempname counts
    qa_state_snapshot, tag(tt_numeric)
    quietly crosstab y Y
    assert r(N)==20
    matrix `counts'=r(table)
    assert rowsof(`counts')==2 & colsof(`counts')==2
    assert `counts'[rownumb(`counts',"0"),colnumb(`counts',"-9")]==10
    assert `counts'[rownumb(`counts',"2"),colnumb(`counts',"11")]==10
    assert `counts'[rownumb(`counts',"0"),colnumb(`counts',"11")]==0
    assert `counts'[rownumb(`counts',"2"),colnumb(`counts',"-9")]==0
    matrix drop `counts'
    qa_state_compare, tag(tt_numeric)
}
local outcome=_rc
capture restore
capture frame drop `display'
capture matrix drop `C' `N' `counts'
if `outcome' {
    local ++fail
    display as error "FAIL: crosstab case twins rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: crosstab case twins"
}

**# crosstab signed large codes
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_codes, clear
    generate byte binary=mod(y,2)
    tempname counts
    qa_state_snapshot, tag(tt_numeric)
    quietly crosstab code binary
    assert r(N)==15
    matrix `counts'=r(table)
    assert rowsof(`counts')==5 & colsof(`counts')==2
    foreach code in -7 2 20 3000000000 3000000001 {
        local row=rownumb(`counts',"`code'")
        local n0=cond(inlist(`code',2,3000000001),2,1)
        assert !missing(`row')
        assert `counts'[`row',colnumb(`counts',"0")]==`n0'
        assert `counts'[`row',colnumb(`counts',"1")]==3-`n0'
    }
    matrix drop `counts'
    qa_state_compare, tag(tt_numeric)
}
local outcome=_rc
capture restore
capture frame drop `display'
capture matrix drop `C' `N' `counts'
if `outcome' {
    local ++fail
    display as error "FAIL: crosstab signed large codes rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: crosstab signed large codes"
}

**# corrtab full case and 32-byte identity
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_names, clear
    tempname C N
    qa_state_snapshot, tag(tt_numeric)
    quietly corrtab y Y abcdefghijklmnopqrstuvwxyz_1234a abcdefghijklmnopqrstuvwxyz_1234b, full
    matrix `C'=r(C)
    matrix `N'=r(N)
    assert rowsof(`C')==4 & colsof(`C')==4
    local rows : rownames `C'
    local cols : colnames `C'
    assert "`rows'"=="y Y abcdefghijklmnopqrstuvwxyz_1234a abcdefghijklmnopqrstuvwxyz_1234b"
    assert "`cols'"=="`rows'"
    forvalues i=1/4 {
        forvalues j=1/4 {
            assert `N'[`i',`j']==20 & !missing(`C'[`i',`j'])
        }
        assert abs(`C'[`i',`i']-1)<1e-14
    }
    assert abs(`C'[1,2]-1)<1e-14 & abs(`C'[3,4]+1)<1e-14
    assert abs(`C'[1,3]+1/sqrt(133))<1e-14
    assert abs(`C'[2,4]-1/sqrt(133))<1e-14
    matrix drop `C' `N'
    qa_state_compare, tag(tt_numeric)
}
local outcome=_rc
capture restore
capture frame drop `display'
capture matrix drop `C' `N' `counts'
if `outcome' {
    local ++fail
    display as error "FAIL: corrtab full case and 32-byte identity rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: corrtab full case and 32-byte identity"
}

**# corrtab opaque label corpus
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37)
    qa_hostile_strings
    local corpus `r(names)'
    foreach g of local corpus {
        mata: st_varlabel("x",st_global(st_local("g")))
        tempname display C
        qa_state_snapshot, tag(tt_numeric)
        quietly corrtab x id, full frame(`display')
        matrix `C'=r(C)
        assert abs(`C'[1,2]-1)<1e-14
        frame `display': python: from sfi import Data,Macro; assert Data.getAt("c1",2)==Macro.getGlobal(Macro.getLocal("g")) and Data.getAt("c2",1)==Macro.getGlobal(Macro.getLocal("g"))
        frame drop `display'
        matrix drop `C'
        qa_state_compare, tag(tt_numeric)
    }
}
local outcome=_rc
capture restore
capture frame drop `display'
capture matrix drop `C' `N' `counts'
if `outcome' {
    local ++fail
    display as error "FAIL: corrtab opaque label corpus rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: corrtab opaque label corpus"
}

**# desctab last-byte long names
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_names, clear
    generate byte group=1+mod(_n,2)
    tempname display
    qa_state_snapshot, tag(tt_numeric)
    quietly desctab, by(group) vars(abcdefghijklmnopqrstuvwxyz_1234a contn %9.1f \ abcdefghijklmnopqrstuvwxyz_1234b contn %9.1f) frame(`display')
    frame `display': assert _N==4
    frame `display': assert factor[3]=="abcdefghijklmnopqrstuvwxyz_1234a" & factor[4]=="abcdefghijklmnopqrstuvwxyz_1234b"
    frame `display': assert group_1[2]=="N=10" & group_2[2]=="N=10"
    frame `display': assert group_1[3]=="11.0±6.1" & group_2[3]=="10.0±6.1"
    frame `display': assert group_1[4]=="-11.0±6.1" & group_2[4]=="-10.0±6.1"
    frame drop `display'
    qa_state_compare, tag(tt_numeric)
}
local outcome=_rc
capture restore
capture frame drop `display'
capture matrix drop `C' `N' `counts'
if `outcome' {
    local ++fail
    display as error "FAIL: desctab last-byte long names rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: desctab last-byte long names"
}

**# desctab signed-code named refusal
local ++tests
capture noisily {
    * expect: REFUSED
    qa_hostile_codes, clear
    tempname display
    qa_state_snapshot, tag(tt_numeric)
    capture noisily desctab, by(code) vars(y contn %9.1f) frame(`display')
    assert _rc==498
    qa_state_compare, tag(tt_numeric)
}
local outcome=_rc
capture restore
capture frame drop `display'
capture matrix drop `C' `N' `counts'
if `outcome' {
    local ++fail
    display as error "FAIL: desctab signed-code named refusal rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: desctab signed-code named refusal"
}

**# desctab positive large-code payload
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_codes, clear
    drop if code<0
    tempname display
    qa_state_snapshot, tag(tt_numeric)
    quietly desctab, by(code) vars(y contn %9.1f) frame(`display')
    frame `display': assert _N==3
    foreach code in 2 20 3000000000 3000000001 {
        local mean=cond(`code'==2,11,cond(`code'==20,14,cond(`code'==3000000000,2,5)))
        local target=strtrim(string(`mean',"%9.1f"))+"±1.0"
        frame `display': assert code_`code'[2]=="N=3" & code_`code'[3]=="`target'"
    }
    frame drop `display'
    qa_state_compare, tag(tt_numeric)
}
local outcome=_rc
capture restore
capture frame drop `display'
capture matrix drop `C' `N' `counts'
if `outcome' {
    local ++fail
    display as error "FAIL: desctab positive large-code payload rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: desctab positive large-code payload"
}

**# table1_tc last-byte long names
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_names, clear
    generate byte group=1+mod(_n,2)
    tempname display
    qa_state_snapshot, tag(tt_numeric)
    quietly table1_tc, by(group) vars(abcdefghijklmnopqrstuvwxyz_1234a contn %9.1f \ abcdefghijklmnopqrstuvwxyz_1234b contn %9.1f) frame(`display')
    frame `display': assert _N==4
    frame `display': assert factor[3]=="abcdefghijklmnopqrstuvwxyz_1234a" & factor[4]=="abcdefghijklmnopqrstuvwxyz_1234b"
    frame `display': assert group_1[2]=="N=10" & group_2[2]=="N=10"
    frame `display': assert group_1[3]=="11.0±6.1" & group_2[3]=="10.0±6.1"
    frame `display': assert group_1[4]=="-11.0±6.1" & group_2[4]=="-10.0±6.1"
    frame drop `display'
    qa_state_compare, tag(tt_numeric)
}
local outcome=_rc
capture restore
capture frame drop `display'
capture matrix drop `C' `N' `counts'
if `outcome' {
    local ++fail
    display as error "FAIL: table1_tc last-byte long names rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: table1_tc last-byte long names"
}

**# table1_tc signed-code named refusal
local ++tests
capture noisily {
    * expect: REFUSED
    qa_hostile_codes, clear
    tempname display
    qa_state_snapshot, tag(tt_numeric)
    capture noisily table1_tc, by(code) vars(y contn %9.1f) frame(`display')
    assert _rc==498
    qa_state_compare, tag(tt_numeric)
}
local outcome=_rc
capture restore
capture frame drop `display'
capture matrix drop `C' `N' `counts'
if `outcome' {
    local ++fail
    display as error "FAIL: table1_tc signed-code named refusal rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: table1_tc signed-code named refusal"
}

**# table1_tc positive large-code payload
local ++tests
capture noisily {
    * expect: EXACT
    qa_hostile_codes, clear
    drop if code<0
    tempname display
    qa_state_snapshot, tag(tt_numeric)
    quietly table1_tc, by(code) vars(y contn %9.1f) frame(`display')
    frame `display': assert _N==3
    foreach code in 2 20 3000000000 3000000001 {
        local mean=cond(`code'==2,11,cond(`code'==20,14,cond(`code'==3000000000,2,5)))
        local target=strtrim(string(`mean',"%9.1f"))+"±1.0"
        frame `display': assert code_`code'[2]=="N=3" & code_`code'[3]=="`target'"
    }
    frame drop `display'
    qa_state_compare, tag(tt_numeric)
}
local outcome=_rc
capture restore
capture frame drop `display'
capture matrix drop `C' `N' `counts'
if `outcome' {
    local ++fail
    display as error "FAIL: table1_tc positive large-code payload rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: table1_tc positive large-code payload"
}

display "RESULT: validation_tabtools_fixture_numeric_primitives tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
