*! validation_compress_tc_fixture_primitives.do -- primitive contents and conversion threshold
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using validation_compress_tc_fixture_primitives.log,text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_hostile.do
do _qa_state.do
local tests 0
local pass 0
local fail 0

**# Primitive names
local ++tests
capture noisily {
    * expect: INVARIANT
        qa_hostile_names, clear
        tempfile source
        quietly save `source'
        quietly compress_tc, quietly lowmem
        assert !missing(r(bytes_initial),r(bytes_final),r(bytes_saved))
        assert r(bytes_initial)-r(bytes_final)==r(bytes_saved)
        cf _all using `source'
        qa_state_snapshot, tag(comp_native)
        quietly compress_tc, quietly dryrun lowmem
        qa_state_compare, tag(comp_native)

}
local outcome=_rc
if `outcome' {
    local ++fail
    display as error "FAIL: primitive names; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: primitive names"
}

**# Primitive codes
local ++tests
capture noisily {
    * expect: INVARIANT
        qa_hostile_codes, clear
        tempfile source
        quietly save `source'
        quietly compress_tc, quietly lowmem
        assert !missing(r(bytes_initial),r(bytes_final),r(bytes_saved))
        assert r(bytes_initial)-r(bytes_final)==r(bytes_saved)
        cf _all using `source'
        qa_state_snapshot, tag(comp_native)
        quietly compress_tc, quietly dryrun lowmem
        qa_state_compare, tag(comp_native)

}
local outcome=_rc
if `outcome' {
    local ++fail
    display as error "FAIL: primitive codes; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: primitive codes"
}

**# Primitive strings
local ++tests
capture noisily {
    * expect: INVARIANT
        qa_fx_a7_labelled, clear seed(37)
        qa_hostile_strings
        local corpus `r(names)'
        generate strL corpus_text=""
        local j=0
        foreach g of local corpus {
            local ++j
            mata: st_sstore(strtoreal(st_local("j")),"corpus_text",st_global(st_local("g")))
        }
        tempfile source
        quietly save `source'
        quietly compress_tc, quietly lowmem
        assert !missing(r(bytes_initial),r(bytes_final),r(bytes_saved))
        assert r(bytes_initial)-r(bytes_final)==r(bytes_saved)
        cf _all using `source'
        qa_state_snapshot, tag(comp_native)
        quietly compress_tc, quietly dryrun lowmem
        qa_state_compare, tag(comp_native)

}
local outcome=_rc
if `outcome' {
    local ++fail
    display as error "FAIL: primitive strings; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: primitive strings"
}
foreach threshold in 0 244 245 -1 {
    local ++tests
    capture noisily {
        * expect: EXACT
        qa_fx_a7_labelled, clear seed(37) perturb(boundary_values)
        generate str244 probe="repeated exact string Å"
        tempfile source
        quietly save `source'
        if `threshold'<0 {
            * expect: REFUSED
            qa_state_snapshot, tag(comp_threshold)
            capture noisily compress_tc probe, quietly nocompress minlength(`threshold')
            assert _rc==198
            qa_state_compare, tag(comp_threshold)
        }
        else {
            quietly compress_tc probe, quietly nocompress minlength(`threshold')
            assert r(k_converted)==(`threshold'<=244)
            local storage: type probe
            assert "`storage'"==cond(`threshold'<=244,"strL","str244")
            cf _all using `source'
        }
    }
    local outcome=_rc
    if `outcome' {
        local ++fail
        display as error "FAIL: minlength `threshold'; rc=" `outcome'
    }
    else {
        local ++pass
        display as result "PASS: minlength `threshold'"
    }
}
display "RESULT: validation_compress_tc_fixture_primitives tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
