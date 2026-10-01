*! validation_stacktab_precision_controls.do -- numeric and native date import boundaries
*! Author: Timothy P Copeland, Karolinska Institutet
version 17.0
clear all
set more off
capture log close _all
log using "validation_stacktab_precision_controls.log", text replace
local pkgdir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkgdir'"
local tests 0
local pass 0
local fail 0
python:
from pathlib import Path
from datetime import datetime,date
import math
from openpyxl import Workbook,load_workbook
from openpyxl.utils.cell import coordinate_to_tuple
from sfi import Macro,Data

def _stack_control_write(path,sheets):
    wb=Workbook();wb.remove(wb.active)
    for name,rows in sheets.items():
        ws=wb.create_sheet(name)
        for row in rows:ws.append(row)
    wb.save(path);wb.close()

def _stack_control_check(path,sheet,anchor,expected,numeric=False):
    wb=load_workbook(path,data_only=True);ws=wb[sheet];startrow,startcol=coordinate_to_tuple(anchor)
    for i,row in enumerate(expected):
        for j,target in enumerate(row):
            cell=ws.cell(startrow+i,startcol+j);value=cell.value
            if target is None:assert value in (None,''),(cell.coordinate,value)
            elif isinstance(target,(int,float)) and numeric:
                assert isinstance(value,str),(cell.coordinate,value,cell.data_type)
                assert math.isfinite(float(value))
                assert abs(float(value)-target)<=max(1e-25,8*math.ulp(target)),(cell.coordinate,value,target)
            else:assert isinstance(value,str) and value==target,(cell.coordinate,value,target)
    wb.close()
end

**# Mixed numeric/string cells: signed, tiny, large and blank
local ++tests
capture noisily {
    tempfile stem
    local workbook "`stem'.xlsx"
    python: _mixed=[['0042',-.12345678912345,'0.000000'],['tiny',-1.2345678912345e-12,None],['large',-1234567891234.5,'unavailable']];_stack_control_write(Macro.getLocal('workbook'),{'Mixed':_mixed})
    quietly stacktab using "`workbook'",blocks(sheet(Mixed) rows(1/3) cols(A-C)) sheet("Mixed output") sheetreplace
    assert r(rows_written)==3 & r(blocks_loaded)==1 & r(cols_out)==3
    local anchor "`r(table_start)'"
    python: _stack_control_check(Macro.getLocal('workbook'),'Mixed output',Macro.getLocal('anchor'),_mixed,numeric=True)
    erase "`workbook'"
}
if _rc {
    local ++fail
    display as error "FAIL: mixed signed/tiny/large and blank cells; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: mixed signed/tiny/large and blank cells"
}

**# Excel dates: independent calendar days plus native formatted-string reference
local ++tests
capture noisily {
    tempfile stem
    local workbook "`stem'.xlsx"
    python: _dates=[date(2020,1,1),date(2020,6,30)];_stack_control_write(Macro.getLocal('workbook'),{'Dates':[[v] for v in _dates]});Macro.setLocal('day1',str((_dates[0]-date(1960,1,1)).days));Macro.setLocal('day2',str((_dates[1]-date(1960,1,1)).days))
    python: _datebook=load_workbook(Macro.getLocal("workbook"));assert all(_datebook["Dates"].cell(i,1).number_format=="yyyy-mm-dd" for i in (1,2));_datebook.close()
    import excel using "`workbook'",sheet("Dates") clear
    confirm numeric variable A
    assert _N==2 & A[1]==`day1' & A[2]==`day2'
    import excel using "`workbook'",sheet("Dates") clear allstring("%24.17g")
    confirm string variable A
    python: _date_strings=[[Data.getAt('A',i)] for i in range(Data.getObsTotal())];assert len(_date_strings)==2 and all(isinstance(v,list) and len(v)==1 and isinstance(v[0],str) and v[0] for v in _date_strings)
    quietly stacktab using "`workbook'",blocks(sheet(Dates)) sheet("Dates output") sheetreplace
    assert r(rows_written)==2 & r(cols_out)==1
    local anchor "`r(table_start)'"
    python: _stack_control_check(Macro.getLocal('workbook'),'Dates output',Macro.getLocal('anchor'),_date_strings)
    erase "`workbook'"
}
if _rc {
    local ++fail
    display as error "FAIL: calendar date/native string import boundary; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: calendar date/native string import boundary"
}

**# Default vertical layout/zero spacing retains preformatted source text
local ++tests
capture noisily {
    tempfile stem
    local workbook "`stem'.xlsx"
    python: _left=[['row A','0.123457'],['row B','0.000000']];_right=[['row C','1.000000'],['row D','-0.123457']];_stack_control_write(Macro.getLocal('workbook'),{'Left':_left,'Right':_right})
    quietly stacktab using "`workbook'",blocks(sheet(Left) \ sheet(Right)) sheet("Default output") sheetreplace
    assert r(rows_written)==4 & r(blocks_loaded)==2 & r(cols_out)==2
    assert "`r(layout)'"=="vstack"
    local anchor "`r(table_start)'"
    assert "`anchor'"=="B2"
    python: _stack_control_check(Macro.getLocal('workbook'),'Default output',Macro.getLocal('anchor'),_left+_right)
    erase "`workbook'"
}
if _rc {
    local ++fail
    display as error "FAIL: default layout preserves existing formatted text; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: default layout preserves existing formatted text"
}
display "RESULT: validation_stacktab_precision_controls tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 1
