*! validation_tabtools_precision.do -- precise numerical payload, independent input arithmetic
*! Author: Timothy P Copeland, Karolinska Institutet
* Phase2 S1 probe; no session-hygiene or cosmetic contract claim.
version 16.0
clear all
set more off
capture log close _all
log using "validation_tabtools_precision.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
local tests 0
local pass 0
local fail 0
do _qa_fx_a1.do
do _qa_fx_a6.do
do _qa_fx_a7.do
do _qa_metamorphic.do
python:
import math, csv, sys, importlib.util
from pathlib import Path
from sfi import Macro
from openpyxl import load_workbook
_spec=importlib.util.spec_from_file_location('_qa_xlsx',Path.cwd()/'tools'/'check_xlsx.py')
_xlsx=importlib.util.module_from_spec(_spec);sys.modules[_spec.name]=_xlsx;_spec.loader.exec_module(_xlsx)
def _tt_numeric_xlsx(path,sheet,values,start=1,col=1):
    wb=load_workbook(path,data_only=True);ws=wb[sheet]
    for row,value in enumerate(values,start):
        assert type(ws.cell(row,col).value) in (int,float),(row,ws.cell(row,col).value)
        assert _xlsx.check_cell_approx(ws,f'{ws.cell(row,col).column_letter}{row}',value,max(1e-25,8*math.ulp(value))).passed
    wb.close()
def _tt_text_xlsx(path,sheet,values,start=2,col=2,labels=None):
    wb=load_workbook(path,data_only=True);ws=wb[sheet]
    for row,value in enumerate(values,start):
        actual=ws.cell(row,col).value
        assert type(actual) is str,(row,col,type(actual),actual)
        assert actual==value,(row,col,actual,value)
        if labels is not None:
            assert ws.cell(row,col-1).value==labels[row-start]
    wb.close()
def _tt_copied_numeric_text(path,sheet,values,start,col):
    wb=load_workbook(path,data_only=True);ws=wb[sheet]
    for row,value in enumerate(values,start):
        actual=ws.cell(row,col).value
        assert type(actual) is str,(row,col,type(actual),actual)
        parsed=float(actual)
        assert math.isfinite(parsed) and abs(parsed-value)<=max(1e-25,8*math.ulp(value)),(row,actual,value)
    wb.close()
end

**# corrtab precise centered-product truth and reordered named columns
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    keep if id<=5
    generate double precise_y=.
    replace x=0.12345678912345 in 1
    replace precise_y=0.33333333312344998 in 1
    replace x=0.99999998099999998 in 2
    replace precise_y=1.9000000000000001e-08 in 2
    replace x=1.2345678912345e-12 in 3
    replace precise_y=0.77777777123449998 in 3
    replace x=2.3456789012344998 in 4
    replace precise_y=1.0000000187 in 4
    replace x=0.98765432198765002 in 5
    replace precise_y=0.12345678912345 in 5
    quietly corrtab x precise_y, full digits(6)
    tempname C
    matrix `C'=r(C)
    assert !missing(`C'[1,2]) & abs(`C'[1,2]-0.32190395135656835)<1e-12
    quietly corrtab precise_y x, full digits(6)
    matrix `C'=r(C)
    assert !missing(`C'[2,1]) & abs(`C'[2,1]-0.32190395135656835)<1e-12
    qa_metamorphic unsorted, command(corrtab x precise_y, full) returns(r(C) r(N)) tol(1e-12)

}
if _rc {
    local ++fail
    display as error "FAIL: corrtab precise centered-product truth and reordered named columns; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: corrtab precise centered-product truth and reordered named columns"
}

**# crosstab nonterminating effects and frequency scaling
local ++tests
capture noisily {
    clear
    set obs 4
    generate byte row=cond(_n<=2,1,2)
    generate byte col=cond(mod(_n,2)==1,1,2)
    generate double w=cond(_n==1,13,cond(_n==2,17,cond(_n==3,19,23)))
    tempname got
    quietly crosstab row col [fw=w], or rr rd digits(6)
    matrix `got'=r(table)
    assert `got'[1,1]==13 & `got'[1,2]==17 & `got'[2,1]==19 & `got'[2,2]==23
    assert r(N)==72
    assert !missing(r(or),r(rr),r(rd))
    assert abs(r(or)-0.92569659442724461)<1e-12
    assert abs(r(rr)-0.96842105263157896)<1e-12
    assert abs(r(rd)--0.018749999999999999)<1e-12
    qa_metamorphic weight_scale, command(crosstab row col [fw=@w@], or rr rd) weight(w) factor(7) returns(r(or) r(rr) r(rd)) tol(1e-12)

}
if _rc {
    local ++fail
    display as error "FAIL: crosstab nonterminating effects and frequency scaling; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: crosstab nonterminating effects and frequency scaling"
}

**# desctab eight-decimal precise mean and SD
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    replace x=.12345678912345+cond(mod(id,2),-.000000019,.000000019)
    tempname table
    quietly desctab, by(group) vars(x contn %21.8f) frame(`table') pdp(8) highpdp(8)

    frame `table': assert _N==3
    frame `table': assert strtrim(group_1[3])=="0.12345679±0.00000002"
    frame `table': assert strtrim(group_2[3])=="0.12345679±0.00000002"
    frame `table': assert strtrim(group_5[3])=="0.12345679±0.00000002"
    frame `table': assert strtrim(group_9[3])=="0.12345679±0.00000002"
    frame drop `table'

}
if _rc {
    local ++fail
    display as error "FAIL: desctab eight-decimal precise mean and SD; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: desctab eight-decimal precise mean and SD"
}

**# table1_tc eight-decimal precise mean and SD
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    replace x=.12345678912345+cond(mod(id,2),-.000000019,.000000019)
    tempname table
    quietly table1_tc, by(group) vars(x contn %21.8f) frame(`table') pdp(8) highpdp(8)

    frame `table': assert _N==3
    frame `table': assert strtrim(group_1[3])=="0.12345679±0.00000002"
    frame `table': assert strtrim(group_2[3])=="0.12345679±0.00000002"
    frame `table': assert strtrim(group_5[3])=="0.12345679±0.00000002"
    frame `table': assert strtrim(group_9[3])=="0.12345679±0.00000002"
    frame drop `table'

}
if _rc {
    local ++fail
    display as error "FAIL: table1_tc eight-decimal precise mean and SD; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: table1_tc eight-decimal precise mean and SD"
}

**# effecttab precise full double matrix companion
local ++tests
capture noisily {
    qa_fx_a6_estmat, clear seed(37)
    replace term="precise" in 1
    replace term="nearone" in 2
    replace term="tiny" in 3
    replace b=.12345678912345 in 1
    replace b=.999999981 in 2
    replace b=1.2345678912345e-12 in 3
    replace ll=b*.8
    replace ul=b*1.2
    replace p=.12345678912345
    tempname source display analytic
    mkmat b ll ul p, matrix(`source') rownames(term)
    quietly effecttab, from(`source') type(margins) frame(`display') eplotframe(`analytic') digits(6) pdp(8) highpdp(8)
    frame `analytic': format estimate ll ul pvalue %21x
    frame `analytic': noisily list label estimate ll ul pvalue, noobs
    forvalues i=1/3 {
        local name=term[`i']
        foreach field in b ll ul p {
            tempname expected
            scalar `expected'=`field'[`i']
            local output=cond("`field'"=="b","estimate",cond("`field'"=="p","pvalue","`field'"))
            frame `analytic': quietly count if label=="`name'"
            assert r(N)==1
            frame `analytic': assert !missing(`output') & abs(`output'-`expected')<=max(1e-25,8*c(epsdouble)*abs(`expected')) if label=="`name'"
        }
    }
    frame drop `display' `analytic'

}
if _rc {
    local ++fail
    display as error "FAIL: effecttab precise full double matrix companion; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: effecttab precise full double matrix companion"
}

**# comptab selected precise formatted rows
local ++tests
capture noisily {
    qa_fx_a6_estmat, clear seed(37)
    replace term="precise" in 1
    replace term="nearone" in 2
    replace term="tiny" in 3
    replace b=.12345678912345 in 1
    replace b=.999999981 in 2
    replace b=1.2345678912345e-12 in 3
    replace ll=b*.8
    replace ul=b*1.2
    replace p=.12345678912345
    tempname source display analytic
    mkmat b ll ul p, matrix(`source') rownames(term)
    quietly effecttab, from(`source') type(margins) frame(`display') eplotframe(`analytic') digits(6) pdp(8) highpdp(8)
    frame `analytic': format estimate ll ul pvalue %21x
    frame `analytic': noisily list label estimate ll ul pvalue, noobs
    forvalues i=1/3 {
        local name=term[`i']
        foreach field in b ll ul p {
            tempname expected
            scalar `expected'=`field'[`i']
            local output=cond("`field'"=="b","estimate",cond("`field'"=="p","pvalue","`field'"))
            frame `analytic': quietly count if label=="`name'"
            assert r(N)==1
            frame `analytic': assert !missing(`output') & abs(`output'-`expected')<=max(1e-25,8*c(epsdouble)*abs(`expected')) if label=="`name'"
        }
    }
    tempname composite
    quietly comptab `display' `display', rows(1 3 \ 2) frame(`composite')
    frame `composite': assert strtrim(c1[4])=="0.123457"
    frame `composite': assert strtrim(c1[5])=="0.000000"
    frame `composite': assert strtrim(c1[6])=="1.000000"
    frame drop `display' `analytic' `composite'

}
if _rc {
    local ++fail
    display as error "FAIL: comptab selected precise formatted rows; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: comptab selected precise formatted rows"
}

**# regtab precise native collected coefficient
local ++tests
capture noisily {
    qa_fx_a1_gauss, clear tier(micro) seed(37)
    replace y=.999999981+.12345678912345*a+.0198765432198765*x1
    label variable a "precise"
    collect clear
    quietly collect: regress y a
    tempname display analytic
    quietly regtab, frame(`display') eplotframe(`analytic') noint digits(6) pdp(8) highpdp(8)
    frame `analytic': quietly count if label=="precise" & rowtype=="effect"
    assert r(N)==1
    frame `analytic': assert !missing(estimate) & abs(estimate-.12345678912345)<1e-14 if label=="precise" & rowtype=="effect"
    frame drop `display' `analytic'

}
if _rc {
    local ++fail
    display as error "FAIL: regtab precise native collected coefficient; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: regtab precise native collected coefficient"
}

**# stratetab nonterminating raw rate and eight decimal table
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    generate double follow=1+(y==0)
    quietly stset follow, failure(y) id(id)
    tempfile source
    tempname display rates
    quietly strate group, per(1) output(`source'.dta, replace)
    quietly stratetab, using(`source') outcomes(1) frame(`display') outcomeids(y) outlabels("Outcome") explabels("Exposure") digits(8) eventdigits(8) pydigits(8) ratescale(1000) pyscale(1)
    matrix `rates'=r(rates)
    assert rowsof(`rates')==4
    matrix list `rates', format(%21x)
    frame `display': noisily list c1 c2 c3 c4, noobs
    forvalues j=1/4 {
        assert !missing(`rates'[`j',1]) & abs(`rates'[`j',1]-1000/3)<1e-12
        frame `display': assert c2[`j'+4]=="5.00000000" & c3[`j'+4]=="15.00000000"
        frame `display': assert c4[`j'+4]=="333.33333333 (138.74260442, 800.84348693)"
    }
    frame drop `display'
    erase "`source'.dta"

}
if _rc {
    local ++fail
    display as error "FAIL: stratetab nonterminating raw rate and eight decimal table; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: stratetab nonterminating raw rate and eight decimal table"
}

**# hrcomptab retained eight-decimal rate scaffold
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    generate double follow=1+(y==0)
    quietly stset follow, failure(y) id(id)
    tempfile source
    tempname display rates
    quietly strate group, per(1) output(`source'.dta, replace)
    quietly stratetab, using(`source') outcomes(1) frame(`display') outcomeids(y) outlabels("Outcome") explabels("Exposure") digits(8) eventdigits(8) pydigits(8) ratescale(1000) pyscale(1)
    matrix `rates'=r(rates)
    assert rowsof(`rates')==4
    matrix list `rates', format(%21x)
    frame `display': noisily list c1 c2 c3 c4, noobs
    forvalues j=1/4 {
        assert !missing(`rates'[`j',1]) & abs(`rates'[`j',1]-1000/3)<1e-12
        frame `display': assert c2[`j'+4]=="5.00000000" & c3[`j'+4]=="15.00000000"
        frame `display': assert c4[`j'+4]=="333.33333333 (138.74260442, 800.84348693)"
    }
    collect clear
    quietly collect: stcox i.group, nolog
    tempname model analytic composite
    quietly regtab, noint frame(`model') coef(HR) eplotframe(`analytic') models("Outcome") digits(6)
    quietly hrcomptab `display', modelframes(`model') rows(3/5) outcomemap("Outcome") frame(`composite') effect(HR)
    forvalues j=5/8 {
        frame `composite': assert c2[`j']=="5.00000000" & c3[`j']=="15.00000000"
        frame `composite': assert c4[`j']=="333.33333333 (138.74260442, 800.84348693)"
    }
    frame drop `display' `model' `analytic' `composite'
    erase "`source'.dta"

}
if _rc {
    local ++fail
    display as error "FAIL: hrcomptab retained eight-decimal rate scaffold; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: hrcomptab retained eight-decimal rate scaffold"
}

**# survtab nonterminating KM and piecewise RMST
local ++tests
capture noisily {
    clear
    set obs 3
    generate double follow=cond(_n==1,1,3)
    generate byte event=(_n==1)
    quietly stset follow,failure(event)
    quietly survtab,times(2 1 .5) rmst(2) digits(6) pdp(8) highpdp(8)
    tempname got
    matrix `got'=r(table)
    assert rowsof(`got')==3 & colsof(`got')==1
    local time_names : rownames `got'
    assert "`time_names'"=="t2 t1 t.5"
    assert !missing(`got'[rownumb(`got',"t.5"),1]) & abs(`got'[rownumb(`got',"t.5"),1]-1)<1e-14
    foreach time in t2 t1 {
        assert !missing(`got'[rownumb(`got',"`time'"),1]) & abs(`got'[rownumb(`got',"`time'"),1]-2/3)<1e-14
    }
    assert !missing(r(rmst_1)) & abs(r(rmst_1)-5/3)<1e-14
    assert !missing(r(rmst_se_1)) & abs(r(rmst_se_1)-sqrt(2/27))<1e-14

}
if _rc {
    local ++fail
    display as error "FAIL: survtab nonterminating KM and piecewise RMST; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: survtab nonterminating KM and piecewise RMST"
}

**# puttab data XLSX exact supported six-decimal text cells
local ++tests
capture noisily {
    clear
    set obs 4
    generate double precise=cond(_n==1,.12345678912345,cond(_n==2,.999999981,cond(_n==3,1.2345678912345e-12,1234567891234.5)))
    tempfile stem
    local workbook "`stem'.xlsx"
    quietly puttab precise using "`workbook'", sheet("Precise") noheader digits(6) 
    assert r(n_datarows)==4
    python: _tt_text_xlsx(Macro.getLocal('workbook'),'Precise',['0.123457','1.000000','0.000000','1234567891234.500000'])
    erase "`workbook'"

}
if _rc {
    local ++fail
    display as error "FAIL: puttab data XLSX exact supported six-decimal text cells; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: puttab data XLSX exact supported six-decimal text cells"
}

**# puttab frame XLSX exact supported six-decimal text cells
local ++tests
capture noisily {
    clear
    set obs 4
    generate double precise=cond(_n==1,.12345678912345,cond(_n==2,.999999981,cond(_n==3,1.2345678912345e-12,1234567891234.5)))
    tempfile stem
    local workbook "`stem'.xlsx"
    tempname source
    frame put precise,into(`source')
    quietly puttab using "`workbook'", sheet("Precise") noheader digits(6) frame(`source')
    assert r(n_datarows)==4
    python: _tt_text_xlsx(Macro.getLocal('workbook'),'Precise',['0.123457','1.000000','0.000000','1234567891234.500000'])
    erase "`workbook'"
    frame drop `source'

}
if _rc {
    local ++fail
    display as error "FAIL: puttab frame XLSX exact supported six-decimal text cells; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: puttab frame XLSX exact supported six-decimal text cells"
}

**# puttab matrix XLSX exact supported six-decimal text cells
local ++tests
capture noisily {
    clear
    set obs 4
    generate double precise=cond(_n==1,.12345678912345,cond(_n==2,.999999981,cond(_n==3,1.2345678912345e-12,1234567891234.5)))
    tempfile stem
    local workbook "`stem'.xlsx"
    tempname input
    mkmat precise,matrix(`input')
    quietly puttab using "`workbook'", sheet("Precise") noheader digits(6) matrix(`input')
    assert r(n_datarows)==4
    python: _tt_text_xlsx(Macro.getLocal('workbook'),'Precise',['0.123457','1.000000','0.000000','1234567891234.500000'],col=3,labels=['r1','r2','r3','r4'])
    erase "`workbook'"

}
if _rc {
    local ++fail
    display as error "FAIL: puttab matrix XLSX exact supported six-decimal text cells; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: puttab matrix XLSX exact supported six-decimal text cells"
}

**# stacktab precise numeric source block
local ++tests
capture noisily {
    clear
    set obs 4
    generate double precise=cond(_n==1,.12345678912345,cond(_n==2,.999999981,cond(_n==3,1.2345678912345e-12,1234567891234.5)))
    tempfile stem
    local workbook "`stem'.xlsx"
    export excel precise using "`workbook'", sheet("Source") replace
    python: _tt_numeric_xlsx(Macro.getLocal('workbook'),'Source',[.12345678912345,.999999981,1.2345678912345e-12,1234567891234.5])
    quietly stacktab using "`workbook'", blocks(sheet(Source) rows(1/4) cols(A-A)) sheet("Composite") sheetreplace
    assert r(rows_written)==4
    local startcell "`r(table_start)'"
    python: from openpyxl.utils.cell import coordinate_to_tuple; _row,_col=coordinate_to_tuple(Macro.getLocal('startcell')); _tt_copied_numeric_text(Macro.getLocal('workbook'),'Composite',[.12345678912345,.999999981,1.2345678912345e-12,1234567891234.5],_row,_col)
    erase "`workbook'"

}
if _rc {
    local ++fail
    display as error "FAIL: stacktab precise numeric source block; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: stacktab precise numeric source block"
}

display "RESULT: validation_tabtools_precision tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 1
