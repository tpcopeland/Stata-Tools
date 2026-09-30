*! validation_eplot_fixture_contract.do -- exact effect payload across four modes
*! Author: Timothy P Copeland, Karolinska Institutet
* guard: factor estimates without current source variable were red before1.4.3 repair.
version 16.0
clear all
set more off
capture log close _all
log using "validation_eplot_fixture_contract.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _eplot_qa_common.do
do _qa_fx_a6.do
do _qa_state.do
local tests 0
local pass 0
local fail 0

**# data exact named payload friendly
local ++tests
capture noisily {
    qa_fx_a6_estmat, clear seed(37)  
    tempname truth got
    matrix `truth'=r(truth_table)
    quietly eplot b ll ul, labels(term) pvalue(p) name(fxplot, replace)
    matrix `got'=r(table)
    assert r(k)==3 & r(N)==3 & rowsof(`got')==3 & colsof(`got')==3
    forvalues j=1/3 {
        local terms : colnames `truth'
        local term : word `j' of `terms'
        local row=rownumb(`got',"`term'")
        assert !missing(`row')
        assert !missing(`got'[`row',1],`truth'[1,`j'])
        assert abs(`got'[`row',1]-`truth'[1,`j'])<1e-12
        assert abs(`got'[`row',2]-`truth'[3,`j'])<1e-12
        assert abs(`got'[`row',3]-`truth'[4,`j'])<1e-12
    }
    graph drop fxplot

}
if _rc {
    local ++fail
    display as error "FAIL: data exact named payload friendly; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: data exact named payload friendly"
}

**# data exact named payload factor_names
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_estmat, clear seed(37) perturb(factor_names) 
    tempname truth got
    matrix `truth'=r(truth_table)
    quietly eplot b ll ul, labels(term) pvalue(p) name(fxplot, replace)
    matrix `got'=r(table)
    assert r(k)==3 & r(N)==3 & rowsof(`got')==3 & colsof(`got')==3
    forvalues j=1/3 {
        local terms : colnames `truth'
        local term : word `j' of `terms'
        local row=rownumb(`got',"`term'")
        assert !missing(`row')
        assert !missing(`got'[`row',1],`truth'[1,`j'])
        assert abs(`got'[`row',1]-`truth'[1,`j'])<1e-12
        assert abs(`got'[`row',2]-`truth'[3,`j'])<1e-12
        assert abs(`got'[`row',3]-`truth'[4,`j'])<1e-12
    }
    graph drop fxplot

}
if _rc {
    local ++fail
    display as error "FAIL: data exact named payload factor_names; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: data exact named payload factor_names"
}

**# data exact named payload long_row_names
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_estmat, clear seed(37) perturb(long_row_names) 
    tempname truth got
    matrix `truth'=r(truth_table)
    quietly eplot b ll ul, labels(term) pvalue(p) name(fxplot, replace)
    matrix `got'=r(table)
    assert r(k)==3 & r(N)==3 & rowsof(`got')==3 & colsof(`got')==3
    forvalues j=1/3 {
        local terms : colnames `truth'
        local term : word `j' of `terms'
        local row=rownumb(`got',"`term'")
        assert !missing(`row')
        assert !missing(`got'[`row',1],`truth'[1,`j'])
        assert abs(`got'[`row',1]-`truth'[1,`j'])<1e-12
        assert abs(`got'[`row',2]-`truth'[3,`j'])<1e-12
        assert abs(`got'[`row',3]-`truth'[4,`j'])<1e-12
    }
    graph drop fxplot

}
if _rc {
    local ++fail
    display as error "FAIL: data exact named payload long_row_names; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: data exact named payload long_row_names"
}

**# data exact named payload positional_mismatch
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_estmat, clear seed(37) perturb(positional_mismatch) 
    tempname truth got
    matrix `truth'=r(truth_table)
    quietly eplot b ll ul, labels(term) pvalue(p) name(fxplot, replace)
    matrix `got'=r(table)
    assert r(k)==3 & r(N)==3 & rowsof(`got')==3 & colsof(`got')==3
    forvalues j=1/3 {
        local terms : colnames `truth'
        local term : word `j' of `terms'
        local row=rownumb(`got',"`term'")
        assert !missing(`row')
        assert !missing(`got'[`row',1],`truth'[1,`j'])
        assert abs(`got'[`row',1]-`truth'[1,`j'])<1e-12
        assert abs(`got'[`row',2]-`truth'[3,`j'])<1e-12
        assert abs(`got'[`row',3]-`truth'[4,`j'])<1e-12
    }
    graph drop fxplot

}
if _rc {
    local ++fail
    display as error "FAIL: data exact named payload positional_mismatch; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: data exact named payload positional_mismatch"
}

**# data exact named payload boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_estmat, clear seed(37) perturb(boundary_values) 
    tempname truth got
    matrix `truth'=r(truth_table)
    quietly eplot b ll ul, labels(term) pvalue(p) name(fxplot, replace)
    matrix `got'=r(table)
    assert r(k)==3 & r(N)==3 & rowsof(`got')==3 & colsof(`got')==3
    forvalues j=1/3 {
        local terms : colnames `truth'
        local term : word `j' of `terms'
        local row=rownumb(`got',"`term'")
        assert !missing(`row')
        assert !missing(`got'[`row',1],`truth'[1,`j'])
        assert abs(`got'[`row',1]-`truth'[1,`j'])<1e-12
        assert abs(`got'[`row',2]-`truth'[3,`j'])<1e-12
        assert abs(`got'[`row',3]-`truth'[4,`j'])<1e-12
    }
    graph drop fxplot

}
if _rc {
    local ++fail
    display as error "FAIL: data exact named payload boundary_values; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: data exact named payload boundary_values"
}

**# matrix exact named payload friendly
local ++tests
capture noisily {
    qa_fx_a6_estmat, clear seed(37)  
    tempname truth got
    matrix `truth'=r(truth_table)
    tempname input
    matrix `input'=(`truth'[1,1...] \ `truth'[2,1...])'
    quietly eplot, matrix(`input') stars name(fxplot, replace)
    matrix `got'=r(table)
    assert r(k)==3 & r(N)==3 & rowsof(`got')==3 & colsof(`got')==3
    forvalues j=1/3 {
        local terms : colnames `truth'
        local term : word `j' of `terms'
        local row=rownumb(`got',"`term'")
        assert !missing(`row')
        assert !missing(`got'[`row',1],`truth'[1,`j'])
        assert abs(`got'[`row',1]-`truth'[1,`j'])<1e-12
        assert abs(`got'[`row',2]-`truth'[3,`j'])<1e-12
        assert abs(`got'[`row',3]-`truth'[4,`j'])<1e-12
    }
    graph drop fxplot

}
if _rc {
    local ++fail
    display as error "FAIL: matrix exact named payload friendly; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: matrix exact named payload friendly"
}

**# matrix exact named payload factor_names
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_estmat, clear seed(37) perturb(factor_names) 
    tempname truth got
    matrix `truth'=r(truth_table)
    tempname input
    matrix `input'=(`truth'[1,1...] \ `truth'[2,1...])'
    quietly eplot, matrix(`input') stars name(fxplot, replace)
    matrix `got'=r(table)
    assert r(k)==3 & r(N)==3 & rowsof(`got')==3 & colsof(`got')==3
    forvalues j=1/3 {
        local terms : colnames `truth'
        local term : word `j' of `terms'
        local row=rownumb(`got',"`term'")
        assert !missing(`row')
        assert !missing(`got'[`row',1],`truth'[1,`j'])
        assert abs(`got'[`row',1]-`truth'[1,`j'])<1e-12
        assert abs(`got'[`row',2]-`truth'[3,`j'])<1e-12
        assert abs(`got'[`row',3]-`truth'[4,`j'])<1e-12
    }
    graph drop fxplot

}
if _rc {
    local ++fail
    display as error "FAIL: matrix exact named payload factor_names; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: matrix exact named payload factor_names"
}

**# matrix exact named payload long_row_names
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_estmat, clear seed(37) perturb(long_row_names) 
    tempname truth got
    matrix `truth'=r(truth_table)
    tempname input
    matrix `input'=(`truth'[1,1...] \ `truth'[2,1...])'
    quietly eplot, matrix(`input') stars name(fxplot, replace)
    matrix `got'=r(table)
    assert r(k)==3 & r(N)==3 & rowsof(`got')==3 & colsof(`got')==3
    forvalues j=1/3 {
        local terms : colnames `truth'
        local term : word `j' of `terms'
        local row=rownumb(`got',"`term'")
        assert !missing(`row')
        assert !missing(`got'[`row',1],`truth'[1,`j'])
        assert abs(`got'[`row',1]-`truth'[1,`j'])<1e-12
        assert abs(`got'[`row',2]-`truth'[3,`j'])<1e-12
        assert abs(`got'[`row',3]-`truth'[4,`j'])<1e-12
    }
    graph drop fxplot

}
if _rc {
    local ++fail
    display as error "FAIL: matrix exact named payload long_row_names; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: matrix exact named payload long_row_names"
}

**# matrix exact named payload positional_mismatch
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_estmat, clear seed(37) perturb(positional_mismatch) 
    tempname truth got
    matrix `truth'=r(truth_table)
    tempname input
    matrix `input'=(`truth'[1,1...] \ `truth'[2,1...])'
    quietly eplot, matrix(`input') stars name(fxplot, replace)
    matrix `got'=r(table)
    assert r(k)==3 & r(N)==3 & rowsof(`got')==3 & colsof(`got')==3
    forvalues j=1/3 {
        local terms : colnames `truth'
        local term : word `j' of `terms'
        local row=rownumb(`got',"`term'")
        assert !missing(`row')
        assert !missing(`got'[`row',1],`truth'[1,`j'])
        assert abs(`got'[`row',1]-`truth'[1,`j'])<1e-12
        assert abs(`got'[`row',2]-`truth'[3,`j'])<1e-12
        assert abs(`got'[`row',3]-`truth'[4,`j'])<1e-12
    }
    graph drop fxplot

}
if _rc {
    local ++fail
    display as error "FAIL: matrix exact named payload positional_mismatch; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: matrix exact named payload positional_mismatch"
}

**# matrix exact named payload boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_estmat, clear seed(37) perturb(boundary_values) 
    tempname truth got
    matrix `truth'=r(truth_table)
    tempname input
    matrix `input'=(`truth'[1,1...] \ `truth'[2,1...])'
    quietly eplot, matrix(`input') stars name(fxplot, replace)
    matrix `got'=r(table)
    assert r(k)==3 & r(N)==3 & rowsof(`got')==3 & colsof(`got')==3
    forvalues j=1/3 {
        local terms : colnames `truth'
        local term : word `j' of `terms'
        local row=rownumb(`got',"`term'")
        assert !missing(`row')
        assert !missing(`got'[`row',1],`truth'[1,`j'])
        assert abs(`got'[`row',1]-`truth'[1,`j'])<1e-12
        assert abs(`got'[`row',2]-`truth'[3,`j'])<1e-12
        assert abs(`got'[`row',3]-`truth'[4,`j'])<1e-12
    }
    graph drop fxplot

}
if _rc {
    local ++fail
    display as error "FAIL: matrix exact named payload boundary_values; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: matrix exact named payload boundary_values"
}

**# estimates exact named payload friendly
local ++tests
capture noisily {
    qa_fx_a6_estmat, clear seed(37)  post
    tempname truth got
    matrix `truth'=r(truth_table)
    quietly eplot, stars name(fxplot, replace)
    matrix `got'=r(table)
    assert r(k)==3 & r(N)==3 & rowsof(`got')==3 & colsof(`got')==3
    forvalues j=1/3 {
        local terms : colnames `truth'
        local term : word `j' of `terms'
        local row=rownumb(`got',"`term'")
        assert !missing(`row')
        assert !missing(`got'[`row',1],`truth'[1,`j'])
        assert abs(`got'[`row',1]-`truth'[1,`j'])<1e-12
        assert abs(`got'[`row',2]-`truth'[3,`j'])<1e-12
        assert abs(`got'[`row',3]-`truth'[4,`j'])<1e-12
    }
    graph drop fxplot

}
if _rc {
    local ++fail
    display as error "FAIL: estimates exact named payload friendly; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: estimates exact named payload friendly"
}

**# estimates exact named payload factor_names
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_estmat, clear seed(37) perturb(factor_names) post
    tempname truth got
    matrix `truth'=r(truth_table)
    quietly eplot, stars name(fxplot, replace)
    matrix `got'=r(table)
    assert r(k)==3 & r(N)==3 & rowsof(`got')==3 & colsof(`got')==3
    forvalues j=1/3 {
        local terms : colnames `truth'
        local term : word `j' of `terms'
        local row=rownumb(`got',"`term'")
        assert !missing(`row')
        assert !missing(`got'[`row',1],`truth'[1,`j'])
        assert abs(`got'[`row',1]-`truth'[1,`j'])<1e-12
        assert abs(`got'[`row',2]-`truth'[3,`j'])<1e-12
        assert abs(`got'[`row',3]-`truth'[4,`j'])<1e-12
    }
    graph drop fxplot

}
if _rc {
    local ++fail
    display as error "FAIL: estimates exact named payload factor_names; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: estimates exact named payload factor_names"
}

**# estimates exact named payload long_row_names
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_estmat, clear seed(37) perturb(long_row_names) post
    tempname truth got
    matrix `truth'=r(truth_table)
    quietly eplot, stars name(fxplot, replace)
    matrix `got'=r(table)
    assert r(k)==3 & r(N)==3 & rowsof(`got')==3 & colsof(`got')==3
    forvalues j=1/3 {
        local terms : colnames `truth'
        local term : word `j' of `terms'
        local row=rownumb(`got',"`term'")
        assert !missing(`row')
        assert !missing(`got'[`row',1],`truth'[1,`j'])
        assert abs(`got'[`row',1]-`truth'[1,`j'])<1e-12
        assert abs(`got'[`row',2]-`truth'[3,`j'])<1e-12
        assert abs(`got'[`row',3]-`truth'[4,`j'])<1e-12
    }
    graph drop fxplot

}
if _rc {
    local ++fail
    display as error "FAIL: estimates exact named payload long_row_names; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: estimates exact named payload long_row_names"
}

**# estimates exact named payload positional_mismatch
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_estmat, clear seed(37) perturb(positional_mismatch) post
    tempname truth got
    matrix `truth'=r(truth_table)
    quietly eplot, stars name(fxplot, replace)
    matrix `got'=r(table)
    assert r(k)==3 & r(N)==3 & rowsof(`got')==3 & colsof(`got')==3
    forvalues j=1/3 {
        local terms : colnames `truth'
        local term : word `j' of `terms'
        local row=rownumb(`got',"`term'")
        assert !missing(`row')
        assert !missing(`got'[`row',1],`truth'[1,`j'])
        assert abs(`got'[`row',1]-`truth'[1,`j'])<1e-12
        assert abs(`got'[`row',2]-`truth'[3,`j'])<1e-12
        assert abs(`got'[`row',3]-`truth'[4,`j'])<1e-12
    }
    graph drop fxplot

}
if _rc {
    local ++fail
    display as error "FAIL: estimates exact named payload positional_mismatch; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: estimates exact named payload positional_mismatch"
}

**# estimates exact named payload boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_estmat, clear seed(37) perturb(boundary_values) post
    tempname truth got
    matrix `truth'=r(truth_table)
    quietly eplot, stars name(fxplot, replace)
    matrix `got'=r(table)
    assert r(k)==3 & r(N)==3 & rowsof(`got')==3 & colsof(`got')==3
    forvalues j=1/3 {
        local terms : colnames `truth'
        local term : word `j' of `terms'
        local row=rownumb(`got',"`term'")
        assert !missing(`row')
        assert !missing(`got'[`row',1],`truth'[1,`j'])
        assert abs(`got'[`row',1]-`truth'[1,`j'])<1e-12
        assert abs(`got'[`row',2]-`truth'[3,`j'])<1e-12
        assert abs(`got'[`row',3]-`truth'[4,`j'])<1e-12
    }
    graph drop fxplot

}
if _rc {
    local ++fail
    display as error "FAIL: estimates exact named payload boundary_values; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: estimates exact named payload boundary_values"
}

**# frame exact named payload friendly
local ++tests
capture noisily {
    qa_fx_a6_estmat, clear seed(37)  
    tempname truth got
    matrix `truth'=r(truth_table)
    capture frame drop fx_input
    frame put b ll ul term p, into(fx_input)
    quietly eplot, frame(fx_input) estimate(b) ll(ll) ul(ul) labels(term) pvalue(p) name(fxplot, replace)
    frame drop fx_input
    matrix `got'=r(table)
    assert r(k)==3 & r(N)==3 & rowsof(`got')==3 & colsof(`got')==3
    forvalues j=1/3 {
        local terms : colnames `truth'
        local term : word `j' of `terms'
        local row=rownumb(`got',"`term'")
        assert !missing(`row')
        assert !missing(`got'[`row',1],`truth'[1,`j'])
        assert abs(`got'[`row',1]-`truth'[1,`j'])<1e-12
        assert abs(`got'[`row',2]-`truth'[3,`j'])<1e-12
        assert abs(`got'[`row',3]-`truth'[4,`j'])<1e-12
    }
    graph drop fxplot

}
if _rc {
    local ++fail
    display as error "FAIL: frame exact named payload friendly; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: frame exact named payload friendly"
}

**# frame exact named payload factor_names
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_estmat, clear seed(37) perturb(factor_names) 
    tempname truth got
    matrix `truth'=r(truth_table)
    capture frame drop fx_input
    frame put b ll ul term p, into(fx_input)
    quietly eplot, frame(fx_input) estimate(b) ll(ll) ul(ul) labels(term) pvalue(p) name(fxplot, replace)
    frame drop fx_input
    matrix `got'=r(table)
    assert r(k)==3 & r(N)==3 & rowsof(`got')==3 & colsof(`got')==3
    forvalues j=1/3 {
        local terms : colnames `truth'
        local term : word `j' of `terms'
        local row=rownumb(`got',"`term'")
        assert !missing(`row')
        assert !missing(`got'[`row',1],`truth'[1,`j'])
        assert abs(`got'[`row',1]-`truth'[1,`j'])<1e-12
        assert abs(`got'[`row',2]-`truth'[3,`j'])<1e-12
        assert abs(`got'[`row',3]-`truth'[4,`j'])<1e-12
    }
    graph drop fxplot

}
if _rc {
    local ++fail
    display as error "FAIL: frame exact named payload factor_names; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: frame exact named payload factor_names"
}

**# frame exact named payload long_row_names
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_estmat, clear seed(37) perturb(long_row_names) 
    tempname truth got
    matrix `truth'=r(truth_table)
    capture frame drop fx_input
    frame put b ll ul term p, into(fx_input)
    quietly eplot, frame(fx_input) estimate(b) ll(ll) ul(ul) labels(term) pvalue(p) name(fxplot, replace)
    frame drop fx_input
    matrix `got'=r(table)
    assert r(k)==3 & r(N)==3 & rowsof(`got')==3 & colsof(`got')==3
    forvalues j=1/3 {
        local terms : colnames `truth'
        local term : word `j' of `terms'
        local row=rownumb(`got',"`term'")
        assert !missing(`row')
        assert !missing(`got'[`row',1],`truth'[1,`j'])
        assert abs(`got'[`row',1]-`truth'[1,`j'])<1e-12
        assert abs(`got'[`row',2]-`truth'[3,`j'])<1e-12
        assert abs(`got'[`row',3]-`truth'[4,`j'])<1e-12
    }
    graph drop fxplot

}
if _rc {
    local ++fail
    display as error "FAIL: frame exact named payload long_row_names; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: frame exact named payload long_row_names"
}

**# frame exact named payload positional_mismatch
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_estmat, clear seed(37) perturb(positional_mismatch) 
    tempname truth got
    matrix `truth'=r(truth_table)
    capture frame drop fx_input
    frame put b ll ul term p, into(fx_input)
    quietly eplot, frame(fx_input) estimate(b) ll(ll) ul(ul) labels(term) pvalue(p) name(fxplot, replace)
    frame drop fx_input
    matrix `got'=r(table)
    assert r(k)==3 & r(N)==3 & rowsof(`got')==3 & colsof(`got')==3
    forvalues j=1/3 {
        local terms : colnames `truth'
        local term : word `j' of `terms'
        local row=rownumb(`got',"`term'")
        assert !missing(`row')
        assert !missing(`got'[`row',1],`truth'[1,`j'])
        assert abs(`got'[`row',1]-`truth'[1,`j'])<1e-12
        assert abs(`got'[`row',2]-`truth'[3,`j'])<1e-12
        assert abs(`got'[`row',3]-`truth'[4,`j'])<1e-12
    }
    graph drop fxplot

}
if _rc {
    local ++fail
    display as error "FAIL: frame exact named payload positional_mismatch; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: frame exact named payload positional_mismatch"
}

**# frame exact named payload boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_estmat, clear seed(37) perturb(boundary_values) 
    tempname truth got
    matrix `truth'=r(truth_table)
    capture frame drop fx_input
    frame put b ll ul term p, into(fx_input)
    quietly eplot, frame(fx_input) estimate(b) ll(ll) ul(ul) labels(term) pvalue(p) name(fxplot, replace)
    frame drop fx_input
    matrix `got'=r(table)
    assert r(k)==3 & r(N)==3 & rowsof(`got')==3 & colsof(`got')==3
    forvalues j=1/3 {
        local terms : colnames `truth'
        local term : word `j' of `terms'
        local row=rownumb(`got',"`term'")
        assert !missing(`row')
        assert !missing(`got'[`row',1],`truth'[1,`j'])
        assert abs(`got'[`row',1]-`truth'[1,`j'])<1e-12
        assert abs(`got'[`row',2]-`truth'[3,`j'])<1e-12
        assert abs(`got'[`row',3]-`truth'[4,`j'])<1e-12
    }
    graph drop fxplot

}
if _rc {
    local ++fail
    display as error "FAIL: frame exact named payload boundary_values; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: frame exact named payload boundary_values"
}

**# matrix missing bound refusal missing_se
local ++tests
capture noisily {
    * expect: REFUSED
    qa_fx_a6_estmat, clear seed(37) perturb(missing_se)
    tempname truth input
    matrix `truth'=r(truth_table)
    matrix `input'=(`truth'[1,1...] \ `truth'[3,1...] \ `truth'[4,1...])'
    qa_state_snapshot, tag(ep_refused)
    capture noisily eplot, matrix(`input') name(fxplot, replace)
    local refusal=_rc
    assert `refusal'==198
    qa_state_compare, tag(ep_refused)

}
if _rc {
    local ++fail
    display as error "FAIL: matrix missing bound refusal missing_se; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: matrix missing bound refusal missing_se"
}

**# matrix missing bound refusal infinite_ci
local ++tests
capture noisily {
    * expect: REFUSED
    qa_fx_a6_estmat, clear seed(37) perturb(infinite_ci)
    tempname truth input
    matrix `truth'=r(truth_table)
    matrix `input'=(`truth'[1,1...] \ `truth'[3,1...] \ `truth'[4,1...])'
    qa_state_snapshot, tag(ep_refused)
    capture noisily eplot, matrix(`input') name(fxplot, replace)
    local refusal=_rc
    assert `refusal'==198
    qa_state_compare, tag(ep_refused)

}
if _rc {
    local ++fail
    display as error "FAIL: matrix missing bound refusal infinite_ci; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: matrix missing bound refusal infinite_ci"
}

**# Stored estimate after clearing source data friendly
local ++tests
capture noisily {
    qa_fx_a6_estmat, clear seed(37)  post
    tempname truth got
    matrix `truth'=r(truth_table)
    estimates store fxstored
    clear
    quietly eplot fxstored, name(fxplot, replace)
    matrix `got'=r(table)
    assert rowsof(`got')==3
    local terms : colnames `truth'
    forvalues j=1/3 {
        local term : word `j' of `terms'
        local row=rownumb(`got',"`term'")
        assert !missing(`row')
        assert abs(`got'[`row',1]-`truth'[1,`j'])<1e-12
        assert abs(`got'[`row',2]-`truth'[3,`j'])<1e-12
        assert abs(`got'[`row',3]-`truth'[4,`j'])<1e-12
    }
    graph drop fxplot
    estimates drop fxstored

}
if _rc {
    local ++fail
    display as error "FAIL: Stored estimate after clearing source data friendly; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Stored estimate after clearing source data friendly"
}

**# Stored estimate after clearing source data factor_names
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_estmat, clear seed(37) perturb(factor_names) post
    tempname truth got
    matrix `truth'=r(truth_table)
    estimates store fxstored
    clear
    quietly eplot fxstored, name(fxplot, replace)
    matrix `got'=r(table)
    assert rowsof(`got')==3
    local terms : colnames `truth'
    forvalues j=1/3 {
        local term : word `j' of `terms'
        local row=rownumb(`got',"`term'")
        assert !missing(`row')
        assert abs(`got'[`row',1]-`truth'[1,`j'])<1e-12
        assert abs(`got'[`row',2]-`truth'[3,`j'])<1e-12
        assert abs(`got'[`row',3]-`truth'[4,`j'])<1e-12
    }
    graph drop fxplot
    estimates drop fxstored

}
if _rc {
    local ++fail
    display as error "FAIL: Stored estimate after clearing source data factor_names; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Stored estimate after clearing source data factor_names"
}

**# Stored estimate after clearing source data long_row_names
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a6_estmat, clear seed(37) perturb(long_row_names) post
    tempname truth got
    matrix `truth'=r(truth_table)
    estimates store fxstored
    clear
    quietly eplot fxstored, name(fxplot, replace)
    matrix `got'=r(table)
    assert rowsof(`got')==3
    local terms : colnames `truth'
    forvalues j=1/3 {
        local term : word `j' of `terms'
        local row=rownumb(`got',"`term'")
        assert !missing(`row')
        assert abs(`got'[`row',1]-`truth'[1,`j'])<1e-12
        assert abs(`got'[`row',2]-`truth'[3,`j'])<1e-12
        assert abs(`got'[`row',3]-`truth'[4,`j'])<1e-12
    }
    graph drop fxplot
    estimates drop fxstored

}
if _rc {
    local ++fail
    display as error "FAIL: Stored estimate after clearing source data long_row_names; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Stored estimate after clearing source data long_row_names"
}

**# Available factor value label path unchanged
local ++tests
capture noisily {
    qa_fx_a6_estmat, clear seed(37) post
    quietly generate byte group=2
    label define fx_group 2 "Second category", replace
    label values group fx_group
    quietly eplot, name(fxplot, replace)
    tempname got
    matrix `got'=r(table)
    assert rownumb(`got',"Second category")<.
    assert strpos(`"`r(cmd)'"',"Second category")>0
    assert abs(`got'[rownumb(`got',"Second category"),1]+1)<1e-12
    graph drop fxplot

}
if _rc {
    local ++fail
    display as error "FAIL: Available factor value label path unchanged; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Available factor value label path unchanged"
}

**# Factor identity keeps case and32character last-byte twins
local ++tests
capture noisily {
    qa_fx_a6_estmat, clear seed(37)
    tempname B V truth got
    matrix Bfx=r(b)
    matrix Vfx=r(V)
    matrix colnames Bfx=2.abcdefghijklmnopqrstuvwxyzabcdeA 2.abcdefghijklmnopqrstuvwxyzabcdeB 2.GROUP
    matrix colnames Vfx=2.abcdefghijklmnopqrstuvwxyzabcdeA 2.abcdefghijklmnopqrstuvwxyzabcdeB 2.GROUP
    matrix rownames Vfx=2.abcdefghijklmnopqrstuvwxyzabcdeA 2.abcdefghijklmnopqrstuvwxyzabcdeB 2.GROUP
    _qa_fxa6_post Bfx Vfx 0
    quietly eplot, name(fxplot, replace)
    matrix `got'=r(table)
    local a=rownumb(`got',"2.abcdefghijklmnopqrstuvwxyzabcdeA")
    local b=rownumb(`got',"2.abcdefghijklmnopqrstuvwxyzabcdeB")
    local c=rownumb(`got',"2.GROUP")
    assert !missing(`a',`b',`c') & `a'!=`b' & `b'!=`c'
    assert `got'[`a',1]==.5 & `got'[`b',1]==-1 & `got'[`c',1]==2
    graph drop fxplot
    matrix drop Bfx Vfx

}
if _rc {
    local ++fail
    display as error "FAIL: Factor identity keeps case and32character last-byte twins; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Factor identity keeps case and32character last-byte twins"
}

**# Case-sensitive factor twins preserve separate effects after store/clear
local ++tests
capture noisily {
    qa_fx_a6_estmat, clear seed(37)
    tempname B V got
    matrix `B'=r(b)
    matrix `V'=r(V)
    matrix colnames `B'=2.group 2.GROUP _cons
    matrix colnames `V'=2.group 2.GROUP _cons
    matrix rownames `V'=2.group 2.GROUP _cons
    _qa_fxa6_post `B' `V' 0
    estimates store fxcase
    clear
    quietly eplot fxcase, name(fxplot, replace)
    matrix `got'=r(table)
    local lower=rownumb(`got',"2.group")
    local upper=rownumb(`got',"2.GROUP")
    assert !missing(`lower',`upper') & `lower'!=`upper'
    assert `got'[`lower',1]==.5 & `got'[`upper',1]==-1
    graph drop fxplot
    estimates drop fxcase
}
if _rc {
    local ++fail
    display as error "FAIL: Case-sensitive factor twins; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: Case-sensitive factor twins"
}

_eplot_qa_result validation_eplot_fixture_contract, tests(`tests') pass(`pass') fail(`fail') skip(0)
log close
if `fail' exit 1
