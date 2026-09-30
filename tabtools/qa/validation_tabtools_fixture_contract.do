*! validation_tabtools_fixture_contract.do -- canonical labelled designs and independent contents
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using "validation_tabtools_fixture_contract.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_state.do
local tests 0
local pass 0
local fail 0
java set heapmax 256m
do _qa_fx_a1.do
do _qa_fx_a6.do

**# Sparse labelled crosstab exact friendly
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    tempname truth got
    matrix `truth'=r(truth_cells)
    quietly crosstab group y, label
    matrix `got'=r(table)
    assert r(N)==40 & rowsof(`got')==4 & colsof(`got')==2
    forvalues i=1/`=rowsof(`truth')' {
        local level=`truth'[`i',1]
        local row=rownumb(`got',"`level'")
        assert !missing(`row')
        assert `got'[`row',1]==5 & `got'[`row',2]==5
    }

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Sparse labelled crosstab exact friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Sparse labelled crosstab exact friendly"
}

**# Sparse labelled crosstab exact label_gaps
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempname truth got
    matrix `truth'=r(truth_cells)
    quietly crosstab group y, label
    matrix `got'=r(table)
    assert r(N)==40 & rowsof(`got')==4 & colsof(`got')==2
    forvalues i=1/`=rowsof(`truth')' {
        local level=`truth'[`i',1]
        local row=rownumb(`got',"`level'")
        assert !missing(`row')
        assert `got'[`row',1]==5 & `got'[`row',2]==5
    }

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Sparse labelled crosstab exact label_gaps; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Sparse labelled crosstab exact label_gaps"
}

**# Sparse labelled crosstab exact miss_all_column
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(miss_all_column)
    tempname truth got
    matrix `truth'=r(truth_cells)
    quietly crosstab group y, label
    matrix `got'=r(table)
    assert r(N)==40 & rowsof(`got')==4 & colsof(`got')==2
    forvalues i=1/`=rowsof(`truth')' {
        local level=`truth'[`i',1]
        local row=rownumb(`got',"`level'")
        assert !missing(`row')
        assert `got'[`row',1]==5 & `got'[`row',2]==5
    }

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Sparse labelled crosstab exact miss_all_column; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Sparse labelled crosstab exact miss_all_column"
}

**# Sparse labelled crosstab exact single_row
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(single_row)
    tempname truth got
    matrix `truth'=r(truth_cells)
    quietly crosstab group y, label
    matrix `got'=r(table)
    assert r(N)==1 & rowsof(`got')==1 & colsof(`got')==1
    forvalues i=1/`=rowsof(`truth')' {
        local level=`truth'[`i',1]
        local row=rownumb(`got',"`level'")
        assert !missing(`row')
        assert `got'[1,1]==1
    }

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Sparse labelled crosstab exact single_row; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Sparse labelled crosstab exact single_row"
}

**# Sparse labelled crosstab exact boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(boundary_values)
    tempname truth got
    matrix `truth'=r(truth_cells)
    quietly crosstab group y, label
    matrix `got'=r(table)
    assert r(N)==40 & rowsof(`got')==4 & colsof(`got')==2
    forvalues i=1/`=rowsof(`truth')' {
        local level=`truth'[`i',1]
        local row=rownumb(`got',"`level'")
        assert !missing(`row')
        assert `got'[`row',1]==5 & `got'[`row',2]==5
    }

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Sparse labelled crosstab exact boundary_values; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Sparse labelled crosstab exact boundary_values"
}

**# Sparse labelled crosstab exact unsorted
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    tempname truth got
    matrix `truth'=r(truth_cells)
    quietly crosstab group y, label
    matrix `got'=r(table)
    assert r(N)==40 & rowsof(`got')==4 & colsof(`got')==2
    forvalues i=1/`=rowsof(`truth')' {
        local level=`truth'[`i',1]
        local row=rownumb(`got',"`level'")
        assert !missing(`row')
        assert `got'[`row',1]==5 & `got'[`row',2]==5
    }

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Sparse labelled crosstab exact unsorted; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Sparse labelled crosstab exact unsorted"
}

**# Exact correlation and pairwise N friendly
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    quietly corrtab x id, full spearman
    tempname C N
    matrix `C'=r(C)
    matrix `N'=r(N)
    assert `N'[1,2]==40 & !missing(`C'[1,2],`C'[2,1])
    assert abs(`C'[1,2]-1)<1e-12 & abs(`C'[2,1]-1)<1e-12

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Exact correlation and pairwise N friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Exact correlation and pairwise N friendly"
}

**# Exact correlation and pairwise N label_gaps
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    quietly corrtab x id, full spearman
    tempname C N
    matrix `C'=r(C)
    matrix `N'=r(N)
    assert `N'[1,2]==40 & !missing(`C'[1,2],`C'[2,1])
    assert abs(`C'[1,2]-1)<1e-12 & abs(`C'[2,1]-1)<1e-12

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Exact correlation and pairwise N label_gaps; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Exact correlation and pairwise N label_gaps"
}

**# Exact correlation and pairwise N unsorted
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    quietly corrtab x id, full spearman
    tempname C N
    matrix `C'=r(C)
    matrix `N'=r(N)
    assert `N'[1,2]==40 & !missing(`C'[1,2],`C'[2,1])
    assert abs(`C'[1,2]-1)<1e-12 & abs(`C'[2,1]-1)<1e-12

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Exact correlation and pairwise N unsorted; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Exact correlation and pairwise N unsorted"
}

**# Exact correlation and pairwise N miss_all_column
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(miss_all_column)
    quietly corrtab x id, full spearman
    tempname C N
    matrix `C'=r(C)
    matrix `N'=r(N)
    assert `N'[1,1]==0 & `N'[1,2]==0 & `N'[2,2]==40
    assert missing(`C'[1,1],`C'[1,2]) & `C'[2,2]==1

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Exact correlation and pairwise N miss_all_column; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Exact correlation and pairwise N miss_all_column"
}

**# Exact raw exporters or refused stem friendly
local ++tests
capture noisily {
    local root ""
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local output `"`r(path_xlsx)'"'
    local noext `"`r(path_noext)'"'
    local csv `"`macval(root)'/cells.csv"'
    local md `"`macval(root)'/cells.md"'
    qa_fx_a6_estmat, clear seed(37)
    * expect: EXACT
    quietly puttab b se using `"`macval(output)'"', sheet("package_summary") title("Known cells") csv(`"`macval(csv)'"') markdown(`"`macval(md)'"') digits(2)
    assert r(n_datarows)==3 & r(n_cols)==2
    python: __import__("subprocess").run([__import__("sys").executable,"tools/check_xlsx.py",__import__("sfi").Macro.getLocal("output"),"--sheet","package_summary","--cell","A1","Known cells","--cell","B3","0.50","--cell","C3","0.25","--cell","B4","-1.00","--cell","C4","0.50","--cell","B5","2.00","--cell","C5","1.00"],check=True)
    python: _rows=list(__import__("csv").reader(open(__import__("sfi").Macro.getLocal("csv"),encoding="utf-8"))); assert _rows[2:]==[["0.50","0.25"],["-1.00","0.50"],["2.00","1.00"]]
    python: _md=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("md")).read_text(); assert "| 0.50 | 0.25 |" in _md and "| -1.00 | 0.50 |" in _md and "| 2.00 | 1.00 |" in _md
    python: _w=__import__("openpyxl").load_workbook(__import__("sfi").Macro.getLocal("output")); assert _w["user_notes"]["A1"].value=="USER_KEEP"

}
local outcome=_rc
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Exact raw exporters or refused stem friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Exact raw exporters or refused stem friendly"
}

**# Exact raw exporters or refused stem stale_sheet
local ++tests
capture noisily {
    local root ""
    qa_fx_a7_files, clear seed(37) perturb(stale_sheet)
    local root `"`r(root)'"'
    local output `"`r(path_xlsx)'"'
    local noext `"`r(path_noext)'"'
    local csv `"`macval(root)'/cells.csv"'
    local md `"`macval(root)'/cells.md"'
    qa_fx_a6_estmat, clear seed(37)
    * expect: EXACT
    quietly puttab b se using `"`macval(output)'"', sheet("package_summary") title("Known cells") csv(`"`macval(csv)'"') markdown(`"`macval(md)'"') digits(2)
    assert r(n_datarows)==3 & r(n_cols)==2
    python: __import__("subprocess").run([__import__("sys").executable,"tools/check_xlsx.py",__import__("sfi").Macro.getLocal("output"),"--sheet","package_summary","--cell","A1","Known cells","--cell","B3","0.50","--cell","C3","0.25","--cell","B4","-1.00","--cell","C4","0.50","--cell","B5","2.00","--cell","C5","1.00"],check=True)
    python: _rows=list(__import__("csv").reader(open(__import__("sfi").Macro.getLocal("csv"),encoding="utf-8"))); assert _rows[2:]==[["0.50","0.25"],["-1.00","0.50"],["2.00","1.00"]]
    python: _md=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("md")).read_text(); assert "| 0.50 | 0.25 |" in _md and "| -1.00 | 0.50 |" in _md and "| 2.00 | 1.00 |" in _md
    python: _w=__import__("openpyxl").load_workbook(__import__("sfi").Macro.getLocal("output")); assert _w["user_notes"]["A1"].value=="USER_KEEP"
    python: assert _w["package_detail"]["A1"].value=="STALE_DETAIL"

}
local outcome=_rc
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Exact raw exporters or refused stem stale_sheet; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Exact raw exporters or refused stem stale_sheet"
}

**# Exact raw exporters or refused stem path_noext
local ++tests
capture noisily {
    local root ""
    qa_fx_a7_files, clear seed(37) perturb(path_noext)
    local root `"`r(root)'"'
    local output `"`r(path_xlsx)'"'
    local noext `"`r(path_noext)'"'
    local csv `"`macval(root)'/cells.csv"'
    local md `"`macval(root)'/cells.md"'
    qa_fx_a6_estmat, clear seed(37)
    * expect: REFUSED
    qa_state_snapshot, tag(pt_bad)
    capture noisily puttab b se using `"`macval(noext)'"', title("Known cells")
    assert _rc==198
    qa_state_compare, tag(pt_bad)
    python: assert __import__("pathlib").Path(__import__("sfi").Macro.getLocal("noext")).read_text()=="EXTENSIONLESS_KEEP\n"

}
local outcome=_rc
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Exact raw exporters or refused stem path_noext; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Exact raw exporters or refused stem path_noext"
}

display "RESULT: validation_tabtools_fixture_contract tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
