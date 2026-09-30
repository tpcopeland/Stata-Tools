*! validation_tc_schemes_fixture_primitives.do -- hostile caller data and exact source catalogue
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using validation_tc_schemes_fixture_primitives.log,text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_hostile.do
do _qa_metamorphic.do
do _qa_state.do
local tests 0
local pass 0
local fail 0
capture program drop _tc_fixture_source_check
program define _tc_fixture_source_check
    local source "`r(sources)'"
    assert r(n_schemes)==cond("`source'"=="tc",3,cond("`source'"=="modern",2,cond("`source'"=="cleanplots",1,cond("`source'"=="blindschemes",4,cond("`source'"=="schemepack",35,45)))))
    if "`source'"=="tc" assert "`r(schemes)'"=="rdbu ki ki_black"
    if "`source'"=="modern" assert "`r(schemes)'"=="modern modern_dark"
    if "`source'"=="cleanplots" assert "`r(schemes)'"=="cleanplots"
    if "`source'"=="blindschemes" assert "`r(schemes)'"=="plotplain plotplainblind plottig plottigblind"
end

**# 32-byte and case-distinct caller variables
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_hostile_names, clear
    * This read-only catalogue promises caller-data preservation. Its
    * literal identities are independent of variable names, codes and text.
    qa_state_snapshot, tag(sch_primitive)
    quietly tc_schemes, source(modern) detail
    assert r(n_schemes)==2 & "`r(schemes)'"=="modern modern_dark"
    assert "`r(sources)'"=="modern"
    qa_state_compare, tag(sch_primitive)

}
if _rc {
    local ++fail
    display as error "FAIL: 32-byte and case-distinct caller variables"
}
else {
    local ++pass
    display as result "PASS: 32-byte and case-distinct caller variables"
}

**# Negative and above-maxlong caller groups
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_hostile_codes, clear
    * This read-only catalogue promises caller-data preservation. Its
    * literal identities are independent of variable names, codes and text.
    qa_state_snapshot, tag(sch_primitive)
    quietly tc_schemes, source(modern) detail
    assert r(n_schemes)==2 & "`r(schemes)'"=="modern modern_dark"
    assert "`r(sources)'"=="modern"
    qa_state_compare, tag(sch_primitive)

}
if _rc {
    local ++fail
    display as error "FAIL: Negative and above-maxlong caller groups"
}
else {
    local ++pass
    display as result "PASS: Negative and above-maxlong caller groups"
}

**# Wholly missing labelled caller column
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(miss_all_column)
    * This read-only catalogue promises caller-data preservation. Its
    * literal identities are independent of variable names, codes and text.
    qa_state_snapshot, tag(sch_primitive)
    quietly tc_schemes, source(modern) detail
    assert r(n_schemes)==2 & "`r(schemes)'"=="modern modern_dark"
    assert "`r(sources)'"=="modern"
    qa_state_compare, tag(sch_primitive)

}
if _rc {
    local ++fail
    display as error "FAIL: Wholly missing labelled caller column"
}
else {
    local ++pass
    display as result "PASS: Wholly missing labelled caller column"
}

**# All opaque caller strings
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37)
    qa_hostile_strings
    local corpus `r(names)'
    generate strL caption=""
    local row=0
    foreach g of local corpus {
        local ++row
        mata: st_sstore(strtoreal(st_local("row")),"caption",st_global(st_local("g")))
    }
    * This read-only catalogue promises caller-data preservation. Its
    * literal identities are independent of variable names, codes and text.
    qa_state_snapshot, tag(sch_primitive)
    quietly tc_schemes, source(modern) detail
    assert r(n_schemes)==2 & "`r(schemes)'"=="modern modern_dark"
    assert "`r(sources)'"=="modern"
    qa_state_compare, tag(sch_primitive)

}
if _rc {
    local ++fail
    display as error "FAIL: All opaque caller strings"
}
else {
    local ++pass
    display as result "PASS: All opaque caller strings"
}

**# Documented categorical source domain
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    qa_option_domain, command(tc_schemes, source(@v@) list) inside(all blindschemes schemepack cleanplots modern tc) outside(not_a_source) check(_tc_fixture_source_check)
    assert r(n_cells)==7 & r(n_violations)==0

}
if _rc {
    local ++fail
    display as error "FAIL: Documented categorical source domain"
}
else {
    local ++pass
    display as result "PASS: Documented categorical source domain"
}

display "RESULT: validation_tc_schemes_fixture_primitives tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
