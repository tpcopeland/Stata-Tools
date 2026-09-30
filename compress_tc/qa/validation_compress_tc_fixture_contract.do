*! validation_compress_tc_fixture_contract.do -- canonical labelled designs and independent contents
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using "validation_compress_tc_fixture_contract.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_state.do
local tests 0
local pass 0
local fail 0

**# Labelled values storage and dryrun friendly
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    tempfile source
    quietly save `source'
    local vals : value label group
    local fmt : format date
    local xlab : variable label x
    quietly compress_tc, quietly
    assert !missing(r(bytes_initial),r(bytes_final),r(bytes_saved),r(pct_saved))
    assert r(bytes_initial)-r(bytes_final)==r(bytes_saved)
    assert r(bytes_saved)>=0 & inrange(r(pct_saved),0,100)
    cf _all using `source'
    local aftervals : value label group
    local afterfmt : format date
    local afterlab : variable label x
    assert "`vals'"=="`aftervals'" & "`fmt'"=="`afterfmt'"
    assert `"`xlab'"'==`"`afterlab'"'
    qa_state_snapshot, tag(comp_dry)
    quietly compress_tc, quietly dryrun lowmem
    qa_state_compare, tag(comp_dry)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Labelled values storage and dryrun friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Labelled values storage and dryrun friendly"
}

**# Labelled values storage and dryrun label_gaps
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    tempfile source
    quietly save `source'
    local vals : value label group
    local fmt : format date
    local xlab : variable label x
    quietly compress_tc, quietly
    assert !missing(r(bytes_initial),r(bytes_final),r(bytes_saved),r(pct_saved))
    assert r(bytes_initial)-r(bytes_final)==r(bytes_saved)
    assert r(bytes_saved)>=0 & inrange(r(pct_saved),0,100)
    cf _all using `source'
    local aftervals : value label group
    local afterfmt : format date
    local afterlab : variable label x
    assert "`vals'"=="`aftervals'" & "`fmt'"=="`afterfmt'"
    assert `"`xlab'"'==`"`afterlab'"'
    qa_state_snapshot, tag(comp_dry)
    quietly compress_tc, quietly dryrun lowmem
    qa_state_compare, tag(comp_dry)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Labelled values storage and dryrun label_gaps; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Labelled values storage and dryrun label_gaps"
}

**# Labelled values storage and dryrun miss_all_column
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(miss_all_column)
    tempfile source
    quietly save `source'
    local vals : value label group
    local fmt : format date
    local xlab : variable label x
    quietly compress_tc, quietly
    assert !missing(r(bytes_initial),r(bytes_final),r(bytes_saved),r(pct_saved))
    assert r(bytes_initial)-r(bytes_final)==r(bytes_saved)
    assert r(bytes_saved)>=0 & inrange(r(pct_saved),0,100)
    cf _all using `source'
    local aftervals : value label group
    local afterfmt : format date
    local afterlab : variable label x
    assert "`vals'"=="`aftervals'" & "`fmt'"=="`afterfmt'"
    assert `"`xlab'"'==`"`afterlab'"'
    qa_state_snapshot, tag(comp_dry)
    quietly compress_tc, quietly dryrun lowmem
    qa_state_compare, tag(comp_dry)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Labelled values storage and dryrun miss_all_column; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Labelled values storage and dryrun miss_all_column"
}

**# Labelled values storage and dryrun single_row
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(single_row)
    tempfile source
    quietly save `source'
    local vals : value label group
    local fmt : format date
    local xlab : variable label x
    quietly compress_tc, quietly
    assert !missing(r(bytes_initial),r(bytes_final),r(bytes_saved),r(pct_saved))
    assert r(bytes_initial)-r(bytes_final)==r(bytes_saved)
    assert r(bytes_saved)>=0 & inrange(r(pct_saved),0,100)
    cf _all using `source'
    local aftervals : value label group
    local afterfmt : format date
    local afterlab : variable label x
    assert "`vals'"=="`aftervals'" & "`fmt'"=="`afterfmt'"
    assert `"`xlab'"'==`"`afterlab'"'
    qa_state_snapshot, tag(comp_dry)
    quietly compress_tc, quietly dryrun lowmem
    qa_state_compare, tag(comp_dry)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Labelled values storage and dryrun single_row; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Labelled values storage and dryrun single_row"
}

**# Labelled values storage and dryrun boundary_values
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(boundary_values)
    tempfile source
    quietly save `source'
    local vals : value label group
    local fmt : format date
    local xlab : variable label x
    quietly compress_tc, quietly
    assert !missing(r(bytes_initial),r(bytes_final),r(bytes_saved),r(pct_saved))
    assert r(bytes_initial)-r(bytes_final)==r(bytes_saved)
    assert r(bytes_saved)>=0 & inrange(r(pct_saved),0,100)
    cf _all using `source'
    local aftervals : value label group
    local afterfmt : format date
    local afterlab : variable label x
    assert "`vals'"=="`aftervals'" & "`fmt'"=="`afterfmt'"
    assert `"`xlab'"'==`"`afterlab'"'
    qa_state_snapshot, tag(comp_dry)
    quietly compress_tc, quietly dryrun lowmem
    qa_state_compare, tag(comp_dry)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Labelled values storage and dryrun boundary_values; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Labelled values storage and dryrun boundary_values"
}

**# Labelled values storage and dryrun unsorted
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    tempfile source
    quietly save `source'
    local vals : value label group
    local fmt : format date
    local xlab : variable label x
    quietly compress_tc, quietly
    assert !missing(r(bytes_initial),r(bytes_final),r(bytes_saved),r(pct_saved))
    assert r(bytes_initial)-r(bytes_final)==r(bytes_saved)
    assert r(bytes_saved)>=0 & inrange(r(pct_saved),0,100)
    cf _all using `source'
    local aftervals : value label group
    local afterfmt : format date
    local afterlab : variable label x
    assert "`vals'"=="`aftervals'" & "`fmt'"=="`afterfmt'"
    assert `"`xlab'"'==`"`afterlab'"'
    qa_state_snapshot, tag(comp_dry)
    quietly compress_tc, quietly dryrun lowmem
    qa_state_compare, tag(comp_dry)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Labelled values storage and dryrun unsorted; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Labelled values storage and dryrun unsorted"
}

**# Invalid compression options preserve caller
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    * expect: REFUSED
    qa_state_snapshot, tag(comp_bad)
    capture noisily compress_tc, nostrl nocompress
    assert _rc==198
    qa_state_compare, tag(comp_bad)

}
local outcome=_rc

if `outcome' {
    local ++fail
    display as error "FAIL: Invalid compression options preserve caller; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Invalid compression options preserve caller"
}

display "RESULT: validation_compress_tc_fixture_contract tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
