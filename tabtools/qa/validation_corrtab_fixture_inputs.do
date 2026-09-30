*! validation_corrtab_fixture_inputs.do -- signed/large inputs and supported undefined estimates
*! Author: Timothy P Copeland, Karolinska Institutet
* Primary methods fetched2026-09-30: https://www.stata.com/manuals/rcorrelate.pdf
* p7 centered product-moment correlation; https://www.stata.com/manuals/rspearman.pdf
* p6/p11 average ranks for tied values. Integer sums/60-digit Decimal oracle
* below are independent of native correlation/ranking routines.
version 17
clear all
set more off
capture log close _all
log using validation_corrtab_fixture_inputs.log, text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_state.do
program define _tt_seed_r, rclass
    args kind
    return clear
    if "`kind'"=="empty" exit
    tempname payload
    matrix `payload'=(1,-2\3,4)
    matrix rownames `payload'=First second
    matrix colnames `payload'=X y
    return scalar exact=123.125
    return scalar extended=.a
    local opaque ""
    mata: st_local("opaque",char(36)+"UNSET"+char(96)+"missing"+char(39)+char(34)+"opaque")
    return local bytes `"`macval(opaque)'"'
    return matrix payload=`payload'
end
do _qa_hostile.do
java set heapmax 256m
local tests 0
local pass 0
local fail 0
python:
from decimal import Decimal, localcontext
from sfi import Macro
from pathlib import Path
def _tt_integer_corr(x,y):
    n=len(x)
    a=n*sum(a*b for a,b in zip(x,y))-sum(x)*sum(y)
    vx=n*sum(a*a for a in x)-sum(x)**2
    vy=n*sum(b*b for b in y)-sum(y)**2
    with localcontext() as ctx:
        ctx.prec=60
        return Decimal(a)/Decimal(vx*vy).sqrt()
_tt_codes=[c for c in (3000000000,3000000001,-7,2,20) for j in range(3)]
_tt_y=list(range(1,16))
# Independently enumerated mean ranks for the five three-way tie blocks:
# sorted code order -7,2,20,3000000000,3000000001 gives ranks2,5,8,11,14.
_tt_ranks=[r for r in (11,14,2,5,8) for j in range(3)]
_tt_expected={'pearson':str(_tt_integer_corr(_tt_codes,_tt_y)),
              'spearman':str(_tt_integer_corr(_tt_ranks,_tt_y))}
end

**# Signed large code numerical pearson
local ++tests
capture noisily {
    qa_hostile_codes, clear
    python: Macro.setLocal('expected',_tt_expected['pearson'])
    qa_state_snapshot, tag(corr_input)
    * expect: EXACT
    corrtab code y, full
    tempname cc nn
    matrix `cc'=r(C)
    matrix `nn'=r(N)
    assert !missing(`cc'[1,2]) & abs(`cc'[1,2]-`expected')<1e-12
    assert `nn'[1,1]==15 & `nn'[1,2]==15 & `nn'[2,2]==15
    matrix drop `cc' `nn'
    qa_state_compare, tag(corr_input)
}
local outcome=_rc
if `outcome' {
    local ++fail
    display as error "FAIL: codes pearson rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: codes pearson"
}

**# Signed large code numerical spearman
local ++tests
capture noisily {
    qa_hostile_codes, clear
    python: Macro.setLocal('expected',_tt_expected['spearman'])
    qa_state_snapshot, tag(corr_input)
    * expect: EXACT
    corrtab code y, full spearman
    tempname cc nn
    matrix `cc'=r(C)
    matrix `nn'=r(N)
    assert !missing(`cc'[1,2]) & abs(`cc'[1,2]-`expected')<1e-12
    assert `nn'[1,1]==15 & `nn'[1,2]==15 & `nn'[2,2]==15
    matrix drop `cc' `nn'
    qa_state_compare, tag(corr_input)
}
local outcome=_rc
if `outcome' {
    local ++fail
    display as error "FAIL: codes spearman rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: codes spearman"
}

**# One observation pearson supported missing results
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37) perturb(stale_sheet)
    local root `"`r(root)'"'
    local output `"`r(path_xlsx)'"'
    mata: st_local("csvfile",st_local("root")+"/single.csv")
    mata: st_local("mdfile",st_local("root")+"/single.md")
    python: _tt_single_before={str(p.relative_to(Path(Macro.getLocal('root')))):p.read_bytes() for p in Path(Macro.getLocal('root')).rglob('*') if p.is_file() and str(p)!=Macro.getLocal('output')}
    qa_fx_a7_labelled, clear seed(37) perturb(single_row)
    qa_state_snapshot, tag(corr_input)
    * expect: EXACT
    corrtab x id, full frame(single_display, replace) xlsx(`"`macval(output)'"') csv(`"`macval(csvfile)'"') markdown(`"`macval(mdfile)'"') sheet(package_summary) title("Single exact")
    tempname cc pp nn
    matrix `cc'=r(C)
    matrix `pp'=r(P)
    matrix `nn'=r(N)
    forvalues i=1/2 {
        forvalues j=1/2 {
            assert missing(`cc'[`i',`j']) & missing(`pp'[`i',`j'])
            assert `nn'[`i',`j']==1
        }
    }
    frame single_display {
        assert c2[3]=="" & c3[3]=="." & c2[4]=="." & c3[4]==""
        assert strpos(c2[3]+c3[3]+c2[4]+c3[4],"*")==0
    }
    matrix drop `cc' `pp' `nn'
    frame drop single_display
    qa_state_compare, tag(corr_input)
    python:
from openpyxl import load_workbook
import csv
w=load_workbook(Macro.getLocal('output'))
t=w['package_summary']
assert [t[c].value or '' for c in ('C3','D3','C4','D4')]==['','.','.','']
assert w['user_notes']['A1'].value=='USER_KEEP' and w['package_detail']['A1'].value=='STALE_DETAIL'
w.close()
rows=list(csv.reader(Path(Macro.getLocal('csvfile')).open(encoding='utf-8-sig')))
assert [row[1:] for row in rows[2:4]]==[['','.'],['.','']]
md=Path(Macro.getLocal('mdfile')).read_text()
assert '| Exact sequence 1–40 |  | . |' in md and '| id | . |  |' in md
for name,content in _tt_single_before.items():
    assert (Path(Macro.getLocal('root'))/name).read_bytes()==content
end
}

local outcome=_rc
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: single pearson rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: single pearson"
}

**# One observation spearman supported missing results
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37) perturb(stale_sheet)
    local root `"`r(root)'"'
    local output `"`r(path_xlsx)'"'
    mata: st_local("csvfile",st_local("root")+"/single.csv")
    mata: st_local("mdfile",st_local("root")+"/single.md")
    python: _tt_single_before={str(p.relative_to(Path(Macro.getLocal('root')))):p.read_bytes() for p in Path(Macro.getLocal('root')).rglob('*') if p.is_file() and str(p)!=Macro.getLocal('output')}
    qa_fx_a7_labelled, clear seed(37) perturb(single_row)
    qa_state_snapshot, tag(corr_input)
    * expect: EXACT
    corrtab x id, full spearman frame(single_display, replace) xlsx(`"`macval(output)'"') csv(`"`macval(csvfile)'"') markdown(`"`macval(mdfile)'"') sheet(package_summary) title("Single exact")
    tempname cc pp nn
    matrix `cc'=r(C)
    matrix `pp'=r(P)
    matrix `nn'=r(N)
    forvalues i=1/2 {
        forvalues j=1/2 {
            assert missing(`cc'[`i',`j']) & missing(`pp'[`i',`j'])
            assert `nn'[`i',`j']==1
        }
    }
    frame single_display {
        assert c2[3]=="" & c3[3]=="." & c2[4]=="." & c3[4]==""
        assert strpos(c2[3]+c3[3]+c2[4]+c3[4],"*")==0
    }
    matrix drop `cc' `pp' `nn'
    frame drop single_display
    qa_state_compare, tag(corr_input)
    python:
from openpyxl import load_workbook
import csv
w=load_workbook(Macro.getLocal('output'))
t=w['package_summary']
assert [t[c].value or '' for c in ('C3','D3','C4','D4')]==['','.','.','']
assert w['user_notes']['A1'].value=='USER_KEEP' and w['package_detail']['A1'].value=='STALE_DETAIL'
w.close()
rows=list(csv.reader(Path(Macro.getLocal('csvfile')).open(encoding='utf-8-sig')))
assert [row[1:] for row in rows[2:4]]==[['','.'],['.','']]
md=Path(Macro.getLocal('mdfile')).read_text()
assert '| Exact sequence 1–40 |  | . |' in md and '| id | . |  |' in md
for name,content in _tt_single_before.items():
    assert (Path(Macro.getLocal('root'))/name).read_bytes()==content
end
}

local outcome=_rc
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: single spearman rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: single spearman"
}

**# Defined diagonal and undefined pair pearson
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    generate double constant=1
    qa_state_snapshot, tag(corr_input)
    * expect: EXACT
    corrtab x constant, full
    tempname cc pp nn
    matrix `cc'=r(C)
    matrix `pp'=r(P)
    matrix `nn'=r(N)
    assert !missing(`cc'[1,1]) & abs(`cc'[1,1]-1)<1e-12
    assert missing(`cc'[1,2]) & missing(`pp'[1,2]) & `nn'[1,2]==40
    matrix drop `cc' `pp' `nn'
    qa_state_compare, tag(corr_input)
}
local outcome=_rc
if `outcome' {
    local ++fail
    display as error "FAIL: mixed constant pearson rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: mixed constant pearson"
}

**# Defined diagonal and undefined pair spearman
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    generate double constant=1
    qa_state_snapshot, tag(corr_input)
    * expect: EXACT
    corrtab x constant, full spearman
    tempname cc pp nn
    matrix `cc'=r(C)
    matrix `pp'=r(P)
    matrix `nn'=r(N)
    assert !missing(`cc'[1,1]) & abs(`cc'[1,1]-1)<1e-12
    assert missing(`cc'[1,2]) & missing(`pp'[1,2]) & `nn'[1,2]==40
    matrix drop `cc' `pp' `nn'
    qa_state_compare, tag(corr_input)
}
local outcome=_rc
if `outcome' {
    local ++fail
    display as error "FAIL: mixed constant spearman rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: mixed constant spearman"
}

display "RESULT: validation_corrtab_fixture_inputs tests=`tests' pass=`pass' fail=`fail'"
log close _all
if `fail' exit 1
