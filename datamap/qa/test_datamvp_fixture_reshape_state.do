*! test_datamvp_fixture_reshape_state.do -- caller native reshape globals are opaque state
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using test_datamvp_fixture_reshape_state.log, text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_state.do
* Native inventory: installed base/r/reshape.ado globals/drop at9,190,257,898,
*915,1174,1294,1507-1514,1569; names preserved as opaque caller state.
local native S_1 S_2 S_FN S_FNDATE S_1_full ReS_Call ReS_j ReS_jv ReS_jv2 ReS_i ReS_Xij Res_Xi ReS_atwl ReS_str rVANS rtmpST
local tests 0
local pass 0
local fail 0

**# absent matrix
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37)
    generate double a=y
    generate double b=y
    replace a=. if inrange(id,1,10)
    replace b=. if inrange(id,6,15)
    foreach g of local native {
        macro drop `g'
    }
    qa_state_snapshot, tag(reshape_state)
    quietly datamvp a b, nodrop graph(matrix) gname(reshape_matrix) nodraw
    assert r(N)==40 & r(N_mv_total)==20
    qa_state_compare, tag(reshape_state)
    preserve
    keep id
    generate double v1=11
    generate double v2=22
    quietly reshape long v, i(id) j(wave)
    assert _N==80 & v==11*wave
    isid id wave
    restore
}
local outcome=_rc
capture graph drop reshape_matrix
if `outcome' {
    local ++fail
    display as error "FAIL: absent matrix rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: absent matrix"
}

**# absent patterns
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37)
    generate double a=y
    generate double b=y
    replace a=. if inrange(id,1,10)
    replace b=. if inrange(id,6,15)
    foreach g of local native {
        macro drop `g'
    }
    qa_state_snapshot, tag(reshape_state)
    quietly datamvp a b, nodrop graph(patterns) gname(reshape_matrix) nodraw
    assert r(N)==40 & r(N_mv_total)==20
    qa_state_compare, tag(reshape_state)
    preserve
    keep id
    generate double v1=11
    generate double v2=22
    quietly reshape long v, i(id) j(wave)
    assert _N==80 & v==11*wave
    isid id wave
    restore
}
local outcome=_rc
capture graph drop reshape_matrix
if `outcome' {
    local ++fail
    display as error "FAIL: absent patterns rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: absent patterns"
}

**# absent correlation
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37)
    generate double a=y
    generate double b=y
    replace a=. if inrange(id,1,10)
    replace b=. if inrange(id,6,15)
    foreach g of local native {
        macro drop `g'
    }
    qa_state_snapshot, tag(reshape_state)
    quietly datamvp a b, nodrop graph(correlation) gname(reshape_matrix) nodraw
    assert r(N)==40 & r(N_mv_total)==20
    qa_state_compare, tag(reshape_state)
    preserve
    keep id
    generate double v1=11
    generate double v2=22
    quietly reshape long v, i(id) j(wave)
    assert _N==80 & v==11*wave
    isid id wave
    restore
}
local outcome=_rc
capture graph drop reshape_matrix
if `outcome' {
    local ++fail
    display as error "FAIL: absent correlation rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: absent correlation"
}

**# absent no_missing
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37)
    generate double a=y
    generate double b=y
    replace a=. if inrange(id,1,10)
    replace b=. if inrange(id,6,15)
    foreach g of local native {
        macro drop `g'
    }
    qa_state_snapshot, tag(reshape_state)
    quietly datamvp x
    assert r(N)==40 & r(N_mv_total)==0
    qa_state_compare, tag(reshape_state)
    preserve
    keep id
    generate double v1=11
    generate double v2=22
    quietly reshape long v, i(id) j(wave)
    assert _N==80 & v==11*wave
    isid id wave
    restore
}
local outcome=_rc
capture graph drop reshape_matrix
if `outcome' {
    local ++fail
    display as error "FAIL: absent no_missing rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: absent no_missing"
}

**# absent early
local ++tests
capture noisily {
    * expect: REFUSED
    qa_fx_a7_labelled, clear seed(37)
    generate double a=y
    generate double b=y
    replace a=. if inrange(id,1,10)
    replace b=. if inrange(id,6,15)
    foreach g of local native {
        macro drop `g'
    }
    qa_state_snapshot, tag(reshape_state)
    capture noisily datamvp a b, groupgap(.) graph(matrix)
    assert _rc==198
    qa_state_compare, tag(reshape_state)
    preserve
    keep id
    generate double v1=11
    generate double v2=22
    quietly reshape long v, i(id) j(wave)
    assert _N==80 & v==11*wave
    isid id wave
    restore
}
local outcome=_rc
capture graph drop reshape_matrix
if `outcome' {
    local ++fail
    display as error "FAIL: absent early rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: absent early"
}

**# absent late
local ++tests
capture noisily {
    * expect: REFUSED
    qa_fx_a7_labelled, clear seed(37)
    generate double a=y
    generate double b=y
    replace a=. if inrange(id,1,10)
    replace b=. if inrange(id,6,15)
    foreach g of local native {
        macro drop `g'
    }
    qa_state_snapshot, tag(reshape_state)
    capture noisily datamvp a b, nodrop graph(matrix) gname(reshape_matrix) nodraw graphoptions(qa_invalid_graph_option)
    assert _rc==198
    qa_state_compare, tag(reshape_state)
    preserve
    keep id
    generate double v1=11
    generate double v2=22
    quietly reshape long v, i(id) j(wave)
    assert _N==80 & v==11*wave
    isid id wave
    restore
}
local outcome=_rc
capture graph drop reshape_matrix
if `outcome' {
    local ++fail
    display as error "FAIL: absent late rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: absent late"
}

**# opaque matrix
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37)
    generate double a=y
    generate double b=y
    replace a=. if inrange(id,1,10)
    replace b=. if inrange(id,6,15)
    python: from sfi import Macro; [Macro.setGlobal(g,"opaque "+g+" "+chr(36)+"NOT_A_GLOBAL "+chr(96)+"not_a_local"+chr(39)+" "+chr(34)+" Å") for g in Macro.getLocal("native").split()]
    qa_state_snapshot, tag(reshape_state)
    quietly datamvp a b, nodrop graph(matrix) gname(reshape_matrix) nodraw
    assert r(N)==40 & r(N_mv_total)==20
    qa_state_compare, tag(reshape_state)
    preserve
    keep id
    generate double v1=11
    generate double v2=22
    quietly reshape long v, i(id) j(wave)
    assert _N==80 & v==11*wave
    isid id wave
    restore
}
local outcome=_rc
capture graph drop reshape_matrix
if `outcome' {
    local ++fail
    display as error "FAIL: opaque matrix rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: opaque matrix"
}

**# opaque patterns
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37)
    generate double a=y
    generate double b=y
    replace a=. if inrange(id,1,10)
    replace b=. if inrange(id,6,15)
    python: from sfi import Macro; [Macro.setGlobal(g,"opaque "+g+" "+chr(36)+"NOT_A_GLOBAL "+chr(96)+"not_a_local"+chr(39)+" "+chr(34)+" Å") for g in Macro.getLocal("native").split()]
    qa_state_snapshot, tag(reshape_state)
    quietly datamvp a b, nodrop graph(patterns) gname(reshape_matrix) nodraw
    assert r(N)==40 & r(N_mv_total)==20
    qa_state_compare, tag(reshape_state)
    preserve
    keep id
    generate double v1=11
    generate double v2=22
    quietly reshape long v, i(id) j(wave)
    assert _N==80 & v==11*wave
    isid id wave
    restore
}
local outcome=_rc
capture graph drop reshape_matrix
if `outcome' {
    local ++fail
    display as error "FAIL: opaque patterns rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: opaque patterns"
}

**# opaque correlation
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37)
    generate double a=y
    generate double b=y
    replace a=. if inrange(id,1,10)
    replace b=. if inrange(id,6,15)
    python: from sfi import Macro; [Macro.setGlobal(g,"opaque "+g+" "+chr(36)+"NOT_A_GLOBAL "+chr(96)+"not_a_local"+chr(39)+" "+chr(34)+" Å") for g in Macro.getLocal("native").split()]
    qa_state_snapshot, tag(reshape_state)
    quietly datamvp a b, nodrop graph(correlation) gname(reshape_matrix) nodraw
    assert r(N)==40 & r(N_mv_total)==20
    qa_state_compare, tag(reshape_state)
    preserve
    keep id
    generate double v1=11
    generate double v2=22
    quietly reshape long v, i(id) j(wave)
    assert _N==80 & v==11*wave
    isid id wave
    restore
}
local outcome=_rc
capture graph drop reshape_matrix
if `outcome' {
    local ++fail
    display as error "FAIL: opaque correlation rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: opaque correlation"
}

**# opaque no_missing
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37)
    generate double a=y
    generate double b=y
    replace a=. if inrange(id,1,10)
    replace b=. if inrange(id,6,15)
    python: from sfi import Macro; [Macro.setGlobal(g,"opaque "+g+" "+chr(36)+"NOT_A_GLOBAL "+chr(96)+"not_a_local"+chr(39)+" "+chr(34)+" Å") for g in Macro.getLocal("native").split()]
    qa_state_snapshot, tag(reshape_state)
    quietly datamvp x
    assert r(N)==40 & r(N_mv_total)==0
    qa_state_compare, tag(reshape_state)
    preserve
    keep id
    generate double v1=11
    generate double v2=22
    quietly reshape long v, i(id) j(wave)
    assert _N==80 & v==11*wave
    isid id wave
    restore
}
local outcome=_rc
capture graph drop reshape_matrix
if `outcome' {
    local ++fail
    display as error "FAIL: opaque no_missing rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: opaque no_missing"
}

**# opaque early
local ++tests
capture noisily {
    * expect: REFUSED
    qa_fx_a7_labelled, clear seed(37)
    generate double a=y
    generate double b=y
    replace a=. if inrange(id,1,10)
    replace b=. if inrange(id,6,15)
    python: from sfi import Macro; [Macro.setGlobal(g,"opaque "+g+" "+chr(36)+"NOT_A_GLOBAL "+chr(96)+"not_a_local"+chr(39)+" "+chr(34)+" Å") for g in Macro.getLocal("native").split()]
    qa_state_snapshot, tag(reshape_state)
    capture noisily datamvp a b, groupgap(.) graph(matrix)
    assert _rc==198
    qa_state_compare, tag(reshape_state)
    preserve
    keep id
    generate double v1=11
    generate double v2=22
    quietly reshape long v, i(id) j(wave)
    assert _N==80 & v==11*wave
    isid id wave
    restore
}
local outcome=_rc
capture graph drop reshape_matrix
if `outcome' {
    local ++fail
    display as error "FAIL: opaque early rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: opaque early"
}

**# opaque late
local ++tests
capture noisily {
    * expect: REFUSED
    qa_fx_a7_labelled, clear seed(37)
    generate double a=y
    generate double b=y
    replace a=. if inrange(id,1,10)
    replace b=. if inrange(id,6,15)
    python: from sfi import Macro; [Macro.setGlobal(g,"opaque "+g+" "+chr(36)+"NOT_A_GLOBAL "+chr(96)+"not_a_local"+chr(39)+" "+chr(34)+" Å") for g in Macro.getLocal("native").split()]
    qa_state_snapshot, tag(reshape_state)
    capture noisily datamvp a b, nodrop graph(matrix) gname(reshape_matrix) nodraw graphoptions(qa_invalid_graph_option)
    assert _rc==198
    qa_state_compare, tag(reshape_state)
    preserve
    keep id
    generate double v1=11
    generate double v2=22
    quietly reshape long v, i(id) j(wave)
    assert _N==80 & v==11*wave
    isid id wave
    restore
}
local outcome=_rc
capture graph drop reshape_matrix
if `outcome' {
    local ++fail
    display as error "FAIL: opaque late rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: opaque late"
}

**# absent bar
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37)
    generate double a=y
    generate double b=y
    replace a=. if inrange(id,1,10)
    replace b=. if inrange(id,6,15)
    foreach g of local native {
        macro drop `g'
    }
    qa_state_snapshot, tag(reshape_state)
    quietly datamvp a b, nodrop graph(bar) gname(reshape_matrix) nodraw
    assert r(N)==40 & r(N_mv_total)==20
    qa_state_compare, tag(reshape_state)
    preserve
    keep id
    generate double v1=11
    generate double v2=22
    quietly reshape long v, i(id) j(wave)
    assert _N==80 & v==11*wave
    isid id wave
    restore
}
local outcome=_rc
capture graph drop reshape_matrix
if `outcome' {
    local ++fail
    display as error "FAIL: absent bar rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: absent bar"
}

**# opaque bar
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37)
    generate double a=y
    generate double b=y
    replace a=. if inrange(id,1,10)
    replace b=. if inrange(id,6,15)
    python: from sfi import Macro; [Macro.setGlobal(g,"opaque "+g+" "+chr(36)+"NOT_A_GLOBAL "+chr(96)+"not_a_local"+chr(39)+" "+chr(34)+" Å") for g in Macro.getLocal("native").split()]
    qa_state_snapshot, tag(reshape_state)
    quietly datamvp a b, nodrop graph(bar) gname(reshape_matrix) nodraw
    assert r(N)==40 & r(N_mv_total)==20
    qa_state_compare, tag(reshape_state)
    preserve
    keep id
    generate double v1=11
    generate double v2=22
    quietly reshape long v, i(id) j(wave)
    assert _N==80 & v==11*wave
    isid id wave
    restore
}
local outcome=_rc
capture graph drop reshape_matrix
if `outcome' {
    local ++fail
    display as error "FAIL: opaque bar rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: opaque bar"
}


**# real filename bar
local ++tests
local root ""
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local source `"`root'/caller source Å.dta"'
    qa_fx_a7_labelled, clear seed(37)
    generate double a=y
    generate double b=y
    replace a=. if inrange(id,1,10)
    replace b=. if inrange(id,6,15)
    quietly save `"`source'"', replace
    quietly use `"`source'"', clear
    assert `"`c(filename)'"'==`"`source'"'
    qa_state_snapshot, tag(real_file)
    quietly datamvp a b, nodrop graph(bar) gname(real_file) nodraw
    assert r(N)==40 & r(N_mv_total)==20 & r(N_complete)==25
    qa_state_compare, tag(real_file)
    assert `"`c(filename)'"'==`"`source'"'
    quietly scatter y x, name(next_native, replace) nodraw
    preserve
    serset use, clear
    assert _N==40 & x==_n & y==mod(x,2)
    restore
}
local outcome=_rc
capture restore
capture graph drop real_file next_native
if `"`root'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: real filename bar rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: real filename bar"
}

**# real filename patterns
local ++tests
local root ""
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local source `"`root'/caller source Å.dta"'
    qa_fx_a7_labelled, clear seed(37)
    generate double a=y
    generate double b=y
    replace a=. if inrange(id,1,10)
    replace b=. if inrange(id,6,15)
    quietly save `"`source'"', replace
    quietly use `"`source'"', clear
    assert `"`c(filename)'"'==`"`source'"'
    qa_state_snapshot, tag(real_file)
    quietly datamvp a b, nodrop graph(patterns) gname(real_file) nodraw
    assert r(N)==40 & r(N_mv_total)==20 & r(N_complete)==25
    qa_state_compare, tag(real_file)
    assert `"`c(filename)'"'==`"`source'"'
    quietly scatter y x, name(next_native, replace) nodraw
    preserve
    serset use, clear
    assert _N==40 & x==_n & y==mod(x,2)
    restore
}
local outcome=_rc
capture restore
capture graph drop real_file next_native
if `"`root'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: real filename patterns rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: real filename patterns"
}

**# real filename matrix
local ++tests
local root ""
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local source `"`root'/caller source Å.dta"'
    qa_fx_a7_labelled, clear seed(37)
    generate double a=y
    generate double b=y
    replace a=. if inrange(id,1,10)
    replace b=. if inrange(id,6,15)
    quietly save `"`source'"', replace
    quietly use `"`source'"', clear
    assert `"`c(filename)'"'==`"`source'"'
    qa_state_snapshot, tag(real_file)
    quietly datamvp a b, nodrop graph(matrix) gname(real_file) nodraw
    assert r(N)==40 & r(N_mv_total)==20 & r(N_complete)==25
    qa_state_compare, tag(real_file)
    assert `"`c(filename)'"'==`"`source'"'
    quietly scatter y x, name(next_native, replace) nodraw
    preserve
    serset use, clear
    assert _N==40 & x==_n & y==mod(x,2)
    restore
}
local outcome=_rc
capture restore
capture graph drop real_file next_native
if `"`root'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: real filename matrix rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: real filename matrix"
}

**# real filename correlation
local ++tests
local root ""
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local source `"`root'/caller source Å.dta"'
    qa_fx_a7_labelled, clear seed(37)
    generate double a=y
    generate double b=y
    replace a=. if inrange(id,1,10)
    replace b=. if inrange(id,6,15)
    quietly save `"`source'"', replace
    quietly use `"`source'"', clear
    assert `"`c(filename)'"'==`"`source'"'
    qa_state_snapshot, tag(real_file)
    quietly datamvp a b, nodrop graph(correlation) gname(real_file) nodraw
    assert r(N)==40 & r(N_mv_total)==20 & r(N_complete)==25
    qa_state_compare, tag(real_file)
    assert `"`c(filename)'"'==`"`source'"'
    quietly scatter y x, name(next_native, replace) nodraw
    preserve
    serset use, clear
    assert _N==40 & x==_n & y==mod(x,2)
    restore
}
local outcome=_rc
capture restore
capture graph drop real_file next_native
if `"`root'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: real filename correlation rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: real filename correlation"
}

**# absent late pattern file I/O
local ++tests
local root ""
capture noisily {
    * expect: REFUSED
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local output `"`root'/absent/patterns.dta"'
    python: from pathlib import Path; from sfi import Macro; _rs_tree={str(p.relative_to(Path(Macro.getLocal("root")))):p.read_bytes() for p in Path(Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_fx_a7_labelled, clear seed(37)
    foreach g of local native {
        macro drop `g'
    }
    qa_state_snapshot, tag(pattern_save)
    capture noisily datamvp x all_missing extended, nodrop save(`"`macval(output)'"')
    assert _rc==603
    qa_state_compare, tag(pattern_save)
    python: assert _rs_tree=={str(p.relative_to(Path(Macro.getLocal("root")))):p.read_bytes() for p in Path(Macro.getLocal("root")).rglob("*") if p.is_file()}
}
local outcome=_rc
capture restore
if `"`root'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: absent late pattern file I/O rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: absent late pattern file I/O"
}

**# opaque late pattern file I/O
local ++tests
local root ""
capture noisily {
    * expect: REFUSED
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local output `"`root'/absent/patterns.dta"'
    python: from pathlib import Path; from sfi import Macro; _rs_tree={str(p.relative_to(Path(Macro.getLocal("root")))):p.read_bytes() for p in Path(Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_fx_a7_labelled, clear seed(37)
    python: from sfi import Macro; [Macro.setGlobal(g,"opaque "+g+" "+chr(36)+"NOT_A_GLOBAL "+chr(96)+"not_a_local"+chr(39)+" "+chr(34)+" Å") for g in Macro.getLocal("native").split()]
    qa_state_snapshot, tag(pattern_save)
    capture noisily datamvp x all_missing extended, nodrop save(`"`macval(output)'"')
    assert _rc==603
    qa_state_compare, tag(pattern_save)
    python: assert _rs_tree=={str(p.relative_to(Path(Macro.getLocal("root")))):p.read_bytes() for p in Path(Macro.getLocal("root")).rglob("*") if p.is_file()}
}
local outcome=_rc
capture restore
if `"`root'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: opaque late pattern file I/O rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: opaque late pattern file I/O"
}

**# caller external preserve success
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37)
    preserve
    replace y=999
    qa_state_snapshot, tag(external_hold)
    quietly datamvp x all_missing extended, nodrop graph(matrix) gname(external_hold) nodraw
    assert r(N)==40 & r(N_mv_total)==80
    qa_state_compare, tag(external_hold)
    restore
    assert _N==40 & y==mod(id,2)
}
local outcome=_rc
capture restore
capture graph drop external_hold
if `outcome' {
    local ++fail
    display as error "FAIL: caller external preserve success rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: caller external preserve success"
}

**# caller external preserve early
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37)
    preserve
    replace y=999
    qa_state_snapshot, tag(external_hold)
    capture noisily datamvp x all_missing extended, groupgap(.) graph(bar) over(group)
    assert _rc==198
    qa_state_compare, tag(external_hold)
    restore
    assert _N==40 & y==mod(id,2)
}
local outcome=_rc
capture restore
capture graph drop external_hold
if `outcome' {
    local ++fail
    display as error "FAIL: caller external preserve early rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: caller external preserve early"
}

**# caller external preserve late
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37)
    preserve
    replace y=999
    qa_state_snapshot, tag(external_hold)
    capture noisily datamvp x all_missing extended, nodrop graph(matrix) gname(external_hold) nodraw graphoptions(qa_invalid_graph_option)
    assert _rc==198
    qa_state_compare, tag(external_hold)
    restore
    assert _N==40 & y==mod(id,2)
}
local outcome=_rc
capture restore
capture graph drop external_hold
if `outcome' {
    local ++fail
    display as error "FAIL: caller external preserve late rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: caller external preserve late"
}
display "RESULT: test_datamvp_fixture_reshape_state tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
