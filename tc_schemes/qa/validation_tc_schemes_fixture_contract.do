*! validation_tc_schemes_fixture_contract.do -- canonical labelled designs and independent contents
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using "validation_tc_schemes_fixture_contract.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_state.do
local tests 0
local pass 0
local fail 0

**# Original schemes and caller state friendly
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(sch_list)
    quietly tc_schemes, source(tc) list
    assert r(n_schemes)==3 & "`r(schemes)'"=="rdbu ki ki_black"
    assert "`r(sources)'"=="tc"
    qa_state_compare, tag(sch_list)
    quietly scatter x id, scheme(ki) name(fxscheme, replace)
    tempfile description
    log using `description', text replace name(fxdescription)
    graph describe fxscheme
    log close fxdescription
    python: assert __import__("re").search(r"scheme:\s+ki\b",__import__("pathlib").Path(__import__("sfi").Macro.getLocal("description")).read_text())

    graph drop fxscheme

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Original schemes and caller state friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Original schemes and caller state friendly"
}

**# Original schemes and caller state label_gaps
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    qa_state_snapshot, tag(sch_list)
    quietly tc_schemes, source(tc) list
    assert r(n_schemes)==3 & "`r(schemes)'"=="rdbu ki ki_black"
    assert "`r(sources)'"=="tc"
    qa_state_compare, tag(sch_list)
    quietly scatter x id, scheme(ki) name(fxscheme, replace)
    tempfile description
    log using `description', text replace name(fxdescription)
    graph describe fxscheme
    log close fxdescription
    python: assert __import__("re").search(r"scheme:\s+ki\b",__import__("pathlib").Path(__import__("sfi").Macro.getLocal("description")).read_text())

    graph drop fxscheme

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Original schemes and caller state label_gaps; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Original schemes and caller state label_gaps"
}

**# Original schemes and caller state single_row
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(single_row)
    qa_state_snapshot, tag(sch_list)
    quietly tc_schemes, source(tc) list
    assert r(n_schemes)==3 & "`r(schemes)'"=="rdbu ki ki_black"
    assert "`r(sources)'"=="tc"
    qa_state_compare, tag(sch_list)
    quietly scatter x id, scheme(ki) name(fxscheme, replace)
    tempfile description
    log using `description', text replace name(fxdescription)
    graph describe fxscheme
    log close fxdescription
    python: assert __import__("re").search(r"scheme:\s+ki\b",__import__("pathlib").Path(__import__("sfi").Macro.getLocal("description")).read_text())

    graph drop fxscheme

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Original schemes and caller state single_row; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Original schemes and caller state single_row"
}

**# Original schemes and caller state unsorted
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    qa_state_snapshot, tag(sch_list)
    quietly tc_schemes, source(tc) list
    assert r(n_schemes)==3 & "`r(schemes)'"=="rdbu ki ki_black"
    assert "`r(sources)'"=="tc"
    qa_state_compare, tag(sch_list)
    quietly scatter x id, scheme(ki) name(fxscheme, replace)
    tempfile description
    log using `description', text replace name(fxdescription)
    graph describe fxscheme
    log close fxdescription
    python: assert __import__("re").search(r"scheme:\s+ki\b",__import__("pathlib").Path(__import__("sfi").Macro.getLocal("description")).read_text())

    graph drop fxscheme

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Original schemes and caller state unsorted; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Original schemes and caller state unsorted"
}

**# Invalid catalogue source refuses with unchanged state
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    * expect: REFUSED
    qa_state_snapshot, tag(sch_bad)
    capture noisily tc_schemes, source(not_a_source)
    assert _rc==198
    qa_state_compare, tag(sch_bad)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Invalid catalogue source refuses with unchanged state; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Invalid catalogue source refuses with unchanged state"
}

display "RESULT: validation_tc_schemes_fixture_contract tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
