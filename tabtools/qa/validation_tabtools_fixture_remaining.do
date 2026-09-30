*! validation_tabtools_fixture_remaining.do -- canonical labelled designs and independent contents
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using "validation_tabtools_fixture_remaining.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_state.do
do _qa_hostile.do
local tests 0
local pass 0
local fail 0
do _qa_fx_a6.do
java set heapmax 256m
* Explicit LABELLED-to-survival adapter: every failure at1, censoring at2.
* Canonical groups each have5 events/10 people, total time15; KM=.5,
* RMST(2)=1.5. Native [ST] sts and strate manuals fetched2026-09-30:
* https://www.stata.com/manuals/ststs.pdf and /ststrate.pdf

**# survtab exact friendly
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    tempname display rates model companion composite
    tempfile source
    tempvar follow
    generate double `follow'=1+(y==0)
    quietly stset `follow', failure(y) id(id)
    qa_state_snapshot, tag(tt_remaining)
    quietly survtab, times(.5 1 2) by(group) rmst(2) events riskset frame(`display') timeunit(days) digits(6) pdp(10) highpdp(10) level(90)
    matrix `rates'=r(table)
    assert r(n_groups)==4 & r(N_rows)==13 & r(ci_level)==90
    assert r(logrank_p)==1 & r(logrank_chi2)==0
    assert rowsof(`rates')==3 & colsof(`rates')==4
    forvalues j=1/4 {
        assert !missing(`rates'[1,`j'],`rates'[2,`j'],`rates'[3,`j'])
        assert `rates'[1,`j']==1 & `rates'[2,`j']==.5 & `rates'[3,`j']==.5
        assert r(events_`j')==5 & r(atrisk_`j')==10
        assert abs(r(rmst_`j')-1.5)<1e-14 & abs(r(rmst_se_`j')-sqrt(.025))<1e-14
    }
    frame `display': assert _N==13
    frame drop `display'
    capture matrix drop `rates'
    qa_state_compare, tag(tt_remaining)

}
local outcome=_rc
capture erase "`source'.dta"
foreach f in display model companion composite {
    capture frame drop ``f''
}
if `outcome' {
    local ++fail
    display as error "FAIL: survtab exact friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: survtab exact friendly"
}

**# survtab exact unsorted
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    tempname display rates model companion composite
    tempfile source
    tempvar follow
    generate double `follow'=1+(y==0)
    quietly stset `follow', failure(y) id(id)
    qa_state_snapshot, tag(tt_remaining)
    quietly survtab, times(.5 1 2) by(group) rmst(2) events riskset frame(`display') timeunit(days) digits(6) pdp(10) highpdp(10) level(90)
    matrix `rates'=r(table)
    assert r(n_groups)==4 & r(N_rows)==13 & r(ci_level)==90
    assert r(logrank_p)==1 & r(logrank_chi2)==0
    assert rowsof(`rates')==3 & colsof(`rates')==4
    forvalues j=1/4 {
        assert !missing(`rates'[1,`j'],`rates'[2,`j'],`rates'[3,`j'])
        assert `rates'[1,`j']==1 & `rates'[2,`j']==.5 & `rates'[3,`j']==.5
        assert r(events_`j')==5 & r(atrisk_`j')==10
        assert abs(r(rmst_`j')-1.5)<1e-14 & abs(r(rmst_se_`j')-sqrt(.025))<1e-14
    }
    frame `display': assert _N==13
    frame drop `display'
    capture matrix drop `rates'
    qa_state_compare, tag(tt_remaining)

}
local outcome=_rc
capture erase "`source'.dta"
foreach f in display model companion composite {
    capture frame drop ``f''
}
if `outcome' {
    local ++fail
    display as error "FAIL: survtab exact unsorted; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: survtab exact unsorted"
}

**# survtab exact label_gaps
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempname display rates model companion composite
    tempfile source
    tempvar follow
    generate double `follow'=1+(y==0)
    quietly stset `follow', failure(y) id(id)
    qa_state_snapshot, tag(tt_remaining)
    quietly survtab, times(.5 1 2) by(group) rmst(2) events riskset frame(`display') timeunit(days) digits(6) pdp(10) highpdp(10) level(90)
    matrix `rates'=r(table)
    assert r(n_groups)==4 & r(N_rows)==13 & r(ci_level)==90
    assert r(logrank_p)==1 & r(logrank_chi2)==0
    assert rowsof(`rates')==3 & colsof(`rates')==4
    forvalues j=1/4 {
        assert !missing(`rates'[1,`j'],`rates'[2,`j'],`rates'[3,`j'])
        assert `rates'[1,`j']==1 & `rates'[2,`j']==.5 & `rates'[3,`j']==.5
        assert r(events_`j')==5 & r(atrisk_`j')==10
        assert abs(r(rmst_`j')-1.5)<1e-14 & abs(r(rmst_se_`j')-sqrt(.025))<1e-14
    }
    frame `display': assert _N==13
    frame drop `display'
    capture matrix drop `rates'
    qa_state_compare, tag(tt_remaining)

}
local outcome=_rc
capture erase "`source'.dta"
foreach f in display model companion composite {
    capture frame drop ``f''
}
if `outcome' {
    local ++fail
    display as error "FAIL: survtab exact label_gaps; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: survtab exact label_gaps"
}

**# survtab exact boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(boundary_values)
    tempname display rates model companion composite
    tempfile source
    tempvar follow
    generate double `follow'=1+(y==0)
    quietly stset `follow', failure(y) id(id)
    qa_state_snapshot, tag(tt_remaining)
    quietly survtab, times(.5 1 2) by(group) rmst(2) events riskset frame(`display') timeunit(days) digits(6) pdp(10) highpdp(10) level(90)
    matrix `rates'=r(table)
    assert r(n_groups)==4 & r(N_rows)==13 & r(ci_level)==90
    assert r(logrank_p)==1 & r(logrank_chi2)==0
    assert rowsof(`rates')==3 & colsof(`rates')==4
    forvalues j=1/4 {
        assert !missing(`rates'[1,`j'],`rates'[2,`j'],`rates'[3,`j'])
        assert `rates'[1,`j']==1 & `rates'[2,`j']==.5 & `rates'[3,`j']==.5
        assert r(events_`j')==5 & r(atrisk_`j')==10
        assert abs(r(rmst_`j')-1.5)<1e-14 & abs(r(rmst_se_`j')-sqrt(.025))<1e-14
    }
    frame `display': assert _N==13
    frame drop `display'
    capture matrix drop `rates'
    qa_state_compare, tag(tt_remaining)

}
local outcome=_rc
capture erase "`source'.dta"
foreach f in display model companion composite {
    capture frame drop ``f''
}
if `outcome' {
    local ++fail
    display as error "FAIL: survtab exact boundary_values; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: survtab exact boundary_values"
}

**# stratetab exact friendly
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    tempname display rates model companion composite
    tempfile source
    tempvar follow
    generate double `follow'=1+(y==0)
    quietly stset `follow', failure(y) id(id)
    * Native artefact contains exact5events/15time in each canonical group.
    * Native source is independently checked before formatting consumes it.
    quietly strate group, per(1) output(`source'.dta, replace)
    preserve
    quietly use "`source'.dta", clear
    assert _N==4 & _D==5 & _Y==15
    assert abs(_Rate-1/3)<1e-14
    assert abs(_Lower-exp(ln(1/3)-invnormal(.975)/sqrt(5)))<1e-14
    assert abs(_Upper-exp(ln(1/3)+invnormal(.975)/sqrt(5)))<1e-14
    restore
    qa_state_snapshot, tag(tt_remaining)
    quietly stratetab, using(`source') outcomes(1) frame(`display') outcomeids(y) outlabels("Outcome") explabels("Exposure") digits(6) eventdigits(0) pydigits(2) pyscale(1) ratescale(1000) ratiodigits(10)
    matrix `rates'=r(rates)
    assert rowsof(`rates')==4 & colsof(`rates')==1
    assert r(N_rows)==8 & r(N_outcomes)==1 & r(N_exposures)==1
    forvalues j=1/4 {
        assert !missing(`rates'[`j',1]) & abs(`rates'[`j',1]-1000/3)<1e-10
        frame `display': assert c2[`j'+4]=="5" & c3[`j'+4]=="15.00"
        frame `display': assert c4[`j'+4]=="333.333333 (138.742604, 800.843487)"
    }
    frame drop `display'
    capture matrix drop `rates'
    qa_state_compare, tag(tt_remaining)

}
local outcome=_rc
capture erase "`source'.dta"
foreach f in display model companion composite {
    capture frame drop ``f''
}
if `outcome' {
    local ++fail
    display as error "FAIL: stratetab exact friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: stratetab exact friendly"
}

**# stratetab exact unsorted
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    tempname display rates model companion composite
    tempfile source
    tempvar follow
    generate double `follow'=1+(y==0)
    quietly stset `follow', failure(y) id(id)
    * Native artefact contains exact5events/15time in each canonical group.
    * Native source is independently checked before formatting consumes it.
    quietly strate group, per(1) output(`source'.dta, replace)
    preserve
    quietly use "`source'.dta", clear
    assert _N==4 & _D==5 & _Y==15
    assert abs(_Rate-1/3)<1e-14
    assert abs(_Lower-exp(ln(1/3)-invnormal(.975)/sqrt(5)))<1e-14
    assert abs(_Upper-exp(ln(1/3)+invnormal(.975)/sqrt(5)))<1e-14
    restore
    qa_state_snapshot, tag(tt_remaining)
    quietly stratetab, using(`source') outcomes(1) frame(`display') outcomeids(y) outlabels("Outcome") explabels("Exposure") digits(6) eventdigits(0) pydigits(2) pyscale(1) ratescale(1000) ratiodigits(10)
    matrix `rates'=r(rates)
    assert rowsof(`rates')==4 & colsof(`rates')==1
    assert r(N_rows)==8 & r(N_outcomes)==1 & r(N_exposures)==1
    forvalues j=1/4 {
        assert !missing(`rates'[`j',1]) & abs(`rates'[`j',1]-1000/3)<1e-10
        frame `display': assert c2[`j'+4]=="5" & c3[`j'+4]=="15.00"
        frame `display': assert c4[`j'+4]=="333.333333 (138.742604, 800.843487)"
    }
    frame drop `display'
    capture matrix drop `rates'
    qa_state_compare, tag(tt_remaining)

}
local outcome=_rc
capture erase "`source'.dta"
foreach f in display model companion composite {
    capture frame drop ``f''
}
if `outcome' {
    local ++fail
    display as error "FAIL: stratetab exact unsorted; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: stratetab exact unsorted"
}

**# stratetab exact label_gaps
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempname display rates model companion composite
    tempfile source
    tempvar follow
    generate double `follow'=1+(y==0)
    quietly stset `follow', failure(y) id(id)
    * Native artefact contains exact5events/15time in each canonical group.
    * Native source is independently checked before formatting consumes it.
    quietly strate group, per(1) output(`source'.dta, replace)
    preserve
    quietly use "`source'.dta", clear
    assert _N==4 & _D==5 & _Y==15
    assert abs(_Rate-1/3)<1e-14
    assert abs(_Lower-exp(ln(1/3)-invnormal(.975)/sqrt(5)))<1e-14
    assert abs(_Upper-exp(ln(1/3)+invnormal(.975)/sqrt(5)))<1e-14
    restore
    qa_state_snapshot, tag(tt_remaining)
    * expect: REFUSED
    capture noisily stratetab, using(`source') outcomes(1) frame(`display')
    assert _rc==198
    qa_state_compare, tag(tt_remaining)

}
local outcome=_rc
capture erase "`source'.dta"
foreach f in display model companion composite {
    capture frame drop ``f''
}
if `outcome' {
    local ++fail
    display as error "FAIL: stratetab exact label_gaps; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: stratetab exact label_gaps"
}

**# stratetab exact boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(boundary_values)
    tempname display rates model companion composite
    tempfile source
    tempvar follow
    generate double `follow'=1+(y==0)
    quietly stset `follow', failure(y) id(id)
    * Native artefact contains exact5events/15time in each canonical group.
    * Native source is independently checked before formatting consumes it.
    quietly strate group, per(1) output(`source'.dta, replace)
    preserve
    quietly use "`source'.dta", clear
    assert _N==4 & _D==5 & _Y==15
    assert abs(_Rate-1/3)<1e-14
    assert abs(_Lower-exp(ln(1/3)-invnormal(.975)/sqrt(5)))<1e-14
    assert abs(_Upper-exp(ln(1/3)+invnormal(.975)/sqrt(5)))<1e-14
    restore
    qa_state_snapshot, tag(tt_remaining)
    quietly stratetab, using(`source') outcomes(1) frame(`display') outcomeids(y) outlabels("Outcome") explabels("Exposure") digits(6) eventdigits(0) pydigits(2) pyscale(1) ratescale(1000) ratiodigits(10)
    matrix `rates'=r(rates)
    assert rowsof(`rates')==4 & colsof(`rates')==1
    assert r(N_rows)==8 & r(N_outcomes)==1 & r(N_exposures)==1
    forvalues j=1/4 {
        assert !missing(`rates'[`j',1]) & abs(`rates'[`j',1]-1000/3)<1e-10
        frame `display': assert c2[`j'+4]=="5" & c3[`j'+4]=="15.00"
        frame `display': assert c4[`j'+4]=="333.333333 (138.742604, 800.843487)"
    }
    frame drop `display'
    capture matrix drop `rates'
    qa_state_compare, tag(tt_remaining)

}
local outcome=_rc
capture erase "`source'.dta"
foreach f in display model companion composite {
    capture frame drop ``f''
}
if `outcome' {
    local ++fail
    display as error "FAIL: stratetab exact boundary_values; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: stratetab exact boundary_values"
}

**# hrcomptab exact friendly
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    tempname display rates model companion composite
    tempfile source
    tempvar follow
    generate double `follow'=1+(y==0)
    quietly stset `follow', failure(y) id(id)
    * Native artefact contains exact5events/15time in each canonical group.
    * Native source is independently checked before formatting consumes it.
    quietly strate group, per(1) output(`source'.dta, replace)
    preserve
    quietly use "`source'.dta", clear
    assert _N==4 & _D==5 & _Y==15
    assert abs(_Rate-1/3)<1e-14
    assert abs(_Lower-exp(ln(1/3)-invnormal(.975)/sqrt(5)))<1e-14
    assert abs(_Upper-exp(ln(1/3)+invnormal(.975)/sqrt(5)))<1e-14
    restore
    qa_state_snapshot, tag(tt_remaining)
    quietly stratetab, using(`source') outcomes(1) frame(`display') outcomeids(y) outlabels("Outcome") explabels("Exposure") digits(6) eventdigits(0) pydigits(2) pyscale(1) ratescale(1000) ratiodigits(10)
    matrix `rates'=r(rates)
    assert rowsof(`rates')==4 & colsof(`rates')==1
    assert r(N_rows)==8 & r(N_outcomes)==1 & r(N_exposures)==1
    forvalues j=1/4 {
        assert !missing(`rates'[`j',1]) & abs(`rates'[`j',1]-1000/3)<1e-10
        frame `display': assert c2[`j'+4]=="5" & c3[`j'+4]=="15.00"
        frame `display': assert c4[`j'+4]=="333.333333 (138.742604, 800.843487)"
    }
    * Remove legitimate output before comparing, then rebuild it for composition.
    frame drop `display'
    capture matrix drop `rates'
    qa_state_compare, tag(tt_remaining)
    * Rebuild the checked scaffold; caller data remains the canonical adapter.
    quietly stratetab, using(`source') outcomes(1) frame(`display') outcomeids(y) outlabels("Outcome") explabels("Exposure") digits(6) eventdigits(0) pydigits(2) pyscale(1) ratescale(1000) ratiodigits(10)
    collect clear
    * Symmetry: identical tied-risk/event counts in each group => all HR1.
    quietly collect: stcox i.group, nolog
    quietly regtab, noint frame(`model') coef(HR) eplotframe(`companion') models("Outcome") digits(4)
    qa_state_snapshot, tag(tt_remaining)
    quietly hrcomptab `display', modelframes(`model') rows(3/5) outcomemap("Outcome") frame(`composite') effect(HR)
    assert r(N_rows)==8 & r(N_modelrows)==3 & r(N_outcomes)==1
    forvalues j=5/8 {
        frame `composite': assert c2[`j']=="5" & c3[`j']=="15.00" & c4[`j']=="333.333333 (138.742604, 800.843487)"
    }
    frame `composite': assert c5[5]=="Reference"
    forvalues j=6/8 {
        frame `composite': assert c5[`j']=="1.0000 (0.2895, 3.4542)" & c6[`j']=="1.00"
    }
    frame drop `composite'
    qa_state_compare, tag(tt_remaining)
    frame drop `model' `companion' `display'

}
local outcome=_rc
capture erase "`source'.dta"
foreach f in display model companion composite {
    capture frame drop ``f''
}
if `outcome' {
    local ++fail
    display as error "FAIL: hrcomptab exact friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: hrcomptab exact friendly"
}

**# hrcomptab exact unsorted
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    tempname display rates model companion composite
    tempfile source
    tempvar follow
    generate double `follow'=1+(y==0)
    quietly stset `follow', failure(y) id(id)
    * Native artefact contains exact5events/15time in each canonical group.
    * Native source is independently checked before formatting consumes it.
    quietly strate group, per(1) output(`source'.dta, replace)
    preserve
    quietly use "`source'.dta", clear
    assert _N==4 & _D==5 & _Y==15
    assert abs(_Rate-1/3)<1e-14
    assert abs(_Lower-exp(ln(1/3)-invnormal(.975)/sqrt(5)))<1e-14
    assert abs(_Upper-exp(ln(1/3)+invnormal(.975)/sqrt(5)))<1e-14
    restore
    qa_state_snapshot, tag(tt_remaining)
    quietly stratetab, using(`source') outcomes(1) frame(`display') outcomeids(y) outlabels("Outcome") explabels("Exposure") digits(6) eventdigits(0) pydigits(2) pyscale(1) ratescale(1000) ratiodigits(10)
    matrix `rates'=r(rates)
    assert rowsof(`rates')==4 & colsof(`rates')==1
    assert r(N_rows)==8 & r(N_outcomes)==1 & r(N_exposures)==1
    forvalues j=1/4 {
        assert !missing(`rates'[`j',1]) & abs(`rates'[`j',1]-1000/3)<1e-10
        frame `display': assert c2[`j'+4]=="5" & c3[`j'+4]=="15.00"
        frame `display': assert c4[`j'+4]=="333.333333 (138.742604, 800.843487)"
    }
    * Remove legitimate output before comparing, then rebuild it for composition.
    frame drop `display'
    capture matrix drop `rates'
    qa_state_compare, tag(tt_remaining)
    * Rebuild the checked scaffold; caller data remains the canonical adapter.
    quietly stratetab, using(`source') outcomes(1) frame(`display') outcomeids(y) outlabels("Outcome") explabels("Exposure") digits(6) eventdigits(0) pydigits(2) pyscale(1) ratescale(1000) ratiodigits(10)
    collect clear
    * Symmetry: identical tied-risk/event counts in each group => all HR1.
    quietly collect: stcox i.group, nolog
    quietly regtab, noint frame(`model') coef(HR) eplotframe(`companion') models("Outcome") digits(4)
    qa_state_snapshot, tag(tt_remaining)
    quietly hrcomptab `display', modelframes(`model') rows(3/5) outcomemap("Outcome") frame(`composite') effect(HR)
    assert r(N_rows)==8 & r(N_modelrows)==3 & r(N_outcomes)==1
    forvalues j=5/8 {
        frame `composite': assert c2[`j']=="5" & c3[`j']=="15.00" & c4[`j']=="333.333333 (138.742604, 800.843487)"
    }
    frame `composite': assert c5[5]=="Reference"
    forvalues j=6/8 {
        frame `composite': assert c5[`j']=="1.0000 (0.2895, 3.4542)" & c6[`j']=="1.00"
    }
    frame drop `composite'
    qa_state_compare, tag(tt_remaining)
    frame drop `model' `companion' `display'

}
local outcome=_rc
capture erase "`source'.dta"
foreach f in display model companion composite {
    capture frame drop ``f''
}
if `outcome' {
    local ++fail
    display as error "FAIL: hrcomptab exact unsorted; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: hrcomptab exact unsorted"
}

**# hrcomptab exact boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(boundary_values)
    tempname display rates model companion composite
    tempfile source
    tempvar follow
    generate double `follow'=1+(y==0)
    quietly stset `follow', failure(y) id(id)
    * Native artefact contains exact5events/15time in each canonical group.
    * Native source is independently checked before formatting consumes it.
    quietly strate group, per(1) output(`source'.dta, replace)
    preserve
    quietly use "`source'.dta", clear
    assert _N==4 & _D==5 & _Y==15
    assert abs(_Rate-1/3)<1e-14
    assert abs(_Lower-exp(ln(1/3)-invnormal(.975)/sqrt(5)))<1e-14
    assert abs(_Upper-exp(ln(1/3)+invnormal(.975)/sqrt(5)))<1e-14
    restore
    qa_state_snapshot, tag(tt_remaining)
    quietly stratetab, using(`source') outcomes(1) frame(`display') outcomeids(y) outlabels("Outcome") explabels("Exposure") digits(6) eventdigits(0) pydigits(2) pyscale(1) ratescale(1000) ratiodigits(10)
    matrix `rates'=r(rates)
    assert rowsof(`rates')==4 & colsof(`rates')==1
    assert r(N_rows)==8 & r(N_outcomes)==1 & r(N_exposures)==1
    forvalues j=1/4 {
        assert !missing(`rates'[`j',1]) & abs(`rates'[`j',1]-1000/3)<1e-10
        frame `display': assert c2[`j'+4]=="5" & c3[`j'+4]=="15.00"
        frame `display': assert c4[`j'+4]=="333.333333 (138.742604, 800.843487)"
    }
    * Remove legitimate output before comparing, then rebuild it for composition.
    frame drop `display'
    capture matrix drop `rates'
    qa_state_compare, tag(tt_remaining)
    * Rebuild the checked scaffold; caller data remains the canonical adapter.
    quietly stratetab, using(`source') outcomes(1) frame(`display') outcomeids(y) outlabels("Outcome") explabels("Exposure") digits(6) eventdigits(0) pydigits(2) pyscale(1) ratescale(1000) ratiodigits(10)
    collect clear
    * Symmetry: identical tied-risk/event counts in each group => all HR1.
    quietly collect: stcox i.group, nolog
    quietly regtab, noint frame(`model') coef(HR) eplotframe(`companion') models("Outcome") digits(4)
    qa_state_snapshot, tag(tt_remaining)
    quietly hrcomptab `display', modelframes(`model') rows(3/5) outcomemap("Outcome") frame(`composite') effect(HR)
    assert r(N_rows)==8 & r(N_modelrows)==3 & r(N_outcomes)==1
    forvalues j=5/8 {
        frame `composite': assert c2[`j']=="5" & c3[`j']=="15.00" & c4[`j']=="333.333333 (138.742604, 800.843487)"
    }
    frame `composite': assert c5[5]=="Reference"
    forvalues j=6/8 {
        frame `composite': assert c5[`j']=="1.0000 (0.2895, 3.4542)" & c6[`j']=="1.00"
    }
    frame drop `composite'
    qa_state_compare, tag(tt_remaining)
    frame drop `model' `companion' `display'

}
local outcome=_rc
capture erase "`source'.dta"
foreach f in display model companion composite {
    capture frame drop ``f''
}
if `outcome' {
    local ++fail
    display as error "FAIL: hrcomptab exact boundary_values; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: hrcomptab exact boundary_values"
}

**# Stack actual workbook friendly
local ++tests
capture noisily {
    local root ""
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local output `"`r(path_xlsx)'"'
    local noext `"`r(path_noext)'"'
    qa_fx_a6_estmat, clear seed(37)
    tempname display
    quietly puttab b se using `"`macval(output)'"', sheet("package_summary") title("Source") digits(2)
    qa_state_snapshot, tag(tt_stack)
    quietly stacktab using `"`macval(output)'"', blocks(sheet(package_summary) rows(3/5) cols(B-C)) sheet("package_detail") sheetreplace frame(`display') spacing(0) layout(vstack)
    assert r(rows_written)==3 & r(rows_out)==4 & r(cols_out)==2 & r(blocks_loaded)==1
    assert `"`r(table_start)'"'=="B2" & `"`r(layout)'"'=="vstack"
    python: __import__("subprocess").run([__import__("sys").executable,"tools/check_xlsx.py",__import__("sfi").Macro.getLocal("output"),"--sheet","package_detail","--cell","B2","0.50","--cell","C2","0.25","--cell","B3","-1.00","--cell","C3","0.50","--cell","B4","2.00","--cell","C4","1.00"],check=True)
    python: _w=__import__("openpyxl").load_workbook(__import__("sfi").Macro.getLocal("output")); assert _w["user_notes"]["A1"].value=="USER_KEEP" and _w["package_summary"]["B3"].value=="0.50"
    frame drop `display'
    capture matrix drop `rates'
    qa_state_compare, tag(tt_stack)

}
local outcome=_rc
capture frame drop `display'
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Stack actual workbook friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Stack actual workbook friendly"
}

**# Stack actual workbook stale_sheet
local ++tests
capture noisily {
    local root ""
    * expect: EXACT
    qa_fx_a7_files, clear seed(37) perturb(stale_sheet)
    local root `"`r(root)'"'
    local output `"`r(path_xlsx)'"'
    local noext `"`r(path_noext)'"'
    qa_fx_a6_estmat, clear seed(37)
    tempname display
    quietly puttab b se using `"`macval(output)'"', sheet("package_summary") title("Source") digits(2)
    qa_state_snapshot, tag(tt_stack)
    quietly stacktab using `"`macval(output)'"', blocks(sheet(package_summary) rows(3/5) cols(B-C)) sheet("package_detail") sheetreplace frame(`display') spacing(0) layout(vstack)
    assert r(rows_written)==3 & r(rows_out)==4 & r(cols_out)==2 & r(blocks_loaded)==1
    assert `"`r(table_start)'"'=="B2" & `"`r(layout)'"'=="vstack"
    python: __import__("subprocess").run([__import__("sys").executable,"tools/check_xlsx.py",__import__("sfi").Macro.getLocal("output"),"--sheet","package_detail","--cell","B2","0.50","--cell","C2","0.25","--cell","B3","-1.00","--cell","C3","0.50","--cell","B4","2.00","--cell","C4","1.00"],check=True)
    python: _w=__import__("openpyxl").load_workbook(__import__("sfi").Macro.getLocal("output")); assert _w["user_notes"]["A1"].value=="USER_KEEP" and _w["package_summary"]["B3"].value=="0.50"
    frame drop `display'
    capture matrix drop `rates'
    qa_state_compare, tag(tt_stack)

}
local outcome=_rc
capture frame drop `display'
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Stack actual workbook stale_sheet; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Stack actual workbook stale_sheet"
}

**# Stack actual workbook path_noext
local ++tests
capture noisily {
    local root ""
    * expect: REFUSED
    qa_fx_a7_files, clear seed(37) perturb(path_noext)
    local root `"`r(root)'"'
    local output `"`r(path_xlsx)'"'
    local noext `"`r(path_noext)'"'
    qa_fx_a6_estmat, clear seed(37)
    tempname display
    quietly puttab b se using `"`macval(output)'"', sheet("package_summary") title("Source") digits(2)
    qa_state_snapshot, tag(tt_stack)
    capture noisily stacktab using `"`macval(noext)'"', blocks(sheet(package_summary) rows(3/5) cols(B-C)) sheet("package_detail") sheetreplace
    assert _rc==198
    qa_state_compare, tag(tt_stack)
    python: assert __import__("pathlib").Path(__import__("sfi").Macro.getLocal("noext")).read_text()=="EXTENSIONLESS_KEEP\n"

}
local outcome=_rc
capture frame drop `display'
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Stack actual workbook path_noext; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Stack actual workbook path_noext"
}

**# Tips content friendly
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    * Console documentation is independent of dataset values; exact public text.
    tempfile transcript
    tempname handle
    qa_state_snapshot, tag(tt_tips)
    log using "`transcript'", text replace name(tips_receipt)
    noisily tabtools_tips
    log close tips_receipt
    qa_state_compare, tag(tt_tips)
    python: _t=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("transcript")).read_text(); assert "tabtools tips - quick reference and worked recipes" in _t and "Merged guide: help tabtools_tips" in _t and "Option patterns by command: quick reference" in _t and "End-to-end workflows: recipes" in _t

}
local outcome=_rc
capture log close tips_receipt
if `outcome' {
    local ++fail
    display as error "FAIL: Tips content friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Tips content friendly"
}

**# Tips content unsorted
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    * Console documentation is independent of dataset values; exact public text.
    tempfile transcript
    tempname handle
    qa_state_snapshot, tag(tt_tips)
    log using "`transcript'", text replace name(tips_receipt)
    noisily tabtools_tips
    log close tips_receipt
    qa_state_compare, tag(tt_tips)
    python: _t=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("transcript")).read_text(); assert "tabtools tips - quick reference and worked recipes" in _t and "Merged guide: help tabtools_tips" in _t and "Option patterns by command: quick reference" in _t and "End-to-end workflows: recipes" in _t

}
local outcome=_rc
capture log close tips_receipt
if `outcome' {
    local ++fail
    display as error "FAIL: Tips content unsorted; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Tips content unsorted"
}

display "RESULT: validation_tabtools_fixture_remaining tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
