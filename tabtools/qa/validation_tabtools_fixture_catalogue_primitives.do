*! validation_tabtools_fixture_catalogue_primitives.do -- exact dataset-independent catalogues and caller state
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using validation_tabtools_fixture_catalogue_primitives.log, text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_hostile.do
do _qa_state.do
local tests 0
local pass 0
local fail 0

**# tabtools names
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_hostile_names, clear
    * Catalogue text is independent of caller data. Full fingerprints prove
    * these actual hostile datasets/opaque strings survive the public command.
    qa_state_snapshot, tag(tt_catalogue)
    quietly tabtools, list category(all)
    assert r(n_commands)==17
    assert `"`r(commands)'"'=="table1_tc desctab crosstab corrtab regtab effecttab tabcell outtab stratetab ratetab survtab comptab hrcomptab puttab stacktab tabtools tabtools_tips"
    assert `"`r(categories)'"'=="descriptive models rates survival composite export general"
    qa_state_compare, tag(tt_catalogue)
}
local outcome=_rc
capture log close tips_receipt
if `outcome' {
    local ++fail
    display as error "FAIL: tabtools names rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: tabtools names"
}

**# tabtools codes
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_hostile_codes, clear
    * Catalogue text is independent of caller data. Full fingerprints prove
    * these actual hostile datasets/opaque strings survive the public command.
    qa_state_snapshot, tag(tt_catalogue)
    quietly tabtools, list category(all)
    assert r(n_commands)==17
    assert `"`r(commands)'"'=="table1_tc desctab crosstab corrtab regtab effecttab tabcell outtab stratetab ratetab survtab comptab hrcomptab puttab stacktab tabtools tabtools_tips"
    assert `"`r(categories)'"'=="descriptive models rates survival composite export general"
    qa_state_compare, tag(tt_catalogue)
}
local outcome=_rc
capture log close tips_receipt
if `outcome' {
    local ++fail
    display as error "FAIL: tabtools codes rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: tabtools codes"
}

**# tabtools strings
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
    * Catalogue text is independent of caller data. Full fingerprints prove
    * these actual hostile datasets/opaque strings survive the public command.
    qa_state_snapshot, tag(tt_catalogue)
    quietly tabtools, list category(all)
    assert r(n_commands)==17
    assert `"`r(commands)'"'=="table1_tc desctab crosstab corrtab regtab effecttab tabcell outtab stratetab ratetab survtab comptab hrcomptab puttab stacktab tabtools tabtools_tips"
    assert `"`r(categories)'"'=="descriptive models rates survival composite export general"
    qa_state_compare, tag(tt_catalogue)
}
local outcome=_rc
capture log close tips_receipt
if `outcome' {
    local ++fail
    display as error "FAIL: tabtools strings rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: tabtools strings"
}

**# tabtools label_gaps
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    * Catalogue text is independent of caller data. Full fingerprints prove
    * these actual hostile datasets/opaque strings survive the public command.
    qa_state_snapshot, tag(tt_catalogue)
    quietly tabtools, list category(all)
    assert r(n_commands)==17
    assert `"`r(commands)'"'=="table1_tc desctab crosstab corrtab regtab effecttab tabcell outtab stratetab ratetab survtab comptab hrcomptab puttab stacktab tabtools tabtools_tips"
    assert `"`r(categories)'"'=="descriptive models rates survival composite export general"
    qa_state_compare, tag(tt_catalogue)
}
local outcome=_rc
capture log close tips_receipt
if `outcome' {
    local ++fail
    display as error "FAIL: tabtools label_gaps rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: tabtools label_gaps"
}

**# tabtools miss_all_column
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(miss_all_column)
    * Catalogue text is independent of caller data. Full fingerprints prove
    * these actual hostile datasets/opaque strings survive the public command.
    qa_state_snapshot, tag(tt_catalogue)
    quietly tabtools, list category(all)
    assert r(n_commands)==17
    assert `"`r(commands)'"'=="table1_tc desctab crosstab corrtab regtab effecttab tabcell outtab stratetab ratetab survtab comptab hrcomptab puttab stacktab tabtools tabtools_tips"
    assert `"`r(categories)'"'=="descriptive models rates survival composite export general"
    qa_state_compare, tag(tt_catalogue)
}
local outcome=_rc
capture log close tips_receipt
if `outcome' {
    local ++fail
    display as error "FAIL: tabtools miss_all_column rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: tabtools miss_all_column"
}

**# tabtools single_row
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(single_row)
    * Catalogue text is independent of caller data. Full fingerprints prove
    * these actual hostile datasets/opaque strings survive the public command.
    qa_state_snapshot, tag(tt_catalogue)
    quietly tabtools, list category(all)
    assert r(n_commands)==17
    assert `"`r(commands)'"'=="table1_tc desctab crosstab corrtab regtab effecttab tabcell outtab stratetab ratetab survtab comptab hrcomptab puttab stacktab tabtools tabtools_tips"
    assert `"`r(categories)'"'=="descriptive models rates survival composite export general"
    qa_state_compare, tag(tt_catalogue)
}
local outcome=_rc
capture log close tips_receipt
if `outcome' {
    local ++fail
    display as error "FAIL: tabtools single_row rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: tabtools single_row"
}

**# tabtools_tips names
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_hostile_names, clear
    * Catalogue text is independent of caller data. Full fingerprints prove
    * these actual hostile datasets/opaque strings survive the public command.
    qa_state_snapshot, tag(tt_catalogue)
    tempfile transcript
    log using "`transcript'", text replace name(tips_receipt)
    noisily tabtools_tips
    log close tips_receipt
    qa_state_compare, tag(tt_catalogue)
    python: _t=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("transcript")).read_text(); assert "tabtools tips - quick reference and worked recipes" in _t and "Merged guide: help tabtools_tips" in _t and "Option patterns by command: quick reference" in _t and "End-to-end workflows: recipes" in _t
}
local outcome=_rc
capture log close tips_receipt
if `outcome' {
    local ++fail
    display as error "FAIL: tabtools_tips names rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: tabtools_tips names"
}

**# tabtools_tips codes
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_hostile_codes, clear
    * Catalogue text is independent of caller data. Full fingerprints prove
    * these actual hostile datasets/opaque strings survive the public command.
    qa_state_snapshot, tag(tt_catalogue)
    tempfile transcript
    log using "`transcript'", text replace name(tips_receipt)
    noisily tabtools_tips
    log close tips_receipt
    qa_state_compare, tag(tt_catalogue)
    python: _t=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("transcript")).read_text(); assert "tabtools tips - quick reference and worked recipes" in _t and "Merged guide: help tabtools_tips" in _t and "Option patterns by command: quick reference" in _t and "End-to-end workflows: recipes" in _t
}
local outcome=_rc
capture log close tips_receipt
if `outcome' {
    local ++fail
    display as error "FAIL: tabtools_tips codes rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: tabtools_tips codes"
}

**# tabtools_tips strings
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
    * Catalogue text is independent of caller data. Full fingerprints prove
    * these actual hostile datasets/opaque strings survive the public command.
    qa_state_snapshot, tag(tt_catalogue)
    tempfile transcript
    log using "`transcript'", text replace name(tips_receipt)
    noisily tabtools_tips
    log close tips_receipt
    qa_state_compare, tag(tt_catalogue)
    python: _t=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("transcript")).read_text(); assert "tabtools tips - quick reference and worked recipes" in _t and "Merged guide: help tabtools_tips" in _t and "Option patterns by command: quick reference" in _t and "End-to-end workflows: recipes" in _t
}
local outcome=_rc
capture log close tips_receipt
if `outcome' {
    local ++fail
    display as error "FAIL: tabtools_tips strings rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: tabtools_tips strings"
}

**# tabtools_tips label_gaps
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    * Catalogue text is independent of caller data. Full fingerprints prove
    * these actual hostile datasets/opaque strings survive the public command.
    qa_state_snapshot, tag(tt_catalogue)
    tempfile transcript
    log using "`transcript'", text replace name(tips_receipt)
    noisily tabtools_tips
    log close tips_receipt
    qa_state_compare, tag(tt_catalogue)
    python: _t=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("transcript")).read_text(); assert "tabtools tips - quick reference and worked recipes" in _t and "Merged guide: help tabtools_tips" in _t and "Option patterns by command: quick reference" in _t and "End-to-end workflows: recipes" in _t
}
local outcome=_rc
capture log close tips_receipt
if `outcome' {
    local ++fail
    display as error "FAIL: tabtools_tips label_gaps rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: tabtools_tips label_gaps"
}

**# tabtools_tips miss_all_column
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(miss_all_column)
    * Catalogue text is independent of caller data. Full fingerprints prove
    * these actual hostile datasets/opaque strings survive the public command.
    qa_state_snapshot, tag(tt_catalogue)
    tempfile transcript
    log using "`transcript'", text replace name(tips_receipt)
    noisily tabtools_tips
    log close tips_receipt
    qa_state_compare, tag(tt_catalogue)
    python: _t=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("transcript")).read_text(); assert "tabtools tips - quick reference and worked recipes" in _t and "Merged guide: help tabtools_tips" in _t and "Option patterns by command: quick reference" in _t and "End-to-end workflows: recipes" in _t
}
local outcome=_rc
capture log close tips_receipt
if `outcome' {
    local ++fail
    display as error "FAIL: tabtools_tips miss_all_column rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: tabtools_tips miss_all_column"
}

**# tabtools_tips single_row
local ++tests
capture noisily {
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(single_row)
    * Catalogue text is independent of caller data. Full fingerprints prove
    * these actual hostile datasets/opaque strings survive the public command.
    qa_state_snapshot, tag(tt_catalogue)
    tempfile transcript
    log using "`transcript'", text replace name(tips_receipt)
    noisily tabtools_tips
    log close tips_receipt
    qa_state_compare, tag(tt_catalogue)
    python: _t=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("transcript")).read_text(); assert "tabtools tips - quick reference and worked recipes" in _t and "Merged guide: help tabtools_tips" in _t and "Option patterns by command: quick reference" in _t and "End-to-end workflows: recipes" in _t
}
local outcome=_rc
capture log close tips_receipt
if `outcome' {
    local ++fail
    display as error "FAIL: tabtools_tips single_row rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: tabtools_tips single_row"
}

display "RESULT: validation_tabtools_fixture_catalogue_primitives tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
