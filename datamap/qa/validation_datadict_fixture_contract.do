*! validation_datadict_fixture_contract.do -- canonical metadata and actual dictionary content
*! Author: Timothy P Copeland, Karolinska Institutet
version 16
clear all
set more off
capture log close _all
log using "validation_datadict_fixture_contract.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_state.do
local tests 0
local pass 0
local fail 0

**# Dictionary exact friendly
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37)
    local N=_N
    local xm=r(truth_mean)
    local defined=r(truth_x_defined)
    tempfile md metadata
    qa_state_snapshot, tag(dictionary)
    quietly datadict, output("`md'") saving("`metadata'", replace) stats continuous(x) mincell(1)
    assert r(nfiles)==1 & r(nvars_total)==10 & r(nobs_total)==`N'
    assert `"`r(metadata)'"'=="`metadata'"
    qa_state_compare, tag(dictionary)
    preserve
    quietly use "`metadata'", clear
    assert _N==10 & N==`N' & nvars==10 & source=="memory"
    assert mean==`xm' & unique==`N' & missing==0 if variable=="x" & `defined'
    assert missing(mean,min,max) & unique==0 & missing==`N' if variable=="x" & !`defined'
    assert missing(mean,min,max) & unique==0 & missing==`N' if variable=="all_missing"
    assert value_label=="_qa_fx_a7_group" if inlist(variable,"group","shared")
    assert display_format=="%td" if variable=="date"
    restore
    * Numeric truth is pinned in metadata; Markdown must carry the corresponding
    * exact rendered summary, including all-missing rather than a zero mean.
    python: _txt=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("md")).read_text(); assert "| `x` | Exact sequence 1–40 | Numeric |" in _txt; assert "| `all_missing` |  | Numeric | All missing |" in _txt
    python: assert "Mean=20.50 (SD=11.69)" in _txt
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: friendly"
}

**# Dictionary exact unsorted
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    local N=_N
    local xm=r(truth_mean)
    local defined=r(truth_x_defined)
    tempfile md metadata
    qa_state_snapshot, tag(dictionary)
    quietly datadict, output("`md'") saving("`metadata'", replace) stats continuous(x) mincell(1)
    assert r(nfiles)==1 & r(nvars_total)==10 & r(nobs_total)==`N'
    assert `"`r(metadata)'"'=="`metadata'"
    qa_state_compare, tag(dictionary)
    preserve
    quietly use "`metadata'", clear
    assert _N==10 & N==`N' & nvars==10 & source=="memory"
    assert mean==`xm' & unique==`N' & missing==0 if variable=="x" & `defined'
    assert missing(mean,min,max) & unique==0 & missing==`N' if variable=="x" & !`defined'
    assert missing(mean,min,max) & unique==0 & missing==`N' if variable=="all_missing"
    assert value_label=="_qa_fx_a7_group" if inlist(variable,"group","shared")
    assert display_format=="%td" if variable=="date"
    restore
    * Numeric truth is pinned in metadata; Markdown must carry the corresponding
    * exact rendered summary, including all-missing rather than a zero mean.
    python: _txt=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("md")).read_text(); assert "| `x` | Exact sequence 1–40 | Numeric |" in _txt; assert "| `all_missing` |  | Numeric | All missing |" in _txt
    python: assert "Mean=20.50 (SD=11.69)" in _txt
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: unsorted; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: unsorted"
}

**# Dictionary exact label_gaps
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    local N=_N
    local xm=r(truth_mean)
    local defined=r(truth_x_defined)
    tempfile md metadata
    qa_state_snapshot, tag(dictionary)
    quietly datadict, output("`md'") saving("`metadata'", replace) stats continuous(x) mincell(1)
    assert r(nfiles)==1 & r(nvars_total)==10 & r(nobs_total)==`N'
    assert `"`r(metadata)'"'=="`metadata'"
    qa_state_compare, tag(dictionary)
    preserve
    quietly use "`metadata'", clear
    assert _N==10 & N==`N' & nvars==10 & source=="memory"
    assert mean==`xm' & unique==`N' & missing==0 if variable=="x" & `defined'
    assert missing(mean,min,max) & unique==0 & missing==`N' if variable=="x" & !`defined'
    assert missing(mean,min,max) & unique==0 & missing==`N' if variable=="all_missing"
    assert value_label=="_qa_fx_a7_group" if inlist(variable,"group","shared")
    assert display_format=="%td" if variable=="date"
    restore
    * Numeric truth is pinned in metadata; Markdown must carry the corresponding
    * exact rendered summary, including all-missing rather than a zero mean.
    python: _txt=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("md")).read_text(); assert "| `x` | Exact sequence 1–40 | Numeric |" in _txt; assert "| `all_missing` |  | Numeric | All missing |" in _txt
    python: assert "Mean=20.50 (SD=11.69)" in _txt
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: label_gaps; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: label_gaps"
}

**# Dictionary exact single_row
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(single_row)
    local N=_N
    local xm=r(truth_mean)
    local defined=r(truth_x_defined)
    tempfile md metadata
    qa_state_snapshot, tag(dictionary)
    quietly datadict, output("`md'") saving("`metadata'", replace) stats continuous(x) mincell(1)
    assert r(nfiles)==1 & r(nvars_total)==10 & r(nobs_total)==`N'
    assert `"`r(metadata)'"'=="`metadata'"
    qa_state_compare, tag(dictionary)
    preserve
    quietly use "`metadata'", clear
    assert _N==10 & N==`N' & nvars==10 & source=="memory"
    assert mean==`xm' & unique==`N' & missing==0 if variable=="x" & `defined'
    assert missing(mean,min,max) & unique==0 & missing==`N' if variable=="x" & !`defined'
    assert missing(mean,min,max) & unique==0 & missing==`N' if variable=="all_missing"
    assert value_label=="_qa_fx_a7_group" if inlist(variable,"group","shared")
    assert display_format=="%td" if variable=="date"
    restore
    * Numeric truth is pinned in metadata; Markdown must carry the corresponding
    * exact rendered summary, including all-missing rather than a zero mean.
    python: _txt=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("md")).read_text(); assert "| `x` | Exact sequence 1–40 | Numeric |" in _txt; assert "| `all_missing` |  | Numeric | All missing |" in _txt
    python: assert "Mean=1.00" in _txt
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: single_row; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: single_row"
}

**# Dictionary exact miss_all_column
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(miss_all_column)
    local N=_N
    local xm=r(truth_mean)
    local defined=r(truth_x_defined)
    tempfile md metadata
    qa_state_snapshot, tag(dictionary)
    quietly datadict, output("`md'") saving("`metadata'", replace) stats continuous(x) mincell(1)
    assert r(nfiles)==1 & r(nvars_total)==10 & r(nobs_total)==`N'
    assert `"`r(metadata)'"'=="`metadata'"
    qa_state_compare, tag(dictionary)
    preserve
    quietly use "`metadata'", clear
    assert _N==10 & N==`N' & nvars==10 & source=="memory"
    assert mean==`xm' & unique==`N' & missing==0 if variable=="x" & `defined'
    assert missing(mean,min,max) & unique==0 & missing==`N' if variable=="x" & !`defined'
    assert missing(mean,min,max) & unique==0 & missing==`N' if variable=="all_missing"
    assert value_label=="_qa_fx_a7_group" if inlist(variable,"group","shared")
    assert display_format=="%td" if variable=="date"
    restore
    * Numeric truth is pinned in metadata; Markdown must carry the corresponding
    * exact rendered summary, including all-missing rather than a zero mean.
    python: _txt=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("md")).read_text(); assert "| `x` | Exact sequence 1–40 | Numeric |" in _txt; assert "| `all_missing` |  | Numeric | All missing |" in _txt
    python: assert "| `x` | Exact sequence 1–40 | Numeric | All missing |" in _txt
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: miss_all_column; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: miss_all_column"
}

**# Dictionary exact boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(boundary_values)
    local N=_N
    local xm=r(truth_mean)
    local defined=r(truth_x_defined)
    tempfile md metadata
    qa_state_snapshot, tag(dictionary)
    quietly datadict, output("`md'") saving("`metadata'", replace) stats continuous(x) mincell(1)
    assert r(nfiles)==1 & r(nvars_total)==10 & r(nobs_total)==`N'
    assert `"`r(metadata)'"'=="`metadata'"
    qa_state_compare, tag(dictionary)
    preserve
    quietly use "`metadata'", clear
    assert _N==10 & N==`N' & nvars==10 & source=="memory"
    assert mean==`xm' & unique==`N' & missing==0 if variable=="x" & `defined'
    assert missing(mean,min,max) & unique==0 & missing==`N' if variable=="x" & !`defined'
    assert missing(mean,min,max) & unique==0 & missing==`N' if variable=="all_missing"
    assert value_label=="_qa_fx_a7_group" if inlist(variable,"group","shared")
    assert display_format=="%td" if variable=="date"
    restore
    * Numeric truth is pinned in metadata; Markdown must carry the corresponding
    * exact rendered summary, including all-missing rather than a zero mean.
    python: _txt=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("md")).read_text(); assert "| `x` | Exact sequence 1–40 | Numeric |" in _txt; assert "| `all_missing` |  | Numeric | All missing |" in _txt
    python: assert "Mean=20.50 (SD=11.69)" in _txt
}
local outcome=_rc
capture restore
if `outcome' {
    local ++fail
    display as error "FAIL: boundary_values; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: boundary_values"
}

display "RESULT: validation_datadict_fixture_contract tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
