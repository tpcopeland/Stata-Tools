*! validation_tabtools_fixture_domains.do -- real numeric option domains and content
*! Author: Timothy P Copeland, Karolinska Institutet
version 17
clear all
set more off
capture log close _all
log using validation_tabtools_fixture_domains.log, text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_state.do
do _qa_metamorphic.do
program define _tt_domain_setup
    args kind
    qa_fx_a7_labelled, clear seed(37)
    capture frame drop domain_frame
    generate byte g=group<=2
end
program define _tt_domain_corr_check
    tempname cc nn
    matrix `cc'=r(C)
    matrix `nn'=r(N)
    assert rowsof(`cc')==2 & colsof(`cc')==2
    assert !missing(`cc'[1,2]) & abs(`cc'[1,2]-1)<1e-12 & `nn'[1,2]==40
    frame domain_frame: assert _N==4 & strpos(c2[4],"1")==1
    matrix drop `cc' `nn'
    frame drop domain_frame
end
program define _tt_domain_cross_check
    args kind
    tempname tt
    matrix `tt'=r(table)
    if "`kind'"=="level" {
        assert r(N)==40 & r(or)==1 & inlist(r(ci_level),10,99.99)
        assert rowsof(`tt')==2 & colsof(`tt')==2
        forvalues i=1/2 {
            assert `tt'[`i',1]==10 & `tt'[`i',2]==10
        }
        frame domain_frame: assert strpos(c1[7],"OR = 1.0 (")==1
    }
    else if "`kind'"=="smallcells" {
        assert inlist(r(smallcells),3,5,6)
        if r(smallcells)==6 {
            assert r(N_primary_suppressed)==8 & r(chi2)==.d & r(p)==.d
            forvalues i=1/4 {
                assert `tt'[`i',1]==.p & `tt'[`i',2]==.p
            }
            frame domain_frame: assert c2[3]=="<6" & c3[3]=="<6"
        }
        else {
            assert r(N_primary_suppressed)==0 & r(N)==40 & r(chi2)==0 & r(p)==1
            forvalues i=1/4 {
                assert `tt'[`i',1]==5 & `tt'[`i',2]==5
            }
        }
    }
    else {
        assert r(N)==40 & r(chi2)==0 & r(p)==1
        assert rowsof(`tt')==4 & colsof(`tt')==2
        forvalues i=1/4 {
            assert `tt'[`i',1]==5 & `tt'[`i',2]==5
        }
        if "`kind'"=="digits" {
            frame domain_frame: assert inlist(c2[3],"5 (25%)","5 (25.0%)","5 (25.000000%)")
        }
    }
    matrix drop `tt'
    frame drop domain_frame
end
program define _tt_domain_desc_check
    args kind
    tempname tt
    matrix `tt'=r(table)
    assert rowsof(`tt')==1 & colsof(`tt')==1
    if "`kind'"=="pdp" {
        * Four groups of10 consecutive integers: betweenMS5000/3,
        * withinMS55/6; hence F(3,36)=2000/11.
        assert !missing(`tt'[1,1]) & abs(`tt'[1,1]-Ftail(3,36,2000/11))<1e-30
        frame domain_frame: assert inlist(pvalue[3],"<0.1","<0.0000000001")
    }
    else if "`kind'"=="highpdp" {
        * Alternating0/1 outcome is exactly balanced in every10-row group.
        assert `tt'[1,1]==1
        frame domain_frame: assert inlist(strtrim(pvalue[3]),"1.0","1.0000000000")
    }
    else {
        assert inlist(r(smallcells),3,5,6)
        if r(smallcells)==6 {
            assert r(N_primary_suppressed)==8 & `tt'[1,1]==.d
            frame domain_frame: assert pvalue[3]=="Suppressed"
        }
        else assert r(N_primary_suppressed)==0 & `tt'[1,1]==1
    }
    matrix drop `tt'
    frame drop domain_frame
end
local tests 0
local pass 0
local fail 0

**# corrtab_star
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37)
    qa_option_domain, command(corrtab x id, full star(@v@) frame(domain_frame)) inside("0.0000001;0.05;0.9999999;0.001 0.01 0.05") outside("0;1;0.1 0.1;0.1 0.2 0.3 0.4") setup(_tt_domain_setup) check(_tt_domain_corr_check)
    assert r(n_cells)==8 & r(n_violations)==0
}
local outcome=_rc
capture frame drop domain_frame
if `outcome' {
    local ++fail
    display as error "FAIL: corrtab_star rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: corrtab_star"
}

**# corrtab_digits
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37)
    qa_option_domain, command(corrtab x id, full digits(@v@) frame(domain_frame)) inside("-1;0;6") outside("-2;7;3.5;.;.a") setup(_tt_domain_setup) check(_tt_domain_corr_check)
    assert r(n_cells)==8 & r(n_violations)==0
}
local outcome=_rc
capture frame drop domain_frame
if `outcome' {
    local ++fail
    display as error "FAIL: corrtab_digits rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: corrtab_digits"
}

**# crosstab_level
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37)
    qa_option_domain, command(crosstab g y, or level(@v@) frame(domain_frame)) inside("10;99.99") outside("9.99;99.991;.;.a") setup(_tt_domain_setup) check(_tt_domain_cross_check level)
    assert r(n_cells)==6 & r(n_violations)==0
}
local outcome=_rc
capture frame drop domain_frame
if `outcome' {
    local ++fail
    display as error "FAIL: crosstab_level rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: crosstab_level"
}

**# crosstab_digits
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37)
    qa_option_domain, command(crosstab group y, digits(@v@) frame(domain_frame)) inside("-1;0;6") outside("-2;7;3.5;.;.a") setup(_tt_domain_setup) check(_tt_domain_cross_check digits)
    assert r(n_cells)==8 & r(n_violations)==0
}
local outcome=_rc
capture frame drop domain_frame
if `outcome' {
    local ++fail
    display as error "FAIL: crosstab_digits rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: crosstab_digits"
}

**# crosstab_boldp
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37)
    qa_option_domain, command(crosstab group y, boldp(@v@) frame(domain_frame)) inside("0.000001;0.999999;-1") outside("0;1;.;.a") setup(_tt_domain_setup) check(_tt_domain_cross_check boldp)
    assert r(n_cells)==7 & r(n_violations)==0
}
local outcome=_rc
capture frame drop domain_frame
if `outcome' {
    local ++fail
    display as error "FAIL: crosstab_boldp rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: crosstab_boldp"
}

**# crosstab_smallcells
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37)
    qa_option_domain, command(crosstab group y, smallcells(@v@) frame(domain_frame)) inside("3;5;6") outside("2;0;-1;3.5;.;.a") setup(_tt_domain_setup) check(_tt_domain_cross_check smallcells)
    assert r(n_cells)==9 & r(n_violations)==0
}
local outcome=_rc
capture frame drop domain_frame
if `outcome' {
    local ++fail
    display as error "FAIL: crosstab_smallcells rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: crosstab_smallcells"
}

**# desctab_pdp
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37)
    qa_option_domain, command(desctab, by(group) vars(x contn %9.1f) pdp(@v@) frame(domain_frame)) range(1 10) integer outside(". .a") setup(_tt_domain_setup) check(_tt_domain_desc_check pdp)
    assert r(n_cells)==6 & r(n_violations)==0
}
local outcome=_rc
capture frame drop domain_frame
if `outcome' {
    local ++fail
    display as error "FAIL: desctab_pdp rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: desctab_pdp"
}

**# desctab_highpdp
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37)
    qa_option_domain, command(desctab, by(group) vars(y contn %9.1f) highpdp(@v@) frame(domain_frame)) range(1 10) integer outside(". .a") setup(_tt_domain_setup) check(_tt_domain_desc_check highpdp)
    assert r(n_cells)==6 & r(n_violations)==0
}
local outcome=_rc
capture frame drop domain_frame
if `outcome' {
    local ++fail
    display as error "FAIL: desctab_highpdp rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: desctab_highpdp"
}

**# desctab_smallcells
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37)
    qa_option_domain, command(desctab, by(group) vars(y cat) smallcells(@v@) frame(domain_frame)) inside("3;5;6") outside("2;0;-1;3.5;.;.a") setup(_tt_domain_setup) check(_tt_domain_desc_check smallcells)
    assert r(n_cells)==9 & r(n_violations)==0
}
local outcome=_rc
capture frame drop domain_frame
if `outcome' {
    local ++fail
    display as error "FAIL: desctab_smallcells rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: desctab_smallcells"
}

display "RESULT: validation_tabtools_fixture_domains tests=`tests' pass=`pass' fail=`fail'"
log close _all
if `fail' exit 1
